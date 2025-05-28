package com.example.handreceipt.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.handreceipt.data.model.TransferStatus
import com.example.handreceipt.viewmodels.*
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransferDetailScreen(
    // Inject both ViewModels
    detailViewModel: TransferDetailViewModel = hiltViewModel(),
    transfersViewModel: TransfersViewModel = hiltViewModel(), // Assumes singleton or correctly scoped VM
    onNavigateBack: () -> Unit,
    // TODO: Inject current user ID properly for button logic
    currentUserId: UUID? // Placeholder
) {
    val detailState by detailViewModel.detailState.collectAsState()
    val actionState by transfersViewModel.actionState.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() } // Snackbar for detail-specific feedback if needed

    // LaunchedEffect to potentially navigate back after successful action
    LaunchedEffect(actionState) {
        if (actionState is TransferActionState.Success) {
            // Delay slightly so user sees success message from list screen
            // kotlinx.coroutines.delay(500) 
            // onNavigateBack() // Navigate back after success
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    // Show placeholder or actual ID based on state
                    val titleText = if (detailState is TransferDetailState.Success) {
                         "Transfer #" + (detailState as TransferDetailState.Success).transfer.id.toString().take(8)
                    } else {
                         "Transfer Details"
                    }
                     Text(titleText)
                 },
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
                .padding(16.dp)
        ) {
            when (val state = detailState) {
                is TransferDetailState.Loading -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
                is TransferDetailState.Success -> {
                    val transfer = state.transfer
                    Column(modifier = Modifier.fillMaxSize()) {
                        TransferListItem(transfer = transfer) {} // Display details (non-clickable)
                        Spacer(modifier = Modifier.height(16.dp))
                        // Add more details here if needed
                        // Text("Requested by: ...")
                        
                        Spacer(modifier = Modifier.weight(1f))
                        
                        // Action Buttons
                        if (transfer.status == TransferStatus.PENDING && transfer.toUserId == currentUserId) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterHorizontally)
                            ) {
                                Button(
                                    onClick = { transfersViewModel.approveTransfer(transfer.id.toString()) },
                                    enabled = actionState !is TransferActionState.Loading,
                                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
                                ) {
                                    Text("Approve")
                                }
                                Button(
                                    onClick = { transfersViewModel.rejectTransfer(transfer.id.toString()) },
                                    enabled = actionState !is TransferActionState.Loading,
                                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
                                ) {
                                    Text("Reject")
                                }
                            }
                            if (actionState is TransferActionState.Loading) {
                                CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterHorizontally).padding(top = 8.dp))
                            }
                        }
                         Spacer(modifier = Modifier.height(16.dp)) // Bottom padding
                    }
                }
                is TransferDetailState.Error -> {
                    Text(
                        state.message,
                        modifier = Modifier.align(Alignment.Center),
                        color = MaterialTheme.colorScheme.error
                    )
                    // Optional: Add Retry button
                     Button(
                         onClick = { detailViewModel.fetchTransferDetails() },
                         modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 32.dp)
                     ) {
                         Text("Retry")
                     }
                }
            }
        }
    }
} 