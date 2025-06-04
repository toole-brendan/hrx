import Foundation

enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
    // Add other methods as needed
}

// Define a protocol for the API service to allow for mocking/testing
public protocol APIServiceProtocol {
    // Function to fetch reference properties. Throws errors for network/parsing issues.
    func fetchReferencePropertys() async throws -> [ReferenceProperty]

    // Function to fetch a specific property by its serial number.
    func fetchPropertyBySerialNumber(serialNumber: String) async throws -> Property

    // Function to login a user.
    func login(credentials: LoginCredentials) async throws -> LoginResponse

    // Function to register a new user.
    func register(credentials: RegisterCredentials) async throws -> LoginResponse

    // Function to check the current session status by fetching user profile.
    func checkSession() async throws -> LoginResponse

    // Add function to fetch a specific reference item by ID
    func fetchReferencePropertyById(itemId: String) async throws -> ReferenceProperty

    // Add function to fetch current user's properties
    func getMyProperties() async throws -> [Property] // Expect a list of Property objects

    // Add function to fetch specific property by ID
    func getPropertyById(propertyId: Int) async throws -> Property

    // Function to logout the user.
    func logout() async throws

    // --- Photo Functions ---
    func uploadPropertyPhoto(propertyId: Int, imageData: Data) async throws -> PhotoUploadResponse
    func verifyPhotoHash(propertyId: Int, filename: String, expectedHash: String) async throws -> PhotoVerificationResponse
    func deletePropertyPhoto(propertyId: Int, filename: String) async throws

    // Add other API functions here as needed (e.g., fetch by NSN, etc.)
    // func fetchItemByNSN(nsn: String) async throws -> ReferenceProperty
    
    // --- Transfer Functions ---
    func fetchTransfers(status: String?, direction: String?) async throws -> [Transfer]
    func requestTransfer(propertyId: Int, targetUserId: Int) async throws -> Transfer
    func approveTransfer(transferId: Int) async throws -> Transfer
    func rejectTransfer(transferId: Int) async throws -> Transfer



    // --- User Functions ---
    func fetchUsers(searchQuery: String?) async throws -> [UserSummary] // Expect UserSummary for selection
    func getUserById(_ userId: Int) async throws -> UserSummary
    func updateUserProfile(userId: Int, profileData: [String: Any]) async throws -> LoginResponse.User
    func changePassword(userId: Int, currentPassword: String, newPassword: String) async throws

    // --- User Connection Functions ---
    func getConnections() async throws -> [UserConnection]
    func searchUsers(query: String) async throws -> [UserSummary]
    func sendConnectionRequest(targetUserId: Int) async throws -> UserConnection
    func updateConnectionStatus(connectionId: Int, status: String) async throws -> UserConnection

    // Add requirement for base URL string for cookie clearing
    var baseURLString: String { get }
    
    // --- NSN/LIN Lookup Functions ---
    func lookupNSN(nsn: String) async throws -> NSNLookupResponse
    func lookupLIN(lin: String) async throws -> NSNLookupResponse
    func searchNSN(query: String, limit: Int?) async throws -> NSNSearchResponse
    func universalSearchNSN(query: String, limit: Int?) async throws -> NSNSearchResponse

    // Add function to create a new property
    func createProperty(_ property: CreatePropertyInput) async throws -> Property

    // Update a property
    func updateProperty(_ property: Property) async throws -> Property

    // Verify an imported item
    func verifyImportedItem(id: Int, serialNumber: String, nsn: String?, notes: String) async throws -> Property

    func getPropertyBySN(serialNumber: String) async throws -> Property
    
    // MARK: - Property Status Update
    func updatePropertyStatus(propertyId: Int, status: String) async throws -> Property
    func getPropertyHistory(serialNumber: String) async throws -> [Activity]
    
    // MARK: - Transfer Offer Endpoints
    func requestTransferBySerial(serialNumber: String, notes: String?) async throws -> Transfer
    func createTransferOffer(propertyIds: [Int], recipientIds: [Int], notes: String?) async throws -> TransferOffer
    func getActiveOffers() async throws -> [TransferOffer]
    func acceptOffer(offerId: Int) async throws -> TransferOffer
    func getTransferById(transferId: Int) async throws -> Transfer
    
    // MARK: - Reference Database Endpoints
    func getPropertyTypes() async throws -> [PropertyType]
    func getPropertyModelByNSN(nsn: String) async throws -> ReferenceProperty
    
    // MARK: - Bulk Operations
    func bulkLookupNSN(nsns: [String]) async throws -> [NSNDetails]
    
    // MARK: - Activity Endpoints
    func createActivity(_ activity: CreateActivityInput) async throws -> Activity
    func getActivities(limit: Int?, offset: Int?) async throws -> [Activity]
    func getActivitiesByUser(userId: Int) async throws -> [Activity]
    
    // MARK: - Ledger/Verification Endpoints
    func verifyDatabaseLedger() async throws -> LedgerVerification
    func getLedgerHistory(limit: Int?, offset: Int?) async throws -> [LedgerEntry]
    
    // MARK: - Component Association Endpoints
    func getPropertyComponents(propertyId: Int) async throws -> [PropertyComponent]
    func attachComponent(propertyId: Int, componentId: Int, position: String?, notes: String?) async throws -> PropertyComponent
    func detachComponent(propertyId: Int, componentId: Int) async throws
    func getAvailableComponents(propertyId: Int) async throws -> [Property]
    func updateComponentPosition(propertyId: Int, componentId: Int, position: String) async throws
    
    // MARK: - Document Endpoints
    func getDocuments() async throws -> DocumentsResponse
    func markDocumentAsRead(documentId: Int) async throws -> DocumentResponse
    func sendMaintenanceForm(_ formRequest: CreateMaintenanceFormRequest) async throws -> SendMaintenanceFormResponse
    
    // MARK: - DA2062 Azure OCR Endpoints
    func uploadDA2062Form(pdfData: Data, fileName: String) async throws -> AzureOCRResponse
    func importDA2062Items(items: [DA2062BatchItem], source: String, sourceReference: String?) async throws -> BatchImportResponse
}

// Debug print function to avoid cluttering 
func debugPrint(_ items: Any..., function: String = #function, file: String = #file, line: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    print("DEBUG: [\(fileName):\(line)] \(function) - ", terminator: "")
    for item in items {
        print(item, terminator: " ")
    }
    print()
    #endif
}

// Concrete implementation of the API service
public class APIService: APIServiceProtocol {
    // Shared instance for easy access
    public static let shared = APIService()

    // Replace with your actual backend base URL
    private let baseURL: URL
    public var baseURLString: String { baseURL.absoluteString } // Conform to protocol

    // Use URLSession.shared by default, which handles cookies automatically via HTTPCookieStorage
    private let urlSession: URLSession

    // Allow injecting a custom URLSession (e.g., for testing or specific configurations)
    public init(urlSession: URLSession = .shared, baseURLString: String = "https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io") {
        debugPrint("Initializing APIService with baseURL: \(baseURLString)")
        
        if let url = URL(string: baseURLString) {
            self.baseURL = url
        } else {
            debugPrint("ERROR: Invalid base URL provided: \(baseURLString). Using fallback URL.")
            // Fallback URL in case of invalid string
            self.baseURL = URL(string: "https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io")!
        }
        
        self.urlSession = urlSession
        
        // Debug URLSession configuration
        debugPrint("URLSession configuration: \(urlSession.configuration)")
        debugPrint("Cookie storage: \(String(describing: urlSession.configuration.httpCookieStorage))")
        debugPrint("Cookie accept policy: \(urlSession.configuration.httpCookieAcceptPolicy.rawValue)")
        debugPrint("Timeout interval: \(urlSession.configuration.timeoutIntervalForRequest)")
    }

    // Error enum for specific API related errors
    enum APIError: Error, LocalizedError, Equatable {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
        case encodingError(Error)
        case serverError(statusCode: Int, message: String? = nil)
        case itemNotFound
        case unauthorized // Added for login failures (401)
        case unknownError
        case invalidResponse
        case badRequest(message: String?)
        case forbidden(message: String?)
        case notFound(message: String?)
        case requestFailed(statusCode: Int, data: Data)

        // Implement Equatable manually due to associated values
        static func == (lhs: APIError, rhs: APIError) -> Bool {
            switch (lhs, rhs) {
            case (.invalidURL, .invalidURL): return true
            case (.networkError(let lError), .networkError(let rError)): 
                // Comparing underlying Error objects can be tricky. Often compare by localizedDescription.
                return lError.localizedDescription == rError.localizedDescription
            case (.decodingError(let lError), .decodingError(let rError)):
                return lError.localizedDescription == rError.localizedDescription
            case (.encodingError(let lError), .encodingError(let rError)):
                return lError.localizedDescription == rError.localizedDescription
            case (.serverError(let lCode, let lMsg), .serverError(let rCode, let rMsg)):
                return lCode == rCode && lMsg == rMsg
            case (.itemNotFound, .itemNotFound): return true
            case (.unauthorized, .unauthorized): return true
            case (.unknownError, .unknownError): return true
            case (.invalidResponse, .invalidResponse): return true
            case (.badRequest(let lMsg), .badRequest(let rMsg)): return lMsg == rMsg
            case (.forbidden(let lMsg), .forbidden(let rMsg)): return lMsg == rMsg
            case (.notFound(let lMsg), .notFound(let rMsg)): return lMsg == rMsg
            case (.requestFailed(let lCode, _), .requestFailed(let rCode, _)): return lCode == rCode
            default: return false
            }
        }

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid request URL."
            case .networkError(let error): return "Network error: \(error.localizedDescription)"
            case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
            case .encodingError(let error): return "Failed to encode request: \(error.localizedDescription)"
            case .serverError(let statusCode, let message):
                return "Server error \(statusCode)\(message != nil ? ": \(message!)" : ".")"
            case .itemNotFound: return "Item not found (404)."
            case .unauthorized: return "Unauthorized (401). Check credentials or session."
            case .unknownError: return "An unknown error occurred."
            case .invalidResponse: return "Invalid response format."
            case .badRequest(let message): return "Bad request: \(message ?? "No additional message provided")"
            case .forbidden(let message): return "Forbidden: \(message ?? "No additional message provided")"
            case .notFound(let message): return "Not found: \(message ?? "No additional message provided")"
            case .requestFailed(let statusCode, let data):
                return "Request failed with status code \(statusCode). Data: \(String(data: data, encoding: .utf8) ?? "No data available")"
            }
        }
    }

    // Shared JSON Encoder/Decoder configuration
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        // Configure encoder if needed (e.g., date strategy)
        debugPrint("Creating JSONEncoder with default configuration")
        return encoder
    }()
    
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        
        // Custom date formatter that handles fractional seconds
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        // Create custom date decoding strategy that tries multiple formats
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try with fractional seconds first
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try ISO8601 without fractional seconds
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Try standard ISO8601
            let iso8601Formatter = ISO8601DateFormatter()
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            // Try without fractional seconds
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            if let date = iso8601Formatter.date(from: dateString) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        decoder.keyDecodingStrategy = .convertFromSnakeCase // Handle snake_case keys from server
        debugPrint("Creating JSONDecoder with custom date strategy and .convertFromSnakeCase key strategy")
        return decoder
    }()

    // Helper function to handle common request logic
    private func performRequest<T: Decodable>(request: URLRequest) async throws -> T {
        var modifiedRequest = request
        
        // Add JWT token to header if available
        if let accessToken = AuthManager.shared.getAccessToken() {
            modifiedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            debugPrint("Added JWT token to request headers")
        }
        
        debugPrint(">>> REQUEST (\(modifiedRequest.httpMethod ?? "?")): \(modifiedRequest.url?.absoluteString ?? "invalid URL")")
        
        // Log request headers
        if let headers = modifiedRequest.allHTTPHeaderFields {
            debugPrint("Request headers: \(headers)")
        }
        
        // Log request body if present
        if let httpBody = modifiedRequest.httpBody, let bodyString = String(data: httpBody, encoding: .utf8) {
            debugPrint("Request body: \(bodyString)")
        }
        
        // Log cookies being sent
        if let cookies = urlSession.configuration.httpCookieStorage?.cookies(for: modifiedRequest.url!) {
            let cookieStrings = cookies.map { "\($0.name)=\($0.value)" }
            debugPrint("Sending cookies: \(cookieStrings.joined(separator: "; "))")
        }

        do {
            // Capture start time for timing metrics
            let startTime = Date()
            
            // Use the instance's urlSession
            let (data, response) = try await urlSession.data(for: modifiedRequest)
            
            // Calculate request duration
            let duration = Date().timeIntervalSince(startTime)
            debugPrint("Request completed in \(String(format: "%.3f", duration))s")

            guard let httpResponse = response as? HTTPURLResponse else {
                debugPrint("ERROR: Response is not an HTTPURLResponse")
                throw APIError.unknownError
            }

            debugPrint("<<< RESPONSE: Status \(httpResponse.statusCode) from \(modifiedRequest.url?.path ?? "?")")
            
            // Log response headers
            debugPrint("Response headers: \(httpResponse.allHeaderFields)")
            
            // Log cookies received
            if let headers = httpResponse.allHeaderFields as? [String: String], let url = modifiedRequest.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
                if !cookies.isEmpty {
                    let cookieStrings = cookies.map { "\($0.name)=\($0.value)" }
                    debugPrint("Received cookies: \(cookieStrings.joined(separator: "; "))")
                }
            }
            
            // Log response body for debugging
            let responseBody = String(data: data, encoding: .utf8) ?? "nil/binary"
            debugPrint("Response body (\(data.count) bytes): \(responseBody.prefix(1000))\(responseBody.count > 1000 ? "..." : "")")

            guard (200...299).contains(httpResponse.statusCode) else {
                debugPrint("ERROR: Server returned non-success status code: \(httpResponse.statusCode)")
                let errorMessage = String(data: data, encoding: .utf8)
                debugPrint("Server error body: \(errorMessage ?? "nil")")
                
                if httpResponse.statusCode == 400 {
                    throw APIError.badRequest(message: errorMessage)
                }
                if httpResponse.statusCode == 404 {
                    throw APIError.itemNotFound
                }
                if httpResponse.statusCode == 401 {
                    throw APIError.unauthorized
                }
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }

            // Handle cases with no expected response body (e.g., 204)
            if T.self == EmptyResponse.self { // Assuming an EmptyResponse struct for clarity
                // Check if data is empty or handle as needed for 204
                if data.isEmpty {
                    debugPrint("Empty response body as expected for EmptyResponse")
                    return EmptyResponse() as! T
                }
            }

            do {
                debugPrint("Attempting to decode response as \(T.self)")
                let decodedObject = try decoder.decode(T.self, from: data)
                debugPrint("Successfully decoded response of type \(T.self)")
                return decodedObject
            } catch {
                debugPrint("ERROR: Decoding failed with error: \(error)")
                debugPrint("Raw data being decoded: \(String(data: data, encoding: .utf8) ?? "Invalid UTF8")")
                
                // More detailed decoding error information
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        debugPrint("Type mismatch: Expected \(type) but got something else. Path: \(context.codingPath.map { $0.stringValue })")
                    case .valueNotFound(let type, let context):
                        debugPrint("Value not found: Expected \(type) but found nil. Path: \(context.codingPath.map { $0.stringValue })")
                    case .keyNotFound(let key, let context):
                        debugPrint("Key '\(key.stringValue)' not found. Path: \(context.codingPath.map { $0.stringValue })")
                    case .dataCorrupted(let context):
                        debugPrint("Data corrupted: \(context.debugDescription). Path: \(context.codingPath.map { $0.stringValue })")
                    @unknown default:
                        debugPrint("Unknown decoding error type: \(decodingError)")
                    }
                }
                
                throw APIError.decodingError(error)
            }

        } catch let error as APIError {
            debugPrint("Caught APIError: \(error.localizedDescription)")
            throw error // Re-throw known API errors
        } catch {
            debugPrint("ERROR: Network/URLSession error: \(error)")
            debugPrint("Error details: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }

    // Login function implementation
    public func login(credentials: LoginCredentials) async throws -> LoginResponse {
        debugPrint("Attempting to login user: \(credentials.username)")
        let endpoint = baseURL.appendingPathComponent("/api/auth/login")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(credentials)
            debugPrint("Successfully encoded login credentials")
        } catch {
            debugPrint("ERROR: Failed to encode login credentials: \(error)")
            throw APIError.encodingError(error) // Add encodingError case if needed
        }

        // Expect LoginResponse object upon success
        let response = try await performRequest(request: request) as LoginResponse
        
        // Store tokens if available
        if let accessToken = response.accessToken,
           let refreshToken = response.refreshToken {
            AuthManager.shared.storeTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                userId: response.user.id
            )
            debugPrint("Stored JWT tokens for user: \(response.user.username)")
        }
        
        debugPrint("Login successful for user: \(response.user.username)")
        return response
    }

    // Register function implementation
    public func register(credentials: RegisterCredentials) async throws -> LoginResponse {
        debugPrint("Attempting to register user: \(credentials.username)")
        let endpoint = baseURL.appendingPathComponent("/api/auth/register")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try encoder.encode(credentials)
            debugPrint("Successfully encoded registration credentials")
        } catch {
            debugPrint("ERROR: Failed to encode registration credentials: \(error)")
            throw APIError.encodingError(error)
        }
        
        do {
            // Expect LoginResponse object upon success
            let response = try await performRequest(request: request) as LoginResponse
            
            // Store tokens if available
            if let accessToken = response.accessToken,
               let refreshToken = response.refreshToken {
                AuthManager.shared.storeTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    userId: response.user.id
                )
                debugPrint("Stored JWT tokens for new user: \(response.user.username)")
            }
            
            debugPrint("Registration successful for user: \(response.user.username)")
            return response
        } catch let error as APIError {
            // Re-throw with more specific message for badRequest
            if case .badRequest(let message) = error {
                throw APIError.badRequest(message: message ?? "Username or email already exists")
            }
            throw error
        }
    }

    // Logout function implementation
    public func logout() async throws {
        debugPrint("Attempting to logout")
        let endpoint = baseURL.appendingPathComponent("/api/auth/logout")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        // No body is typically needed for logout, the session cookie identifies the user

        // We expect a 2xx response (e.g., 200 OK or 204 No Content) on success.
        // performRequest handles status code checks and throws errors.
        // Since logout doesn't usually return data, we can expect EmptyResponse.
        let _: EmptyResponse = try await performRequest(request: request)
        
        // Clear stored JWT tokens
        AuthManager.shared.clearTokens()
        
        debugPrint("Logout successful on server and tokens cleared")
    }

    // Check session function implementation
    public func checkSession() async throws -> LoginResponse {
        debugPrint("Checking current session status")
        let endpoint = baseURL.appendingPathComponent("/api/auth/me")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies are handled automatically by URLSession/HTTPCookieStorage

        // Use UserResponse to decode and then convert to LoginResponse for compatibility
        let response = try await performRequest(request: request) as UserResponse
        debugPrint("Session check successful, user: \(response.user.username)")
        // Convert to LoginResponse to maintain compatibility with existing code
        return response.toLoginResponse()
    }

    public func fetchReferencePropertys() async throws -> [ReferenceProperty] {
        debugPrint("Fetching all reference items")
        let endpoint = baseURL.appendingPathComponent("/api/reference/models")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies are handled automatically by URLSession/HTTPCookieStorage
        
        // Use wrapper response type and extract models array
        let response = try await performRequest(request: request) as ReferencePropertysResponse
        debugPrint("Successfully fetched \(response.models.count) reference items")
        return response.models
    }

    public func fetchPropertyBySerialNumber(serialNumber: String) async throws -> Property {
        debugPrint("Fetching property with serial number: \(serialNumber)")
        guard let encodedSerialNumber = serialNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            debugPrint("ERROR: Failed to percent encode serial number: \(serialNumber)")
            throw APIError.invalidURL
        }
        let endpoint = baseURL.appendingPathComponent("/api/property/serial/\(encodedSerialNumber)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies are handled automatically by URLSession/HTTPCookieStorage
        let property = try await performRequest(request: request) as Property
        debugPrint("Successfully fetched property with serial: \(serialNumber), ID: \(property.id)")
        return property
    }

    // Function to fetch a specific reference item by ID
    public func fetchReferencePropertyById(itemId: String) async throws -> ReferenceProperty {
        debugPrint("Fetching reference item with ID: \(itemId)")
        guard let encodedItemId = itemId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            debugPrint("ERROR: Failed to percent encode item ID: \(itemId)")
            throw APIError.invalidURL
        }
        let endpoint = baseURL.appendingPathComponent("/api/reference/models/\(encodedItemId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies are handled automatically by URLSession/HTTPCookieStorage
        let item = try await performRequest(request: request) as ReferenceProperty
        debugPrint("Successfully fetched reference item: \(item.name)")
        return item
    }

    // Function to fetch current user's properties
    public func getMyProperties() async throws -> [Property] {
        debugPrint("Fetching current user's properties")
        
        // First get the current user ID
        let userResponse = try await checkSession()
        let userId = userResponse.user.id
        
        let endpoint = baseURL.appendingPathComponent("/api/property/user/\(userId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies are handled automatically by URLSession/HTTPCookieStorage
        
        // Use wrapper response type and extract items array
        let response = try await performRequest(request: request) as PropertyResponse
        debugPrint("Successfully fetched \(response.items.count) properties for current user")
        return response.items
    }

    // Function to fetch specific property by ID
    public func getPropertyById(propertyId: Int) async throws -> Property {
        debugPrint("Fetching property with ID: \(propertyId)")
        // No need to encode Int for path component
        let endpoint = baseURL.appendingPathComponent("/api/property/\(propertyId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies handled automatically
        let property = try await performRequest(request: request) as Property
        debugPrint("Successfully fetched property: \(property.itemName)")
        return property
    }

    // Create Property Implementation
    public func createProperty(_ input: CreatePropertyInput) async throws -> Property {
        debugPrint("Creating property with serial number: \(input.serialNumber)")
        let endpoint = baseURL.appendingPathComponent("/api/property")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try encoder.encode(input)
            debugPrint("Successfully encoded property creation data")
        } catch {
            debugPrint("ERROR: Failed to encode property creation data: \(error)")
            throw APIError.encodingError(error)
        }
        
        let createdProperty = try await performRequest(request: request) as Property
        debugPrint("Successfully created property with ID: \(createdProperty.id)")
        return createdProperty
    }

    // Update a property
    public func updateProperty(_ property: Property) async throws -> Property {
        debugPrint("Updating property with ID: \(property.id)")
        let endpoint = baseURL.appendingPathComponent("/api/properties/\(property.id)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create a dictionary with the property data we can encode
        let propertyData: [String: Any] = [
            "id": property.id,
            "serialNumber": property.serialNumber,
            "nsn": property.nsn as Any,
            "lin": property.lin as Any,
            "name": property.name,
            "description": property.description as Any,
            "manufacturer": property.manufacturer as Any,
            "status": property.status as Any,
            "currentStatus": property.currentStatus as Any,
            "location": property.location as Any,
            "notes": property.notes as Any
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: propertyData)
            debugPrint("Successfully encoded property update data")
        } catch {
            debugPrint("ERROR: Failed to encode property data: \(error)")
            throw APIError.encodingError(error)
        }
        
        let updatedProperty = try await performRequest(request: request) as Property
        debugPrint("Successfully updated property with ID: \(updatedProperty.id)")
        return updatedProperty
    }
    
    // Verify an imported item
    public func verifyImportedItem(id: Int, serialNumber: String, nsn: String?, notes: String) async throws -> Property {
        debugPrint("Verifying imported item with ID: \(id)")
        let endpoint = baseURL.appendingPathComponent("/api/properties/\(id)/verify")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let verificationData = [
            "serialNumber": serialNumber,
            "nsn": nsn ?? "",
            "notes": notes,
            "verifiedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: verificationData)
            debugPrint("Successfully encoded verification data")
        } catch {
            debugPrint("ERROR: Failed to encode verification data: \(error)")
            throw APIError.encodingError(error)
        }
        
        let verifiedProperty = try await performRequest(request: request) as Property
        debugPrint("Successfully verified property with ID: \(verifiedProperty.id)")
        return verifiedProperty
    }

    public func getPropertyBySN(serialNumber: String) async throws -> Property {
        // Delegate to the existing fetchPropertyBySerialNumber method
        return try await fetchPropertyBySerialNumber(serialNumber: serialNumber)
    }

    // MARK: - Property Status Update
    public func updatePropertyStatus(propertyId: Int, status: String) async throws -> Property {
        debugPrint("Updating status for property: \(propertyId) to: \(status)")
        let endpoint = baseURL.appendingPathComponent("/api/property/\(propertyId)/status")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let statusUpdate = ["status": status]
        do {
            request.httpBody = try encoder.encode(statusUpdate)
            debugPrint("Successfully encoded status update")
        } catch {
            debugPrint("ERROR: Failed to encode status update: \(error)")
            throw APIError.encodingError(error)
        }
        
        let updatedProperty = try await performRequest(request: request) as Property
        debugPrint("Successfully updated property status: \(updatedProperty.id)")
        return updatedProperty
    }
    
    public func getPropertyHistory(serialNumber: String) async throws -> [Activity] {
        debugPrint("Fetching history for property with serial: \(serialNumber)")
        guard let encoded = serialNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL
        }
        
        let endpoint = baseURL.appendingPathComponent("/api/property/history/\(encoded)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as ActivitiesResponse
        debugPrint("Successfully fetched \(response.activities.count) history items")
        return response.activities
    }

    // MARK: - Transfer Offer Endpoints
    public func requestTransferBySerial(serialNumber: String, notes: String? = nil) async throws -> Transfer {
        debugPrint("Requesting transfer by serial: \(serialNumber)")
        let endpoint = baseURL.appendingPathComponent("/api/transfers/request-by-serial")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = SerialTransferRequest(
            serialNumber: serialNumber,
            notes: notes
        )
        
        do {
            request.httpBody = try encoder.encode(requestBody)
            debugPrint("Successfully encoded serial transfer request")
        } catch {
            debugPrint("ERROR: Failed to encode request: \(error)")
            throw APIError.encodingError(error)
        }
        
        let transfer = try await performRequest(request: request) as Transfer
        debugPrint("Successfully created transfer request: \(transfer.id)")
        return transfer
    }
    
    public func createTransferOffer(propertyIds: [Int], recipientIds: [Int], notes: String? = nil) async throws -> TransferOffer {
        debugPrint("Creating transfer offer for \(propertyIds.count) items to \(recipientIds.count) recipients")
        let endpoint = baseURL.appendingPathComponent("/api/transfers/offer")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let offerRequest = TransferOfferRequest(
            propertyIds: propertyIds,
            recipientIds: recipientIds,
            notes: notes
        )
        
        do {
            request.httpBody = try encoder.encode(offerRequest)
            debugPrint("Successfully encoded transfer offer")
        } catch {
            debugPrint("ERROR: Failed to encode offer: \(error)")
            throw APIError.encodingError(error)
        }
        
        let offer = try await performRequest(request: request) as TransferOffer
        debugPrint("Successfully created transfer offer: \(offer.id)")
        return offer
    }
    
    public func getActiveOffers() async throws -> [TransferOffer] {
        debugPrint("Fetching active transfer offers")
        let endpoint = baseURL.appendingPathComponent("/api/transfers/offers/active")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as TransferOffersResponse
        debugPrint("Successfully fetched \(response.offers.count) active offers")
        return response.offers
    }
    
    public func acceptOffer(offerId: Int) async throws -> TransferOffer {
        debugPrint("Accepting transfer offer: \(offerId)")
        let endpoint = baseURL.appendingPathComponent("/api/transfers/offers/\(offerId)/accept")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Empty body for accept action
        request.httpBody = try encoder.encode(EmptyRequest())
        
        let offer = try await performRequest(request: request) as TransferOffer
        debugPrint("Successfully accepted offer: \(offer.id)")
        return offer
    }
    
    public func getTransferById(transferId: Int) async throws -> Transfer {
        debugPrint("Fetching transfer with ID: \(transferId)")
        let endpoint = baseURL.appendingPathComponent("/api/transfers/\(transferId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let transfer = try await performRequest(request: request) as Transfer
        debugPrint("Successfully fetched transfer: \(transfer.id)")
        return transfer
    }

    // MARK: - Reference Database Endpoints
    public func getPropertyTypes() async throws -> [PropertyType] {
        debugPrint("Fetching property types")
        let endpoint = baseURL.appendingPathComponent("/api/reference/types")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as PropertyTypesResponse
        debugPrint("Successfully fetched \(response.types.count) property types")
        return response.types
    }
    
    public func getPropertyModelByNSN(nsn: String) async throws -> ReferenceProperty {
        debugPrint("Fetching property model by NSN: \(nsn)")
        guard let encoded = nsn.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL
        }
        
        let endpoint = baseURL.appendingPathComponent("/api/reference/models/nsn/\(encoded)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let model = try await performRequest(request: request) as ReferenceProperty
        debugPrint("Successfully fetched property model: \(model.name)")
        return model
    }

    // MARK: - Bulk Operations
    public func bulkLookupNSN(nsns: [String]) async throws -> [NSNDetails] {
        debugPrint("Performing bulk NSN lookup for \(nsns.count) items")
        let endpoint = baseURL.appendingPathComponent("/api/nsn/bulk")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bulkRequest = BulkNSNRequest(nsns: nsns)
        do {
            request.httpBody = try encoder.encode(bulkRequest)
            debugPrint("Successfully encoded bulk NSN request")
        } catch {
            debugPrint("ERROR: Failed to encode bulk request: \(error)")
            throw APIError.encodingError(error)
        }
        
        let response = try await performRequest(request: request) as BulkNSNResponse
        debugPrint("Successfully looked up \(response.results.count) NSNs")
        return response.results
    }

    // MARK: - Activity Endpoints
    public func createActivity(_ activity: CreateActivityInput) async throws -> Activity {
        debugPrint("Creating activity: \(activity.activityType)")
        let endpoint = baseURL.appendingPathComponent("/api/activities")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try encoder.encode(activity)
            debugPrint("Successfully encoded activity")
        } catch {
            debugPrint("ERROR: Failed to encode activity: \(error)")
            throw APIError.encodingError(error)
        }
        
        let createdActivity = try await performRequest(request: request) as Activity
        debugPrint("Successfully created activity: \(createdActivity.id)")
        return createdActivity
    }
    
    public func getActivities(limit: Int? = nil, offset: Int? = nil) async throws -> [Activity] {
        debugPrint("Fetching activities")
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/activities"), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem]()
        
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as ActivitiesResponse
        debugPrint("Successfully fetched \(response.activities.count) activities")
        return response.activities
    }
    
    public func getActivitiesByUser(userId: Int) async throws -> [Activity] {
        debugPrint("Fetching activities for user: \(userId)")
        let endpoint = baseURL.appendingPathComponent("/api/activities/user/\(userId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as ActivitiesResponse
        debugPrint("Successfully fetched \(response.activities.count) activities for user")
        return response.activities
    }

    // MARK: - Ledger/Verification Endpoints
    public func verifyDatabaseLedger() async throws -> LedgerVerification {
        debugPrint("Verifying database ledger integrity")
        let endpoint = baseURL.appendingPathComponent("/api/verification/database")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let verification = try await performRequest(request: request) as LedgerVerification
        debugPrint("Ledger verification complete: \(verification.isValid ? "Valid" : "Invalid")")
        return verification
    }
    
    public func getLedgerHistory(limit: Int? = nil, offset: Int? = nil) async throws -> [LedgerEntry] {
        debugPrint("Fetching ledger history")
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/ledger/history"), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem]()
        
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as LedgerHistoryResponse
        debugPrint("Successfully fetched \(response.entries.count) ledger entries")
        return response.entries
    }
    
    // MARK: - Component Association Endpoints
    
    public func getPropertyComponents(propertyId: Int) async throws -> [PropertyComponent] {
        debugPrint("Fetching components for property: \(propertyId)")
        let endpoint = baseURL.appendingPathComponent("/api/property/\(propertyId)/components")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as ComponentsResponse
        debugPrint("Successfully fetched \(response.components.count) components")
        return response.components
    }
    
    public func attachComponent(propertyId: Int, componentId: Int, position: String?, notes: String?) async throws -> PropertyComponent {
        debugPrint("Attaching component \(componentId) to property \(propertyId) at position: \(position ?? "unspecified")")
        let endpoint = baseURL.appendingPathComponent("/api/property/\(propertyId)/components")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = AttachComponentRequest(
            componentId: componentId,
            position: position,
            notes: notes
        )
        
        do {
            request.httpBody = try encoder.encode(requestBody)
            debugPrint("Successfully encoded attach component request")
        } catch {
            debugPrint("ERROR: Failed to encode attach request: \(error)")
            throw APIError.encodingError(error)
        }
        
        let response = try await performRequest(request: request) as AttachmentResponse
        debugPrint("Successfully attached component: \(response.attachment.id)")
        
        // Convert AttachmentSummary to PropertyComponent
        let propertyComponent = PropertyComponent(
            id: response.attachment.id,
            parentPropertyId: response.attachment.parentPropertyId,
            componentPropertyId: response.attachment.componentPropertyId,
            attachedAt: response.attachment.attachedAt,
            attachedByUserId: response.attachment.attachedByUserId,
            notes: response.attachment.notes,
            attachmentType: response.attachment.attachmentType,
            position: response.attachment.position,
            createdAt: response.attachment.createdAt,
            updatedAt: response.attachment.updatedAt
        )
        
        return propertyComponent
    }
    
    public func detachComponent(propertyId: Int, componentId: Int) async throws {
        debugPrint("Detaching component \(componentId) from property \(propertyId)")
        let endpoint = baseURL.appendingPathComponent("/api/property/\(propertyId)/components/\(componentId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        
        let _: EmptyResponse = try await performRequest(request: request)
        debugPrint("Successfully detached component")
    }
    
    public func getAvailableComponents(propertyId: Int) async throws -> [Property] {
        debugPrint("Fetching available components for property: \(propertyId)")
        let endpoint = baseURL.appendingPathComponent("/api/property/\(propertyId)/available-components")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as AvailableComponentsResponse
        debugPrint("Successfully fetched \(response.availableComponents.count) available components")
        return response.availableComponents
    }
    
    public func updateComponentPosition(propertyId: Int, componentId: Int, position: String) async throws {
        debugPrint("Updating component \(componentId) position to: \(position)")
        let endpoint = baseURL.appendingPathComponent("/api/property/\(propertyId)/components/\(componentId)/position")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = UpdatePositionRequest(position: position)
        
        do {
            request.httpBody = try encoder.encode(requestBody)
            debugPrint("Successfully encoded position update request")
        } catch {
            debugPrint("ERROR: Failed to encode position update: \(error)")
            throw APIError.encodingError(error)
        }
        
        let _: EmptyResponse = try await performRequest(request: request)
        debugPrint("Successfully updated component position")
    }

    // --- Transfer Functions (Async/Await) ---
    
    // Fetch Transfers (with optional filters)
    public func fetchTransfers(status: String? = nil, direction: String? = nil) async throws -> [Transfer] {
        // Removed fallback logic, directly call the correct implementation
        debugPrint("Fetching transfers with status: \(status ?? "any")")

        // Base endpoint is /transfers
        let endpoint = "/api/transfers"
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem]()

        // Add status query parameter if provided
        if let status = status, !status.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        
        // NOTE: The 'direction' parameter is currently ignored as the backend route
        // `/transfers` (GetAllTransfers) filters based on the authenticated user
        // and doesn't accept a direction parameter. Filtering by direction
        // is handled client-side in TransfersViewModel based on currentUserId.
        // If server-side direction filtering becomes available on this route,
        // add the query parameter here.
        // if let direction = direction, !direction.isEmpty {
        //     queryItems.append(URLQueryItem(name: "direction", value: direction))
        // }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            debugPrint("ERROR: Failed to construct URL for fetchTransfers")
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Expect the backend to return {"transfers": [...]}
        let response = try await performRequest(request: request) as TransfersResponse
        debugPrint("Successfully fetched \(response.transfers.count) transfers")
        return response.transfers
    }
    
    // Request Transfer
    public func requestTransfer(propertyId: Int, targetUserId: Int) async throws -> Transfer {
        debugPrint("Requesting transfer of property \(propertyId) to user \(targetUserId)")
        // Correct endpoint for creating a transfer is /transfers
        let endpoint = baseURL.appendingPathComponent("/api/transfers")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        let requestBody = TransferRequest(propertyId: propertyId, targetUserId: targetUserId)

        do {
            request.httpBody = try encoder.encode(requestBody)
            debugPrint("Successfully encoded transfer request body")
        } catch {
            debugPrint("ERROR: Failed to encode transfer request: \(error)")
            throw APIError.encodingError(error)
        }
        let transfer = try await performRequest(request: request) as Transfer
        debugPrint("Successfully created transfer request: \(transfer.id)")
        return transfer
    }
    
    // Approve Transfer
    public func approveTransfer(transferId: Int) async throws -> Transfer {
        debugPrint("Approving transfer: \(transferId)")
        // Correct endpoint for approving is /transfers/{id}/status
        guard let url = URL(string: "\(baseURLString)/api/transfers/\(transferId)/status") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        // Approval likely requires a PATCH or PUT with a body indicating approval
        request.httpMethod = "PATCH" // Changed from POST
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        
        // Send status update in the body
        let requestBody = UpdateTransferStatusBody(status: "Approved") // Assuming "Approved" is the correct status string
        do {
            request.httpBody = try encoder.encode(requestBody)
            debugPrint("Encoded approve status body")
        } catch {
            debugPrint("ERROR: Failed to encode approve status: \(error)")
            throw APIError.encodingError(error)
        }

        let transfer = try await performRequest(request: request) as Transfer
        debugPrint("Successfully approved transfer: \(transfer.id)")
        return transfer
    }
    
    // Reject Transfer
    public func rejectTransfer(transferId: Int) async throws -> Transfer {
        debugPrint("Rejecting transfer: \(transferId)")
        // Correct endpoint for rejecting is /transfers/{id}/status
        guard let url = URL(string: "\(baseURLString)/api/transfers/\(transferId)/status") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        // Rejection likely requires a PATCH or PUT with a body indicating rejection
        request.httpMethod = "PATCH" // Changed from POST
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)

        // Send status update in the body
        let requestBody = UpdateTransferStatusBody(status: "Rejected") // Assuming "Rejected" is the correct status string
        do {
            request.httpBody = try encoder.encode(requestBody)
            debugPrint("Encoded reject status body")
        } catch {
            debugPrint("ERROR: Failed to encode reject status: \(error)")
            throw APIError.encodingError(error)
        }

        let transfer = try await performRequest(request: request) as Transfer
        debugPrint("Successfully rejected transfer: \(transfer.id)")
        return transfer
    }

    // --- User Functions (Async/Await) ---

    // Fetch Users (with optional search)
    public func fetchUsers(searchQuery: String? = nil) async throws -> [UserSummary] {
        debugPrint("Fetching users with search query: \(searchQuery ?? "none")")
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/auth/users"), resolvingAgainstBaseURL: false)!
        if let query = searchQuery, !query.isEmpty {
            components.queryItems = [URLQueryItem(name: "search", value: query)]
        }
        
        guard let url = components.url else {
            debugPrint("ERROR: Failed to construct URL for fetchUsers")
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let users = try await performRequest(request: request) as [UserSummary]
        debugPrint("Successfully fetched \(users.count) users")
        return users
    }

    // Get User by ID
    public func getUserById(_ userId: Int) async throws -> UserSummary {
        debugPrint("Fetching user with ID: \(userId)")
        let endpoint = baseURL.appendingPathComponent("/api/auth/users/\(userId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let user = try await performRequest(request: request) as UserSummary
        debugPrint("Successfully fetched user: \(user.username)")
        return user
    }

    // --- User Connection Functions ---
    
    // Get user connections
    public func getConnections() async throws -> [UserConnection] {
        debugPrint("Fetching user connections")
        let endpoint = baseURL.appendingPathComponent("/api/users/connections")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as ConnectionsResponse
        debugPrint("Successfully fetched \(response.connections.count) connections")
        return response.connections
    }
    
    // Search users
    public func searchUsers(query: String) async throws -> [UserSummary] {
        debugPrint("Searching users with query: \(query)")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        
        let endpoint = baseURL.appendingPathComponent("/api/users/search")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: encoded)]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as UsersResponse
        debugPrint("Successfully found \(response.users.count) users")
        return response.users
    }
    
    // Send connection request
    public func sendConnectionRequest(targetUserId: Int) async throws -> UserConnection {
        debugPrint("Sending connection request to user: \(targetUserId)")
        let endpoint = baseURL.appendingPathComponent("/api/users/connections")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["targetUserId": targetUserId]
        do {
            request.httpBody = try encoder.encode(body)
            debugPrint("Successfully encoded connection request")
        } catch {
            debugPrint("ERROR: Failed to encode connection request: \(error)")
            throw APIError.encodingError(error)
        }
        
        let connection = try await performRequest(request: request) as UserConnection
        debugPrint("Successfully sent connection request: \(connection.id)")
        return connection
    }
    
    // Update connection status
    public func updateConnectionStatus(connectionId: Int, status: String) async throws -> UserConnection {
        debugPrint("Updating connection \(connectionId) to status: \(status)")
        let endpoint = baseURL.appendingPathComponent("/api/users/connections/\(connectionId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["status": status]
        do {
            request.httpBody = try encoder.encode(body)
            debugPrint("Successfully encoded status update")
        } catch {
            debugPrint("ERROR: Failed to encode status update: \(error)")
            throw APIError.encodingError(error)
        }
        
        let connection = try await performRequest(request: request) as UserConnection
        debugPrint("Successfully updated connection status: \(connection.id)")
        return connection
    }

    // Helper function to add authentication header (adjust if needed)
    private func addAuthHeader(to request: inout URLRequest) {
        // Add JWT token to header if available
        if let accessToken = AuthManager.shared.getAccessToken() {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            debugPrint("Added JWT token to request headers via addAuthHeader")
        } else {
            debugPrint("No JWT token available, relying on session cookies")
        }
    }

    // --- Photo Functions ---
    
    public func uploadPropertyPhoto(propertyId: Int, imageData: Data) async throws -> PhotoUploadResponse {
        debugPrint("Uploading photo for property: \(propertyId)")
        let endpoint = baseURL.appendingPathComponent("/api/photos/property/\(propertyId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let response = try await performRequest(request: request) as PhotoUploadResponse
        debugPrint("Photo uploaded successfully: \(response.hash)")
        return response
    }
    
    public func verifyPhotoHash(propertyId: Int, filename: String, expectedHash: String) async throws -> PhotoVerificationResponse {
        debugPrint("Verifying photo hash for property: \(propertyId)")
        
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/photos/property/\(propertyId)/verify"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "filename", value: filename),
            URLQueryItem(name: "hash", value: expectedHash)
        ]
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as PhotoVerificationResponse
        debugPrint("Photo verification result: \(response.valid)")
        return response
    }
    
    public func deletePropertyPhoto(propertyId: Int, filename: String) async throws {
        debugPrint("Deleting photo for property: \(propertyId)")
        let endpoint = baseURL.appendingPathComponent("/api/photos/property/\(propertyId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let deleteRequest = DeletePhotoRequest(filename: filename)
        request.httpBody = try encoder.encode(deleteRequest)
        
        let _: EmptyResponse = try await performRequest(request: request)
        debugPrint("Photo deleted successfully")
    }
    
    // --- NSN/LIN Lookup Functions ---
    
    public func lookupNSN(nsn: String) async throws -> NSNLookupResponse {
        debugPrint("Looking up NSN: \(nsn)")
        guard let encodedNSN = nsn.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL
        }
        
        let endpoint = baseURL.appendingPathComponent("/api/nsn/\(encodedNSN)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as NSNLookupResponse
        debugPrint("NSN lookup successful: \(response.data.itemName)")
        return response
    }
    
    public func lookupLIN(lin: String) async throws -> NSNLookupResponse {
        debugPrint("Looking up LIN: \(lin)")
        guard let encodedLIN = lin.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL
        }
        
        let endpoint = baseURL.appendingPathComponent("/api/lin/\(encodedLIN)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as NSNLookupResponse
        debugPrint("LIN lookup successful: \(response.data.itemName)")
        return response
    }
    
    public func searchNSN(query: String, limit: Int? = 20) async throws -> NSNSearchResponse {
        debugPrint("Searching NSN with query: \(query)")
        
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/nsn/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        if let limit = limit {
            components.queryItems?.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as NSNSearchResponse
        debugPrint("NSN search returned \(response.count) results")
        return response
    }
    
    public func universalSearchNSN(query: String, limit: Int? = 20) async throws -> NSNSearchResponse {
        debugPrint("Universal NSN search with query: \(query)")
        
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/nsn/universal-search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
        if let limit = limit {
            components.queryItems?.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as NSNSearchResponse
        debugPrint("Universal NSN search returned \(response.count) results")
        return response
    }

    // --- QR Transfer Functions ---
    // DEPRECATED: QR transfer functionality has been removed
    // Use requestTransferBySerial() instead for serial number-based transfers

    // --- Document Functions ---
    
    public func getDocuments() async throws -> DocumentsResponse {
        debugPrint("Fetching documents")
        let endpoint = baseURL.appendingPathComponent("/api/documents")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        
        let response = try await performRequest(request: request) as DocumentsResponse
        debugPrint("Successfully fetched \(response.documents.count) documents")
        return response
    }
    
    public func markDocumentAsRead(documentId: Int) async throws -> DocumentResponse {
        debugPrint("Marking document \(documentId) as read")
        let endpoint = baseURL.appendingPathComponent("/api/documents/\(documentId)/read")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let response = try await performRequest(request: request) as DocumentResponse
        debugPrint("Successfully marked document as read")
        return response
    }
    
    public func emailDocument(documentId: Int, email: String) async throws {
        debugPrint("Emailing document \(documentId) to \(email)")
        let endpoint = baseURL.appendingPathComponent("/api/documents/\(documentId)/email")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to email document")
        }
        
        debugPrint("Successfully emailed document")
    }
    
    public func sendMaintenanceForm(_ formRequest: CreateMaintenanceFormRequest) async throws -> SendMaintenanceFormResponse {
        debugPrint("Sending maintenance form")
        let endpoint = baseURL.appendingPathComponent("/api/documents/maintenance-forms")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try encoder.encode(formRequest)
            debugPrint("Successfully encoded maintenance form request")
        } catch {
            debugPrint("ERROR: Failed to encode maintenance form: \(error)")
            throw APIError.encodingError(error)
        }
        
        let response = try await performRequest(request: request) as SendMaintenanceFormResponse
        debugPrint("Successfully sent maintenance form")
        return response
    }

    // MARK: - DA2062 Azure OCR Implementation
    
    public func uploadDA2062Form(pdfData: Data, fileName: String) async throws -> AzureOCRResponse {
        debugPrint("Uploading DA2062 form for Azure OCR processing: \(fileName)")
        let endpoint = baseURL.appendingPathComponent("/api/da2062/upload")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let response = try await performRequest(request: request) as AzureOCRResponse
        debugPrint("DA2062 Azure OCR processing completed with \(response.items.count) items")
        return response
    }
    
    public func importDA2062Items(items: [DA2062BatchItem], source: String, sourceReference: String?) async throws -> BatchImportResponse {
        debugPrint("Importing \(items.count) DA2062 items via batch API")
        let endpoint = baseURL.appendingPathComponent("/api/inventory/batch")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let batchRequest = BatchCreateRequest(
            source: source,
            sourceReference: sourceReference,
            items: items
        )
        
        do {
            request.httpBody = try encoder.encode(batchRequest)
            debugPrint("Successfully encoded batch import request")
        } catch {
            debugPrint("ERROR: Failed to encode batch import: \(error)")
            throw APIError.encodingError(error)
        }
        
        let response = try await performRequest(request: request) as BatchImportResponse
        debugPrint("Successfully imported \(response.createdCount) items")
        return response
    }

    // --- User Profile Functions ---
    
    public func updateUserProfile(userId: Int, profileData: [String: Any]) async throws -> LoginResponse.User {
        debugPrint("Updating profile for user: \(userId)")
        let endpoint = baseURL.appendingPathComponent("/api/users/\(userId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: profileData)
            debugPrint("Successfully encoded profile update data")
        } catch {
            debugPrint("ERROR: Failed to encode profile data: \(error)")
            throw APIError.encodingError(error)
        }
        
        let response = try await performRequest(request: request) as UpdateProfileResponse
        debugPrint("Successfully updated profile for user: \(userId)")
        return response.user
    }
    
    public func changePassword(userId: Int, currentPassword: String, newPassword: String) async throws {
        debugPrint("Changing password for user: \(userId)")
        let endpoint = baseURL.appendingPathComponent("/api/users/\(userId)/password")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let passwordChangeData = [
            "current_password": currentPassword,
            "new_password": newPassword,
            "confirm_password": newPassword
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: passwordChangeData)
            debugPrint("Successfully encoded password change data")
        } catch {
            debugPrint("ERROR: Failed to encode password change data: \(error)")
            throw APIError.encodingError(error)
        }
        
        let _: EmptyResponse = try await performRequest(request: request)
        debugPrint("Successfully changed password for user: \(userId)")
    }
}

// Helper struct for requests expecting no response body (e.g., 204)
struct EmptyResponse: Decodable {}

struct ErrorResponse: Decodable {
    let message: String
}

// Add struct for updating transfer status if not already present
struct UpdateTransferStatusBody: Encodable {
    let status: String
    // Add other fields like 'notes' if needed/allowed by the backend endpoint
}

// Add response models for photo operations
public struct PhotoUploadResponse: Codable {
    public let message: String
    public let photoUrl: String
    public let hash: String
    public let filename: String
}

public struct PhotoVerificationResponse: Codable {
    public let valid: Bool
    public let expectedHash: String
    public let actualHash: String
}

struct DeletePhotoRequest: Codable {
    let filename: String
}

// Add NSN response models
public struct NSNLookupResponse: Codable {
    public let success: Bool
    public let data: NSNDetails
}

public struct NSNDetails: Codable {
    public let nsn: String
    public let lin: String?
    public let nomenclature: String
    public let fsc: String?
    public let niin: String?
    public let unitPrice: Double?
    public let manufacturer: String?
    public let partNumber: String?
    public let specifications: [String: String]?
    public let lastUpdated: Date
    
    public var itemName: String {
        return nomenclature
    }
}

public struct NSNSearchResponse: Codable {
    public let success: Bool
    public let data: [NSNDetails]
    public let count: Int
}

// Add CreatePropertyInput model
public struct CreatePropertyInput: Codable {
    public let name: String
    public let serialNumber: String
    public let description: String?
    public let currentStatus: String
    public let propertyModelId: Int?
    public let assignedToUserId: Int?
    public let nsn: String?
    public let lin: String?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case serialNumber = "serial_number"
        case description
        case currentStatus = "current_status"
        case propertyModelId = "property_model_id"
        case assignedToUserId = "assigned_to_user_id"
        case nsn
        case lin
    }
}



// Connection response models
public struct ConnectionsResponse: Decodable {
    public let connections: [UserConnection]
}

public struct UsersResponse: Decodable {
    public let users: [UserSummary]
}

public struct UpdateProfileResponse: Decodable {
    public let message: String
    public let user: LoginResponse.User
}

// Component association request/response models
public struct AttachComponentRequest: Codable {
    public let componentId: Int
    public let position: String?
    public let notes: String?
    
    private enum CodingKeys: String, CodingKey {
        case componentId = "component_id"
        case position
        case notes
    }
}

public struct ComponentsResponse: Decodable {
    public let components: [PropertyComponent]
}

public struct AttachmentResponse: Decodable {
    public let attachment: AttachmentSummary
}

public struct AttachmentSummary: Decodable {
    public let id: Int
    public let parentPropertyId: Int
    public let componentPropertyId: Int
    public let attachedAt: Date
    public let attachedByUserId: Int
    public let notes: String?
    public let attachmentType: String
    public let position: String?
    public let createdAt: Date
    public let updatedAt: Date
    
    private enum CodingKeys: String, CodingKey {
        case id, parentPropertyId, componentPropertyId, attachedAt, attachedByUserId
        case notes, attachmentType, position, createdAt, updatedAt
    }
}

public struct AvailableComponentsResponse: Decodable {
    public let availableComponents: [Property]
    
    private enum CodingKeys: String, CodingKey {
        case availableComponents = "available_components"
    }
}

public struct UpdatePositionRequest: Codable {
    public let position: String
}

// MARK: - Azure OCR Response Models

public struct AzureOCRResponse: Codable {
    public let success: Bool
    public let formInfo: AzureFormInfo
    public let items: [AzureOCRItem]
    public let metadata: AzureOCRMetadata
    public let nextSteps: AzureNextSteps
    
    private enum CodingKeys: String, CodingKey {
        case success
        case formInfo = "form_info"
        case items
        case metadata
        case nextSteps = "next_steps"
    }
}

public struct AzureFormInfo: Codable {
    public let unitName: String?
    public let dodaac: String?
    public let formNumber: String?
    public let confidence: Double
    
    private enum CodingKeys: String, CodingKey {
        case unitName = "unit_name"
        case dodaac
        case formNumber = "form_number"
        case confidence
    }
}

public struct AzureOCRItem: Codable {
    public let name: String
    public let description: String
    public let nsn: String?
    public let serialNumber: String?
    public let quantity: Int
    public let unit: String?
    public let condition: String?
    public let importMetadata: AzureImportMetadata
    
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case nsn
        case serialNumber = "serial_number"
        case quantity
        case unit
        case condition
        case importMetadata = "import_metadata"
    }
}

public struct AzureImportMetadata: Codable {
    public let confidence: Double
    public let requiresVerification: Bool
    public let verificationReasons: [String]
    public let sourceDocumentUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case confidence
        case requiresVerification = "requires_verification"
        case verificationReasons = "verification_reasons"
        case sourceDocumentUrl = "source_document_url"
    }
}

public struct AzureOCRMetadata: Codable {
    public let processingTime: Double
    public let pages: Int
    public let averageConfidence: Double
    public let sourceDocumentUrl: String
    
    private enum CodingKeys: String, CodingKey {
        case processingTime = "processing_time"
        case pages
        case averageConfidence = "average_confidence"
        case sourceDocumentUrl = "source_document_url"
    }
}

public struct AzureNextSteps: Codable {
    public let verificationNeeded: Bool
    public let itemsNeedingReview: Int
    public let suggestedAction: String
    
    private enum CodingKeys: String, CodingKey {
        case verificationNeeded = "verification_needed"
        case itemsNeedingReview = "items_needing_review"
        case suggestedAction = "suggested_action"
    }
}

// MARK: - Batch Import Models

public struct BatchCreateRequest: Codable {
    public let source: String
    public let sourceReference: String?
    public let items: [DA2062BatchItem]
    
    private enum CodingKeys: String, CodingKey {
        case source
        case sourceReference = "source_reference"
        case items
    }
}

public struct DA2062BatchItem: Codable {
    public let name: String
    public let description: String
    public let serialNumber: String?
    public let nsn: String?
    public let quantity: Int
    public let unit: String?
    public let category: String?
    public let importMetadata: BatchImportMetadata?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case description
        case serialNumber = "serial_number"
        case nsn
        case quantity
        case unit
        case category
        case importMetadata = "import_metadata"
    }
}

public struct BatchImportMetadata: Codable {
    public let confidence: Double?
    public let requiresVerification: Bool?
    public let verificationReasons: [String]?
    public let sourceDocumentUrl: String?
    public let originalQuantity: Int?
    public let quantityIndex: Int?
    
    private enum CodingKeys: String, CodingKey {
        case confidence
        case requiresVerification = "requires_verification"
        case verificationReasons = "verification_reasons"
        case sourceDocumentUrl = "source_document_url"
        case originalQuantity = "original_quantity"
        case quantityIndex = "quantity_index"
    }
}

public struct BatchImportResponse: Codable {
    public let success: Bool
    public let createdCount: Int
    public let failedCount: Int
    public let items: [BatchImportItem]
    public let errors: [String]?
    
    private enum CodingKeys: String, CodingKey {
        case success
        case createdCount = "created_count"
        case failedCount = "failed_count"
        case items
        case errors
    }
}

public struct BatchImportItem: Codable {
    public let id: Int?
    public let name: String
    public let serialNumber: String?
    public let status: String
    public let error: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case serialNumber = "serial_number"
        case status
        case error
    }
}

 