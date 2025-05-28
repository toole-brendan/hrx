package com.example.handreceipt.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.data.network.ApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

// Sealed interface for My Properties UI State
sealed interface MyPropertiesUiState {
    object Loading : MyPropertiesUiState
    data class Success(val items: List<Property>) : MyPropertiesUiState
    data class Error(val message: String) : MyPropertiesUiState
}

@HiltViewModel
class MyPropertiesViewModel @Inject constructor(
    private val apiService: ApiService
) : ViewModel() {

    private val _uiState = MutableStateFlow<MyPropertiesUiState>(MyPropertiesUiState.Loading)
    val uiState: StateFlow<MyPropertiesUiState> = _uiState.asStateFlow()

    init {
        loadProperties()
    }

    fun loadProperties() {
        _uiState.value = MyPropertiesUiState.Loading
        viewModelScope.launch {
            try {
                val response = apiService.getMyInventory()
                if (response.isSuccessful) {
                    _uiState.value = MyPropertiesUiState.Success(response.body() ?: emptyList())
                    println("MyPropertiesViewModel: Successfully fetched ${response.body()?.size ?: 0} items.")
                } else {
                    val errorMsg = "Error fetching properties: ${response.code()} - ${response.message()}"
                    _uiState.value = MyPropertiesUiState.Error(errorMsg)
                    println("MyPropertiesViewModel: $errorMsg")
                }
            } catch (e: Exception) {
                val errorMsg = "Network or other error fetching properties: ${e.message}"
                _uiState.value = MyPropertiesUiState.Error(errorMsg)
                println("MyPropertiesViewModel: $errorMsg")
                e.printStackTrace()
            }
        }
    }
} 