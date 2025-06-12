import Foundation
import Combine

// Enum to represent the state of the data loading
enum PropertyDetailLoadingState: Equatable {
    case idle
    case loading
    case success(Property) // Hold the fetched property
    case error(String)
    
    // Implement Equatable manually
    static func == (lhs: PropertyDetailLoadingState, rhs: PropertyDetailLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.success(let lProp), .success(let rProp)): return lProp.id == rProp.id
        case (.error(let lMsg), .error(let rMsg)): return lMsg == rMsg
        default: return false
        }
    }
}

// Reuse TransferRequestState from ScanViewModel or define locally
// Assuming ScanViewModel is available or state is redefined
typealias TransferRequestState = ScanViewModel.TransferRequestState

@MainActor // Ensure UI updates happen on the main thread
class PropertyDetailViewModel: ObservableObject {

    @Published var loadingState: PropertyDetailLoadingState = .idle
    @Published var property: Property? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    // State for user selection sheet
    @Published var showingUserSelection = false
    
    // State for transfer request initiated from this view
    @Published var transferRequestState: TransferRequestState = .idle
    
    // Component management state
    @Published var attachedComponents: [PropertyComponent] = []
    @Published var availableComponents: [Property] = []
    @Published var isLoadingComponents = false
    @Published var componentError: String?
    
    // Computed properties for component management
    var canAttachComponents: Bool {
        guard let property = property else { return false }
        return property.canHaveComponents && !availableComponents.isEmpty
    }

    private let apiService: APIServiceProtocol
    private let propertyId: Int
    private var cancellables = Set<AnyCancellable>()
    private var clearStateTimer: AnyCancellable? // Timer for transfer status message

    init(propertyId: Int, apiService: APIServiceProtocol = APIService()) {
        self.propertyId = propertyId
        self.apiService = apiService
        print("PropertyDetailViewModel initialized for property ID: \(propertyId)")
    }

    func loadProperty() {
        if case .loading = loadingState { return }
        print("Attempting to fetch details for property: \(propertyId)")
        
        loadingState = .loading

        Task {
            do {
                let fetchedProperty = try await apiService.getPropertyById(propertyId: propertyId)
                self.property = fetchedProperty
                loadingState = .success(fetchedProperty)
                print("Successfully fetched details for property: \(fetchedProperty.itemName)")
            } catch let apiError as APIService.APIError {
                print("API Error fetching property details: \(apiError.localizedDescription)")
                let message: String
                switch apiError {
                case .itemNotFound:
                    message = "Property not found."
                case .unauthorized:
                    message = "Unauthorized. Please check login status."
                case .networkError, .serverError:
                    message = "A network or server error occurred."
                default:
                    message = apiError.localizedDescription
                }
                loadingState = .error(message)
            } catch {
                print("Unexpected error fetching property details: \(error.localizedDescription)")
                loadingState = .error("An unexpected error occurred.")
            }
        }
    }

    func requestTransferClicked() {
        // Ensure property is loaded before showing user selection
        guard property != nil else { 
            print("PropertyDetailVM Error: Cannot request transfer, property not loaded.")
            errorMessage = "Property details must be loaded first."
            return
        }
        transferRequestState = .idle // Reset previous state
        showingUserSelection = true
    }
    
    func initiateTransfer(targetUser: UserSummary) {
        // showingUserSelection = false // Dismiss sheet implicitly handled by sheet modifier - no need to set here
        guard let propertyToTransfer = property else {
             transferRequestState = .error("Property details not available.")
             return
        }
        
        print("PropertyDetailVM: Initiating transfer for property \(propertyToTransfer.id) to user \(targetUser.id)")
        transferRequestState = .loading
        clearStateTimer?.cancel() // Cancel previous timer
        
        Task {
             do {
                 let newTransfer = try await apiService.requestTransfer(propertyId: propertyToTransfer.id, targetUserId: targetUser.id)
                 print("PropertyDetailVM: Transfer request successful - ID \(newTransfer.id)")
                 self.transferRequestState = .success(transferId: newTransfer.id)
                 
                 // Trigger sync after successful transfer request
                 OfflineSyncService.shared.startSync()
                 
                 // Schedule state reset
                 self.scheduleTransferStateReset(delay: 3.0)
                 // TODO: Optionally refresh property details or navigate away
             } catch {
                 print("PropertyDetailVM: Transfer request failed - \(error.localizedDescription)")
                 self.transferRequestState = .error("Transfer failed: \(error.localizedDescription)")
                 // Schedule state reset
                 self.scheduleTransferStateReset(delay: 5.0)
             }
        }
    }
    
    // Helper to reset transfer state after a delay
    private func scheduleTransferStateReset(delay: TimeInterval) {
        clearStateTimer?.cancel()
        clearStateTimer = Just(()) 
            .delay(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.transferRequestState = .idle
            }
    }
    
    // MARK: - Component Management Methods
    
    func loadComponents() async {
        guard let property = property else { return }
        isLoadingComponents = true
        componentError = nil
        
        do {
            async let attachedTask = apiService.getPropertyComponents(propertyId: property.id)
            async let availableTask = apiService.getAvailableComponents(propertyId: property.id)
            
            let (attached, available) = try await (attachedTask, availableTask)
            
            self.attachedComponents = attached
            self.availableComponents = available
        } catch {
            componentError = "Failed to load components: \(error.localizedDescription)"
        }
        
        isLoadingComponents = false
    }
    
    func attachComponent(_ component: Property, position: String? = nil, notes: String? = nil) async {
        guard let property = property else { return }
        
        do {
            let attached = try await apiService.attachComponent(
                propertyId: property.id,
                componentId: component.id,
                position: position,
                notes: notes
            )
            
            // Update local state
            attachedComponents.append(attached)
            availableComponents.removeAll { $0.id == component.id }
        } catch {
            componentError = "Failed to attach component: \(error.localizedDescription)"
        }
    }
    
    func detachComponent(_ component: PropertyComponent) async {
        guard let property = property else { return }
        
        do {
            try await apiService.detachComponent(
                propertyId: property.id,
                componentId: component.componentPropertyId
            )
            
            // Update local state
            attachedComponents.removeAll { $0.id == component.id }
            // Optionally reload available components to add the detached one back
            await loadAvailableComponents()
        } catch {
            componentError = "Failed to detach component: \(error.localizedDescription)"
        }
    }
    
    func updateComponentPosition(_ component: PropertyComponent, position: String) async {
        guard let property = property else { return }
        
        do {
            try await apiService.updateComponentPosition(
                propertyId: property.id,
                componentId: component.componentPropertyId,
                position: position
            )
            
            // Update local state
            if let index = attachedComponents.firstIndex(where: { $0.id == component.id }) {
                attachedComponents[index] = PropertyComponent(
                    id: component.id,
                    parentPropertyId: component.parentPropertyId,
                    componentPropertyId: component.componentPropertyId,
                    attachedAt: component.attachedAt,
                    attachedByUserId: component.attachedByUserId,
                    notes: component.notes,
                    attachmentType: component.attachmentType,
                    position: position,
                    createdAt: component.createdAt,
                    updatedAt: Date()
                )
            }
        } catch {
            componentError = "Failed to update component position: \(error.localizedDescription)"
        }
    }
    
    func isPositionOccupied(_ position: String) -> Bool {
        return attachedComponents.contains { $0.position == position }
    }
    
    private func loadAvailableComponents() async {
        guard let property = property else { return }
        
        do {
            let available = try await apiService.getAvailableComponents(propertyId: property.id)
            self.availableComponents = available
        } catch {
            componentError = "Failed to reload available components: \(error.localizedDescription)"
        }
    }
     
    deinit {
        clearStateTimer?.cancel()
    }
} 