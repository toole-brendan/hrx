package com.example.handreceipt.viewmodels

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.ReferenceItem
import com.example.handreceipt.data.network.ApiService
import com.example.handreceipt.ui.navigation.Routes // Import Routes to access arg name
import dagger.hilt.android.lifecycle.HiltViewModel // Import HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject // Import Inject

@HiltViewModel // Annotate ViewModel
class ReferenceItemDetailViewModel @Inject constructor( // Use @Inject constructor
    savedStateHandle: SavedStateHandle, // Hilt provides this automatically
    private val apiService: ApiService // Hilt provides ApiService
) : ViewModel() {

    // Get item ID from SavedStateHandle
    private val itemId: String = checkNotNull(savedStateHandle[Routes.ReferenceItemDetail.ARG_ITEM_ID])

    private val _isLoading = mutableStateOf(false)
    val isLoading: State<Boolean> = _isLoading

    private val _item = mutableStateOf<ReferenceItem?>(null)
    val item: State<ReferenceItem?> = _item

    private val _error = mutableStateOf<String?>(null)
    val error: State<String?> = _error

    init {
        fetchItemDetails()
    }

    private fun fetchItemDetails() {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                println("ReferenceItemDetailViewModel: Fetching details for item ID: $itemId")
                val response = apiService.getReferenceItemById(itemId)
                if (response.isSuccessful) {
                    _item.value = response.body()
                    println("ReferenceItemDetailViewModel: Successfully fetched item: ${_item.value?.itemName}")
                } else {
                    val errorMsg = "Error fetching item details: ${response.code()} - ${response.message()}"
                    _error.value = errorMsg
                     println("ReferenceItemDetailViewModel: $errorMsg")
                     if (response.code() == 404) {
                         _error.value = "Item not found."
                     }
                }
            } catch (e: Exception) {
                val errorMsg = "Network or other error fetching item: ${e.message}"
                _error.value = errorMsg
                 println("ReferenceItemDetailViewModel: $errorMsg")
                 e.printStackTrace()
            }
            _isLoading.value = false
        }
    }

    companion object {
        // Constant for the navigation argument key - MUST match the key in AppNavigation
        const val ARG_ITEM_ID = "itemId" 
    }
} 