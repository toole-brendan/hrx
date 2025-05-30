import Foundation

class MockAPIService: APIServiceProtocol {
    var baseURLString: String = "http://44.193.254.155:8080/api"
    
    func fetchReferenceItems() async throws -> [ReferenceItem] {
        return [ReferenceItem.example]
    }
    
    func fetchPropertyBySerialNumber(serialNumber: String) async throws -> Property {
        return Property.example
    }
    
    func login(credentials: LoginCredentials) async throws -> LoginResponse {
        return LoginResponse(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            expiresAt: Date().addingTimeInterval(86400), // 24 hours from now
            user: LoginResponse.User(
                id: 1,
                uuid: "mock-uuid",
                username: "mock_user",
                email: "mock@example.com",
                firstName: "Mock",
                lastName: "User",
                rank: "SGT",
                unit: "Mock Unit",
                role: "user",
                status: "active"
            )
        )
    }
    
    func register(credentials: RegisterCredentials) async throws -> LoginResponse {
        return LoginResponse(
            accessToken: "mock_access_token_register",
            refreshToken: "mock_refresh_token_register",
            expiresAt: Date().addingTimeInterval(86400),
            user: LoginResponse.User(
                id: 1,
                uuid: "mock-uuid",
                username: credentials.username,
                email: credentials.email,
                firstName: credentials.first_name,
                lastName: credentials.last_name,
                rank: credentials.rank,
                unit: credentials.unit,
                role: credentials.role,
                status: "active"
            )
        )
    }
    
    func checkSession() async throws -> LoginResponse {
        return LoginResponse(
            accessToken: nil, // No token for session check
            refreshToken: nil,
            expiresAt: nil,
            user: LoginResponse.User(
                id: 1,
                uuid: "mock-uuid",
                username: "mock_user",
                email: "mock@example.com",
                firstName: "Mock",
                lastName: "User",
                rank: "SGT",
                unit: "Mock Unit",
                role: "user",
                status: "active"
            )
        )
    }
    
    func fetchReferenceItemById(itemId: String) async throws -> ReferenceItem {
        return ReferenceItem.example
    }
    
    func getMyProperties() async throws -> [Property] {
        return [Property.example]
    }
    
    func getPropertyById(propertyId: Int) async throws -> Property {
        return Property.example
    }
    
    func logout() async throws {
        // Mock logout - do nothing
    }
    
    func uploadPropertyPhoto(propertyId: Int, imageData: Data) async throws -> PhotoUploadResponse {
        return PhotoUploadResponse(
            message: "Photo uploaded successfully",
            photoUrl: "https://mock.example.com/photo.jpg",
            hash: "mock_hash",
            filename: "photo.jpg"
        )
    }
    
    func verifyPhotoHash(propertyId: Int, filename: String, expectedHash: String) async throws -> PhotoVerificationResponse {
        return PhotoVerificationResponse(
            valid: true,
            expectedHash: expectedHash,
            actualHash: expectedHash
        )
    }
    
    func deletePropertyPhoto(propertyId: Int, filename: String) async throws {
        // Mock delete - do nothing
    }
    
    func fetchTransfers(status: String?, direction: String?) async throws -> [Transfer] {
        return []
    }
    
    func requestTransfer(propertyId: Int, targetUserId: Int) async throws -> Transfer {
        return Transfer(
            id: 1,
            propertyId: propertyId,
            propertySerialNumber: "SN123456",
            propertyName: "Mock Property",
            fromUserId: 1,
            toUserId: targetUserId,
            status: .PENDING,
            requestTimestamp: Date(),
            approvalTimestamp: nil,
            fromUser: nil,
            toUser: nil,
            notes: nil
        )
    }
    
    func approveTransfer(transferId: Int) async throws -> Transfer {
        return Transfer(
            id: transferId,
            propertyId: 1,
            propertySerialNumber: "SN123456",
            propertyName: "Mock Property",
            fromUserId: 1,
            toUserId: 2,
            status: .APPROVED,
            requestTimestamp: Date(),
            approvalTimestamp: Date(),
            fromUser: nil,
            toUser: nil,
            notes: nil
        )
    }
    
    func rejectTransfer(transferId: Int) async throws -> Transfer {
        return Transfer(
            id: transferId,
            propertyId: 1,
            propertySerialNumber: "SN123456",
            propertyName: "Mock Property",
            fromUserId: 1,
            toUserId: 2,
            status: .REJECTED,
            requestTimestamp: Date(),
            approvalTimestamp: Date(),
            fromUser: nil,
            toUser: nil,
            notes: nil
        )
    }
    
    func initiateQRTransfer(qrData: [String: Any], scannedAt: String) async throws -> QRTransferResponse {
        return QRTransferResponse(transferId: 1)
    }
    
    func fetchUsers(searchQuery: String?) async throws -> [UserSummary] {
        return [
            UserSummary(
                id: 1,
                username: "mock_user",
                rank: "SGT",
                lastName: "User"
            )
        ]
    }
    
    func lookupNSN(nsn: String) async throws -> NSNLookupResponse {
        return NSNLookupResponse(
            success: true,
            data: NSNDetails(
                nsn: nsn,
                lin: "E03045",
                nomenclature: "Mock Item",
                fsc: "1005",
                niin: "015841079",
                unitPrice: 100.0,
                manufacturer: "Mock Manufacturer",
                partNumber: "MOCK123",
                specifications: nil,
                lastUpdated: Date()
            )
        )
    }
    
    func lookupLIN(lin: String) async throws -> NSNLookupResponse {
        return NSNLookupResponse(
            success: true,
            data: NSNDetails(
                nsn: "1005-01-584-1079",
                lin: lin,
                nomenclature: "Mock Item",
                fsc: "1005",
                niin: "015841079",
                unitPrice: 100.0,
                manufacturer: "Mock Manufacturer",
                partNumber: "MOCK123",
                specifications: nil,
                lastUpdated: Date()
            )
        )
    }
    
    func searchNSN(query: String, limit: Int?) async throws -> NSNSearchResponse {
        return NSNSearchResponse(
            success: true,
            data: [
                NSNDetails(
                    nsn: "1005-01-584-1079",
                    lin: "E03045",
                    nomenclature: "Mock Item \(query)",
                    fsc: "1005",
                    niin: "015841079",
                    unitPrice: 100.0,
                    manufacturer: "Mock Manufacturer",
                    partNumber: "MOCK123",
                    specifications: nil,
                    lastUpdated: Date()
                )
            ],
            count: 1
        )
    }
    
    func createProperty(_ property: CreatePropertyInput) async throws -> Property {
        return Property(
            id: Int.random(in: 1000...9999),
            serialNumber: property.serialNumber,
            nsn: property.nsn ?? "1005-01-584-1079",
            lin: property.lin,
            itemName: property.name,
            description: property.description,
            manufacturer: nil,
            imageUrl: nil,
            status: property.currentStatus,
            currentStatus: property.currentStatus,
            assignedToUserId: property.assignedToUserId,
            location: nil,
            lastInventoryDate: nil,
            acquisitionDate: Date(),
            notes: nil,
            maintenanceDueDate: nil,
            isSensitiveItem: false
        )
    }
} 