import Foundation
import Combine // For ObservableObject

// Enum to represent the state of loading user properties
enum MyPropertiesLoadingState: Equatable {
    case idle
    case loading
    case success([Property]) // Hold the fetched properties on success
    case error(String) // Hold the error message on failure

    // Implement == manually since Property might not be Equatable yet
    static func == (lhs: MyPropertiesLoadingState, rhs: MyPropertiesLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.success(let lProps), .success(let rProps)): return lProps.map { $0.id } == rProps.map { $0.id } // Compare by IDs
        case (.error(let lMsg), .error(let rMsg)): return lMsg == rMsg
        default: return false
        }
    }
}

@MainActor
class MyPropertiesViewModel: ObservableObject {
    
    @Published var loadingState: MyPropertiesLoadingState = .idle
    @Published var isOffline: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    
    private let apiService: APIServiceProtocol
    private let coreDataStack = CoreDataStack.shared
    private let offlineSync = OfflineSyncService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        setupObservers()
        loadProperties()
    }
    
    private func setupObservers() {
        // Observe network status changes
        NotificationCenter.default.publisher(for: Notification.Name("NetworkStatusChanged"))
            .sink { [weak self] notification in
                if let isOnline = notification.object as? Bool {
                    self?.isOffline = !isOnline
                    if isOnline {
                        self?.syncWithServer()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func loadProperties() {
        guard loadingState != .loading else { return }
        
        loadingState = .loading
        print("MyPropertiesViewModel: Loading properties...")
        
        // First, load from cache for immediate display
        loadFromCache()
        
        // Then sync with server if online
        if !offlineSync.isOnline {
            isOffline = true
            print("MyPropertiesViewModel: Offline mode - showing cached data")
        } else {
            syncWithServer()
        }
    }
    
    private func loadFromCache() {
        // TODO: Uncomment when Core Data entities are implemented
        /*
        let cachedProperties = coreDataStack.getCachedProperties()
        
        // Convert CachedProperty to Property
        let properties = cachedProperties.compactMap { cached -> Property? in
            guard let itemName = cached.itemName,
                  let serialNumber = cached.serialNumber else { return nil }
            
            return Property(
                id: Int(cached.id),
                serialNumber: serialNumber,
                nsn: cached.nsn ?? "",
                lin: cached.lin,
                itemName: itemName,
                description: cached.itemDescription,
                manufacturer: nil,
                imageUrl: cached.photoUrl,
                status: "Operational", // Default status
                assignedToUserId: Int(cached.currentHolderId),
                location: nil,
                lastInventoryDate: cached.updatedAt,
                acquisitionDate: cached.createdAt,
                notes: nil
            )
        }
        
        if !properties.isEmpty {
            loadingState = .success(properties)
            print("MyPropertiesViewModel: Loaded \(properties.count) properties from cache")
        }
        */
        print("MyPropertiesViewModel: Cache loading not yet implemented - Core Data entities pending")
    }
    
    private func syncWithServer() {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        Task {
            do {
                let properties = try await apiService.getMyProperties()
                
                // TODO: Uncomment when Core Data entities are implemented
                // Cache all properties
                // for property in properties {
                //     coreDataStack.cacheProperty(property)
                // }
                
                loadingState = .success(properties)
                lastSyncDate = Date()
                isSyncing = false
                print("MyPropertiesViewModel: Successfully synced \(properties.count) properties from server")
                
            } catch let apiError as APIService.APIError {
                isSyncing = false
                print("MyPropertiesViewModel: API Error loading properties - \(apiError.localizedDescription)")
                
                // Don't show error if we have cached data
                if case .success = loadingState {
                    // Keep showing cached data
                    print("MyPropertiesViewModel: Using cached data due to sync error")
                } else {
                    let message: String
                    switch apiError {
                    case .unauthorized: message = "Unauthorized. Please login again."
                    case .networkError: 
                        message = "Network error. Showing offline data."
                        isOffline = true
                    case .serverError: message = "Server error occurred."
                    default: message = apiError.localizedDescription
                    }
                    loadingState = .error(message)
                }
            } catch {
                isSyncing = false
                print("MyPropertiesViewModel: Unknown error loading properties - \(error.localizedDescription)")
                
                // Don't show error if we have cached data
                if case .success = loadingState {
                    print("MyPropertiesViewModel: Using cached data due to sync error")
                } else {
                    loadingState = .error("An unexpected error occurred.")
                }
            }
        }
    }
    
    // Support offline property creation
    func createPropertyOffline(itemName: String, serialNumber: String, description: String?, nsn: String?, lin: String?, photoData: Data?) {
        // Create a temporary property object with all required fields
        let tempProperty = Property(
            id: -Int.random(in: 1...999999), // Negative ID for offline items
            serialNumber: serialNumber,
            nsn: nsn,
            lin: lin,
            name: itemName,
            description: description,
            manufacturer: nil,
            imageUrl: nil,
            status: "Operational",
            currentStatus: "operational",
            assignedToUserId: nil,
            location: nil,
            lastInventoryDate: nil,
            acquisitionDate: Date(),
            notes: nil,
            maintenanceDueDate: nil,
            isSensitiveItem: false,
            propertyModelId: nil,
            lastVerifiedAt: nil,
            lastMaintenanceAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Queue for sync
        offlineSync.queuePropertyCreation(tempProperty, photoData: photoData)
        
        // Update UI immediately
        if case .success(var properties) = loadingState {
            properties.append(tempProperty)
            loadingState = .success(properties)
        }
        
        print("MyPropertiesViewModel: Created property offline - queued for sync")
    }
    
    func refreshData() {
        loadProperties()
    }
} 