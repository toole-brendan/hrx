package com.example.handreceipt.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.* // Import collectAsState, LaunchedEffect, etc.
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.handreceipt.ui.composables.CameraView
import com.example.handreceipt.viewmodels.ScanResultState
import com.example.handreceipt.viewmodels.ScanViewModel
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.data.model.User
import com.example.handreceipt.viewmodels.TransferActionState // If needed for transfer state display
import kotlinx.coroutines.launch
import androidx.compose.ui.graphics.Color

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterialApi::class) // Add ExperimentalMaterialApi for BottomSheet
@Composable
fun ScanScreen(
    onNavigateBack: () -> Unit,
    viewModel: ScanViewModel = hiltViewModel()
) {
    val scanState by viewModel.scanState
    val transferState by viewModel.transferRequestState // Observe transfer state
    
    val coroutineScope = rememberCoroutineScope()
    val modalSheetState = rememberModalBottomSheetState(
         initialValue = ModalBottomSheetValue.Hidden,
         confirmValueChange = { it != ModalBottomSheetValue.HalfExpanded } // Prevent half-expanded state
     )
    var showUserSelectionSheet by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() } // Add SnackbarHostState

    // LaunchedEffect to show Snackbar based on transferState
    LaunchedEffect(transferState) {
        when (val state = transferState) {
            is TransferActionState.Success -> {
                snackbarHostState.showSnackbar(
                    message = state.message,
                    duration = SnackbarDuration.Short
                )
                // Reset state in VM after showing message
                 viewModel.clearTransferState()
                 viewModel.resetState() // Go back to scanning after success
            }
            is TransferActionState.Error -> {
                 snackbarHostState.showSnackbar(
                    message = state.message,
                    duration = SnackbarDuration.Long, // Show errors longer
                    actionLabel = "Dismiss"
                )
                 // Reset state in VM after showing message
                viewModel.clearTransferState()
            }
            else -> { /* Do nothing for Idle or Loading */ }
        }
    }

    // Use ModalBottomSheetLayout to host the sheet content
    ModalBottomSheetLayout(
        sheetState = modalSheetState,
        sheetContent = {
            // Content of the Bottom Sheet - User Selection
            Box(modifier = Modifier.defaultMinSize(minHeight = 1.dp)) { // Needed for sheet to function
                UserSelectionScreen(
                     onUserSelected = { selectedUser ->
                         println("User selected: ${selectedUser.username}")
                         viewModel.initiateTransfer(targetUser = selectedUser)
                         // Hide sheet after selection
                         coroutineScope.launch { modalSheetState.hide() }
                         showUserSelectionSheet = false 
                     },
                     onDismiss = {
                         // Hide sheet on dismiss
                         coroutineScope.launch { modalSheetState.hide() }
                         showUserSelectionSheet = false
                     }
                 )
            }
        },
        sheetShape = MaterialTheme.shapes.large // Optional: customize shape
    ) {
        // Main Scaffold content
        Scaffold(
            snackbarHost = { SnackbarHost(snackbarHostState) }, // Add SnackbarHost
            topBar = {
                TopAppBar(
                    title = { Text("Scan Item") },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                )
            }
        ) { paddingValues ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                // Camera View (only shown when scanning)
                 if (scanState == ScanResultState.Scanning) {
                     CameraView(
                         modifier = Modifier.fillMaxSize(),
                         onBarcodeScanned = { code -> viewModel.processScannedCode(code) },
                         onTextRecognized = { text ->
                             if (text.length > 3) { viewModel.processScannedCode(text) }
                             else { println("Ignoring short recognized text: $text") }
                         }
                     )
                 }

                // Overlay content based on state
                ScanStatusOverlay(
                    scanState = scanState,
                    onScanAgain = { viewModel.resetState() },
                    onConfirm = { property ->
                         println("Confirm button tapped for ${property.serialNumber}")
                         // Show the user selection sheet
                         coroutineScope.launch { 
                            if (modalSheetState.isVisible) modalSheetState.hide() 
                            else modalSheetState.show()
                        }
                         showUserSelectionSheet = true
                    }
                )
                 
                 // TODO: Maybe show a message/indicator about transfer progress based on transferState?
            }
        }
    }
    
     // Handle hiding the sheet when back button is pressed (if sheet is visible)
     LaunchedEffect(modalSheetState.isVisible) {
         if (!modalSheetState.isVisible) {
             showUserSelectionSheet = false
         }
     }
}

@Composable
fun ScanStatusOverlay(
    scanState: ScanResultState,
    onScanAgain: () -> Unit,
    onConfirm: (Property) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Bottom, // Align content to the bottom
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        when (scanState) {
            is ScanResultState.Scanning -> {
                Text(
                    "Point camera at barcode or serial number",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onPrimary, // Use theme colors
                    modifier = Modifier
                        .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.7f), MaterialTheme.shapes.medium)
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                )
            }
            is ScanResultState.Loading -> {
                CircularProgressIndicator()
                Spacer(modifier = Modifier.height(8.dp))
                Text("Looking up item...")
            }
            is ScanResultState.Success -> {
                PropertyDetailsCard(property = scanState.property)
                Spacer(modifier = Modifier.height(16.dp))
                Row( // Use Row for side-by-side buttons
                     modifier = Modifier.fillMaxWidth(),
                     horizontalArrangement = Arrangement.SpaceEvenly
                 ) {
                    Button(onClick = { 
                        println("Confirm button clicked for: ${scanState.property.serialNumber}")
                        onConfirm(scanState.property) 
                        // TODO: Implement actual confirmation action (e.g., navigate, start transfer)
                     }) { 
                         Text("Confirm") 
                     }
                    Button(onClick = onScanAgain) { Text("Scan Again") }
                 }
            }
            is ScanResultState.NotFound -> {
                Text(
                    "Item not found in database.",
                    color = MaterialTheme.colorScheme.onError,
                     modifier = Modifier
                        .background(MaterialTheme.colorScheme.error.copy(alpha = 0.8f), MaterialTheme.shapes.medium)
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                    )
                Spacer(modifier = Modifier.height(16.dp))
                Button(onClick = onScanAgain) { Text("Scan Again") }
                // TODO: Option to manually enter or add?
            }
            is ScanResultState.Error -> {
                 Text(
                    "Error: ${scanState.message}",
                     color = MaterialTheme.colorScheme.onError,
                     modifier = Modifier
                        .background(MaterialTheme.colorScheme.error.copy(alpha = 0.8f), MaterialTheme.shapes.medium)
                        .padding(horizontal = 12.dp, vertical = 8.dp)
                 )
                Spacer(modifier = Modifier.height(16.dp))
                Button(onClick = onScanAgain) { Text("Try Again") }
            }
            ScanResultState.Idle -> {
                 // Should not typically be in Idle state while on this screen
                 Text("Ready")
             }
        }
        Spacer(modifier = Modifier.height(32.dp)) // Add some bottom spacing
    }
}

// Simple Card to display Property Details (can be customized)
@Composable
fun PropertyDetailsCard(property: Property, modifier: Modifier = Modifier) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Item Found", style = MaterialTheme.typography.headlineSmall)
            Spacer(modifier = Modifier.height(8.dp))
            Text("NSN: ${property.referenceItem?.nsn ?: "N/A"}")
            Text("Name: ${property.referenceItem?.itemName ?: "N/A"}")
            Text("Serial Number: ${property.serialNumber}")
            Text("Status: ${property.status}")
            // Add more details as needed (Assigned To, Location, etc.)
        }
    }
} 