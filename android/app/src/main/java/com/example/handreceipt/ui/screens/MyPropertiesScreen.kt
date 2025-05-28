package com.example.handreceipt.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.viewmodels.MyPropertiesUiState
import com.example.handreceipt.viewmodels.MyPropertiesViewModel
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterialApi::class) // For PullRefresh
@Composable
fun MyPropertiesScreen(
    modifier: Modifier = Modifier,
    viewModel: MyPropertiesViewModel = hiltViewModel(),
    onItemClick: (propertyId: String) -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val isLoading = uiState is MyPropertiesUiState.Loading

    val pullRefreshState = rememberPullRefreshState(
        refreshing = isLoading,
        onRefresh = viewModel::loadProperties
    )

    Box(modifier = modifier
        .fillMaxSize()
        .pullRefresh(pullRefreshState)
    ) {
        when (val state = uiState) {
            is MyPropertiesUiState.Loading -> {
                 // Only show indicator if not triggered by pull-to-refresh
                 // PullRefreshIndicator is shown separately at the top
                 // Show a centered indicator on initial load
                if (!pullRefreshState.isRefreshing) {
                     CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
            }
            is MyPropertiesUiState.Success -> {
                if (state.items.isEmpty()) {
                    EmptyPropertiesView(onRefresh = viewModel::loadProperties)
                } else {
                    PropertiesList(items = state.items, onItemClick = onItemClick)
                }
            }
            is MyPropertiesUiState.Error -> {
                ErrorPropertiesView(message = state.message, onRetry = viewModel::loadProperties)
            }
        }

        PullRefreshIndicator(
            refreshing = isLoading,
            state = pullRefreshState,
            modifier = Modifier.align(Alignment.TopCenter),
            backgroundColor = MaterialTheme.colorScheme.surfaceVariant, // Optional: Style indicator
            contentColor = MaterialTheme.colorScheme.primary // Optional: Style indicator
        )
    }
}

@Composable
fun PropertiesList(
    items: List<Property>,
    onItemClick: (propertyId: String) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(items, key = { it.id }) { property ->
            PropertyItemCard(property = property, onClick = { onItemClick(property.id) })
        }
    }
}

@Composable
fun PropertyItemCard(
    property: Property,
    onClick: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // TODO: Consider adding an item image/icon based on category?
            Column(modifier = Modifier.weight(1f)) {
                Text(property.itemName, style = MaterialTheme.typography.titleMedium)
                Spacer(modifier = Modifier.height(4.dp))
                Text("SN: ${property.serialNumber}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (property.lastInventoryDate != null) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        "Last Inv: ${formatDate(property.lastInventoryDate)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.secondary
                    )
                }
            }
            // Optional: Add status indicator (e.g., color dot, icon)
            Spacer(modifier = Modifier.width(16.dp))
            Text(property.status, style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
fun EmptyPropertiesView(onRefresh: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("You have no properties assigned.", style = MaterialTheme.typography.headlineSmall)
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = onRefresh) {
            Text("Refresh")
        }
    }
}

@Composable
fun ErrorPropertiesView(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(Icons.Filled.ErrorOutline, contentDescription = null, modifier = Modifier.size(64.dp), tint = MaterialTheme.colorScheme.error)
        Spacer(modifier = Modifier.height(16.dp))
        Text("Error Loading Properties", style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(8.dp))
        Text(message, style = MaterialTheme.typography.bodyMedium, textAlign = TextAlign.Center)
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = onRetry) {
            Text("Retry")
        }
    }
}

// Helper function to format date (adjust format as needed)
private fun formatDate(date: Date): String {
    val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
    return formatter.format(date)
} 