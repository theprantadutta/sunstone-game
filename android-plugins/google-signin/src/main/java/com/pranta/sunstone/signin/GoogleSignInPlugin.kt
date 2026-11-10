package com.pranta.sunstone.signin

import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import android.os.Bundle
import org.godotengine.godot.Dictionary
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
 * account. The display's refresh rate (see [setRefreshRate]). Play's
 * in-app updates (see [checkUpdate]). Sharing a run card. Notifications
 * through Firebase Cloud Messaging (see [initPush]). And Firebase Analytics
 * and Crashlytics (see [logEvent]); Firebase starts by itself from the
 * resources the export plugin writes out of google-services.json.
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
        // this phone's FCM token ("" when Firebase can't give one)
        SignalInfo("push_token", String::class.java),
        // whether notifications may show, after asking
        SignalInfo("push_permission", Boolean::class.javaObjectType),
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

    /**
     * Opens this game's page in the Google Play app (not a chooser between
     * stores), or on the web when Play isn't installed.
     */
    @UsedByGodot
    fun openStorePage() {
        val act = activity ?: return
        val id = act.packageName
        act.runOnUiThread {
            val play = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("market://details?id=$id"))
                .setPackage("com.android.vending")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                act.startActivity(play)
            } catch (e: android.content.ActivityNotFoundException) {
                act.startActivity(Intent(Intent.ACTION_VIEW,
                    android.net.Uri.parse("https://play.google.com/store/apps/details?id=$id")))
            }
        }
    }

    /**
     * Opens the share sheet with the image at [path] (a file the game wrote
     * under its files/ folder, shared through Godot's own FileProvider) and a
     * line of [text].
     */
    @UsedByGodot
    fun shareImage(path: String, text: String) {
        val act = activity ?: return
        act.runOnUiThread {
            try {
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    act, act.packageName + ".fileprovider", java.io.File(path))
                val send = Intent(Intent.ACTION_SEND)
                    .setType("image/jpeg")
                    .putExtra(Intent.EXTRA_STREAM, uri)
                    .putExtra(Intent.EXTRA_TEXT, text)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                // Clip data carries the read grant to the share sheet's own
                // preview as well as to the app the player picks.
                send.clipData = android.content.ClipData.newRawUri("", uri)
                act.startActivity(Intent.createChooser(send, null).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
            } catch (e: Exception) {
                // No file or no provider: share the words alone.
                val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
                act.startActivity(Intent.createChooser(send, null))
            }
        }
    }

    // ------------------------------------------------ analytics and crashes

    /**
     * Turns Analytics and Crashlytics on or off for this install (the game
     * switches them off in debug builds, so testing doesn't count).
     */
    @UsedByGodot
    fun setCollection(enabled: Boolean) {
        val act = activity ?: return
        try {
            FirebaseAnalytics.getInstance(act).setAnalyticsCollectionEnabled(enabled)
            FirebaseCrashlytics.getInstance().setCrashlyticsCollectionEnabled(enabled)
        } catch (e: Exception) {
            // Firebase not configured in this build (no google-services.json)
        }
    }

    /** One Analytics event; [params] values are strings, numbers or bools. */
    @UsedByGodot
    fun logEvent(name: String, params: Dictionary) {
        val act = activity ?: return
        try {
            val b = Bundle()
            for ((k, v) in params) {
                when (v) {
                    is String -> b.putString(k, v.take(100))
                    is Int -> b.putLong(k, v.toLong())
                    is Long -> b.putLong(k, v)
                    is Float -> b.putDouble(k, v.toDouble())
                    is Double -> b.putDouble(k, v)
                    is Boolean -> b.putLong(k, if (v) 1L else 0L)
                    null -> {}
                    else -> b.putString(k, v.toString().take(100))
                }
            }
            FirebaseAnalytics.getInstance(act).logEvent(name, b)
        } catch (e: Exception) {
        }
    }

    /** Our player id (a server GUID, nothing personal) on events and crashes. */
    @UsedByGodot
    fun setUser(id: String) {
        val act = activity ?: return
        try {
            FirebaseAnalytics.getInstance(act).setUserId(id.ifEmpty { null })
            FirebaseCrashlytics.getInstance().setUserId(id)
        } catch (e: Exception) {
        }
    }

    /** A line in the log that goes with the next crash report. */
    @UsedByGodot
    fun crashLog(line: String) {
        try {
            FirebaseCrashlytics.getInstance().log(line)
        } catch (e: Exception) {
        }
    }

    /**
     * A script or engine error as a Crashlytics non-fatal. [where] is
     * "file:line function", made the top frame so each error groups by place.
     */
    @UsedByGodot
    fun recordError(message: String, where: String) {
        try {
            val error = ScriptError(message)
            val file = where.substringBefore(':').ifEmpty { "godot" }
            val line = where.substringAfter(':', "0").substringBefore(' ').toIntOrNull() ?: 0
            val function = where.substringAfter(' ', "").ifEmpty { "?" }
            error.stackTrace = arrayOf(StackTraceElement("GDScript", function, file, line))
            FirebaseCrashlytics.getInstance().recordException(error)
        } catch (e: Exception) {
        }
    }

    class ScriptError(message: String) : Exception(message)

    // -------------------------------------------------------- notifications

    private val pushRequest = 7302

    /**
     * Starts Firebase with the game's own config (google-services.json, read
     * by the game — no Gradle plugin needed), makes the "dusk" channel and
     * answers with this phone's token ("push_token").
     */
    @UsedByGodot
    fun initPush(appId: String, apiKey: String, projectId: String, senderId: String) {
        val act = activity ?: return
        try {
            if (FirebaseApp.getApps(act).isEmpty()) {
                FirebaseApp.initializeApp(act.applicationContext, FirebaseOptions.Builder()
                    .setApplicationId(appId).setApiKey(apiKey).setProjectId(projectId).setGcmSenderId(senderId)
                    .build())
            }
            if (Build.VERSION.SDK_INT >= 26) {
                val channel = NotificationChannel("dusk", "Dusk reminders", NotificationManager.IMPORTANCE_DEFAULT)
                channel.description = "When dusk falls: the daily causeway, your offering, and news from Xibalba."
                act.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            }
            FirebaseMessaging.getInstance().token
                .addOnSuccessListener { emitSignal("push_token", it ?: "") }
                .addOnFailureListener { emitSignal("push_token", "") }
        } catch (e: Exception) {
            emitSignal("push_token", "")
        }
    }

    /** True when notifications can show (permission given, not switched off). */
    @UsedByGodot
    fun pushAllowed(): Boolean {
        val act = activity ?: return false
        return NotificationManagerCompat.from(act).areNotificationsEnabled()
    }

    /** Asks for the notification permission (Android 13+); answers with "push_permission". */
    @UsedByGodot
    fun requestPushPermission() {
        val act = activity ?: return
        if (Build.VERSION.SDK_INT < 33 ||
            ActivityCompat.checkSelfPermission(act, "android.permission.POST_NOTIFICATIONS") == PackageManager.PERMISSION_GRANTED) {
            emitSignal("push_permission", pushAllowed())
            return
        }
        act.runOnUiThread {
            ActivityCompat.requestPermissions(act, arrayOf("android.permission.POST_NOTIFICATIONS"), pushRequest)
        }
    }

    /** The game's page in the phone's notification settings (after a "no"). */
    @UsedByGodot
    fun openNotificationSettings() {
        val act = activity ?: return
        act.runOnUiThread {
            act.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, act.packageName))
        }
    }

    override fun onMainRequestPermissionsResult(requestCode: Int, permissions: Array<out String>?, grantResults: IntArray?) {
        super.onMainRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == pushRequest) {
            emitSignal("push_permission", grantResults?.firstOrNull() == PackageManager.PERMISSION_GRANTED)
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
