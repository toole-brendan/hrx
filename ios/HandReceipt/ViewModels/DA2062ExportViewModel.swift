import Foundation
import SwiftUI

@MainActor
class DA2062ExportViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var selectedPropertyIDs: Set<Int> = []
    @Published var groupByCategory = true
    @Published var includeQRCodes = true
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
        return "HR-\(dateString)-\(UserDefaults.standard.integer(forKey: "user_id"))"
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
            isLoading = false
        } catch {
            isLoading = false
            print("Failed to load properties: \(error)")
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
    
    func generatePDF() async throws -> Data {
        let request = GeneratePDFRequest(
            propertyIDs: Array(selectedPropertyIDs),
            groupByCategory: groupByCategory,
            includeQRCodes: includeQRCodes,
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
            )
        )
        
        return try await apiService.generateDA2062PDF(request: request)
    }
    
    func emailPDF(to recipients: [String]) async throws {
        let request = GeneratePDFRequest(
            propertyIDs: Array(selectedPropertyIDs),
            groupByCategory: groupByCategory,
            includeQRCodes: includeQRCodes,
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
            )
        )
        
        try await apiService.emailDA2062PDF(request: request)
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
    
    enum CodingKeys: String, CodingKey {
        case propertyIDs = "property_ids"
        case groupByCategory = "group_by_category"
        case includeQRCodes = "include_qr_codes"
        case sendEmail = "send_email"
        case recipients
        case fromUser = "from_user"
        case toUser = "to_user"
        case unitInfo = "unit_info"
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
    
    func getUserProperties() async throws -> [Property] {
        guard let url = URL(string: "\(baseURLString)/api/property") else {
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
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to fetch properties")
        }
        
        return try JSONDecoder().decode([Property].self, from: data)
    }
}

struct DA2062ErrorResponse: Codable {
    let error: String
} 