package com.example.handreceipt.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.handreceipt.data.model.Property
import com.example.handreceipt.data.model.User
import com.example.handreceipt.viewmodels.ManualSNViewModel
import com.example.handreceipt.viewmodels.PropertyLookupUiState
import com.example.handreceipt.viewmodels.TransferUiState
import com.example.handreceipt.viewmodels.UserSearchUiState
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ManualSNEntryScreen(
    viewModel: ManualSNViewModel = viewModel(),
    onNavigateBack: () -> Unit
) {
    val serialNumberInput by viewModel.serialNumberInput.collectAsStateWithLifecycle()
    val lookupState by viewModel.lookupUiState.collectAsStateWithLifecycle()
    val transferState by viewModel.transferUiState.collectAsStateWithLifecycle()
    val recipientQuery by viewModel.recipientSearchQuery.collectAsStateWithLifecycle()
    val userSearchState by viewModel.userSearchUiState.collectAsStateWithLifecycle()
    val selectedRecipient by viewModel.selectedRecipient.collectAsStateWithLifecycle()

    val focusManager = LocalFocusManager.current
    var showConfirmDialog by remember { mutableStateOf(false) }
    var propertyToTransfer by remember { mutableStateOf<Property?>(null) }

    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(transferState) {
        when (transferState) {
            is TransferUiState.Success -> {
                snackbarHostState.showSnackbar(
                    message = "Transfer requested successfully!",
                    duration = SnackbarDuration.Short
                )
                viewModel.clearAndReset()
                propertyToTransfer = null
            }
            is TransferUiState.Error -> {
                snackbarHostState.showSnackbar(
                    message = "Transfer failed: ${(transferState as TransferUiState.Error).message}",
                    duration = SnackbarDuration.Long,
                    actionLabel = "Dismiss"
                )
            }
            else -> {}
        }
    }

    LaunchedEffect(lookupState) {
        if (lookupState is PropertyLookupUiState.Success) {
            propertyToTransfer = (lookupState as PropertyLookupUiState.Success).property
        } else {
            propertyToTransfer = null
        }
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = { Text("Initiate Transfer") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .padding(paddingValues)
                .padding(16.dp)
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {

            OutlinedTextField(
                value = serialNumberInput,
                onValueChange = { viewModel.onSerialNumberChange(it) },
                label = { Text("Enter Serial Number of Item to Transfer") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    imeAction = ImeAction.Search
                ),
                keyboardActions = KeyboardActions(
                    onSearch = { focusManager.clearFocus() }
                ),
                trailingIcon = {
                    if (serialNumberInput.isNotEmpty()) {
                        IconButton(onClick = { viewModel.clearAndReset() }) {
                            Icon(Icons.Default.Clear, contentDescription = "Clear Text")
                        }
                    }
                },
                isError = lookupState is PropertyLookupUiState.NotFound || lookupState is PropertyLookupUiState.Error,
                readOnly = transferState is TransferUiState.Loading
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .defaultMinSize(minHeight = 150.dp)
                    .padding(top = 8.dp),
                contentAlignment = Alignment.Center
            ) {
                when (val state = lookupState) {
                    is PropertyLookupUiState.Idle -> {
                        Text(
                            text = "Enter a serial number to find the item.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = Color.Gray,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(16.dp)
                        )
                    }
                    is PropertyLookupUiState.Loading -> {
                        CircularProgressIndicator()
                    }
                    is PropertyLookupUiState.Success -> {
                        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            PropertyFoundCard(
                                property = state.property,
                            )

                            RecipientSearchField(
                                query = recipientQuery,
                                onQueryChange = viewModel::onRecipientQueryChange,
                                searchState = userSearchState,
                                selectedRecipient = selectedRecipient,
                                onRecipientSelected = viewModel::onRecipientSelected,
                                enabled = transferState !is TransferUiState.Loading
                            )

                            Box(contentAlignment = Alignment.Center) {
                                Button(
                                    onClick = {
                                        if (selectedRecipient != null && propertyToTransfer != null) {
                                            showConfirmDialog = true
                                        } else {
                                            println("Error: Transfer button clicked without selected recipient or property.")
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth(),
                                    enabled = selectedRecipient != null && transferState !is TransferUiState.Loading
                                ) {
                                    Text("Initiate Transfer Request")
                                }
                                if (transferState is TransferUiState.Loading) {
                                    CircularProgressIndicator(modifier = Modifier.size(32.dp))
                                }
                            }
                        }
                    }
                    is PropertyLookupUiState.NotFound -> {
                        ErrorStateView(message = "Serial number '$serialNumberInput' not found.", isWarning = true)
                    }
                    is PropertyLookupUiState.Error -> {
                        ErrorStateView(
                            message = "Lookup failed: ${state.message}",
                            onRetry = {
                                viewModel.onSerialNumberChange(serialNumberInput)
                                focusManager.clearFocus()
                            }
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.weight(1f))
        }
    }

    if (showConfirmDialog) {
        propertyToTransfer?.let { property ->
            AlertDialog(
                onDismissRequest = { showConfirmDialog = false },
                title = { Text("Confirm Transfer Request") },
                text = {
                    Text("Request transfer of " +
                         "\"${property.itemName}\" (SN: ${property.serialNumber}) " +
                         "to user: ${selectedRecipient?.username ?: "Unknown"}?")
                },
                confirmButton = {
                    Button(
                        onClick = {
                            viewModel.initiateTransfer(property)
                            showConfirmDialog = false
                            focusManager.clearFocus()
                        },
                        enabled = propertyToTransfer != null && selectedRecipient != null
                    ) { Text("Confirm Request") }
                },
                dismissButton = {
                    Button(onClick = { showConfirmDialog = false }) { Text("Cancel") }
                }
            )
        }
    }
}

@Composable
fun PropertyFoundCard(
    property: Property,
    modifier: Modifier = Modifier
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Item to Transfer", style = MaterialTheme.typography.titleMedium)
            Divider()

            PropertyDetailRow(label = "Name:", value = property.itemName)
            PropertyDetailRow(label = "Serial #:", value = property.serialNumber)
            PropertyDetailRow(label = "NSN:", value = property.nsn)
            PropertyDetailRow(label = "Status:", value = property.status)
            PropertyDetailRow(label = "Location:", value = property.location ?: "N/A")

            property.notes?.takeIf { it.isNotBlank() }?.let {
                PropertyDetailRow(label = "Notes:", value = it)
            }
            
            val assignedText = property.assignedToUserId?.toString()?.let { "User ID: $it" } ?: "Unassigned"
            PropertyDetailRow(label = "Assigned:", value = assignedText)

            val dateFormatter = remember { SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()) }
            property.lastInventoryDate?.let {
                 PropertyDetailRow(label = "Last Inv:", value = dateFormatter.format(it))
            }
             property.acquisitionDate?.let {
                 PropertyDetailRow(label = "Acquired:", value = dateFormatter.format(it))
            }
        }
    }
}

@Composable
fun PropertyDetailRow(label: String, value: String) {
     Row(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
            modifier = Modifier.width(100.dp)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

@Composable
fun ErrorStateView(
    message: String,
    isWarning: Boolean = false,
    onRetry: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.Warning,
            contentDescription = if (isWarning) "Warning" else "Error",
            tint = if (isWarning) Color(0xFFFFA726) else MaterialTheme.colorScheme.error,
            modifier = Modifier.size(48.dp)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = message,
            color = if (isWarning) Color.Black else MaterialTheme.colorScheme.error,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.bodyLarge
        )
        onRetry?.let {
             Spacer(modifier = Modifier.height(16.dp))
            Button(onClick = it) {
                Text("Retry")
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecipientSearchField(
    query: String,
    onQueryChange: (String) -> Unit,
    searchState: UserSearchUiState,
    selectedRecipient: User?,
    onRecipientSelected: (User) -> Unit,
    enabled: Boolean,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }
    val showDropdown = searchState is UserSearchUiState.Loading ||
                       (searchState is UserSearchUiState.Success && searchState.users.isNotEmpty())

    LaunchedEffect(searchState, enabled) {
        if (!enabled || searchState is UserSearchUiState.Idle ||
            searchState is UserSearchUiState.NoResults ||
            searchState is UserSearchUiState.Error) {
            expanded = false
        }
    }

    ExposedDropdownMenuBox(
        expanded = expanded && showDropdown && enabled,
        onExpandedChange = {
            if(enabled && (query.isNotBlank() || showDropdown)) {
                 expanded = !expanded
             }
        },
        modifier = modifier
    ) {
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChange,
            modifier = Modifier
                .menuAnchor()
                .fillMaxWidth(),
            label = { Text("Search Recipient Username") },
            trailingIcon = {
                 Row(verticalAlignment = Alignment.CenterVertically) {
                     if (searchState is UserSearchUiState.Loading) {
                         CircularProgressIndicator(Modifier.size(24.dp).padding(end = 8.dp))
                     }
                     ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded && showDropdown && enabled)
                 }
            },
            singleLine = true,
            readOnly = !enabled,
            isError = searchState is UserSearchUiState.Error,
            supportingText = {
                 when (searchState) {
                     is UserSearchUiState.Error -> Text(searchState.message, color = MaterialTheme.colorScheme.error)
                     is UserSearchUiState.NoResults -> Text("No users found matching '$query'")
                     else -> { /* Idle, Loading, Success - no supporting text needed */ }
                 }
             },
             keyboardActions = KeyboardActions(onDone = { expanded = false })
        )

        ExposedDropdownMenu(
            expanded = expanded && showDropdown && enabled,
            onDismissRequest = { expanded = false }
        ) {
            when (searchState) {
                is UserSearchUiState.Success -> {
                    searchState.users.forEach { user ->
                        DropdownMenuItem(
                            text = { Text(user.username) },
                            onClick = {
                                onRecipientSelected(user)
                            },
                             modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
                is UserSearchUiState.Loading -> {
                    DropdownMenuItem(
                        text = { Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()){ Text("Searching...") } },
                        onClick = {},
                        enabled = false
                    )
                }
                else -> {
                 }
            }
        }
    }
}

// --- Previews ---
// Previews would need significant updates to reflect the new states and interactions
// Consider mocking the ViewModel states for previewing different scenarios. 