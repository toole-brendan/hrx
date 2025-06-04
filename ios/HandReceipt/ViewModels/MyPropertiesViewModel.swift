import Foundation
import Combine // For ObservableObject
import SwiftUI // For Color and UI types

// MARK: - Filter Types
enum PropertyFilterType: String, CaseIterable {
    case all = "ALL"
    case category = "CATEGORY"
    case status = "STATUS"
    case location = "LOCATION"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .category: return "Category"
        case .status: return "Status"
        case .location: return "Location"
        }
    }
}

// MARK: - Category Filter
enum PropertyCategory: String, CaseIterable, Identifiable {
    case all = "all"
    case weapons = "weapons"
    case comsec = "comsec"
    case optics = "optics"
    case vehicles = "vehicles"
    case individualEquipment = "individual-equipment"
    case medical = "medical"
    case supportEquipment = "support-equipment"
    case electronics = "electronics"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .weapons: return "Weapons"
        case .comsec: return "COMSEC"
        case .optics: return "Optics"
        case .vehicles: return "Vehicles"
        case .individualEquipment: return "TA-50"
        case .medical: return "Medical"
        case .supportEquipment: return "Support"
        case .electronics: return "IT/Elec"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .weapons: return "shield.fill"
        case .comsec: return "antenna.radiowaves.left.and.right"
        case .optics: return "eye.fill"
        case .vehicles: return "car.fill"
        case .individualEquipment: return "person.fill"
        case .medical: return "cross.case.fill"
        case .supportEquipment: return "wrench.fill"
        case .electronics: return "desktopcomputer"
        case .other: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .gray
        case .weapons: return .red
        case .comsec: return .blue
        case .optics: return .purple
        case .vehicles: return .orange
        case .individualEquipment: return .green
        case .medical: return .pink
        case .supportEquipment: return .brown
        case .electronics: return .cyan
        case .other: return .gray
        }
    }
    
    static func fromItemName(_ name: String) -> PropertyCategory {
        let lowercased = name.lowercased()
        
        // Weapons - Military weapons and firearms
        if lowercased.contains("rifle") || lowercased.contains("carbine") || 
           lowercased.contains("m4") || lowercased.contains("m16") || 
           lowercased.contains("pistol") || lowercased.contains("m9") ||
           lowercased.contains("m17") || lowercased.contains("weapon") ||
           lowercased.contains("m240") || lowercased.contains("m249") ||
           lowercased.contains("m2") || lowercased.contains(".50") ||
           lowercased.contains("mk19") || lowercased.contains("grenade") {
            return .weapons
        }
        
        // COMSEC/Communications
        if lowercased.contains("radio") || lowercased.contains("prc-") || 
           lowercased.contains("comm") || lowercased.contains("antenna") ||
           lowercased.contains("sincgars") || lowercased.contains("harris") ||
           lowercased.contains("an/prc") || lowercased.contains("comms") {
            return .comsec
        }
        
        // Optics - Night vision, scopes, thermal
        if lowercased.contains("optic") || lowercased.contains("scope") || 
           lowercased.contains("pvs-") || lowercased.contains("nvg") || 
           lowercased.contains("night vision") || lowercased.contains("thermal") ||
           lowercased.contains("acog") || lowercased.contains("eotech") ||
           lowercased.contains("aimpoint") || lowercased.contains("elcan") ||
           lowercased.contains("an/pvs") || lowercased.contains("nods") {
            return .optics
        }
        
        // Vehicles - Military vehicles
        if lowercased.contains("vehicle") || lowercased.contains("truck") || 
           lowercased.contains("humvee") || lowercased.contains("lmtv") ||
           lowercased.contains("mrap") || lowercased.contains("tank") ||
           lowercased.contains("bradley") || lowercased.contains("stryker") ||
           lowercased.contains("m1078") || lowercased.contains("m998") {
            return .vehicles
        }
        
        // Individual Equipment (TA-50)
        if lowercased.contains("helmet") || lowercased.contains("vest") || 
           lowercased.contains("iotv") || lowercased.contains("pack") || 
           lowercased.contains("rucksack") || lowercased.contains("body armor") ||
           lowercased.contains("kevlar") || lowercased.contains("ach") ||
           lowercased.contains("uniform") || lowercased.contains("boots") ||
           lowercased.contains("ta-50") || lowercased.contains("ta50") {
            return .individualEquipment
        }
        
        // Medical Equipment
        if lowercased.contains("medical") || lowercased.contains("ifak") || 
           lowercased.contains("aid kit") || lowercased.contains("medic") ||
           lowercased.contains("bandage") || lowercased.contains("stretcher") ||
           lowercased.contains("defibrillator") || lowercased.contains("iv") {
            return .medical
        }
        
        // Support Equipment - Tools, generators, etc.
        if lowercased.contains("generator") || lowercased.contains("tool") || 
           lowercased.contains("maintenance") || lowercased.contains("wrench") ||
           lowercased.contains("mep-") || lowercased.contains("compressor") ||
           lowercased.contains("welder") || lowercased.contains("crane") {
            return .supportEquipment
        }
        
        // Electronics/IT Equipment
        if lowercased.contains("computer") || lowercased.contains("laptop") || 
           lowercased.contains("gps") || lowercased.contains("server") ||
           lowercased.contains("router") || lowercased.contains("switch") ||
           lowercased.contains("monitor") || lowercased.contains("tablet") ||
           lowercased.contains("printer") || lowercased.contains("network") {
            return .electronics
        }
        
        return .other
    }
}

// MARK: - Status Filter (Military-specific)
enum PropertyFilterStatus: String, CaseIterable, Identifiable {
    case all = "all"
    case serviceable = "serviceable"
    case unserviceable = "unserviceable"
    case deadlineMaintenance = "deadline-maintenance"
    case inTransit = "in-transit"
    case unknown = "unknown"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .all: return "All Status"
        case .serviceable: return "Serviceable"
        case .unserviceable: return "Unserviceable"
        case .deadlineMaintenance: return "Deadline"
        case .inTransit: return "In Transit"
        case .unknown: return "Unknown"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .all: return "All"
        case .serviceable: return "FMC"  // Fully Mission Capable
        case .unserviceable: return "NMC" // Non-Mission Capable
        case .deadlineMaintenance: return "DL" // Deadline
        case .inTransit: return "Transit"
        case .unknown: return "UNK"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .gray
        case .serviceable: return .green
        case .unserviceable: return .red
        case .deadlineMaintenance: return .orange
        case .inTransit: return .blue
        case .unknown: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "circle"
        case .serviceable: return "checkmark.circle.fill"
        case .unserviceable: return "xmark.circle.fill"
        case .deadlineMaintenance: return "exclamationmark.triangle.fill"
        case .inTransit: return "arrow.triangle.2.circlepath"
        case .unknown: return "questionmark.circle"
        }
    }
    
    static func fromProperty(_ property: Property) -> PropertyFilterStatus {
        let status = (property.currentStatus ?? property.status ?? "").lowercased()
        
        // Check for maintenance conditions first
        if property.needsMaintenance || status.contains("maintenance") || 
           status.contains("deadline") {
            return .deadlineMaintenance
        }
        
        // Check for in-transit status
        if status.contains("transit") || status.contains("transfer") || 
           status.contains("shipping") || status.contains("moving") {
            return .inTransit
        }
        
        // Check for serviceable conditions
        if status.contains("operational") || status.contains("active") || 
           status.contains("serviceable") {
            return .serviceable
        }
        
        // Check for unserviceable conditions
        if status.contains("broken") || status.contains("damaged") || 
           status.contains("non-operational") || status.contains("inoperable") ||
           status.contains("unserviceable") {
            return .unserviceable
        }
        
        // Default to unknown if status is unclear
        return .unknown
    }
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
    
    // New filter system
    @Published var selectedFilterType: PropertyFilterType = .all
    @Published var selectedCategory: PropertyCategory = .all
    @Published var selectedStatus: PropertyFilterStatus = .all
    
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
                property.name.localizedCaseInsensitiveContains(searchText) ||
                property.serialNumber.localizedCaseInsensitiveContains(searchText) ||
                property.nsn?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Apply category filter
        if selectedCategory != .all {
            filtered = filtered.filter { property in
                PropertyCategory.fromItemName(property.name) == selectedCategory
            }
        }
        
        // Apply status filter
        if selectedStatus != .all {
            filtered = filtered.filter { property in
                PropertyFilterStatus.fromProperty(property) == selectedStatus
            }
        }
        
        return filtered
    }
    
    // Category counts for filter badges
    var categoryCounts: [PropertyCategory: Int] {
        var counts: [PropertyCategory: Int] = [:]
        for category in PropertyCategory.allCases {
            if category == .all {
                counts[category] = allProperties.count
            } else {
                counts[category] = allProperties.filter { 
                    PropertyCategory.fromItemName($0.name) == category 
                }.count
            }
        }
        return counts
    }
    
    // Status counts for filter badges
    var statusCounts: [PropertyFilterStatus: Int] {
        var counts: [PropertyFilterStatus: Int] = [:]
        for status in PropertyFilterStatus.allCases {
            if status == .all {
                counts[status] = allProperties.count
            } else {
                counts[status] = allProperties.filter { 
                    PropertyFilterStatus.fromProperty($0) == status 
                }.count
            }
        }
        return counts
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