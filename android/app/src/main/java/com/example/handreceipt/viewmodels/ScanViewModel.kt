package com.example.handreceipt.viewmodels

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.data.network.ApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject
import retrofit2.HttpException // Import for error handling
import java.io.IOException // Import for error handling
import com.example.handreceipt.data.model.TransferRequest // Import TransferRequest

sealed class ScanResultState {
    object Idle : ScanResultState()
    object Scanning : ScanResultState()
    object Loading : ScanResultState() // Loading after scan, before result
    data class Success(val property: Property) : ScanResultState()
    data class Error(val message: String) : ScanResultState()
    object NotFound : ScanResultState() // Specific state for 404
}

sealed class TransferActionState {
    object Idle : TransferActionState()
    object Loading : TransferActionState()
    data class Success(val message: String = "Transfer Requested Successfully!") : TransferActionState()
    data class Error(val message: String) : TransferActionState()
}

@HiltViewModel
class ScanViewModel @Inject constructor(
    private val apiService: ApiService
) : ViewModel() {

    private val _scanState = mutableStateOf<ScanResultState>(ScanResultState.Scanning)
    val scanState: State<ScanResultState> = _scanState
    
    // Hold the successfully scanned property for potential transfer
    private var confirmedProperty: Property? = null 

    // Add state specifically for the transfer request action
    private val _transferRequestState = mutableStateOf<TransferActionState>(TransferActionState.Idle)
    val transferRequestState: State<TransferActionState> = _transferRequestState

    fun processScannedCode(code: String) {
        if (code.isBlank()) {
            _scanState.value = ScanResultState.Error("Scanned code is empty")
            return
        }
        _scanState.value = ScanResultState.Loading // Show loading indicator
        viewModelScope.launch {
            try {
                val response = apiService.getPropertyBySerial(code)
                if (response.isSuccessful && response.body() != null) {
                    // Use helper function
                    handleScanSuccess(response.body()!!)
                } else if (response.code() == 404) {
                     _scanState.value = ScanResultState.NotFound
                    println("ScanViewModel: Property not found for SN: $code")
                } else {
                    val errorBody = response.errorBody()?.string() ?: "Unknown error"
                    _scanState.value = ScanResultState.Error("Error ${response.code()}: $errorBody")
                    println("ScanViewModel: API Error ${response.code()} for SN: $code")
                }
            } catch (e: HttpException) {
                _scanState.value = ScanResultState.Error("Network error: ${e.message()}")
                 println("ScanViewModel: HttpException - ${e.message()}")
            } catch (e: IOException) {
                _scanState.value = ScanResultState.Error("Network connection error. Please check connection.")
                println("ScanViewModel: IOException - ${e.message}")
            } catch (e: Exception) {
                _scanState.value = ScanResultState.Error("An unexpected error occurred: ${e.localizedMessage}")
                println("ScanViewModel: Exception - ${e.message}")
            }
        }
    }

    fun resetState() {
        confirmedProperty = null
        _scanState.value = ScanResultState.Scanning 
        _transferRequestState.value = TransferActionState.Idle // Reset transfer state too
    }
    
    fun initiateTransfer(targetUser: User) {
        if (confirmedProperty == null) {
             // Use transferRequestState for errors related to this action
             _transferRequestState.value = TransferActionState.Error("No property confirmed for transfer.")
            println("ScanViewModel Error: initiateTransfer called with no confirmed property.")
            return
        }
        // No null check needed for targetUser per type system
        
        val propertyToTransfer = confirmedProperty!!
        val recipient = targetUser
        
        println("Initiating transfer for Prop ID: ${propertyToTransfer.id} to User ID: ${recipient.id}")
        _transferRequestState.value = TransferActionState.Loading 
        
        viewModelScope.launch {
           try {
              val request = TransferRequest(propertyId = propertyToTransfer.id, targetUserId = recipient.id)
              val response = apiService.requestTransfer(request)
              if (response.isSuccessful) {
                  println("Transfer request successful: ${response.code()}")
                   _transferRequestState.value = TransferActionState.Success() 
                  // Don't reset scan state immediately, let UI show success message
                  // resetState() 
              } else {
                   val errorBody = response.errorBody()?.string() ?: "Unknown error requesting transfer"
                   println("Error requesting transfer: ${response.code()} - $errorBody")
                   _transferRequestState.value = TransferActionState.Error("Error ${response.code()}: Request failed")
              }
           } catch (e: HttpException) {
                 println("Network error requesting transfer: ${e.message()}")
                 _transferRequestState.value = TransferActionState.Error("Network error: ${e.message()}")
           } catch (e: IOException) {
                 println("Connection error requesting transfer: ${e.message}")
                  _transferRequestState.value = TransferActionState.Error("Network connection error.")
           } catch (e: Exception) {
                  println("Unexpected error requesting transfer: ${e.localizedMessage}")
                  _transferRequestState.value = TransferActionState.Error("An unexpected error occurred.")
           }
        }
    }

    // Function to manually reset the transfer state (e.g., after snackbar dismissal)
    fun clearTransferState() {
        _transferRequestState.value = TransferActionState.Idle
    }

    // Store the confirmed property when scan is successful
    private fun handleScanSuccess(property: Property) {
        confirmedProperty = property
        _scanState.value = ScanResultState.Success(property)
        println("ScanViewModel: Stored confirmed property - ${property.serialNumber}")
    }
} 