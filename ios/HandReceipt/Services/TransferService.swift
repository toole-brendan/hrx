import Foundation

public class TransferService: ObservableObject {
    public static let shared = TransferService()
    
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    // MARK: - Transfer Offers
    
    public func getActiveOffers() async throws -> [TransferOffer] {
        // For now, return empty array - implement when backend API is available
        return []
    }
    
    public func createOffer(_ request: TransferOfferRequest) async throws {
        // Implement when backend API is available
        throw APIService.APIError.serverError(statusCode: 501, message: "Feature not implemented")
    }
    
    public func acceptOffer(_ offerId: Int) async throws {
        // Implement when backend API is available
        throw APIService.APIError.serverError(statusCode: 501, message: "Feature not implemented")
    }
    
    public func rejectOffer(_ offerId: Int) async throws {
        // Implement when backend API is available
        throw APIService.APIError.serverError(statusCode: 501, message: "Feature not implemented")
    }
    
    // MARK: - Transfer Requests
    
    public func requestBySerial(_ request: SerialTransferRequest) async throws {
        // Implement when backend API is available
        throw APIService.APIError.serverError(statusCode: 501, message: "Feature not implemented")
    }
}

// Supporting models for TransferService
public struct TransferOfferRequest: Codable {
    public let propertyId: Int
    public let offeredToUserId: Int
    public let notes: String?
    public let expiresAt: Date?
    
    public init(propertyId: Int, offeredToUserId: Int, notes: String? = nil, expiresAt: Date? = nil) {
        self.propertyId = propertyId
        self.offeredToUserId = offeredToUserId
        self.notes = notes
        self.expiresAt = expiresAt
    }
}

public struct SerialTransferRequest: Codable {
    public let serialNumber: String
    public let requestedFromUserId: Int?
    public let notes: String?
    
    public init(serialNumber: String, requestedFromUserId: Int? = nil, notes: String? = nil) {
        self.serialNumber = serialNumber
        self.requestedFromUserId = requestedFromUserId
        self.notes = notes
    }
} 