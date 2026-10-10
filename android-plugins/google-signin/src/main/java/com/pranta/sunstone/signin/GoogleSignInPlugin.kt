package com.pranta.sunstone.signin

import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import android.content.Intent
import android.os.Build
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Sunstone's own Android bits. "Sign in with Google": shows Android's own
 * Google account sheet (Credential Manager) and hands the game a Google ID
 * token, which the game passes to Firebase Auth to link the player's guest
 * account. The display's refresh rate (see [setRefreshRate]). And Play's
 * in-app updates (see [checkUpdate]).
 */
class GoogleSignInPlugin(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName() = "SunstoneGoogleSignIn"

    override fun getPluginSignals() = setOf(
        // id token, account email
        SignalInfo("signed_in", String::class.java, String::class.java),
        // reason: "cancelled" or a message
        SignalInfo("sign_in_failed", String::class.java),
        // available, priority (0-5, set when publishing), days since Play
        // learned of it (-1 = unknown), flexible allowed, immediate allowed
        SignalInfo("update_checked", Boolean::class.javaObjectType, Int::class.javaObjectType,
            Int::class.javaObjectType, Boolean::class.javaObjectType, Boolean::class.javaObjectType),
        // a flexible update finished downloading: completeUpdate() installs it
        SignalInfo("update_downloaded"),
        // reason
        SignalInfo("update_failed", String::class.java),
    )

    /** [webClientId] is the OAuth *web* client of the Firebase project. */
    @UsedByGodot
    fun signIn(webClientId: String) {
        val act = activity
        if (act == null) {
            emitSignal("sign_in_failed", "no activity")
            return
        }
        val request = GetCredentialRequest.Builder()
            .addCredentialOption(GetSignInWithGoogleOption.Builder(webClientId).build())
            .build()
        CoroutineScope(Dispatchers.Main).launch {
            try {
                val credential = CredentialManager.create(act).getCredential(act, request).credential
                if (credential is CustomCredential &&
                    credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                ) {
                    val google = GoogleIdTokenCredential.createFrom(credential.data)
                    emitSignal("signed_in", google.idToken, google.id)
                } else {
                    emitSignal("sign_in_failed", "unexpected credential")
                }
            } catch (e: GetCredentialCancellationException) {
                emitSignal("sign_in_failed", "cancelled")
            } catch (e: GetCredentialException) {
                emitSignal("sign_in_failed", e.message ?: e.type)
            }
        }
    }

    /**
     * Asks the display to run at [hz] (the game passes 60). On a phone with a
     * 90 or 120 Hz screen a game rendering 60–80 fps would otherwise land its
     * frames unevenly (judder); at 60 Hz every frame shows for the same time.
     *
     * Many phones list only their fast mode and offer 60 Hz as an
     * "alternative rate" of it, so pinning a display mode isn't enough: the
     * game's own drawing surface asks for [hz] (Surface.setFrameRate, Android
     * 11+), and the window prefers [hz] too. Returns every rate the display
     * offers, alternatives included, e.g. "60,90".
     */
    @UsedByGodot
    fun setRefreshRate(hz: Float): String {
        val act = activity ?: return ""
        val display = if (Build.VERSION.SDK_INT >= 30) act.display else @Suppress("DEPRECATION") act.windowManager.defaultDisplay
        val modes = display?.supportedModes ?: return ""
        val current = display.mode
        val rates = mutableSetOf<Int>()
        for (m in modes) {
            rates.add(m.refreshRate.roundToInt())
            if (Build.VERSION.SDK_INT >= 31) m.alternativeRefreshRates.forEach { rates.add(it.roundToInt()) }
        }
        // A real mode at [hz] with this resolution, if the display lists one.
        val exact = modes.firstOrNull {
            it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight &&
                abs(it.refreshRate - hz) < 1f
        }
        act.runOnUiThread {
            val lp = act.window.attributes
            if (exact != null) lp.preferredDisplayModeId = exact.modeId
            lp.preferredRefreshRate = hz
            act.window.attributes = lp
            if (Build.VERSION.SDK_INT >= 30) {
                findSurface(act.window.decorView)?.holder?.surface?.let {
                    if (it.isValid) it.setFrameRate(hz, Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE)
                }
            }
        }
        return rates.sorted().joinToString(",")
    }

    // ------------------------------------------------------------- updates

    private var updates: AppUpdateManager? = null
    private var lastInfo: AppUpdateInfo? = null
    private val updateRequest = 7301

    private val installListener = InstallStateUpdatedListener { state ->
        when (state.installStatus()) {
            InstallStatus.DOWNLOADED -> emitSignal("update_downloaded")
            InstallStatus.FAILED -> emitSignal("update_failed", "install failed (${state.installErrorCode()})")
            else -> {}
        }
    }

    private fun manager(): AppUpdateManager? {
        val act = activity ?: return null
        return updates ?: AppUpdateManagerFactory.create(act).also {
            it.registerListener(installListener)
            updates = it
        }
    }

    /** This build's version code (what Play compares against). */
    @UsedByGodot
    fun versionCode(): Int {
        val act = activity ?: return 0
        val info = act.packageManager.getPackageInfo(act.packageName, 0)
        return if (Build.VERSION.SDK_INT >= 28) info.longVersionCode.toInt() else @Suppress("DEPRECATION") info.versionCode
    }

    /** Asks Play whether a newer build is out; answers with "update_checked". */
    @UsedByGodot
    fun checkUpdate() {
        val m = manager()
        if (m == null) {
            emitSignal("update_checked", false, 0, -1, false, false)
            return
        }
        m.appUpdateInfo.addOnSuccessListener { info ->
            lastInfo = info
            if (info.installStatus() == InstallStatus.DOWNLOADED) {
                emitSignal("update_downloaded")
                return@addOnSuccessListener
            }
            val available = info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
            emitSignal("update_checked", available, info.updatePriority(), info.clientVersionStalenessDays() ?: -1,
                info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE), info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE))
        }.addOnFailureListener { e ->
            // Not installed from Play (a debug build), no Play Store, offline...
            emitSignal("update_checked", false, 0, -1, false, false)
        }
    }

    /**
     * Starts Play's update flow for the build [checkUpdate] found: [immediate]
     * takes over the screen until it's installed; otherwise it downloads in
     * the background ("update_downloaded" when it's ready).
     */
    @UsedByGodot
    fun startUpdate(immediate: Boolean): Boolean {
        val act = activity ?: return false
        val m = manager() ?: return false
        val info = lastInfo ?: return false
        val type = if (immediate) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
        if (!info.isUpdateTypeAllowed(type)) return false
        return try {
            act.runOnUiThread {
                @Suppress("DEPRECATION")
                m.startUpdateFlowForResult(info, act, AppUpdateOptions.newBuilder(type).build(), updateRequest)
            }
            true
        } catch (e: Exception) {
            emitSignal("update_failed", e.message ?: "could not start")
            false
        }
    }

    /** Installs a downloaded flexible update (the app restarts). */
    @UsedByGodot
    fun completeUpdate() {
        manager()?.completeUpdate()
    }

    override fun onMainActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onMainActivityResult(requestCode, resultCode, data)
        if (requestCode == updateRequest && resultCode != android.app.Activity.RESULT_OK) {
            emitSignal("update_failed", if (resultCode == android.app.Activity.RESULT_CANCELED) "declined" else "failed ($resultCode)")
        }
    }

    override fun onMainResume() {
        super.onMainResume()
        // Back from the background: an immediate update left half done carries
        // on, and a flexible one that finished meanwhile says so.
        val m = updates ?: return
        val act = activity ?: return
        m.appUpdateInfo.addOnSuccessListener { info ->
            lastInfo = info
            if (info.installStatus() == InstallStatus.DOWNLOADED) {
                emitSignal("update_downloaded")
            } else if (info.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
                @Suppress("DEPRECATION")
                m.startUpdateFlowForResult(info, act, AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(), updateRequest)
            }
        }
    }

    /** The game's drawing surface: the first SurfaceView under [v]. */
    private fun findSurface(v: View): SurfaceView? {
        if (v is SurfaceView) return v
        if (v is ViewGroup) {
            for (i in 0 until v.childCount) {
                findSurface(v.getChildAt(i))?.let { return it }
            }
        }
        return null
    }
}
