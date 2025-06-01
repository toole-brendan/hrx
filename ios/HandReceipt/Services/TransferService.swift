import Foundation

public class TransferService: ObservableObject {
    public static let shared = TransferService()
    
    private let apiService: APIServiceProtocol
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
    }
    
    // MARK: - Transfer Offers
    
    /// Get active transfer offers
    public func getActiveOffers() async throws -> [TransferOffer] {
        return try await apiService.getActiveOffers()
    }
    
    /// Create a transfer offer (supports single property to single user)
    public func createOffer(propertyId: Int, offeredToUserId: Int, notes: String? = nil, expiresAt: Date? = nil) async throws -> TransferOffer {
        // Convert single property/user to arrays for bulk endpoint
        return try await apiService.createTransferOffer(
            propertyIds: [propertyId],
            recipientIds: [offeredToUserId],
            notes: notes
        )
    }
    
    /// Create a bulk transfer offer (multiple properties to multiple users)
    public func createBulkOffer(propertyIds: [Int], recipientIds: [Int], notes: String? = nil) async throws -> TransferOffer {
        return try await apiService.createTransferOffer(
            propertyIds: propertyIds,
            recipientIds: recipientIds,
            notes: notes
        )
    }
    
    /// Accept a transfer offer
    public func acceptOffer(_ offerId: Int) async throws -> TransferOffer {
        return try await apiService.acceptOffer(offerId: offerId)
    }
    
    /// Reject a transfer offer (using generic transfer status update)
    public func rejectOffer(_ offerId: Int) async throws {
        // Since there's no specific reject offer endpoint, we might need to use the transfer status update
        // For now, throw not implemented
        throw APIService.APIError.serverError(statusCode: 501, message: "Reject offer not implemented")
    }
    
    // MARK: - Transfer Requests
    
    /// Request transfer by serial number
    public func requestBySerial(serialNumber: String, notes: String? = nil) async throws -> Transfer {
        return try await apiService.requestTransferBySerial(
            serialNumber: serialNumber,
            notes: notes
        )
    }
    
    /// Get a specific transfer by ID
    public func getTransfer(transferId: Int) async throws -> Transfer {
        return try await apiService.getTransferById(transferId: transferId)
    }
} 