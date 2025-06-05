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
        let request = GeneratePDFRequest(
            propertyIDs: Array(selectedPropertyIDs),
            groupByCategory: groupByCategory,
            includeQRCodes: false,
            sendEmail: false,
            recipients: [],
            fromUser: PDFUserInfo(
                name: userInfo.name,
                rank: userInfo.rank,
                title: userInfo.title,
                phone: userInfo.phone
            ),
            toUser: PDFUserInfo(
                name: userInfo.name,
                rank: userInfo.rank,
                title: userInfo.title,
                phone: userInfo.phone
            ),
            unitInfo: PDFUnitInfo(
                unitName: unitInfo.unitName,
                dodaac: unitInfo.dodaac,
                stockNumber: unitInfo.stockNumber,
                location: unitInfo.location
            ),
            toUserId: 0
        )
        
        return try await apiService.generateDA2062PDF(request: request)
    }
    
    func emailPDF(to recipients: [String]) async throws {
        let request = GeneratePDFRequest(
            propertyIDs: Array(selectedPropertyIDs),
            groupByCategory: groupByCategory,
            includeQRCodes: false,
            sendEmail: true,
            recipients: recipients,
            fromUser: PDFUserInfo(
                name: userInfo.name,
                rank: userInfo.rank,
                title: userInfo.title,
                phone: userInfo.phone
            ),
            toUser: PDFUserInfo(
                name: userInfo.name,
                rank: userInfo.rank,
                title: userInfo.title,
                phone: userInfo.phone
            ),
            unitInfo: PDFUnitInfo(
                unitName: unitInfo.unitName,
                dodaac: unitInfo.dodaac,
                stockNumber: unitInfo.stockNumber,
                location: unitInfo.location
            ),
            toUserId: 0
        )
        
        try await apiService.emailDA2062PDF(request: request)
    }
    
    func sendHandReceipt(to recipientId: Int) async throws {
        let request = GeneratePDFRequest(
            propertyIDs: Array(selectedPropertyIDs),
            groupByCategory: groupByCategory,
            includeQRCodes: false,
            sendEmail: false,
            recipients: [],
            fromUser: PDFUserInfo(
                name: userInfo.name,
                rank: userInfo.rank,
                title: userInfo.title,
                phone: userInfo.phone
            ),
            toUser: PDFUserInfo(
                name: userInfo.name,
                rank: userInfo.rank,
                title: userInfo.title,
                phone: userInfo.phone
            ),
            unitInfo: PDFUnitInfo(
                unitName: unitInfo.unitName,
                dodaac: unitInfo.dodaac,
                stockNumber: unitInfo.stockNumber,
                location: unitInfo.location
            ),
            toUserId: recipientId
        )
        
        _ = try await apiService.sendDA2062InApp(request: request)
    }
}

// MARK: - Request Models

struct GeneratePDFRequest: Codable {
    let propertyIDs: [Int]
    let groupByCategory: Bool
    let includeQRCodes: Bool
    let sendEmail: Bool
    let recipients: [String]
    let fromUser: PDFUserInfo
    let toUser: PDFUserInfo
    let unitInfo: PDFUnitInfo
    let toUserId: Int
    
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
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONDecoder().decode(DA2062ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorData.error)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to generate PDF")
        }
        
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
            if let errorData = try? JSONDecoder().decode(DA2062ErrorResponse.self, from: data) {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorData.error)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to send hand receipt")
        }
        
        // Decode the returned document
        let result = try JSONDecoder().decode([String: Document].self, from: data)
        guard let document = result["document"] else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Invalid server response")
        }
        return document
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