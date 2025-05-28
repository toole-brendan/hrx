package com.example.handreceipt.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.handreceipt.data.model.Transfer
import com.example.handreceipt.data.model.TransferStatus
import com.example.handreceipt.viewmodels.*
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.flow.collectLatest // Needed for collecting action state

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterial3Api::class)
@Composable
fun TransfersScreen(
    viewModel: TransfersViewModel = hiltViewModel(),
    onNavigateToDetail: (String) -> Unit, // Callback for navigation
    // Add callback for showing snackbar if not handled internally
    // showSnackbar: (String, SnackbarDuration) -> Unit 
) {
    val loadingState by viewModel.loadingState.collectAsState()
    val actionState by viewModel.actionState.collectAsState()
    val filteredTransfers by viewModel.filteredTransfers.collectAsState()
    val selectedDirection by viewModel.selectedDirectionFilter.collectAsState()
    val selectedStatus by viewModel.selectedStatusFilter.collectAsState()
    
    val snackbarHostState = remember { SnackbarHostState() }

    // Observe action state for Snackbars
    LaunchedEffect(actionState) {
        when (val state = actionState) {
            is TransferActionState.Success -> {
                snackbarHostState.showSnackbar(state.message, duration = SnackbarDuration.Short)
                // State reset is handled by timer in ViewModel
            }
            is TransferActionState.Error -> {
                snackbarHostState.showSnackbar(state.message, duration = SnackbarDuration.Long)
                 // State reset is handled by timer in ViewModel
            }
            else -> { /* Do nothing for Idle/Loading */ }
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("Transfers") },
                actions = {
                    IconButton(
                        onClick = { viewModel.fetchTransfers() },
                        enabled = loadingState !is TransfersLoadingState.Loading
                    ) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 8.dp) // Add horizontal padding
        ) {
            // Filter Row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                FilterChipGroup(
                    title = "Direction",
                    filters = TransferDirectionFilter.values().toList(),
                    selectedFilter = selectedDirection,
                    onFilterSelected = { viewModel.setDirectionFilter(it) },
                    modifier = Modifier.weight(1f)
                )
                FilterChipGroup(
                    title = "Status",
                    filters = TransferStatusFilter.values().toList(),
                    selectedFilter = selectedStatus,
                    onFilterSelected = { viewModel.setStatusFilter(it) },
                    modifier = Modifier.weight(1f)
                )
            }

            Divider()

            // Content Area
            Box(modifier = Modifier.fillMaxSize()) {
                when (val state = loadingState) {
                    is TransfersLoadingState.Loading -> {
                        CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                    }
                    is TransfersLoadingState.Success -> {
                        if (filteredTransfers.isEmpty()) {
                            Text(
                                "No transfers match filters.",
                                modifier = Modifier.align(Alignment.Center),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        } else {
                            LazyColumn(modifier = Modifier.fillMaxSize()) {
                                items(filteredTransfers, key = { it.id }) { transfer ->
                                    TransferListItem(transfer = transfer) {
                                        onNavigateToDetail(transfer.id.toString()) // Navigate with ID
                                    }
                                    Divider()
                                }
                            }
                        }
                    }
                    is TransfersLoadingState.Error -> {
                        Text(
                            state.message,
                            modifier = Modifier.align(Alignment.Center).padding(16.dp),
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                     is TransfersLoadingState.Idle -> {
                         Text(
                            "Initializing...", // Or "Select filters..."
                            modifier = Modifier.align(Alignment.Center),
                             style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                         )
                     }
                }
                 // Overlay for Action Loading state?
                 if (actionState is TransferActionState.Loading) {
                     CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                 }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun <T : Enum<T>> FilterChipGroup(
    title: String,
    filters: List<T>,
    selectedFilter: T,
    onFilterSelected: (T) -> Unit,
    modifier: Modifier = Modifier,
    getDisplayName: (T) -> String = { it.name } // Default to enum name
) {
    Column(modifier = modifier) {
        // Text(title, style = MaterialTheme.typography.labelSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            filters.forEach { filter ->
                FilterChip(
                    selected = filter == selectedFilter,
                    onClick = { onFilterSelected(filter) },
                    label = { 
                        // Use reflection to get displayName if available
                        val name = try { 
                            filter::class.java.getDeclaredMethod("getDisplayName").invoke(filter) as String
                        } catch (e: Exception) { 
                            getDisplayName(filter) // Fallback
                        }
                        Text(name) 
                    },
                    modifier = Modifier.height(32.dp) // Adjust chip height
                )
            }
        }
    }
}

@Composable
fun TransferListItem(
    transfer: Transfer,
    onClick: () -> Unit
) {
    // Simple Date Formatter (Consider injecting or providing via CompositionLocal)
    val dateFormatter = remember { SimpleDateFormat("MM/dd/yy HH:mm", Locale.getDefault()) }

    ListItem(
        headlineContent = { Text(transfer.propertyName ?: transfer.propertySerialNumber) },
        supportingContent = {
            Column {
                Text("SN: ${transfer.propertySerialNumber}", style = MaterialTheme.typography.bodySmall)
                Text(
                    "From: ${transfer.fromUser?.username ?: "?"} -> To: ${transfer.toUser?.username ?: "?"}",
                    style = MaterialTheme.typography.bodySmall
                )
                Text(
                    "Requested: ${dateFormatter.format(transfer.requestTimestamp)}",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        },
        trailingContent = {
            Text(
                transfer.status.name,
                style = MaterialTheme.typography.labelSmall,
                color = Color.White,
                modifier = Modifier
                    .background(statusColor(transfer.status), shape = MaterialTheme.shapes.small)
                    .padding(horizontal = 6.dp, vertical = 2.dp)
            )
        },
        modifier = Modifier.clickable(onClick = onClick)
    )
}

fun statusColor(status: TransferStatus): Color {
    return when (status) {
        TransferStatus.PENDING -> Color(0xFFFFA500) // Orange
        TransferStatus.APPROVED -> Color(0xFF4CAF50) // Green
        TransferStatus.REJECTED -> Color(0xFFF44336) // Red
        TransferStatus.CANCELLED -> Color.Gray
        TransferStatus.UNKNOWN -> Color.Magenta
    }
} 