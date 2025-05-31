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
    // Function to fetch reference items. Throws errors for network/parsing issues.
    func fetchReferenceItems() async throws -> [ReferenceItem]

    // Function to fetch a specific property by its serial number.
    func fetchPropertyBySerialNumber(serialNumber: String) async throws -> Property

    // Function to login a user.
    func login(credentials: LoginCredentials) async throws -> LoginResponse

    // Function to register a new user.
    func register(credentials: RegisterCredentials) async throws -> LoginResponse

    // Function to check the current session status by fetching user profile.
    func checkSession() async throws -> LoginResponse

    // Add function to fetch a specific reference item by ID
    func fetchReferenceItemById(itemId: String) async throws -> ReferenceItem

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
    // func fetchItemByNSN(nsn: String) async throws -> ReferenceItem
    
    // --- Transfer Functions ---
    func fetchTransfers(status: String?, direction: String?) async throws -> [Transfer]
    func requestTransfer(propertyId: Int, targetUserId: Int) async throws -> Transfer
    func approveTransfer(transferId: Int) async throws -> Transfer
    func rejectTransfer(transferId: Int) async throws -> Transfer

    // --- QR Transfer Functions ---
    func initiateQRTransfer(qrData: [String: Any], scannedAt: String) async throws -> QRTransferResponse

    // --- User Functions ---
    func fetchUsers(searchQuery: String?) async throws -> [UserSummary] // Expect UserSummary for selection

    // --- User Connection Functions ---
    func getConnections() async throws -> [UserConnection]
    func searchUsers(query: String) async throws -> [User]
    func sendConnectionRequest(targetUserId: Int) async throws -> UserConnection
    func updateConnectionStatus(connectionId: Int, status: String) async throws -> UserConnection

    // Add requirement for base URL string for cookie clearing
    var baseURLString: String { get }
    
    // --- NSN/LIN Lookup Functions ---
    func lookupNSN(nsn: String) async throws -> NSNLookupResponse
    func lookupLIN(lin: String) async throws -> NSNLookupResponse
    func searchNSN(query: String, limit: Int?) async throws -> NSNSearchResponse

    // Add function to create a new property
    func createProperty(_ property: CreatePropertyInput) async throws -> Property
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

    // Replace with your actual backend base URL
    private let baseURL: URL
    public var baseURLString: String { baseURL.absoluteString } // Conform to protocol

    // Use URLSession.shared by default, which handles cookies automatically via HTTPCookieStorage
    private let urlSession: URLSession

    // Allow injecting a custom URLSession (e.g., for testing or specific configurations)
    public init(urlSession: URLSession = .shared, baseURLString: String = "https://api.handreceipt.com") {
        debugPrint("Initializing APIService with baseURL: \(baseURLString)")
        
        if let url = URL(string: baseURLString) {
            self.baseURL = url
        } else {
            debugPrint("ERROR: Invalid base URL provided: \(baseURLString). Using fallback URL.")
            // Fallback URL in case of invalid string
            self.baseURL = URL(string: "https://api.handreceipt.com")!
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
        decoder.dateDecodingStrategy = .iso8601 // Matches Property model
        decoder.keyDecodingStrategy = .convertFromSnakeCase // Handle snake_case keys from server
        debugPrint("Creating JSONDecoder with .iso8601 date strategy and .convertFromSnakeCase key strategy")
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

    public func fetchReferenceItems() async throws -> [ReferenceItem] {
        debugPrint("Fetching all reference items")
        let endpoint = baseURL.appendingPathComponent("/api/reference/models")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies are handled automatically by URLSession/HTTPCookieStorage
        
        // Use wrapper response type and extract models array
        let response = try await performRequest(request: request) as ReferenceItemsResponse
        debugPrint("Successfully fetched \(response.models.count) reference items")
        return response.models
    }

    public func fetchPropertyBySerialNumber(serialNumber: String) async throws -> Property {
        debugPrint("Fetching property with serial number: \(serialNumber)")
        guard let encodedSerialNumber = serialNumber.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            debugPrint("ERROR: Failed to percent encode serial number: \(serialNumber)")
            throw APIError.invalidURL
        }
        let endpoint = baseURL.appendingPathComponent("/api/inventory/property/serial/\(encodedSerialNumber)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies are handled automatically by URLSession/HTTPCookieStorage
        let property = try await performRequest(request: request) as Property
        debugPrint("Successfully fetched property with serial: \(serialNumber), ID: \(property.id)")
        return property
    }

    // Function to fetch a specific reference item by ID
    public func fetchReferenceItemById(itemId: String) async throws -> ReferenceItem {
        debugPrint("Fetching reference item with ID: \(itemId)")
        guard let encodedItemId = itemId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            debugPrint("ERROR: Failed to percent encode item ID: \(itemId)")
            throw APIError.invalidURL
        }
        let endpoint = baseURL.appendingPathComponent("/api/reference/models/\(encodedItemId)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        // Cookies are handled automatically by URLSession/HTTPCookieStorage
        let item = try await performRequest(request: request) as ReferenceItem
        debugPrint("Successfully fetched reference item: \(item.name)")
        return item
    }

    // Function to fetch current user's properties
    public func getMyProperties() async throws -> [Property] {
        debugPrint("Fetching current user's properties")
        
        // First get the current user ID
        let userResponse = try await checkSession()
        let userId = userResponse.user.id
        
        let endpoint = baseURL.appendingPathComponent("/api/inventory/user/\(userId)")
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
        let endpoint = baseURL.appendingPathComponent("/api/inventory/property/\(propertyId)")
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
        let endpoint = baseURL.appendingPathComponent("/api/inventory")
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
    public func searchUsers(query: String) async throws -> [User] {
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

    // --- QR Transfer Functions ---
    public func initiateQRTransfer(qrData: [String: Any], scannedAt: String) async throws -> QRTransferResponse {
        debugPrint("Initiating QR transfer with data: \(qrData)")
        let endpoint = baseURL.appendingPathComponent("/api/transfers/qr-initiate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeader(to: &request)
        
        // Create the request body manually since we have a dictionary
        let requestBody: [String: Any] = [
            "qr_data": qrData,
            "scanned_at": scannedAt
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            debugPrint("Successfully encoded QR transfer request body")
        } catch {
            debugPrint("ERROR: Failed to encode QR transfer request: \(error)")
            throw APIError.encodingError(error)
        }
        
        let response = try await performRequest(request: request) as QRTransferResponse
        debugPrint("QR transfer initiated successfully: \(response.transferId)")
        return response
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
    
    // Map server field names
    private enum CodingKeys: String, CodingKey {
        case nsn, lin, nomenclature, fsc, niin
        case unitPrice = "unit_price"
        case manufacturer
        case partNumber = "part_number"
        case specifications
        case lastUpdated = "last_updated"
    }
    
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

public struct QRTransferResponse: Decodable {
    public let transferId: Int
}

// Connection response models
public struct ConnectionsResponse: Decodable {
    public let connections: [UserConnection]
}

public struct UsersResponse: Decodable {
    public let users: [User]
} 