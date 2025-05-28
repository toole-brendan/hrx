package com.example.handreceipt.data.network

// Import Auth models
import com.example.handreceipt.data.model.LoginCredentials
import com.example.handreceipt.data.model.LoginResponse
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.data.model.ReferenceItem
import com.example.handreceipt.data.model.TransferRequest
import com.example.handreceipt.data.model.User // Import User model
import retrofit2.Response
import retrofit2.http.Body // Import Body annotation
import retrofit2.http.GET
import retrofit2.http.POST // Import POST annotation
import retrofit2.http.Path
import retrofit2.http.Query // Import Query annotation
// import retrofit2.http.Header // Import if adding authentication headers

// Retrofit interface defining the API endpoints
interface ApiService {

    // --- Authentication --- 

    // Login endpoint
    // Expects LoginCredentials in the request body.
    // Returns Response<LoginResponse> to allow handling of non-200 status codes (e.g., 401 Unauthorized)
    @POST("auth/login")
    suspend fun login(
        @Body credentials: LoginCredentials
    ): Response<LoginResponse>

    // Check current session by fetching user profile
    @GET("users/me")
    suspend fun checkSession(): Response<LoginResponse> // Returns Response to handle 401 etc.

    // TODO: Add other auth endpoints like logout, register, check-session etc. if needed
    @POST("auth/logout")
    suspend fun logout(): Response<Unit> // Assuming logout returns no specific body

    // --- Reference Database --- 

    // Define the GET request to fetch reference items
    // The path should match the endpoint on your Go backend API
    // TODO: Update the endpoint path (e.g., "reference/items")
    @GET("reference-db/items") // Placeholder path
    suspend fun getReferenceItems(): List<ReferenceItem>

    // Get specific reference item details by ID
    // Uses Response<ReferenceItem> to handle 404 Not Found
    @GET("reference-db/items/{itemId}")
    suspend fun getReferenceItemById(
        @Path("itemId") itemId: String
        // TODO: Add authentication if needed
    ): Response<ReferenceItem>

    // --- Inventory / Property --- 

    // Get properties assigned to the current user
    @GET("users/me/inventory")
    suspend fun getMyInventory(): Response<List<Property>>

    // Get specific property details by its ID
    @GET("inventory/id/{propertyId}")
    suspend fun getPropertyById(
        @Path("propertyId") propertyId: String // Or UUID/Int
    ): Response<Property>

    // Get specific property details by serial number
    @GET("inventory/serial/{serialNumber}")
    suspend fun getPropertyBySerialNumber(
        @Path("serialNumber") serialNumber: String
    ): Response<Property>

    // Add other API functions here as needed
    /*
    @GET("reference-db/items/{nsn}")
    suspend fun getItemByNsn(
        @Path("nsn") nsn: String,
        // Example: Add authentication header if needed
        // @Header("Authorization") token: String
    ): ReferenceItem
    */

    /*
    @GET("inventory/id/{propertyId}")
    suspend fun getPropertyById(
        @Path("propertyId") propertyId: String // Or UUID/Int
    ): Response<Property>
    */

    // --- Transfers ---

    // Request a property transfer
    @POST("transfers/request") // Assuming endpoint path /api/transfers/request
    suspend fun requestTransfer(
        @Body request: TransferRequest
    ): Response<Unit> // Assuming simple 200 OK or error response, adjust if backend sends a body

    // TODO: Add endpoints for viewing transfers (pending, history)
    // TODO: Add endpoints for approving/rejecting transfers

    // --- Users ---

    // Search users by query (e.g., username)
    @GET("users") // Assuming endpoint path /api/users
    suspend fun searchUsers(
        @Query("search") query: String // Assuming backend uses 'search' query parameter
    ): Response<List<User>> // Returns a list of matching users

    // Endpoint to get current user details (already exists)
    @GET("users/me")
    suspend fun checkSession(): Response<LoginResponse> // Assuming LoginResponse contains User info or similar

    // TODO: Add endpoint to get user by ID if needed for recipient details display?

    // --- Transfer Endpoints ---

    @GET("/api/transfers")
    suspend fun getTransfers(
        @Query("status") status: String? = null, // e.g., "PENDING", "APPROVED"
        @Query("direction") direction: String? = null // e.g., "incoming", "outgoing"
    ): Response<List<Transfer>>

    // Add endpoint to get single transfer by ID
    @GET("/api/transfers/{transferId}")
    suspend fun getTransferById(@Path("transferId") transferId: String): Response<Transfer>

    @POST("/api/transfers")
    suspend fun requestTransfer(@Body transferRequest: TransferRequest): Response<Transfer> // Assuming backend returns the created transfer

    @POST("/api/transfers/{transferId}/approve")
    suspend fun approveTransfer(@Path("transferId") transferId: String): Response<Transfer> // Assuming backend returns the updated transfer
    
    @POST("/api/transfers/{transferId}/reject")
    suspend fun rejectTransfer(@Path("transferId") transferId: String): Response<Transfer> // Assuming backend returns the updated transfer

    // --- User Endpoints ---
    
    @GET("/api/users")
    suspend fun getUsers(@Query("search") searchQuery: String? = null): Response<List<User>>
} 