package com.example.handreceipt.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.handreceipt.data.model.LoginResponse // For success callback
import com.example.handreceipt.viewmodels.LoginEvent
import com.example.handreceipt.viewmodels.LoginScreenState
import com.example.handreceipt.viewmodels.LoginViewModel
import kotlinx.coroutines.flow.collectLatest

@Composable
fun LoginScreen(
    viewModel: LoginViewModel = hiltViewModel(),
    onLoginSuccess: (LoginResponse) -> Unit // Callback after successful login
) {
    val username by viewModel.username.collectAsStateWithLifecycle()
    val password by viewModel.password.collectAsStateWithLifecycle()
    val screenState by viewModel.screenState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current
    var passwordVisible by rememberSaveable { mutableStateOf(false) }

    // State for Snackbar host
    val snackbarHostState = remember { SnackbarHostState() }

    // Listen for events from ViewModel to show Snackbar
    LaunchedEffect(key1 = viewModel.eventFlow) {
        viewModel.eventFlow.collectLatest { event ->
            when (event) {
                is LoginEvent.ShowSnackbar -> {
                    focusManager.clearFocus() // Dismiss keyboard if error occurs
                    snackbarHostState.showSnackbar(
                        message = event.message,
                        duration = SnackbarDuration.Short
                    )
                }
            }
        }
    }

    // Navigate away when login is successful
    LaunchedEffect(screenState) {
        if (screenState is LoginScreenState.Success) {
            focusManager.clearFocus() // Clear focus before navigating
            onLoginSuccess((screenState as LoginScreenState.Success).response)
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues) // Apply padding from Scaffold
                .padding(horizontal = 32.dp, vertical = 16.dp) // Add specific screen padding
                .verticalScroll(rememberScrollState()), // Allow scrolling
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {

            Text("HandReceipt Login", style = MaterialTheme.typography.headlineLarge)
            Spacer(modifier = Modifier.height(32.dp))

            // Username Field
            OutlinedTextField(
                value = username,
                onValueChange = viewModel::onUsernameChange,
                label = { Text("Username") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Text,
                    imeAction = ImeAction.Next
                ),
                // Error state doesn't visually change the field now, relies on Snackbar
                // isError = screenState is LoginScreenState.Error
            )
            Spacer(modifier = Modifier.height(16.dp))

            // Password Field
            OutlinedTextField(
                value = password,
                onValueChange = viewModel::onPasswordChange,
                label = { Text("Password") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done
                ),
                keyboardActions = KeyboardActions(
                    onDone = {
                        focusManager.clearFocus()
                        if (viewModel.canAttemptLogin()) {
                            viewModel.attemptLogin()
                        }
                    }
                ),
                // Toggle password visibility
                trailingIcon = {
                    val image = if (passwordVisible)
                        Icons.Filled.Visibility
                    else Icons.Filled.VisibilityOff
                    val description = if (passwordVisible) "Hide password" else "Show password"

                    IconButton(onClick = { passwordVisible = !passwordVisible }) {
                        Icon(imageVector = image, description)
                    }
                },
                // Error state doesn't visually change the field now, relies on Snackbar
                // isError = screenState is LoginScreenState.Error
            )
            Spacer(modifier = Modifier.height(24.dp)) // Increased space before button

            // Login Button
            Button(
                onClick = {
                    focusManager.clearFocus()
                    viewModel.attemptLogin()
                },
                modifier = Modifier.fillMaxWidth(),
                // Enable button unless loading
                enabled = screenState !is LoginScreenState.Loading && viewModel.canAttemptLogin()
            ) {
                if (screenState is LoginScreenState.Loading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text("Login")
                }
            }

            // Remove the Text error display, using Snackbar now
            /*
            if (loginState is LoginUiState.Error) {
                Text(...)
            }
            */
        }
    }
}

// Add previews if desired
/*
@Preview(showBackground = true)
@Composable
fun LoginScreenPreviewIdle() {
    // Need Theme wrapper
    LoginScreen(onLoginSuccess = {})
}

@Preview(showBackground = true)
@Composable
fun LoginScreenPreviewLoading() {
    // Need Theme wrapper & mock ViewModel state
    LoginScreen(onLoginSuccess = {})
}

@Preview(showBackground = true)
@Composable
fun LoginScreenPreviewError() {
    // Need Theme wrapper & mock ViewModel state
    LoginScreen(onLoginSuccess = {})
}
*/ 