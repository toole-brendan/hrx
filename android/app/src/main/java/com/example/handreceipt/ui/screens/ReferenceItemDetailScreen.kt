package com.example.handreceipt.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue // Import getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.example.handreceipt.R // Assuming you have placeholder drawable
import com.example.handreceipt.data.model.ReferenceItem
import com.example.handreceipt.viewmodels.ReferenceItemDetailViewModel // Import ViewModel

@Composable
fun ReferenceItemDetailScreen(
    // Remove direct item parameter, accept ViewModel instead
    // item: ReferenceItem,
    viewModel: ReferenceItemDetailViewModel, // Inject the ViewModel
    onNavigateBack: () -> Unit // Keep navigation callback
) {
    val isLoading by viewModel.isLoading
    val item by viewModel.item
    val error by viewModel.error

    Box(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        when {
            isLoading -> {
                // Show loading indicator
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
            }
            error != null -> {
                // Show error message
                Text(
                    text = "Error: $error",
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.align(Alignment.Center)
                )
            }
            item != null -> {
                // Show item details when loaded successfully
                ItemDetailsContent(item = item!!)
            }
            else -> {
                 // Optional: Handle the case where item is null and no error/loading
                 // This shouldn't happen with the current ViewModel logic but good for robustness
                 Text("No item data available.", modifier = Modifier.align(Alignment.Center))
            }
        }
    }
    // Note: Back navigation is typically handled by the Scaffold/TopAppBar now
}

// Extracted composable for displaying the actual item details
@Composable
private fun ItemDetailsContent(item: ReferenceItem) {
    Column(modifier = Modifier.fillMaxWidth()) {
        // Image (using Coil)
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(item.imageUrl)
                .crossfade(true)
                 // Add placeholder and error drawables (create these in res/drawable)
                 .placeholder(R.drawable.ic_placeholder) // Example placeholder
                 .error(R.drawable.ic_broken_image) // Example error image
                .build(),
            contentDescription = "Image of ${item.itemName}",
            modifier = Modifier
                .fillMaxWidth()
                .height(200.dp)
                 .padding(bottom = 16.dp),
            contentScale = ContentScale.Fit
        )

        // Item Name
        Text(
            text = item.itemName ?: "Unnamed Item",
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.padding(bottom = 8.dp)
        )

        // NSN
        Text(
            text = "NSN: ${item.nsn}",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(bottom = 4.dp)
        )

        // Manufacturer
        item.manufacturer?.let {
            Text(
                text = "Manufacturer: $it",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.padding(bottom = 12.dp)
            )
        }

        // Description
        item.description?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyLarge
            )
        }
    }
} 