import Foundation
import SwiftUI

@MainActor
class DA2062ExportViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var selectedPropertyIDs: Set<Int> = []
    @Published var groupByCategory = true
    @Published var unitInfo = UnitInfo()
    @Published var userInfo = UserInfo()
    @Published var isLoading = false
    @Published var recipientConnection: UserConnection? = nil
    
    private let apiService = APIService.shared
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    
    var formNumber: String {
        let dateString = dateFormatter.string(from: Date())
        let userId = AuthManager.shared.getUserId() ?? 0
        return "HR-\(dateString)-\(userId)"
    }
    
    struct UnitInfo {
        var unitName: String = UserDefaults.standard.string(forKey: "unit_name") ?? ""
        var dodaac: String = UserDefaults.standard.string(forKey: "unit_dodaac") ?? ""
        var location: String = UserDefaults.standard.string(forKey: "unit_location") ?? ""
        var stockNumber: String = UserDefaults.standard.string(forKey: "unit_stock_number") ?? ""
    }
    
    struct UserInfo {
        var name: String = UserDefaults.standard.string(forKey: "user_name") ?? ""
        var rank: String = UserDefaults.standard.string(forKey: "user_rank") ?? ""
        var title: String = UserDefaults.standard.string(forKey: "user_title") ?? "Property Book Officer"
        var phone: String = UserDefaults.standard.string(forKey: "user_phone") ?? ""
    }
    
    func loadUserProperties() async {
        isLoading = true
        do {
            properties = try await apiService.getUserProperties()
            print("Loaded \(properties.count) properties")
            isLoading = false
        } catch {
            isLoading = false
            print("Failed to load properties: \(error)")
        }
    }
    
    func loadUserPropertiesAndSetSelection(_ initialPropertyIDs: [Int]) async {
        await loadUserProperties()
        if !initialPropertyIDs.isEmpty && !properties.isEmpty {
            print("Setting initial selection for property IDs: \(initialPropertyIDs)")
            print("Available property IDs: \(properties.map { $0.id })")
            setInitialSelection(initialPropertyIDs)
        }
    }
    
    func toggleSelection(for propertyID: Int) {
        if selectedPropertyIDs.contains(propertyID) {
            selectedPropertyIDs.remove(propertyID)
        } else {
            selectedPropertyIDs.insert(propertyID)
        }
    }
    
    func selectAll() {
        selectedPropertyIDs = Set(properties.map { $0.id })
    }
    
    func clearSelection() {
        selectedPropertyIDs.removeAll()
    }
    
    func selectCategory(_ category: String) {
        clearSelection()
        switch category {
        case "weapons":
            selectedPropertyIDs = Set(properties.filter { $0.name.lowercased().contains("weapon") || $0.description?.lowercased().contains("weapon") == true }.map { $0.id })
        case "equipment":
            selectedPropertyIDs = Set(properties.filter { $0.name.lowercased().contains("equipment") || $0.description?.lowercased().contains("equipment") == true }.map { $0.id })
        default:
            break
        }
    }
    
    func selectSensitiveItems() {
        clearSelection()
        selectedPropertyIDs = Set(properties.filter { $0.isSensitive }.map { $0.id })
    }
    
    func setInitialSelection(_ propertyIDs: [Int]) {
        print("setInitialSelection called with IDs: \(propertyIDs)")
        let validIDs = propertyIDs.filter { id in
            properties.contains { $0.id == id }
        }
        print("Valid property IDs found: \(validIDs)")
        selectedPropertyIDs = Set(validIDs)
        print("Selected property IDs set to: \(selectedPropertyIDs)")
    }
    
    func generatePDF() async throws -> Data {
        // Get current user's signature URL if available
        let currentUserId = AuthManager.shared.getUserId() ?? 0
        let signatureUrl = UserDefaults.standard.string(forKey: "user_signature_url_\(currentUserId)")
        
        let fromInfo = PDFUserInfo(
            name: userInfo.name,
            rank: userInfo.rank,
            title: userInfo.title,
            phone: userInfo.phone,
            signatureUrl: signatureUrl
        )
        
        var toInfo = fromInfo
        var recipientId: UInt = 0
        
        if let connection = recipientConnection, let other = connection.connectedUser {
            // Build the recipient's PDFUserInfo from connection details
            let fullName = [other.firstName, other.lastName]
                          .compactMap{$0}.joined(separator: " ")
            toInfo = PDFUserInfo(
                name: fullName.isEmpty ? other.email ?? "" : fullName,
                rank: other.rank ?? "",
                title: !(other.unit ?? "").isEmpty ? other.unit! : "Hand Receipt Holder",
                phone: "",  // we don't have the other user's phone in UserSummary
                signatureUrl: nil  // TODO: Fetch recipient's signature URL if needed
            )
            recipientId = UInt(other.id)
        }
        
        let request = GeneratePDFRequest(
            propertyIDs: selectedPropertyIDs.map { UInt($0) },
            groupByCategory: groupByCategory,
            includeQRCodes: false,
            sendEmail: false,
            recipients: [],
            fromUser: fromInfo,
            toUser: toInfo,
            unitInfo: PDFUnitInfo(
                unitName: unitInfo.unitName,
                dodaac: unitInfo.dodaac,
                stockNumber: unitInfo.stockNumber,
                location: unitInfo.location
            ),
            toUserId: recipientId
        )
        
        return try await apiService.generateDA2062PDF(request: request)
    }
    
    func emailPDF(to recipients: [String]) async throws {
        // Get current user's signature URL if available
        let currentUserId = AuthManager.shared.getUserId() ?? 0
        let signatureUrl = UserDefaults.standard.string(forKey: "user_signature_url_\(currentUserId)")
        
        let fromInfo = PDFUserInfo(
            name: userInfo.name,
            rank: userInfo.rank,
            title: userInfo.title,
            phone: userInfo.phone,
            signatureUrl: signatureUrl
        )
        
        var toInfo = fromInfo
        var recipientId: UInt = 0
        
        if let connection = recipientConnection, let other = connection.connectedUser {
            // Build the recipient's PDFUserInfo from connection details
            let fullName = [other.firstName, other.lastName]
                          .compactMap{$0}.joined(separator: " ")
            toInfo = PDFUserInfo(
                name: fullName.isEmpty ? other.email ?? "" : fullName,
                rank: other.rank ?? "",
                title: !(other.unit ?? "").isEmpty ? other.unit! : "Hand Receipt Holder",
                phone: "",  // we don't have the other user's phone in UserSummary
                signatureUrl: nil  // TODO: Fetch recipient's signature URL if needed
            )
            recipientId = UInt(other.id)
        }
        
        let request = GeneratePDFRequest(
            propertyIDs: selectedPropertyIDs.map { UInt($0) },
            groupByCategory: groupByCategory,
            includeQRCodes: false,
            sendEmail: true,
            recipients: recipients,
            fromUser: fromInfo,
            toUser: toInfo,
            unitInfo: PDFUnitInfo(
                unitName: unitInfo.unitName,
                dodaac: unitInfo.dodaac,
                stockNumber: unitInfo.stockNumber,
                location: unitInfo.location
            ),
            toUserId: recipientId
        )
        
        try await apiService.emailDA2062PDF(request: request)
    }
    
    func sendHandReceipt(to recipientId: Int) async throws {
        // Get current user's signature URL if available
        let currentUserId = AuthManager.shared.getUserId() ?? 0
        let signatureUrl = UserDefaults.standard.string(forKey: "user_signature_url_\(currentUserId)")
        
        let fromInfo = PDFUserInfo(
            name: userInfo.name,
            rank: userInfo.rank,
            title: userInfo.title,
            phone: userInfo.phone,
            signatureUrl: signatureUrl
        )
        
        guard let other = recipientConnection?.connectedUser else {
            throw NSError(domain: "DA2062Export", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recipient not set"])
        }
        
        let fullName = [other.firstName, other.lastName]
                      .compactMap{$0}.joined(separator: " ")
        let toInfo = PDFUserInfo(
            name: fullName.isEmpty ? other.email ?? "" : fullName,
            rank: other.rank ?? "",
            title: !(other.unit ?? "").isEmpty ? other.unit! : "Hand Receipt Holder",
            phone: "",
            signatureUrl: nil  // TODO: Fetch recipient's signature URL if needed
        )
        
        let request = GeneratePDFRequest(
            propertyIDs: selectedPropertyIDs.map { UInt($0) },
            groupByCategory: groupByCategory,
            includeQRCodes: false,
            sendEmail: false,
            recipients: [],
            fromUser: fromInfo,
            toUser: toInfo,
            unitInfo: PDFUnitInfo(
                unitName: unitInfo.unitName,
                dodaac: unitInfo.dodaac,
                stockNumber: unitInfo.stockNumber,
                location: unitInfo.location
            ),
            toUserId: UInt(recipientId)
        )
        
        _ = try await apiService.sendDA2062InApp(request: request)
    }
}

// MARK: - Request Models

struct GeneratePDFRequest: Codable {
    let propertyIDs: [UInt]
    let groupByCategory: Bool
    let includeQRCodes: Bool
    let sendEmail: Bool
    let recipients: [String]
    let fromUser: PDFUserInfo
    let toUser: PDFUserInfo
    let unitInfo: PDFUnitInfo
    let toUserId: UInt
    
    enum CodingKeys: String, CodingKey {
        case propertyIDs = "property_ids"
        case groupByCategory = "group_by_category"
        case includeQRCodes = "include_qr_codes"
        case sendEmail = "send_email"
        case recipients
        case fromUser = "from_user"
        case toUser = "to_user"
        case unitInfo = "unit_info"
        case toUserId = "to_user_id"
    }
}

struct PDFUserInfo: Codable {
    let name: String
    let rank: String
    let title: String
    let phone: String
    let signatureUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case name, rank, title, phone
        case signatureUrl = "signature_url"
    }
}

struct PDFUnitInfo: Codable {
    let unitName: String
    let dodaac: String
    let stockNumber: String
    let location: String
    
    enum CodingKeys: String, CodingKey {
        case unitName = "unit_name"
        case dodaac
        case stockNumber = "stock_number"
        case location
    }
}

// MARK: - Property Extensions
// isSensitive property is now defined in Property.swift

// MARK: - API Service Extensions

extension APIService {
    func generateDA2062PDF(request: GeneratePDFRequest) async throws -> Data {
        guard let url = URL(string: "\(baseURLString)/api/da2062/generate-pdf") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if available
        if let accessToken = AuthManager.shared.getAccessToken() {
            urlRequest.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData
        
        // Debug: Print request details
        print("DEBUG: DA2062 PDF request URL: \(url)")
        if let requestString = String(data: requestData, encoding: .utf8) {
            print("DEBUG: DA2062 PDF request body: \(requestString)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        print("DEBUG: DA2062 PDF response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("DEBUG: DA2062 PDF failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG: DA2062 PDF error response: \(responseString)")
            }
            
            if let errorData = try? JSONDecoder().decode(DA2062ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorData.error)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to generate PDF")
        }
        
        print("DEBUG: DA2062 PDF generated successfully, data size: \(data.count) bytes")
        return data
    }
    
    func emailDA2062PDF(request: GeneratePDFRequest) async throws {
        guard let url = URL(string: "\(baseURLString)/api/da2062/generate-pdf") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if available
        if let accessToken = AuthManager.shared.getAccessToken() {
            urlRequest.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(DA2062ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorData.error)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to send email")
        }
    }
    
    func sendDA2062InApp(request: GeneratePDFRequest) async throws -> Document {
        guard let url = URL(string: "\(baseURLString)/api/da2062/generate-pdf") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header if available
        if let accessToken = AuthManager.shared.getAccessToken() {
            urlRequest.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let requestData = try JSONEncoder().encode(request)
        urlRequest.httpBody = requestData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 201 else {
            // Log the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG: Non-201 response (\(httpResponse.statusCode)): \(responseString)")
            }
            
            if let errorData = try? JSONDecoder().decode(DA2062ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorData.error)
            }
            
            // Try to parse as generic error response
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let errorMessage = jsonObject["error"] as? String {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
            
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to send hand receipt")
        }
        
        // Debug: Print raw response for troubleshooting
        if let responseString = String(data: data, encoding: .utf8) {
            print("DEBUG: DA2062 in-app send response: \(responseString)")
        }
        
        // Configure decoder to handle ISO8601 dates from backend
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Use custom date decoding to handle various ISO8601 formats
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Try multiple date formats
            let dateFormatters = [
                "yyyy-MM-dd'T'HH:mm:ss'Z'",           // ISO 8601 UTC
                "yyyy-MM-dd'T'HH:mm:ssZ",             // ISO 8601 with Z
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",         // ISO 8601 with milliseconds
                "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",       // ISO 8601 with milliseconds and Z
                "yyyy-MM-dd'T'HH:mm:ss",              // ISO 8601 without timezone
            ]
            
            for format in dateFormatters {
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
        }
        
        do {
            // Decode using the existing SendMaintenanceFormResponse structure
            let response = try decoder.decode(SendMaintenanceFormResponse.self, from: data)
            return response.document
        } catch {
            print("DEBUG: Failed to decode Document response: \(error)")
            
            // Try to decode just to see the structure
            if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("DEBUG: Response structure: \(jsonObject.keys)")
                if let documentData = jsonObject["document"] as? [String: Any] {
                    print("DEBUG: Document keys: \(documentData.keys)")
                    // Check specific fields that might be problematic
                    if let attachments = documentData["attachments"] {
                        print("DEBUG: Attachments type: \(type(of: attachments)), value: \(attachments)")
                    }
                    if let sentAt = documentData["sentAt"] {
                        print("DEBUG: sentAt type: \(type(of: sentAt)), value: \(sentAt)")
                    }
                }
            }
            
            // If decoding fails, try to provide more specific error information
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("DEBUG: Type mismatch - expected \(type)")
                    print("DEBUG: Context path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("DEBUG: Debug description: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("DEBUG: Value not found - type: \(type)")
                    print("DEBUG: Context path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .keyNotFound(let key, let context):
                    print("DEBUG: Key not found - key: \(key.stringValue)")
                    print("DEBUG: Context path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("DEBUG: Data corrupted")
                    print("DEBUG: Context path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    print("DEBUG: Debug description: \(context.debugDescription)")
                @unknown default:
                    print("DEBUG: Unknown decoding error")
                }
            }
            
            // Return a more user-friendly error message
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unable to process server response. Please try again.")
        }
    }
    
    func getUserProperties() async throws -> [Property] {
        // Get current user ID from AuthManager
        guard let currentUserID = AuthManager.shared.getUserId() else {
            print("DEBUG: No user ID in AuthManager, checking session...")
            
            // Try to get user info from session check
            do {
                let sessionResponse = try await self.checkSession()
                let userId = sessionResponse.user.id
                print("DEBUG: Got user ID from session: \(userId)")
                
                return try await getUserPropertiesForUser(userId)
            } catch {
                print("DEBUG: Session check failed: \(error)")
                throw APIError.badRequest(message: "User not logged in - session check failed")
            }
        }
        
        print("DEBUG: Using user ID from AuthManager: \(currentUserID)")
        return try await getUserPropertiesForUser(currentUserID)
    }
    
    private func getUserPropertiesForUser(_ userId: Int) async throws -> [Property] {
        print("DEBUG: Fetching properties for user ID: \(userId)")
        
        guard let url = URL(string: "\(baseURLString)/api/property?assignedToUserId=\(userId)") else {
            throw APIError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        
        // Add authorization header if available
        if let accessToken = AuthManager.shared.getAccessToken() {
            urlRequest.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            print("DEBUG: API call failed with status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("DEBUG: Response body: \(responseString)")
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to fetch properties")
        }
        
        // Debug: Print raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("DEBUG: Raw API response: \(responseString.prefix(500))...")  // First 500 chars
        }
        
        // Decode the wrapped response format {"properties": [...]}
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Set up custom date decoding strategy to handle ISO 8601 date strings
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            
            // Try to decode as string first
            if let dateString = try? container.decode(String.self) {
                // Try multiple date formats
                let dateFormatters = [
                    "yyyy-MM-dd'T'HH:mm:ss'Z'",           // ISO 8601 UTC
                    "yyyy-MM-dd'T'HH:mm:ssZ",             // ISO 8601 with Z
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",         // ISO 8601 with milliseconds
                    "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",       // ISO 8601 with milliseconds and Z
                    "yyyy-MM-dd HH:mm:ss",                // Simple format
                ]
                
                for format in dateFormatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone(abbreviation: "UTC")
                    
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                print("DEBUG: Could not parse date string: \(dateString)")
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
            }
            
            // Try to decode as timestamp (Double)
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            
            // Try to decode as timestamp (Int)
            if let timestamp = try? container.decode(Int.self) {
                return Date(timeIntervalSince1970: Double(timestamp))
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date - expected string or number")
        }
        
        let propertiesResponse = try decoder.decode(PropertiesResponse.self, from: data)
        print("DEBUG: Successfully decoded \(propertiesResponse.properties.count) properties")
        return propertiesResponse.properties
    }
}

struct DA2062ErrorResponse: Codable {
    let error: String
}

struct PropertiesResponse: Codable {
    let properties: [Property]
}