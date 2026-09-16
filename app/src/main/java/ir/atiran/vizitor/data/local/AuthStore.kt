package ir.atiran.vizitor.data.local

import android.content.Context
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Secure server-session storage. Access tokens are encrypted with Android Keystore AES-GCM. */
object AuthStore {
    private const val PREFS = "vizitor_auth"
    private const val KEY_TOKEN = "access_token"
    private const val KEY_USER = "username"
    private const val KEY_NAME = "display_name"
    private const val KEY_VISITOR = "visitor_code"
    private const val KEY_EXPIRES = "expires_at"
    private const val KS = "AndroidKeyStore"
    private const val ALIAS = "VizitorSessionKey"

    private lateinit var appContext: Context
    private val _loggedIn = MutableStateFlow(false)
    val loggedIn: StateFlow<Boolean> = _loggedIn.asStateFlow()

    fun init(context: Context) {
        appContext = context.applicationContext
        _loggedIn.value = isSessionValid()
    }

    fun deviceId(): String = Settings.Secure.getString(appContext.contentResolver, Settings.Secure.ANDROID_ID)
        ?: "unknown-device"

    fun token(): String = if (isSessionValid()) readToken() else ""
    fun isSessionValid(): Boolean {
        val t = readToken()
        if (t.isBlank()) return false
        val exp = prefs().getString(KEY_EXPIRES, "") ?: return false
        return runCatching {
            LocalDateTime.parse(exp, DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"))
                .toInstant(ZoneOffset.UTC).toEpochMilli() > System.currentTimeMillis()
        }.getOrDefault(false)
    }
    fun username(): String = prefs().getString(KEY_USER, "") ?: ""
    fun displayName(): String = prefs().getString(KEY_NAME, "") ?: ""
    fun visitorCode(): String = prefs().getString(KEY_VISITOR, "") ?: ""
    fun expiresAt(): String = prefs().getString(KEY_EXPIRES, "") ?: ""

    fun save(token: String, username: String, displayName: String, visitorCode: String, expiresAt: String) {
        prefs().edit()
            .putString(KEY_TOKEN, encrypt(token))
            .putString(KEY_USER, username)
            .putString(KEY_NAME, displayName)
            .putString(KEY_VISITOR, visitorCode)
            .putString(KEY_EXPIRES, expiresAt)
            .apply()
        _loggedIn.value = token.isNotBlank()
    }

    fun clear() {
        prefs().edit().clear().apply()
        _loggedIn.value = false
    }

    private fun prefs() = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun readToken(): String {
        if (!::appContext.isInitialized) return ""
        val value = prefs().getString(KEY_TOKEN, "") ?: return ""
        return runCatching { decrypt(value) }.getOrDefault("")
    }

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance(KS).apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KS)
        generator.init(KeyGenParameterSpec.Builder(
            ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build())
        return generator.generateKey().also { /* stored by Android Keystore */ }
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val combined = cipher.iv + cipher.doFinal(value.toByteArray(StandardCharsets.UTF_8))
        return Base64.encodeToString(combined, Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String {
        val combined = Base64.decode(value, Base64.NO_WRAP)
        require(combined.size > 12)
        val iv = combined.copyOfRange(0, 12)
        val ciphertext = combined.copyOfRange(12, combined.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(ciphertext), StandardCharsets.UTF_8)
    }
}
