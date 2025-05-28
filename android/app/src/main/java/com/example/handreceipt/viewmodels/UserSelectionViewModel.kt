package com.example.handreceipt.viewmodels

import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.handreceipt.data.model.User
import com.example.handreceipt.data.network.ApiService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import javax.inject.Inject
import retrofit2.HttpException
import java.io.IOException

sealed class UserListState {
    object Idle : UserListState() // Not searched yet
    object Loading : UserListState()
    data class Success(val users: List<User>) : UserListState()
    data class Error(val message: String) : UserListState()
}

@HiltViewModel
class UserSelectionViewModel @Inject constructor(
    private val apiService: ApiService
) : ViewModel() {

    private val _userListState = mutableStateOf<UserListState>(UserListState.Idle)
    val userListState: State<UserListState> = _userListState

    private var searchJob: Job? = null
    private val debouncePeriodMs = 300L // Debounce search input

    fun searchUsers(query: String) {
        searchJob?.cancel() // Cancel previous job if user types quickly
        if (query.isBlank()) {
            _userListState.value = UserListState.Idle // Clear results if query is blank
            return
        }
        _userListState.value = UserListState.Loading
        searchJob = viewModelScope.launch {
            delay(debouncePeriodMs)
            try {
                val response = apiService.getUsers(searchQuery = query)
                if (response.isSuccessful && response.body() != null) {
                    _userListState.value = UserListState.Success(response.body()!!)
                } else {
                    val errorBody = response.errorBody()?.string() ?: "Unknown error fetching users"
                    _userListState.value = UserListState.Error("Error ${response.code()}: $errorBody")
                }
            } catch (e: HttpException) {
                _userListState.value = UserListState.Error("Network error: ${e.message()}")
            } catch (e: IOException) {
                _userListState.value = UserListState.Error("Network connection error.")
            } catch (e: Exception) {
                _userListState.value = UserListState.Error("An unexpected error occurred: ${e.localizedMessage}")
            }
        }
    }

    // Call this when the view is closed or search is cancelled
    fun clearSearch() {
        searchJob?.cancel()
        _userListState.value = UserListState.Idle
    }
} 