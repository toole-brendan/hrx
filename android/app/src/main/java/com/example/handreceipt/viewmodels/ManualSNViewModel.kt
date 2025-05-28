package com.example.handreceipt.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.data.model.TransferRequest
import com.example.handreceipt.data.model.User
import com.example.handreceipt.data.network.ApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import retrofit2.HttpException
import java.util.UUID
import java.util.concurrent.TimeUnit
import javax.inject.Inject

// Sealed interface to represent the UI state for property lookup
sealed interface PropertyLookupUiState {
    object Idle : PropertyLookupUiState
    object Loading : PropertyLookupUiState
    data class Success(val property: Property) : PropertyLookupUiState
    object NotFound : PropertyLookupUiState
    data class Error(val message: String) : PropertyLookupUiState
}

// Sealed interface to represent the UI state for transfer requests
sealed interface TransferUiState {
    object Idle : TransferUiState
    object Loading : TransferUiState
    object Success : TransferUiState
    data class Error(val message: String) : TransferUiState
}

// Sealed interface for User Search state
sealed interface UserSearchUiState {
    object Idle : UserSearchUiState // Not actively searching
    object Loading : UserSearchUiState
    data class Success(val users: List<User>) : UserSearchUiState
    data class Error(val message: String) : UserSearchUiState
    object NoResults : UserSearchUiState // Search complete, no users found
}

@OptIn(FlowPreview::class) // For debounce
@HiltViewModel
class ManualSNViewModel @Inject constructor(
    private val service: ApiService
): ViewModel() {

    // --- State Management ---

    // MutableStateFlow for the serial number input
    private val _serialNumberInput = MutableStateFlow("")
    val serialNumberInput: StateFlow<String> = _serialNumberInput.asStateFlow()

    // Private mutable state flow for the lookup result
    private val _lookupUiState = MutableStateFlow<PropertyLookupUiState>(PropertyLookupUiState.Idle)
    // Public immutable state flow for the UI to observe
    val lookupUiState: StateFlow<PropertyLookupUiState> = _lookupUiState.asStateFlow()

    // Private mutable state flow for the transfer request status
    private val _transferUiState = MutableStateFlow<TransferUiState>(TransferUiState.Idle)
    // Public immutable state flow for the transfer status
    val transferUiState: StateFlow<TransferUiState> = _transferUiState.asStateFlow()

    // Recipient Search State
    private val _recipientSearchQuery = MutableStateFlow("")
    val recipientSearchQuery: StateFlow<String> = _recipientSearchQuery.asStateFlow()

    private val _userSearchUiState = MutableStateFlow<UserSearchUiState>(UserSearchUiState.Idle)
    val userSearchUiState: StateFlow<UserSearchUiState> = _userSearchUiState.asStateFlow()

    // Selected Recipient State
    private val _selectedRecipient = MutableStateFlow<User?>(null)
    val selectedRecipient: StateFlow<User?> = _selectedRecipient.asStateFlow()

    // --- Dependencies ---
    // ApiService is now injected by Hilt via the constructor

    // --- Initialization & Logic ---

    init {
        observeSerialNumberInput()
        observeRecipientSearchQuery() // Start observing recipient search input
    }

    // Observe the serial number input with debounce
    private fun observeSerialNumberInput() {
        viewModelScope.launch {
            _serialNumberInput
                .debounce(500L)
                .distinctUntilChanged()
                .filter { it.isNotBlank() }
                .collect { serialNumber ->
                    findProperty(serialNumber)
                }
        }
        viewModelScope.launch {
            _serialNumberInput
                .filter { it.isBlank() }
                .collect { 
                    if (_lookupUiState.value != PropertyLookupUiState.Idle) {
                        _lookupUiState.value = PropertyLookupUiState.Idle
                        println("SN Input cleared, lookup state reset to Idle")
                    }
                    clearRecipientSelection() // Clear recipient when SN is cleared
                    resetTransferState()
                }
        }
    }

    // Observe Recipient Search Query input
    private fun observeRecipientSearchQuery() {
        viewModelScope.launch {
            _recipientSearchQuery
                .debounce(400L) // Slightly shorter debounce for user search?
                .distinctUntilChanged()
                .collectLatest { query -> // Use collectLatest to cancel previous searches
                    if (query.length >= 2) { // Only search if query is reasonably long
                        searchUsers(query)
                    } else if (query.isBlank()) {
                         // Clear results if query is blank, but only if not already Idle
                        if (_userSearchUiState.value != UserSearchUiState.Idle) {
                            _userSearchUiState.value = UserSearchUiState.Idle
                            println("Recipient search query cleared, state reset.")
                        }
                    }
                     // If query is short but not blank, potentially keep old results or set to Idle?
                     // For now, let's just reset to Idle if short.
                     else if (query.length < 2 && _userSearchUiState.value != UserSearchUiState.Idle) {
                         _userSearchUiState.value = UserSearchUiState.Idle
                         println("Recipient search query too short, state reset.")
                     }
                }
        }
    }

    // Function called by UI to update the serial number input
    fun onSerialNumberChange(input: String) {
        _serialNumberInput.value = input
        // Reset related states when SN changes
        resetTransferState()
        clearRecipientSelection()
    }

    // Function to initiate the property lookup
    private fun findProperty(serialNumber: String) {
        val serialToSearch = serialNumber.trim()
        if (serialToSearch.isEmpty()) return

        _lookupUiState.value = PropertyLookupUiState.Loading
        resetTransferState()
        clearRecipientSelection() // Clear recipient before new lookup
        println("Attempting to find property with SN: $serialToSearch")

        viewModelScope.launch {
            try {
                val response = service.getPropertyBySerialNumber(serialToSearch)
                if (response.isSuccessful) {
                    val property = response.body()
                    if (property != null) {
                        _lookupUiState.value = PropertyLookupUiState.Success(property)
                        println("Successfully found property: ${property.itemName}")
                    } else {
                        println("Server returned success but null body for SN: $serialToSearch")
                        _lookupUiState.value = PropertyLookupUiState.Error("Received empty response from server.")
                    }
                } else {
                    if (response.code() == 404) {
                        println("Property with SN $serialToSearch not found (404).")
                        _lookupUiState.value = PropertyLookupUiState.NotFound
                    } else {
                        val errorBody = response.errorBody()?.string() ?: "Unknown server error"
                        println("Server error ${response.code()}: $errorBody")
                        _lookupUiState.value = PropertyLookupUiState.Error("Server error: ${response.code()}")
                    }
                }
            } catch (e: HttpException) {
                 println("HTTP Exception during property lookup: ${e.message()}")
                 _lookupUiState.value = PropertyLookupUiState.Error("Network communication error.")
                 e.printStackTrace()
            } catch (e: Throwable) {
                 println("Generic Throwable during property lookup: ${e.message}")
                 _lookupUiState.value = PropertyLookupUiState.Error("An error occurred: ${e.message}")
                 e.printStackTrace()
            }
        }
    }

    // Update Recipient Search Query (UI Call)
    fun onRecipientQueryChange(query: String) {
         _recipientSearchQuery.value = query
         // If the query no longer matches the selected user, clear selection
         if (_selectedRecipient.value != null && query != _selectedRecipient.value?.username) {
            _selectedRecipient.value = null
            // Keep search results visible while user might be editing
            // if(_userSearchUiState.value is UserSearchUiState.Success) {
            //     _userSearchUiState.value = UserSearchUiState.Idle
            // }
         }
         resetTransferState() // Reset transfer if recipient query changes
    }

    // Select a Recipient User (UI Call - e.g., when user taps a result)
    fun onRecipientSelected(user: User) {
        _selectedRecipient.value = user
        _recipientSearchQuery.value = user.username // Update query field to show selection
        _userSearchUiState.value = UserSearchUiState.Idle // Hide search results dropdown
        println("Recipient selected: ${user.username} (ID: ${user.id})")
        resetTransferState() // Reset transfer state after selection
    }

    // Clear recipient selection and search
     fun clearRecipientSelection() {
        _selectedRecipient.value = null
        _recipientSearchQuery.value = "" // Clear input field too
        // User search state will reset via observer
        println("Recipient selection cleared.")
     }

    // Search for users based on query
    private fun searchUsers(query: String) {
         val trimmedQuery = query.trim()
         if (trimmedQuery.length < 2) return // Avoid searching for very short strings

        _userSearchUiState.value = UserSearchUiState.Loading
        println("Searching for users with query: $trimmedQuery")

        viewModelScope.launch {
            try {
                val response = service.searchUsers(trimmedQuery)
                if (response.isSuccessful) {
                    val users = response.body()
                    if (!users.isNullOrEmpty()) {
                        _userSearchUiState.value = UserSearchUiState.Success(users)
                        println("Found ${users.size} users.")
                    } else {
                        _userSearchUiState.value = UserSearchUiState.NoResults
                        println("No users found for query: $trimmedQuery")
                    }
                } else {
                    val errorBody = response.errorBody()?.string() ?: "Unknown server error"
                    val errorMsg = "User search failed: ${response.code()} - $errorBody"
                    _userSearchUiState.value = UserSearchUiState.Error(errorMsg)
                    println(errorMsg)
                }
            } catch (e: HttpException) {
                 val errorMsg = "Network error during user search: ${e.message()}"
                 _userSearchUiState.value = UserSearchUiState.Error(errorMsg)
                 println(errorMsg)
                 e.printStackTrace()
            } catch (e: Throwable) {
                 val errorMsg = "Error searching users: ${e.message}"
                 _userSearchUiState.value = UserSearchUiState.Error(errorMsg)
                 println(errorMsg)
                 e.printStackTrace()
            }
        }
    }

    // Function to initiate the transfer request
    fun initiateTransfer(property: Property) {
        val recipient = _selectedRecipient.value

        if (recipient == null) {
            _transferUiState.value = TransferUiState.Error("No recipient selected.")
            println("Transfer initiation failed: No recipient selected.")
            return
        }

        // Validate property ID just in case, though it should be valid if lookup succeeded
        val propertyId = property.id

        _transferUiState.value = TransferUiState.Loading
        println("Initiating transfer for property ID $propertyId to recipient ${recipient.username} (ID: ${recipient.id})")

        viewModelScope.launch {
            try {
                val request = TransferRequest(propertyId = propertyId, recipientUserId = recipient.id)
                val response = service.requestTransfer(request)

                if (response.isSuccessful) {
                    _transferUiState.value = TransferUiState.Success
                    println("Transfer request successful for property ID $propertyId")
                    // Clear selection/query after successful transfer
                    clearRecipientSelection()
                    // Optionally reset lookup state too
                    // _lookupUiState.value = PropertyLookupUiState.Idle
                    // _serialNumberInput.value = "" // Maybe clear SN too?
                } else {
                    val errorBody = response.errorBody()?.string() ?: "Unknown server error"
                    val errorMessage = "Transfer request failed: ${response.code()} - $errorBody"
                    _transferUiState.value = TransferUiState.Error(errorMessage)
                    println(errorMessage)
                }
            } catch (e: HttpException) {
                val errorMsg = "Network error during transfer: ${e.message()}"
                _transferUiState.value = TransferUiState.Error(errorMsg)
                println(errorMsg)
                e.printStackTrace()
            } catch (e: Throwable) {
                 val errorMsg = "Error initiating transfer: ${e.message}"
                 _transferUiState.value = TransferUiState.Error(errorMsg)
                 println(errorMsg)
                 e.printStackTrace()
            }
        }
    }

    // Function to manually clear the input and reset the state
    fun clearAndReset() {
        _serialNumberInput.value = ""
        // Other states (lookup, recipient, transfer) will reset via observers/calls
    }

    // Function to reset the transfer UI state
    fun resetTransferState() {
        if (_transferUiState.value != TransferUiState.Idle) {
            _transferUiState.value = TransferUiState.Idle
            println("Transfer state reset to Idle")
        }
    }
} 