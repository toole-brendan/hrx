package com.example.handreceipt.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.viewmodels.PropertyDetailUiState
import com.example.handreceipt.viewmodels.PropertyDetailViewModel
import com.example.handreceipt.viewmodels.TransferActionState
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterialApi::class)
@Composable
fun PropertyDetailScreen(
    propertyId: String,
    viewModel: PropertyDetailViewModel = hiltViewModel(),
    onNavigateBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val showUserSelection by viewModel.showUserSelection
    val transferState by viewModel.transferRequestState
    
    val coroutineScope = rememberCoroutineScope()
    val modalSheetState = rememberModalBottomSheetState(
         initialValue = ModalBottomSheetValue.Hidden,
         confirmValueChange = { it != ModalBottomSheetValue.HalfExpanded } 
     )
    val snackbarHostState = remember { SnackbarHostState() }
    
    LaunchedEffect(showUserSelection) {
        if (showUserSelection) {
            coroutineScope.launch { modalSheetState.show() }
        } else {
            coroutineScope.launch { modalSheetState.hide() }
        }
    }
    
    LaunchedEffect(modalSheetState.isVisible) {
        if (!modalSheetState.isVisible && showUserSelection) {
             viewModel.userSelectionDismissed()
        }
    }
    
    LaunchedEffect(transferState) {
        when (val state = transferState) {
            is TransferActionState.Success -> {
                snackbarHostState.showSnackbar(message = state.message, duration = SnackbarDuration.Short)
                viewModel.clearTransferState()
            }
            is TransferActionState.Error -> {
                snackbarHostState.showSnackbar(message = state.message, duration = SnackbarDuration.Long)
                viewModel.clearTransferState()
            }
            else -> {}
        }
    }

    ModalBottomSheetLayout(
        sheetState = modalSheetState,
        sheetContent = {
             Box(modifier = Modifier.defaultMinSize(minHeight = 1.dp)) { 
                 UserSelectionScreen(
                     onUserSelected = { selectedUser ->
                         viewModel.initiateTransfer(targetUser = selectedUser)
                     },
                     onDismiss = { viewModel.userSelectionDismissed() }
                 )
            }
        }
    ) {
        Scaffold(
             snackbarHost = { SnackbarHost(snackbarHostState) },
            topBar = {
                TopAppBar(
                    title = { Text("Property Details") },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                )
            }
        ) { paddingValues ->
            Box(modifier = Modifier.fillMaxSize().padding(paddingValues).padding(16.dp)) {
                when (val state = uiState) {
                    is PropertyDetailUiState.Loading -> {
                        CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                    }
                    is PropertyDetailUiState.Success -> {
                        PropertyDetailContent(property = state.property, viewModel = viewModel)
                    }
                    is PropertyDetailUiState.Error -> {
                        PropertyDetailErrorView(message = state.message, onRetry = viewModel::fetchPropertyDetails)
                    }
                }
                if (transferState == TransferActionState.Loading) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
            }
        }
    }
}

@Composable
fun PropertyDetailContent(
    property: Property,
    viewModel: PropertyDetailViewModel
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(property.itemName, style = MaterialTheme.typography.headlineMedium)
        Divider()

        PropertyInfoRow(label = "Serial Number", value = property.serialNumber)
        PropertyInfoRow(label = "NSN", value = property.nsn)
        PropertyInfoRow(label = "Status", value = property.status)
        PropertyInfoRow(label = "Location", value = property.location ?: "N/A")
        
        if (property.lastInventoryDate != null) {
            PropertyInfoRow(label = "Last Inventory", value = formatDate(property.lastInventoryDate))
        }
        if (property.acquisitionDate != null) {
            PropertyInfoRow(label = "Acquisition Date", value = formatDate(property.acquisitionDate))
        }
        if (property.assignedToUserId != null) {
             // TODO: Fetch User Name based on ID for display
            PropertyInfoRow(label = "Assigned To", value = "User ID: ${property.assignedToUserId}")
        }
        if (!property.notes.isNullOrBlank()) {
            PropertyInfoRow(label = "Notes", value = property.notes)
        }

        Spacer(modifier = Modifier.height(16.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = { viewModel.requestTransferClicked() }) { Text("Request Transfer") }
            OutlinedButton(onClick = { /* TODO: View History */ }) { Text("View History") }
        }
    }
}

@Composable
fun PropertyInfoRow(label: String, value: String?) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = "$label:",
            style = MaterialTheme.typography.titleSmall,
            modifier = Modifier.width(120.dp)
        )
        Text(
            text = value ?: "N/A",
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

@Composable
fun PropertyDetailErrorView(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(Icons.Filled.ErrorOutline, contentDescription = null, modifier = Modifier.size(64.dp), tint = MaterialTheme.colorScheme.error)
        Spacer(modifier = Modifier.height(16.dp))
        Text("Error Loading Property", style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(8.dp))
        Text(message, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = onRetry) {
            Text("Retry")
        }
    }
}

private fun formatDate(date: Date): String {
    val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    return formatter.format(date)
} 