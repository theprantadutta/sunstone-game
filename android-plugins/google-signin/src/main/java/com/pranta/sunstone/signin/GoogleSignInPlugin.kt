package com.pranta.sunstone.signin

import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * "Sign in with Google" for Sunstone. Shows Android's own Google account
 * sheet (Credential Manager) and hands the game a Google ID token, which the
 * game passes to Firebase Auth to link the player's guest account.
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
}
