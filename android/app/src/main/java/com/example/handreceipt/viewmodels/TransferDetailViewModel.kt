package com.example.handreceipt.viewmodels

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.Transfer
import com.example.handreceipt.data.network.ApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import retrofit2.HttpException
import java.io.IOException
import javax.inject.Inject

sealed class TransferDetailState {
    object Loading : TransferDetailState()
    data class Success(val transfer: Transfer) : TransferDetailState()
    data class Error(val message: String) : TransferDetailState()
}

@HiltViewModel
class TransferDetailViewModel @Inject constructor(
    private val apiService: ApiService,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val transferId: String = savedStateHandle.get<String>("transferId")!!

    private val _detailState = MutableStateFlow<TransferDetailState>(TransferDetailState.Loading)
    val detailState: StateFlow<TransferDetailState> = _detailState.asStateFlow()

    // We might not need separate action state here if TransfersViewModel handles it globally
    // Alternatively, duplicate action state logic if detail screen needs independent feedback

    init {
        fetchTransferDetails()
    }

    fun fetchTransferDetails() {
        _detailState.value = TransferDetailState.Loading
        viewModelScope.launch {
            try {
                println("Fetching details for transfer ID: $transferId")
                // Call the actual endpoint
                val response = apiService.getTransferById(transferId)
                
                if (response.isSuccessful && response.body() != null) {
                    _detailState.value = TransferDetailState.Success(response.body()!!)
                    println("Successfully fetched details for transfer ID: $transferId")
                } else {
                    val errorMsg = "Error ${response.code()}: ${response.errorBody()?.string() ?: "Failed to load details"}"
                    _detailState.value = TransferDetailState.Error(errorMsg)
                    println("Error fetching transfer details: $errorMsg")
                }
            } catch (e: HttpException) {
                val errorMsg = "Network error: ${e.message()}"
                _detailState.value = TransferDetailState.Error(errorMsg)
                println("Error fetching transfer details: $errorMsg")
            } catch (e: IOException) {
                val errorMsg = "Connection error. Please check network."
                _detailState.value = TransferDetailState.Error(errorMsg)
                println("Error fetching transfer details: $errorMsg")
            } catch (e: Exception) {
                val errorMsg = "An unexpected error occurred: ${e.localizedMessage}"
                _detailState.value = TransferDetailState.Error(errorMsg)
                println("Error fetching transfer details: $errorMsg")
            }
        }
    }
    
    // Actions (Approve/Reject) might be delegated to the parent TransfersViewModel
    // if global action state is sufficient. If independent state/logic is needed,
    // implement approve/reject here similar to TransfersViewModel.
} 