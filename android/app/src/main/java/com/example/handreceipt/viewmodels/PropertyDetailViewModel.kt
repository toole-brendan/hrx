package com.example.handreceipt.viewmodels

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.data.model.User // Import User
import com.example.handreceipt.data.model.TransferRequest // Import TransferRequest
import com.example.handreceipt.data.network.ApiService
import com.example.handreceipt.ui.navigation.Routes // Import Routes for arg key
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import retrofit2.HttpException
import java.io.IOException

sealed interface PropertyDetailUiState {
    object Loading : PropertyDetailUiState
    data class Success(val property: Property) : PropertyDetailUiState
    data class Error(val message: String) : PropertyDetailUiState
}

// Reuse TransferActionState from ScanViewModel or define locally if needed
// Assuming reuse for consistency
// sealed class TransferActionState { ... }

@HiltViewModel
class PropertyDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val apiService: ApiService
) : ViewModel() {

    private val propertyId: String = checkNotNull(savedStateHandle[Routes.PropertyDetail.ARG_PROPERTY_ID])

    private val _uiState = MutableStateFlow<PropertyDetailUiState>(PropertyDetailUiState.Loading)
    val uiState: StateFlow<PropertyDetailUiState> = _uiState.asStateFlow()

    // State for controlling user selection presentation
    private val _showUserSelection = mutableStateOf(false)
    val showUserSelection: State<Boolean> = _showUserSelection
    
    // State for the transfer request action started from this screen
    private val _transferRequestState = mutableStateOf<TransferActionState>(TransferActionState.Idle)
    val transferRequestState: State<TransferActionState> = _transferRequestState

    init {
        fetchPropertyDetails()
    }

    fun fetchPropertyDetails() {
        _uiState.value = PropertyDetailUiState.Loading
        viewModelScope.launch {
            try {
                println("PropertyDetailViewModel: Fetching details for property ID: $propertyId")
                val response = apiService.getPropertyById(propertyId)
                if (response.isSuccessful && response.body() != null) {
                    _uiState.value = PropertyDetailUiState.Success(response.body()!!)
                    println("PropertyDetailViewModel: Successfully fetched property: ${response.body()?.itemName}")
                } else {
                    val errorMsg = "Error fetching property details: ${response.code()} - ${response.message()}"
                    _uiState.value = PropertyDetailUiState.Error(errorMsg)
                    println("PropertyDetailViewModel: $errorMsg")
                    if (response.code() == 404) {
                        _uiState.value = PropertyDetailUiState.Error("Property not found.")
                    }
                }
            } catch (e: Exception) {
                val errorMsg = "Network or other error fetching property: ${e.message}"
                _uiState.value = PropertyDetailUiState.Error(errorMsg)
                println("PropertyDetailViewModel: $errorMsg")
                e.printStackTrace()
            }
        }
    }

    fun requestTransferClicked() {
        _transferRequestState.value = TransferActionState.Idle // Reset previous action state
        _showUserSelection.value = true
    }
    
    fun userSelectionDismissed() {
        _showUserSelection.value = false
    }
    
    fun initiateTransfer(targetUser: User) {
        userSelectionDismissed() // Hide sheet first
        val currentPropertyState = _uiState.value
        if (currentPropertyState !is PropertyDetailUiState.Success) {
             _transferRequestState.value = TransferActionState.Error("Property details not loaded.")
             return
        }
        val propertyToTransfer = currentPropertyState.property
        
         println("Initiating transfer from Detail for Prop ID: ${propertyToTransfer.id} to User ID: ${targetUser.id}")
        _transferRequestState.value = TransferActionState.Loading
        
        viewModelScope.launch {
             try {
                 val request = TransferRequest(propertyId = propertyToTransfer.id, targetUserId = targetUser.id)
                 val response = apiService.requestTransfer(request)
                 if (response.isSuccessful) {
                     println("Transfer request successful from Detail: ${response.code()}")
                     _transferRequestState.value = TransferActionState.Success() 
                     // TODO: Optionally refresh property details or navigate away
                 } else {
                     val errorBody = response.errorBody()?.string() ?: "Unknown error requesting transfer"
                     println("Error requesting transfer from Detail: ${response.code()} - $errorBody")
                     _transferRequestState.value = TransferActionState.Error("Error ${response.code()}: Request failed")
                 }
             } catch (e: HttpException) {
                  _transferRequestState.value = TransferActionState.Error("Network error: ${e.message()}")
             } catch (e: IOException) {
                   _transferRequestState.value = TransferActionState.Error("Network connection error.")
             } catch (e: Exception) {
                   _transferRequestState.value = TransferActionState.Error("An unexpected error occurred.")
             }
         }
    }
    
     // Function to manually reset the transfer state (e.g., after snackbar dismissal)
    fun clearTransferState() {
        _transferRequestState.value = TransferActionState.Idle
    }
} 