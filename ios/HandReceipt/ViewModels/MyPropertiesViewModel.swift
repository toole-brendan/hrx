import Foundation
import Combine // For ObservableObject

// MARK: - Property Filter Enum
enum PropertyFilter: String, CaseIterable {
    case all = "ALL"
    case operational = "OPERATIONAL"
    case maintenance = "MAINTENANCE"
    
    var title: String { rawValue }
}

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
    @Published var allProperties: [Property] = []
    @Published var isOffline: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    @Published var selectedFilter: PropertyFilter = .all
    private var hasLoadedInitialData = false
    
    let apiService: APIServiceProtocol
    private let coreDataStack = CoreDataStack.shared
    private let offlineSync = OfflineSyncService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Computed property for unverified count
    var unverifiedCount: Int {
        guard case .success(let properties) = loadingState else { return 0 }
        return properties.filter { $0.needsVerification }.count
    }
    
    // Properties list for direct access
    var properties: [Property] {
        guard case .success(let properties) = loadingState else { return [] }
        return properties
    }
    
    // Filtered properties for search and filter functionality
    var filteredProperties: [Property] {
        var filtered = allProperties
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { property in
                property.itemName.localizedCaseInsensitiveContains(searchText) ||
                property.serialNumber.localizedCaseInsensitiveContains(searchText) ||
                property.nsn?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .operational:
            filtered = filtered.filter { 
                let status = ($0.currentStatus ?? $0.status ?? "").lowercased()
                return status == "operational" || status == "active"
            }
        case .maintenance:
            filtered = filtered.filter {
                let status = ($0.currentStatus ?? $0.status ?? "").lowercased()
                return status == "maintenance" || status == "needs_maintenance" || $0.needsMaintenance
            }
        }
        
        return filtered
    }
    
    init(apiService: APIServiceProtocol = APIService()) {
        self.apiService = apiService
        setupObservers()
        // Don't load properties automatically - let the view trigger this with .task
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
        
        // Only show loading state if this is the first load
        if !hasLoadedInitialData {
            isLoading = true
            loadingState = .loading
        }
        
        error = nil
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
                lastVerificationDate: cached.updatedAt,
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
                allProperties = properties
                lastSyncDate = Date()
                isSyncing = false
                isLoading = false
                hasLoadedInitialData = true
                print("MyPropertiesViewModel: Successfully synced \(properties.count) properties from server")
                
            } catch let apiError as APIService.APIError {
                isSyncing = false
                isLoading = false
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
                    error = message
                }
            } catch {
                isSyncing = false
                isLoading = false
                print("MyPropertiesViewModel: Unknown error loading properties - \(error.localizedDescription)")
                
                // Don't show error if we have cached data
                if case .success = loadingState {
                    print("MyPropertiesViewModel: Using cached data due to sync error")
                } else {
                    let errorMessage = "An unexpected error occurred."
                    loadingState = .error(errorMessage)
                    self.error = errorMessage
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
            updatedAt: Date(),
            sourceType: "manual",
            importMetadata: nil,
            verified: false,
            verifiedAt: nil,
            isAttachable: false,
            attachmentPoints: nil,
            compatibleWith: nil
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
    
    func loadCachedProperties() async {
        // Load from cache immediately (no loading state)
        print("MyPropertiesViewModel: Loading cached properties...")
        
        // TODO: Implement when Core Data entities are ready
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
                lastVerificationDate: cached.updatedAt,
                acquisitionDate: cached.createdAt,
                notes: nil
            )
        }
        
        if !properties.isEmpty {
            allProperties = properties
            print("MyPropertiesViewModel: Loaded \(properties.count) properties from cache")
        }
        */
    }
    
    func refreshData() {
        // For manual refresh, always sync with server but don't show loading state
        if !offlineSync.isOnline {
            isOffline = true
            print("MyPropertiesViewModel: Offline mode - cannot refresh")
        } else {
            syncWithServer()
        }
    }
    
    // Update a property after verification
    func updateProperty(_ updatedProperty: Property) {
        if case .success(var properties) = loadingState {
            if let index = properties.firstIndex(where: { $0.id == updatedProperty.id }) {
                properties[index] = updatedProperty
                loadingState = .success(properties)
                
                // Sync the update if online
                if offlineSync.isOnline {
                    Task {
                        do {
                            // Call API to update property
                            let _ = try await apiService.updateProperty(updatedProperty)
                            print("MyPropertiesViewModel: Property \(updatedProperty.id) updated successfully")
                        } catch {
                            print("MyPropertiesViewModel: Error updating property - \(error)")
                            // Keep the local update even if sync fails
                        }
                    }
                } else {
                    // Queue for later sync
                    offlineSync.queuePropertyUpdate(updatedProperty)
                }
            }
        }
    }
} 