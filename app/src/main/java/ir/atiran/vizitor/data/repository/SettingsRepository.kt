/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  Vizitor — آتیران ویزیتور | پیکربندی سرور و تنظیمات (DataStore)
 *  Developed by Milano Technical Team, Milad Yaghoobi
 *  ─────────────────────────────────────────────────────────────────────────
 *  IP سرور، پورت وب‌سرویس، پورت 1433 (جهت نمایش/لاگ)، کلید API و آدرس
 *  پراکسی هوش مصنوعی (Cloudflare Worker) به‌صورت امن ذخیره می‌شوند.
 *
 *  نکتهٔ مهم دربارهٔ «اتصال امن»: کلید useHttps مشخص می‌کند آدرس وب‌سرویس با
 *  https ساخته شود یا http. برای شبکهٔ داخلی شرکت (نصب پیش‌فرض سرور روی HTTP)
 *  این کلید را خاموش کنید؛ برای دامنه با گواهی معتبر (مثل api.vizitor.local)
 *  روشن بگذارید.
 * ═══════════════════════════════════════════════════════════════════════════
 */
package ir.atiran.vizitor.data.repository

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.settingsDataStore by preferencesDataStore(name = "vizitor_settings")

data class ServerConfig(
    val serverIp: String = "api.vizitor.local",
    val httpPort: Int = 443,
    val dbPort: Int = 1433,
    val apiPath: String = "",
    val apiKey: String = "",
    /** true = https (پیش‌فرض امن) | false = http برای شبکهٔ داخلی بدون گواهی */
    val useHttps: Boolean = true,
    val workerUrl: String = "https://vizitor-ai-proxy.YOUR-SUBDOMAIN.workers.dev",
    val geminiModel: String = "gemini-1.5-flash",
    val autoSync: Boolean = true,
    val lastSyncAt: Long = 0L
) {
    val scheme: String get() = if (useHttps) "https" else "http"
    val baseUrl: String get() = if (apiPath.isBlank()) "$scheme://$serverIp:$httpPort/"
        else "$scheme://$serverIp:$httpPort/${apiPath.trimStart('/').trimEnd('/')}/"
}

class SettingsRepository(private val context: Context) {

    private object Keys {
        val IP = stringPreferencesKey("server_ip")
        val HTTP_PORT = longPreferencesKey("http_port")
        val DB_PORT = longPreferencesKey("db_port")
        val API_PATH = stringPreferencesKey("api_path")
        val API_KEY = stringPreferencesKey("api_key")
        val USE_HTTPS = booleanPreferencesKey("use_https")
        val WORKER_URL = stringPreferencesKey("worker_url")
        val GEMINI_MODEL = stringPreferencesKey("gemini_model")
        val AUTO_SYNC = booleanPreferencesKey("auto_sync")
        val LAST_SYNC = longPreferencesKey("last_sync_at")
    }

    val config: Flow<ServerConfig> = context.settingsDataStore.data.map { p ->
        ServerConfig(
            serverIp = p[Keys.IP] ?: ServerConfig().serverIp,
            httpPort = (p[Keys.HTTP_PORT] ?: ServerConfig().httpPort.toLong()).toInt(),
            dbPort = (p[Keys.DB_PORT] ?: 1433L).toInt(),
            apiPath = p[Keys.API_PATH] ?: ServerConfig().apiPath,
            apiKey = p[Keys.API_KEY] ?: ServerConfig().apiKey,
            useHttps = p[Keys.USE_HTTPS] ?: ServerConfig().useHttps,
            workerUrl = p[Keys.WORKER_URL] ?: ServerConfig().workerUrl,
            geminiModel = p[Keys.GEMINI_MODEL] ?: ServerConfig().geminiModel,
            autoSync = p[Keys.AUTO_SYNC] ?: true,
            lastSyncAt = p[Keys.LAST_SYNC] ?: 0L
        )
    }

    suspend fun save(config: ServerConfig) {
        context.settingsDataStore.edit { p ->
            p[Keys.IP] = config.serverIp
            p[Keys.HTTP_PORT] = config.httpPort.toLong()
            p[Keys.DB_PORT] = config.dbPort.toLong()
            p[Keys.API_PATH] = config.apiPath
            p[Keys.API_KEY] = config.apiKey
            p[Keys.USE_HTTPS] = config.useHttps
            p[Keys.WORKER_URL] = config.workerUrl
            p[Keys.GEMINI_MODEL] = config.geminiModel
            p[Keys.AUTO_SYNC] = config.autoSync
            p[Keys.LAST_SYNC] = config.lastSyncAt
        }
    }

    suspend fun markSynced(at: Long = System.currentTimeMillis()) {
        context.settingsDataStore.edit { it[Keys.LAST_SYNC] = at }
    }
}
