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
    
    // MARK: - Sync Queue Management
    
    // TODO: Implement these methods when Core Data entities are created
    // These entities need to be added to the .xcdatamodeld file
    
    /*
    func addToSyncQueue(action: String, endpoint: String, payload: [String: Any], priority: Int = 0) {
        let context = persistentContainer.viewContext
        context.perform {
            let syncItem = SyncQueueItem(context: context)
            syncItem.id = UUID()
            syncItem.action = action
            syncItem.endpoint = endpoint
            syncItem.payloadData = try? JSONSerialization.data(withJSONObject: payload)
            syncItem.priority = Int32(priority)
            syncItem.status = "pending"
            syncItem.createdAt = Date()
            syncItem.retryCount = 0
            
            self.saveContext()
        }
    }
    
    func getPendingSyncItems(limit: Int = 50) -> [SyncQueueItem] {
        let fetchRequest: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", "pending")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        fetchRequest.fetchLimit = limit
        
        do {
            return try persistentContainer.viewContext.fetch(fetchRequest)
        } catch {
            debugPrint("Failed to fetch pending sync items: \(error)")
            return []
        }
    }
    
    func updateSyncItemStatus(item: SyncQueueItem, status: String, errorMessage: String? = nil) {
        let context = persistentContainer.viewContext
        context.perform {
            item.status = status
            item.lastAttempt = Date()
            item.errorMessage = errorMessage
            
            if status == "failed" {
                item.retryCount += 1
            }
            
            self.saveContext()
        }
    }
    */
    
    // MARK: - Property Caching
    
    // TODO: Implement when CachedProperty entity is created
    /*
    func cacheProperty(_ property: Property) {
        let context = persistentContainer.newBackgroundContext()
        context.perform {
            // Check if property already exists
            let fetchRequest: NSFetchRequest<CachedProperty> = CachedProperty.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", property.id)
            
            var cachedProperty: CachedProperty
            
            do {
                let existingProperties = try context.fetch(fetchRequest)
                cachedProperty = existingProperties.first ?? CachedProperty(context: context)
            } catch {
                cachedProperty = CachedProperty(context: context)
            }
            
            // Update properties
            cachedProperty.id = Int32(property.id)
            cachedProperty.serialNumber = property.serialNumber
            cachedProperty.nsn = property.nsn
            cachedProperty.itemName = property.itemName
            cachedProperty.propertyDescription = property.description
            cachedProperty.manufacturer = property.manufacturer
            cachedProperty.imageUrl = property.imageUrl
            cachedProperty.status = property.status
            cachedProperty.location = property.location
            cachedProperty.lastUpdated = Date()
            
            self.saveBackgroundContext(context)
        }
    }
    
    func getCachedProperties() -> [CachedProperty] {
        let fetchRequest: NSFetchRequest<CachedProperty> = CachedProperty.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastUpdated", ascending: false)]
        
        do {
            return try persistentContainer.viewContext.fetch(fetchRequest)
        } catch {
            debugPrint("Failed to fetch cached properties: \(error)")
            return []
        }
    }
    */
    
    // MARK: - Transfer Caching
    
    // TODO: Implement when CachedTransfer entity is created
    /*
    func cacheTransfer(_ transfer: Transfer) {
        let context = persistentContainer.newBackgroundContext()
        context.perform {
            // Check if transfer already exists
            let fetchRequest: NSFetchRequest<CachedTransfer> = CachedTransfer.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %d", transfer.id)
            
            var cachedTransfer: CachedTransfer
            
            do {
                let existingTransfers = try context.fetch(fetchRequest)
                cachedTransfer = existingTransfers.first ?? CachedTransfer(context: context)
            } catch {
                cachedTransfer = CachedTransfer(context: context)
            }
            
            // Update properties
            cachedTransfer.id = Int32(transfer.id)
            cachedTransfer.propertyId = Int32(transfer.propertyId)
            cachedTransfer.propertySerialNumber = transfer.propertySerialNumber
            cachedTransfer.propertyName = transfer.propertyName
            cachedTransfer.fromUserId = Int32(transfer.fromUserId)
            cachedTransfer.toUserId = Int32(transfer.toUserId)
            cachedTransfer.status = transfer.status
                    cachedTransfer.requestTimestamp = transfer.requestDate
        cachedTransfer.approvalTimestamp = transfer.resolvedDate
            cachedTransfer.notes = transfer.notes
            cachedTransfer.lastUpdated = Date()
            
            self.saveBackgroundContext(context)
        }
    }
    
    func getCachedTransfers() -> [CachedTransfer] {
        let fetchRequest: NSFetchRequest<CachedTransfer> = CachedTransfer.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "requestTimestamp", ascending: false)]
        
        do {
            return try persistentContainer.viewContext.fetch(fetchRequest)
        } catch {
            debugPrint("Failed to fetch cached transfers: \(error)")
            return []
        }
    }
    */
    
    // MARK: - Photo Upload Queue
    
    // TODO: Implement when PendingPhotoUpload entity is created
    /*
    func queuePhotoUpload(propertyId: Int, imageData: Data, filename: String) {
        let context = persistentContainer.newBackgroundContext()
        context.perform {
            let photoUpload = PendingPhotoUpload(context: context)
            photoUpload.id = UUID()
            photoUpload.propertyId = Int32(propertyId)
            photoUpload.imageData = imageData
            photoUpload.filename = filename
            photoUpload.createdAt = Date()
            photoUpload.status = "pending"
            photoUpload.retryCount = 0
            
            self.saveBackgroundContext(context)
        }
    }
    
    func getPendingPhotoUploads() -> [PendingPhotoUpload] {
        let fetchRequest: NSFetchRequest<PendingPhotoUpload> = PendingPhotoUpload.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", "pending")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        
        do {
            return try persistentContainer.viewContext.fetch(fetchRequest)
        } catch {
            debugPrint("Failed to fetch pending photo uploads: \(error)")
            return []
        }
    }
    */
    
    // MARK: - Cleanup Methods
    
    func clearSyncQueue() {
        // TODO: Implement when SyncQueueItem entity is created
        /*
        let context = persistentContainer.viewContext
        context.perform {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SyncQueueItem.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                debugPrint("Failed to clear sync queue: \(error)")
            }
        }
        */
    }
} 