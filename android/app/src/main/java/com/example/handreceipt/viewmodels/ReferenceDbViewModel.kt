package com.example.handreceipt.viewmodels

// Remove unused imports related to manual network setup
// import android.webkit.CookieManager
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.ReferenceItem
import com.example.handreceipt.data.network.ApiService
import dagger.hilt.android.lifecycle.HiltViewModel // Import HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
// Remove unused imports related to manual network setup
// import okhttp3.CookieJar
// import okhttp3.JavaNetCookieJar
// import okhttp3.OkHttpClient
// import okhttp3.logging.HttpLoggingInterceptor
// import retrofit2.Retrofit
// import retrofit2.converter.gson.GsonConverterFactory
// import java.net.CookieHandler
// import java.net.CookiePolicy
// import java.util.UUID
import javax.inject.Inject // Import Inject

// Sealed interface to represent the UI state
sealed interface ReferenceDbUiState {
    data class Success(val items: List<ReferenceItem>) : ReferenceDbUiState
    object Error : ReferenceDbUiState // Consider adding error message
    object Loading : ReferenceDbUiState
}

@HiltViewModel // Annotate ViewModel with HiltViewModel
class ReferenceDbViewModel @Inject constructor( // Use @Inject constructor
    private val service: ApiService // Hilt provides ApiService
) : ViewModel() {

    // Private mutable state flow
    private val _uiState = MutableStateFlow<ReferenceDbUiState>(ReferenceDbUiState.Loading)
    // Public immutable state flow for the UI to observe
    val uiState: StateFlow<ReferenceDbUiState> = _uiState.asStateFlow()

    // Remove manual base URL definition (handled in NetworkModule)
    // private val BASE_URL = "http://10.0.2.2:8080/api/"

    // Remove companion object with manual network setup
    // companion object { ... }

    // Remove manual service instantiation
    // private val service = apiService

    init {
        loadReferenceItems()
    }

    fun loadReferenceItems() {
        _uiState.update { ReferenceDbUiState.Loading }
        viewModelScope.launch {
            try {
                // Fetch items using the injected service
                val items = service.getReferenceItems()
                _uiState.update { ReferenceDbUiState.Success(items) }
                println("Successfully fetched ${items.size} reference items")
            } catch (e: Exception) {
                _uiState.update { ReferenceDbUiState.Error }
                println("Error loading reference items: ${e.message}")
                e.printStackTrace()
            }
        }
    }

    // TODO: Implement other ViewModel functions as needed (e.g., search, authentication)
} 