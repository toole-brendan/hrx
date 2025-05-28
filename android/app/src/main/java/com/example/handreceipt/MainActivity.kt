package com.example.handreceipt // Adjust to your package name

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels // Import viewModels delegate
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import com.example.handreceipt.ui.navigation.AppNavigation // Import Nav Host
import com.example.handreceipt.ui.theme.HandReceiptTheme // Import your theme
import com.example.handreceipt.viewmodels.AuthViewModel // Import AuthViewModel
import dagger.hilt.android.AndroidEntryPoint // Import Hilt annotation

@AndroidEntryPoint // Add Hilt annotation
class MainActivity : ComponentActivity() {

    // Instantiate AuthViewModel using the activity-compose delegate
    // Hilt will provide this ViewModel now, but the delegate still works.
    // No explicit instantiation needed here if using Hilt directly in Composables.
    // private val authViewModel: AuthViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            HandReceiptTheme { // Apply your app theme
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    // AppNavigation will now use hiltViewModel() internally
                    // So we don't need to pass the authViewModel instance anymore.
                    AppNavigation() // Remove authViewModel parameter
                }
            }
        }
    }
} 