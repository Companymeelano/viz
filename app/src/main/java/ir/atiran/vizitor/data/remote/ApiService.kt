/*
 * ═══════════════════════════════════════════════════════════════════════════
 *  Vizitor — آتیران ویزیتور | سرویس شبکه (Retrofit Interface)
 *  Developed by Milano Technical Team, Milad Yaghoobi
 *  ─────────────────────────────────────────────────────────────────────────
 *  تمامی اندپوینت‌ها به فایل api.php سمت سرور متصل هستند.
 * ═══════════════════════════════════════════════════════════════════════════
 */
package ir.atiran.vizitor.data.remote

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Query

interface VizitorApiService {

    @POST("index.php?action=login")
    suspend fun login(
        @Header("X-Api-Key") apiKey: String,
        @Body request: LoginRequest
    ): ApiEnvelope<LoginDto>

    /** تست سلامت کامل سرور (دیتابیس + PHP + جداول). */
    @GET("index.php")
    suspend fun ping(
        @Header("X-Api-Key") apiKey: String,
        @Query("action") action: String = "ping"
    ): ApiEnvelope<PingDto>

    /** دریافت کاتالوگ کالا (Live Stock). */
    @GET("index.php")
    suspend fun getCatalog(
        @Header("X-Api-Key") apiKey: String,
        @Header("Authorization") authorization: String,
        @Query("action") action: String = "catalog",
        @Query("since") since: Long = 0
    ): ApiEnvelope<List<ProductDto>>

    /** دریافت لیست مشتریان + گروه‌های مشتری (CustGroup). */
    @GET("index.php")
    suspend fun getCustomers(
        @Header("X-Api-Key") apiKey: String,
        @Header("Authorization") authorization: String,
        @Query("action") action: String = "customers",
        @Query("since") since: Long = 0
    ): ApiEnvelope<List<CustomerDto>>

    /** تاریخچه سال مالی برای تحلیل هوش مصنوعی. */
    @GET("index.php")
    suspend fun getSalMali(
        @Header("X-Api-Key") apiKey: String,
        @Header("Authorization") authorization: String,
        @Query("action") action: String = "sal_mali",
        @Query("customer_id") customerId: Int
    ): ApiEnvelope<List<SalMaliRowDto>>

    /** صدور فاکتور — تراکنش اتمیک روی SalesHeader + SalesLines. */
    @POST("index.php?action=submit_invoice")
    suspend fun submitInvoice(
        @Header("X-Api-Key") apiKey: String,
        @Header("Authorization") authorization: String,
        @Body invoice: InvoiceHeaderRequest
    ): ApiEnvelope<SubmitInvoiceResponse>

    /** ثبت مشتری جدید — پس از تأیید در بخش «مشتریان در انتظار» حسابداری آتیران فعال می‌شود. */
    @POST("index.php?action=submit_customer")
    suspend fun submitCustomer(
        @Header("X-Api-Key") apiKey: String,
        @Header("Authorization") authorization: String,
        @Body customer: NewCustomerRequest
    ): ApiEnvelope<NewCustomerResponse>
}
