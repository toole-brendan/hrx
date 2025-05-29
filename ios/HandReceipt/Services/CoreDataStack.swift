import CoreData
import Foundation

class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HandReceipt")
        
        // Enable automatic migration
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                debugPrint("Core Data failed to load: \(error), \(error.userInfo)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            debugPrint("Core Data loaded successfully")
        }
        
        // Configure for performance
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
    
    func save(context: NSManagedObjectContext? = nil) {
        let context = context ?? viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            debugPrint("Core Data context saved successfully")
        } catch {
            let nsError = error as NSError
            debugPrint("Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }
    
    // MARK: - Sync Queue Operations
    
    func addToSyncQueue(operationType: String, entityType: String, entityId: Int32? = nil, payload: Data) {
        let context = newBackgroundContext()
        
        context.perform {
            let syncItem = SyncQueueItem(context: context)
            syncItem.id = UUID()
            syncItem.operationType = operationType
            syncItem.entityType = entityType
            syncItem.entityId = entityId ?? 0
            syncItem.payload = payload
            syncItem.createdAt = Date()
            syncItem.status = "PENDING"
            syncItem.retryCount = 0
            
            self.save(context: context)
            debugPrint("Added item to sync queue: \(operationType) \(entityType)")
        }
    }
    
    func getPendingSyncItems(limit: Int = 50) -> [SyncQueueItem] {
        let fetchRequest: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", "PENDING")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        fetchRequest.fetchLimit = limit
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            debugPrint("Error fetching sync items: \(error)")
            return []
        }
    }
    
    func updateSyncItemStatus(item: SyncQueueItem, status: String, errorMessage: String? = nil) {
        item.status = status
        item.lastAttemptAt = Date()
        if let errorMessage = errorMessage {
            item.errorMessage = errorMessage
            item.retryCount += 1
        }
        save()
    }
    
    // MARK: - Property Cache Operations
    
    func cacheProperty(_ property: Property) {
        let context = newBackgroundContext()
        
        context.perform {
            let fetchRequest: NSFetchRequest<CachedProperty> = CachedProperty.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", property.id)
            
            let cachedProperty: CachedProperty
            if let existing = try? context.fetch(fetchRequest).first {
                cachedProperty = existing
            } else {
                cachedProperty = CachedProperty(context: context)
                cachedProperty.id = Int32(property.id)
            }
            
            cachedProperty.itemName = property.itemName
            cachedProperty.serialNumber = property.serialNumber
            cachedProperty.itemDescription = property.description
            cachedProperty.nsn = property.nsn
            cachedProperty.lin = property.lin
            cachedProperty.currentHolderId = Int32(property.currentHolderId)
            cachedProperty.createdAt = property.createdAt
            cachedProperty.updatedAt = property.updatedAt
            cachedProperty.photoUrl = property.photoUrl
            cachedProperty.lastSyncedAt = Date()
            cachedProperty.isDirty = false
            
            self.save(context: context)
        }
    }
    
    func getCachedProperties() -> [CachedProperty] {
        let fetchRequest: NSFetchRequest<CachedProperty> = CachedProperty.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            debugPrint("Error fetching cached properties: \(error)")
            return []
        }
    }
    
    // MARK: - Transfer Cache Operations
    
    func cacheTransfer(_ transfer: Transfer) {
        let context = newBackgroundContext()
        
        context.perform {
            let fetchRequest: NSFetchRequest<CachedTransfer> = CachedTransfer.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", transfer.id)
            
            let cachedTransfer: CachedTransfer
            if let existing = try? context.fetch(fetchRequest).first {
                cachedTransfer = existing
            } else {
                cachedTransfer = CachedTransfer(context: context)
                cachedTransfer.id = Int32(transfer.id)
            }
            
            cachedTransfer.propertyId = Int32(transfer.propertyId)
            cachedTransfer.fromUserId = Int32(transfer.fromUserId)
            cachedTransfer.toUserId = Int32(transfer.toUserId)
            cachedTransfer.status = transfer.status
            cachedTransfer.notes = transfer.notes
            cachedTransfer.requestDate = transfer.requestDate
            cachedTransfer.resolvedDate = transfer.resolvedDate
            cachedTransfer.lastSyncedAt = Date()
            cachedTransfer.isDirty = false
            
            self.save(context: context)
        }
    }
    
    func getCachedTransfers() -> [CachedTransfer] {
        let fetchRequest: NSFetchRequest<CachedTransfer> = CachedTransfer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestDate", ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            debugPrint("Error fetching cached transfers: \(error)")
            return []
        }
    }
    
    // MARK: - Photo Queue Operations
    
    func addPendingPhotoUpload(propertyId: Int32?, localPath: String, sha256Hash: String) {
        let context = newBackgroundContext()
        
        context.perform {
            let photoUpload = PendingPhotoUpload(context: context)
            photoUpload.id = UUID()
            photoUpload.propertyId = propertyId ?? 0
            photoUpload.localImagePath = localPath
            photoUpload.sha256Hash = sha256Hash
            photoUpload.createdAt = Date()
            photoUpload.uploadStatus = "PENDING"
            photoUpload.retryCount = 0
            
            self.save(context: context)
            debugPrint("Added pending photo upload: \(localPath)")
        }
    }
    
    func getPendingPhotoUploads() -> [PendingPhotoUpload] {
        let fetchRequest: NSFetchRequest<PendingPhotoUpload> = PendingPhotoUpload.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "uploadStatus == %@", "PENDING")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            debugPrint("Error fetching pending photo uploads: \(error)")
            return []
        }
    }
    
    // MARK: - Cleanup Operations
    
    func cleanupCompletedSyncItems(olderThan days: Int = 7) {
        let context = newBackgroundContext()
        
        context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SyncQueueItem.fetchRequest()
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            fetchRequest.predicate = NSPredicate(format: "status == %@ AND lastAttemptAt < %@", "COMPLETED", cutoffDate as NSDate)
            
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                self.save(context: context)
                debugPrint("Cleaned up old sync items")
            } catch {
                debugPrint("Error cleaning up sync items: \(error)")
            }
        }
    }
} 