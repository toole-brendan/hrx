package com.example.handreceipt.viewmodels

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.LoginCredentials
import com.example.handreceipt.data.model.LoginResponse
import com.example.handreceipt.data.network.ApiService
// Remove NetworkModule import, Hilt provides dependencies
// import com.example.handreceipt.data.network.NetworkModule
import dagger.hilt.android.lifecycle.HiltViewModel // Import HiltViewModel
import kotlinx.coroutines.launch
import java.net.CookieManager // Import for clearing cookies
import java.net.HttpCookie
import javax.inject.Inject // Import Inject

@HiltViewModel // Annotate ViewModel with HiltViewModel
class AuthViewModel @Inject constructor( // Use @Inject constructor
    private val apiService: ApiService, // Hilt provides ApiService
    private val cookieManager: CookieManager // Hilt provides CookieManager
) : ViewModel() {

    // Backing private mutable state
    private val _isLoading = mutableStateOf(true) // Start loading
    private val _isAuthenticated = mutableStateOf(false)
    private val _currentUser = mutableStateOf<LoginResponse?>(null)
    private val _authError = mutableStateOf<String?>(null) // For displaying errors

    // Public immutable state holders
    val isLoading: State<Boolean> = _isLoading
    val isAuthenticated: State<Boolean> = _isAuthenticated
    val currentUser: State<LoginResponse?> = _currentUser
    val authError: State<String?> = _authError

    init {
        // Check session when ViewModel is created
        checkSession()
    }

    fun checkSession() {
        viewModelScope.launch {
            _isLoading.value = true
            _authError.value = null // Clear previous errors
            try {
                val response = apiService.checkSession()
                if (response.isSuccessful && response.body() != null) {
                    _currentUser.value = response.body()
                    _isAuthenticated.value = true
                    println("AuthViewModel: Session check successful for ${response.body()?.username}")
                } else {
                    // Handle non-successful responses (like 401 Unauthorized)
                    _isAuthenticated.value = false
                    _currentUser.value = null
                    if (response.code() == 401) {
                        println("AuthViewModel: Session check failed (401 Unauthorized)")
                        // No specific error message needed for initial check failure
                    } else {
                        val errorMsg = "Session check failed: ${response.code()} - ${response.message()}"
                        _authError.value = errorMsg
                        println("AuthViewModel: $errorMsg")
                    }
                }
            } catch (e: Exception) {
                // Handle network or other exceptions
                _isAuthenticated.value = false
                _currentUser.value = null
                val errorMsg = "Session check failed: ${e.message}"
                _authError.value = errorMsg
                println("AuthViewModel: $errorMsg")
                e.printStackTrace()
            }
            _isLoading.value = false
        }
    }

    // Login function - Call this from LoginScreen
    fun login(credentials: LoginCredentials, onLoginSuccess: () -> Unit) {
        viewModelScope.launch {
            _isLoading.value = true
            _authError.value = null
            try {
                val response = apiService.login(credentials)
                if (response.isSuccessful && response.body() != null) {
                    _currentUser.value = response.body()
                    _isAuthenticated.value = true
                    println("AuthViewModel: Login successful for ${response.body()?.username}")
                    onLoginSuccess() // Trigger navigation callback
                } else {
                    _isAuthenticated.value = false
                    _currentUser.value = null
                    val errorMsg = "Login failed: ${response.code()} - ${response.errorBody()?.string() ?: response.message()}"
                    _authError.value = errorMsg
                    println("AuthViewModel: $errorMsg")
                }
            } catch (e: Exception) {
                _isAuthenticated.value = false
                _currentUser.value = null
                val errorMsg = "Login failed: ${e.message}"
                _authError.value = errorMsg
                println("AuthViewModel: $errorMsg")
                e.printStackTrace()
            }
            _isLoading.value = false
        }
    }

    // Logout function - Call this from the UI
    fun logout() {
        // Clear local state immediately
        _isAuthenticated.value = false
        _currentUser.value = null
        _authError.value = null
        _isLoading.value = false // Stop any loading indicators

        // Clear cookies
        try {
            cookieManager.cookieStore.removeAll()
             println("AuthViewModel: Cookies cleared.")
         } catch (e: Exception) {
             println("AuthViewModel: Error clearing cookies: ${e.message}")
             e.printStackTrace()
         }

        // Optionally: Call a backend logout endpoint
        // viewModelScope.launch {
        //     try {
        //         apiService.logout() // Assuming a logout endpoint exists
        //         println("AuthViewModel: Backend logout successful.")
        //     } catch (e: Exception) {
        //         println("AuthViewModel: Backend logout failed: ${e.message}")
        //     }
        // }
         println("AuthViewModel: User logged out locally.")
    }

     // Function to clear the auth error message (e.g., after user acknowledges it)
    fun clearError() {
        _authError.value = null
    }
} 