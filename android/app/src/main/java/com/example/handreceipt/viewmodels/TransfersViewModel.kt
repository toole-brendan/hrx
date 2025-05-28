package com.example.handreceipt.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.Transfer
import com.example.handreceipt.data.model.TransferStatus
import com.example.handreceipt.data.model.UserSummary // Assuming UserSummary exists for filtering
import com.example.handreceipt.data.network.ApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.launch
import retrofit2.HttpException
import java.io.IOException
import java.util.UUID
import javax.inject.Inject

// --- State Enums ---
sealed class TransfersLoadingState {
    object Idle : TransfersLoadingState()
    object Loading : TransfersLoadingState()
    data class Success(val allTransfers: List<Transfer>) : TransfersLoadingState()
    data class Error(val message: String) : TransfersLoadingState()
}

sealed class TransferActionState {
    object Idle : TransferActionState()
    object Loading : TransferActionState()
    data class Success(val message: String) : TransferActionState()
    data class Error(val message: String) : TransferActionState()
}

// --- Filter Enums ---
enum class TransferDirectionFilter(val displayName: String) {
    ALL("All"),
    INCOMING("Incoming"),
    OUTGOING("Outgoing")
}

enum class TransferStatusFilter(val displayName: String, val apiValue: String?) {
    PENDING("Pending", "PENDING"),
    ALL("All", null),
    APPROVED("Approved", "APPROVED"),
    REJECTED("Rejected", "REJECTED"),
    CANCELLED("Cancelled", "CANCELLED")
}

@HiltViewModel
class TransfersViewModel @Inject constructor(
    private val apiService: ApiService,
    // TODO: Inject a way to get the current user ID (e.g., from a SessionManager or AuthRepository)
    private val currentUserId: UUID? // Placeholder - Needs proper injection
) : ViewModel() {

    // --- State Flows ---
    private val _loadingState = MutableStateFlow<TransfersLoadingState>(TransfersLoadingState.Idle)
    val loadingState: StateFlow<TransfersLoadingState> = _loadingState.asStateFlow()

    private val _actionState = MutableStateFlow<TransferActionState>(TransferActionState.Idle)
    val actionState: StateFlow<TransferActionState> = _actionState.asStateFlow()

    private val _selectedDirectionFilter = MutableStateFlow(TransferDirectionFilter.ALL)
    val selectedDirectionFilter: StateFlow<TransferDirectionFilter> = _selectedDirectionFilter.asStateFlow()

    private val _selectedStatusFilter = MutableStateFlow(TransferStatusFilter.PENDING)
    val selectedStatusFilter: StateFlow<TransferStatusFilter> = _selectedStatusFilter.asStateFlow()
    
    private val _filteredTransfers = MutableStateFlow<List<Transfer>>(emptyList())
    val filteredTransfers: StateFlow<List<Transfer>> = _filteredTransfers.asStateFlow()
    
    private var clearActionJob: Job? = null

    init {
        // Combine loading state and filters to update filteredTransfers
        combine(
            loadingState,
            selectedDirectionFilter,
            selectedStatusFilter
        ) { loadState, direction, status ->
            if (loadState is TransfersLoadingState.Success) {
                filterTransfersLocally(loadState.allTransfers, direction, status)
            } else {
                emptyList()
            }
        }.debounce(50) // Small debounce for filter changes
         .launchIn(viewModelScope)
         .also { job -> 
            job.invokeOnCompletion { _filteredTransfers.value = emptyList() } // Clear on scope cancellation
        } // Assign to _filteredTransfers indirectly via collect
        .let { flow -> 
             viewModelScope.launch { flow.collect { _filteredTransfers.value = it } }
        }

        // Fetch transfers when filters change
        combine(selectedDirectionFilter, selectedStatusFilter) { _, _ -> Unit }
            .debounce(100) // Debounce filter changes before fetching
            .launchIn(viewModelScope)
            .let { flow ->
                viewModelScope.launch { flow.collect { fetchTransfers() } }
            }
        
        // Initial fetch
        fetchTransfers()
    }

    // --- Filter Logic ---
    private fun filterTransfersLocally(
        allTransfers: List<Transfer>,
        direction: TransferDirectionFilter,
        status: TransferStatusFilter
    ): List<Transfer> {
        println("Filtering locally: ${allTransfers.size} items, Dir: $direction, Status: $status, User: ${currentUserId?.toString() ?: "N/A"}")
        return allTransfers.filter { transfer ->
            val statusMatch = (status == TransferStatusFilter.ALL || transfer.status.name == status.apiValue)
            val directionMatch = when (direction) {
                TransferDirectionFilter.ALL -> true
                TransferDirectionFilter.INCOMING -> transfer.toUserId == currentUserId
                TransferDirectionFilter.OUTGOING -> transfer.fromUserId == currentUserId
            }
            statusMatch && directionMatch
        }
    }
    
    fun setDirectionFilter(filter: TransferDirectionFilter) {
        _selectedDirectionFilter.value = filter
    }

    fun setStatusFilter(filter: TransferStatusFilter) {
        _selectedStatusFilter.value = filter
    }

    // --- API Calls ---
    fun fetchTransfers() {
        _loadingState.value = TransfersLoadingState.Loading
        _actionState.value = TransferActionState.Idle // Clear action state
        viewModelScope.launch {
            try {
                println("Fetching transfers from API. Status: ${selectedStatusFilter.apiValue}, Direction: ALL (local filtering)")
                // Fetch ALL directions, filter locally based on currentUserId
                // Fetch based on status filter from API
                val response = apiService.getTransfers(status = selectedStatusFilter.apiValue, direction = null)
                if (response.isSuccessful && response.body() != null) {
                    _loadingState.value = TransfersLoadingState.Success(response.body()!!)
                    println("Fetched ${response.body()!!.size} transfers successfully.")
                } else {
                    val errorMsg = "Error ${response.code()}: ${response.errorBody()?.string() ?: "Failed to load"}"
                    _loadingState.value = TransfersLoadingState.Error(errorMsg)
                    println("Error fetching transfers: $errorMsg")
                }
            } catch (e: HttpException) {
                 val errorMsg = "Network error: ${e.message()}"
                _loadingState.value = TransfersLoadingState.Error(errorMsg)
                 println("Error fetching transfers: $errorMsg")
            } catch (e: IOException) {
                 val errorMsg = "Connection error. Please check network."
                _loadingState.value = TransfersLoadingState.Error(errorMsg)
                 println("Error fetching transfers: $errorMsg")
            } catch (e: Exception) {
                 val errorMsg = "An unexpected error occurred: ${e.localizedMessage}"
                _loadingState.value = TransfersLoadingState.Error(errorMsg)
                 println("Error fetching transfers: $errorMsg")
            }
        }
    }

    fun approveTransfer(transferId: String) {
        performAction("Approving", transferId) { apiService.approveTransfer(it) }
    }

    fun rejectTransfer(transferId: String) {
        performAction("Rejecting", transferId) { apiService.rejectTransfer(it) }
    }

    private fun performAction(actionName: String, transferId: String, apiCall: suspend (String) -> Response<Transfer>) {
        _actionState.value = TransferActionState.Loading
        clearActionJob?.cancel()
        println("$actionName transfer ID: $transferId")
        viewModelScope.launch {
            try {
                val response = apiCall(transferId)
                if (response.isSuccessful) {
                    _actionState.value = TransferActionState.Success("Transfer ${actionName.dropLast(3)}ed")
                    println("Successfully ${actionName.dropLast(3)}ed transfer ID $transferId")
                    fetchTransfers() // Refresh list
                    scheduleActionStateClear()
                } else {
                    val errorMsg = "Error ${response.code()}: ${response.errorBody()?.string() ?: "Action failed"}"
                    _actionState.value = TransferActionState.Error(errorMsg)
                    println("Error ${actionName.dropLast(1)} transfer $transferId: $errorMsg")
                    scheduleActionStateClear()
                }
            } catch (e: HttpException) {
                val errorMsg = "Network error: ${e.message()}"
                _actionState.value = TransferActionState.Error(errorMsg)
                 println("Error ${actionName.dropLast(1)} transfer $transferId: $errorMsg")
                scheduleActionStateClear()
            } catch (e: IOException) {
                 val errorMsg = "Connection error. Please check network."
                _actionState.value = TransferActionState.Error(errorMsg)
                 println("Error ${actionName.dropLast(1)} transfer $transferId: $errorMsg")
                scheduleActionStateClear()
            } catch (e: Exception) {
                 val errorMsg = "An unexpected error occurred: ${e.localizedMessage}"
                _actionState.value = TransferActionState.Error(errorMsg)
                 println("Error ${actionName.dropLast(1)} transfer $transferId: $errorMsg")
                scheduleActionStateClear()
            }
        }
    }

    private fun scheduleActionStateClear(delayMillis: Long = 3000) {
        clearActionJob?.cancel()
        clearActionJob = viewModelScope.launch {
            delay(delayMillis)
            if (_actionState.value !is TransferActionState.Idle && _actionState.value !is TransferActionState.Loading) {
                _actionState.value = TransferActionState.Idle
            }
        }
    }
} 