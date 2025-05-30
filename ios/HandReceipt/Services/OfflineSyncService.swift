import Foundation
import Network
import CryptoKit

class OfflineSyncService {
    static let shared = OfflineSyncService()
    
    private let apiService: APIServiceProtocol
    private let coreDataStack = CoreDataStack.shared
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.handreceipt.networkmonitor")
    
    private var isSyncing = false
    private var syncTimer: Timer?
    
    var isOnline = false {
        didSet {
            if isOnline && !oldValue {
                debugPrint("Network connectivity restored - starting sync")
                startSync()
            }
        }
    }
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        setupNetworkMonitoring()
        setupPeriodicSync()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
                debugPrint("Network status changed: \(path.status == .satisfied ? "Online" : "Offline")")
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func setupPeriodicSync() {
        // Sync every 5 minutes when online
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            if self?.isOnline == true {
                self?.startSync()
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startSync() {
        guard isOnline, !isSyncing else {
            debugPrint("Sync skipped: Online=\(isOnline), Already syncing=\(isSyncing)")
            return
        }
        
        isSyncing = true
        
        Task {
            await syncAll()
            isSyncing = false
        }
    }
    
    // MARK: - Sync Operations
    
    private func syncAll() async {
        debugPrint("Starting full sync process")
        
        // TODO: Uncomment when Core Data entities are implemented
        // 1. Process sync queue items
        // await processSyncQueue()
        
        // 2. Upload pending photos
        await uploadPendingPhotos()
        
        // 3. Sync properties from server
        await syncProperties()
        
        // 4. Sync transfers from server
        await syncTransfers()
        
        // 5. Clean up old sync items
        // coreDataStack.cleanupCompletedSyncItems()
        
        debugPrint("Full sync process completed")
    }
    
    // TODO: Implement when SyncQueueItem entity is created
    /*
    private func processSyncQueue() async {
        let pendingItems = coreDataStack.getPendingSyncItems()
        debugPrint("Processing \(pendingItems.count) pending sync items")
        
        for item in pendingItems {
            await processSyncItem(item)
        }
    }
    
    private func processSyncItem(_ item: SyncQueueItem) async {
        guard let operationType = item.operationType,
              let entityType = item.entityType,
              let payload = item.payload else {
            debugPrint("Invalid sync item - marking as failed")
            coreDataStack.updateSyncItemStatus(item: item, status: "FAILED", errorMessage: "Missing required fields")
            return
        }
        
        coreDataStack.updateSyncItemStatus(item: item, status: "IN_PROGRESS")
        
        do {
            switch (entityType, operationType) {
            case ("PROPERTY", "CREATE"):
                try await syncCreateProperty(payload: payload)
            case ("TRANSFER", "CREATE"):
                try await syncCreateTransfer(payload: payload)
            case ("TRANSFER", "APPROVE"):
                try await syncApproveTransfer(entityId: item.entityId)
            case ("TRANSFER", "REJECT"):
                try await syncRejectTransfer(entityId: item.entityId)
            default:
                throw SyncError.unsupportedOperation
            }
            
            coreDataStack.updateSyncItemStatus(item: item, status: "COMPLETED")
        } catch {
            let errorMessage = "Sync failed: \(error.localizedDescription)"
            debugPrint(errorMessage)
            
            // Retry logic - max 3 attempts
            if item.retryCount < 3 {
                coreDataStack.updateSyncItemStatus(item: item, status: "PENDING", errorMessage: errorMessage)
            } else {
                coreDataStack.updateSyncItemStatus(item: item, status: "FAILED", errorMessage: errorMessage)
            }
        }
    }
    */
    
    // MARK: - Property Sync
    
    private func syncCreateProperty(payload: Data) async throws {
        // Decode the property creation data
        let decoder = JSONDecoder()
        let propertyData = try decoder.decode(CreatePropertyPayload.self, from: payload)
        
        // Convert to API input format
        let createInput = CreatePropertyInput(
            name: propertyData.itemName,
            serialNumber: propertyData.serialNumber,
            description: propertyData.description,
            currentStatus: "Operational", // Default status
            propertyModelId: nil, // TODO: Link to property model if NSN/LIN is provided
            assignedToUserId: nil, // Will be set by server to current user
            nsn: propertyData.nsn,
            lin: propertyData.lin
        )
        
        // Call API to create property
        debugPrint("Creating property on server: \(propertyData.serialNumber)")
        let _ = try await apiService.createProperty(createInput)
        // TODO: Uncomment when Core Data entities are implemented
        // coreDataStack.cacheProperty(createdProperty)
        
        // If there's a photo hash, update the sync queue with the property ID
        if propertyData.photoHash != nil {
            // TODO: Uncomment when Core Data entities are implemented
            // Update any pending photo uploads with the new property ID
            // let pendingPhotos = coreDataStack.getPendingPhotoUploads()
            // for photo in pendingPhotos where photo.sha256Hash == photoHash {
            //     photo.propertyId = Int32(createdProperty.id)
            //     coreDataStack.save()
            // }
        }
    }
    
    private func syncProperties() async {
        do {
            let properties = try await apiService.getMyProperties()
            debugPrint("Synced \(properties.count) properties from server")
            
            for _ in properties {
                // TODO: Uncomment when Core Data entities are implemented
                // coreDataStack.cacheProperty(property)
            }
        } catch {
            debugPrint("Failed to sync properties: \(error)")
        }
    }
    
    // MARK: - Transfer Sync
    
    private func syncCreateTransfer(payload: Data) async throws {
        let decoder = JSONDecoder()
        let transferData = try decoder.decode(CreateTransferPayload.self, from: payload)
        
        let _ = try await apiService.requestTransfer(
            propertyId: transferData.propertyId,
            targetUserId: transferData.targetUserId
        )
        // TODO: Uncomment when Core Data entities are implemented
        // coreDataStack.cacheTransfer(transfer)
    }
    
    private func syncApproveTransfer(entityId: Int32) async throws {
        let _ = try await apiService.approveTransfer(transferId: Int(entityId))
        // TODO: Uncomment when Core Data entities are implemented
        // coreDataStack.cacheTransfer(transfer)
    }
    
    private func syncRejectTransfer(entityId: Int32) async throws {
        let _ = try await apiService.rejectTransfer(transferId: Int(entityId))
        // TODO: Uncomment when Core Data entities are implemented
        // coreDataStack.cacheTransfer(transfer)
    }
    
    private func syncTransfers() async {
        do {
            let transfers = try await apiService.fetchTransfers(status: nil, direction: nil)
            debugPrint("Synced \(transfers.count) transfers from server")
            
            for _ in transfers {
                // TODO: Uncomment when Core Data entities are implemented
                // coreDataStack.cacheTransfer(transfer)
            }
        } catch {
            debugPrint("Failed to sync transfers: \(error)")
        }
    }
    
    // MARK: - Photo Upload
    
    private func uploadPendingPhotos() async {
        // TODO: Uncomment when Core Data entities are implemented
        // let pendingPhotos = coreDataStack.getPendingPhotoUploads()
        // debugPrint("Uploading \(pendingPhotos.count) pending photos")
        
        // for photo in pendingPhotos {
        //     await uploadPhoto(photo)
        // }
        debugPrint("Photo upload queued - Core Data entities not yet implemented")
    }
    
    // TODO: Uncomment when PendingPhotoUpload entity is implemented
    /*
    private func uploadPhoto(_ photoUpload: PendingPhotoUpload) async {
        guard let localPath = photoUpload.localImagePath,
              let photoId = photoUpload.id else { return }
        
        let fileURL = URL(fileURLWithPath: localPath)
        
        do {
            let imageData = try Data(contentsOf: fileURL)
            
            // Verify SHA-256 hash
            let computedHash = SHA256.hash(data: imageData)
            let hashString = computedHash.compactMap { String(format: "%02x", $0) }.joined()
            
            guard hashString == photoUpload.sha256Hash else {
                debugPrint("Photo hash mismatch - file may be corrupted")
                return
            }
            
            // Upload photo via API (this would need to be added to APIService)
            debugPrint("Uploading photo: \(photoId)")
            // try await apiService.uploadPhoto(propertyId: Int(photoUpload.propertyId), imageData: imageData, hash: hashString)
            
            // Mark as uploaded
            photoUpload.uploadStatus = "COMPLETED"
            coreDataStack.save()
            
            // Clean up local file
            try? FileManager.default.removeItem(at: fileURL)
            
        } catch {
            debugPrint("Failed to upload photo: \(error)")
            photoUpload.retryCount += 1
            
            if photoUpload.retryCount >= 3 {
                photoUpload.uploadStatus = "FAILED"
            }
            coreDataStack.save()
        }
    }
    */
    
    // MARK: - Helper Methods
    
    func queuePropertyCreation(_ property: Property, photoData: Data?) {
        let encoder = JSONEncoder()
        
        var payload = CreatePropertyPayload(
            itemName: property.itemName,
            serialNumber: property.serialNumber,
            description: property.description,
            nsn: property.nsn,
            lin: property.lin
        )
        
        // Handle photo if provided
        if let photoData = photoData {
            let hash = SHA256.hash(data: photoData)
            let hashString = hash.compactMap { String(format: "%.2x", $0) }.joined()
            
            // Save photo locally
            let photoId = UUID()
            let _ = savePhotoLocally(photoData, id: photoId)
            
            // TODO: Uncomment when Core Data entities are implemented
            // Add to photo upload queue
            // coreDataStack.addPendingPhotoUpload(
            //     propertyId: nil, // Will be set after property is created
            //     localPath: localPath,
            //     sha256Hash: hashString
            // )
            
            payload.photoHash = hashString
        }
        
        if (try? encoder.encode(payload)) != nil {
            // TODO: Uncomment when Core Data entities are implemented
            // coreDataStack.addToSyncQueue(
            //     operationType: "CREATE",
            //     entityType: "PROPERTY",
            //     payload: data
            // )
            debugPrint("Property creation queued - Core Data entities not yet implemented")
        }
    }
    
    private func savePhotoLocally(_ data: Data, id: UUID) -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photoPath = documentsPath.appendingPathComponent("pending_photos/\(id.uuidString).jpg")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: photoPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        try? data.write(to: photoPath)
        return photoPath.path
    }
}

// MARK: - Supporting Types

enum SyncError: LocalizedError {
    case unsupportedOperation
    case invalidPayload
    
    var errorDescription: String? {
        switch self {
        case .unsupportedOperation:
            return "Unsupported sync operation"
        case .invalidPayload:
            return "Invalid sync payload"
        }
    }
}

struct CreatePropertyPayload: Codable {
    let itemName: String
    let serialNumber: String
    let description: String?
    let nsn: String?
    let lin: String?
    var photoHash: String?
}

struct CreateTransferPayload: Codable {
    let propertyId: Int
    let targetUserId: Int
    let notes: String?
} 