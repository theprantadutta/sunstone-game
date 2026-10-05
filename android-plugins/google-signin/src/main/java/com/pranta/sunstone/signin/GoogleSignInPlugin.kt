package com.pranta.sunstone.signin

import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import android.os.Build
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
 * account. And the display's refresh rate (see [setRefreshRate]).
 */
class GoogleSignInPlugin(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName() = "SunstoneGoogleSignIn"

    override fun getPluginSignals() = setOf(
        // id token, account email
        SignalInfo("signed_in", String::class.java, String::class.java),
        // reason: "cancelled" or a message
        SignalInfo("sign_in_failed", String::class.java),
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
