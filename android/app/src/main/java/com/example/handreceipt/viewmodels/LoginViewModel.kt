package com.example.handreceipt.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.LoginCredentials
import com.example.handreceipt.data.model.LoginResponse
import com.example.handreceipt.data.network.ApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import retrofit2.HttpException
import javax.inject.Inject

// Sealed interface for Login UI State (main screen state)
sealed interface LoginScreenState {
    object Idle : LoginScreenState
    object Loading : LoginScreenState
    data class Success(val response: LoginResponse) : LoginScreenState
    // We'll use Snackbar for errors, so remove Error state here
    // data class Error(val message: String) : LoginScreenState
}

// Separate events for one-time actions like showing a Snackbar
sealed interface LoginEvent {
    data class ShowSnackbar(val message: String) : LoginEvent
}

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val service: ApiService
) : ViewModel() {

    // --- State --- 
    private val _username = MutableStateFlow("")
    val username: StateFlow<String> = _username.asStateFlow()

    private val _password = MutableStateFlow("")
    val password: StateFlow<String> = _password.asStateFlow()

    // Represents the main screen state (Idle, Loading, Success)
    private val _screenState = MutableStateFlow<LoginScreenState>(LoginScreenState.Idle)
    val screenState: StateFlow<LoginScreenState> = _screenState.asStateFlow()

    // SharedFlow for one-time events like Snackbars
    private val _eventFlow = MutableSharedFlow<LoginEvent>()
    val eventFlow = _eventFlow.asSharedFlow()

    // --- Event Handlers --- 
    fun onUsernameChange(input: String) {
        _username.value = input
        // Reset screen state if user modifies input after an attempt
        if (_screenState.value != LoginScreenState.Idle && _screenState.value != LoginScreenState.Loading) {
             _screenState.value = LoginScreenState.Idle
        }
    }

    fun onPasswordChange(input: String) {
        _password.value = input
        if (_screenState.value != LoginScreenState.Idle && _screenState.value != LoginScreenState.Loading) {
             _screenState.value = LoginScreenState.Idle
        }
    }

    fun canAttemptLogin(): Boolean {
        return username.value.isNotBlank() && password.value.isNotBlank()
    }

    // --- Actions --- 
    fun attemptLogin() {
        if (!canAttemptLogin()) {
            // Emit event to show Snackbar for validation error
            viewModelScope.launch { _eventFlow.emit(LoginEvent.ShowSnackbar("Username and password cannot be empty.")) }
            return
        }
        if (_screenState.value == LoginScreenState.Loading) return

        _screenState.value = LoginScreenState.Loading
        val credentials = LoginCredentials(username.value.trim(), password.value)

        viewModelScope.launch {
             var success = false
            try {
                val response = service.login(credentials)

                if (response.isSuccessful) {
                    val loginResponse = response.body()
                    if (loginResponse != null) {
                         println("Login Successful: User ${loginResponse.username} (ID: ${loginResponse.userId})")
                        _screenState.value = LoginScreenState.Success(loginResponse)
                         success = true
                        // UI layer observes Success state for navigation
                         // Optionally emit Snackbar event for success too
                         // _eventFlow.emit(LoginEvent.ShowSnackbar("Login successful!"))
                    } else {
                         println("Login Error: Server returned success but empty body.")
                        _eventFlow.emit(LoginEvent.ShowSnackbar("Login failed: Empty server response."))
                    }
                } else {
                    val errorMsg = when (response.code()) {
                        401 -> "Invalid username or password."
                        else -> "Login failed (Code: ${response.code()})."
                    }
                     println("Login Error: ${response.code()} - ${response.errorBody()?.string()}")
                    _eventFlow.emit(LoginEvent.ShowSnackbar(errorMsg))
                }
            } catch (e: HttpException) {
                 println("Login Network/HTTP Error: ${e.message()}")
                 _eventFlow.emit(LoginEvent.ShowSnackbar("Network error during login."))
                 e.printStackTrace()
            } catch (e: Throwable) {
                 println("Login Generic Error: ${e.message}")
                 _eventFlow.emit(LoginEvent.ShowSnackbar("An unexpected error occurred during login."))
                 e.printStackTrace()
            }
            // Reset screen state to Idle only if login didn't succeed
             if (!success) {
                 _screenState.value = LoginScreenState.Idle
             }
        }
    }
} 