package com.example.handreceipt.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.example.handreceipt.data.model.User
import com.example.handreceipt.viewmodels.UserListState
import com.example.handreceipt.viewmodels.UserSelectionViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserSelectionScreen(
    viewModel: UserSelectionViewModel = hiltViewModel(),
    onUserSelected: (User) -> Unit,
    onDismiss: () -> Unit
) {
    var searchQuery by remember { mutableStateOf("") }
    val userListState by viewModel.userListState

    LaunchedEffect(searchQuery) {
        viewModel.searchUsers(searchQuery)
    }

    // Clear search on dismiss
    DisposableEffect(Unit) {
        onDispose { 
            viewModel.clearSearch()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Select User") },
                navigationIcon = {
                    IconButton(onClick = onDismiss) {
                        Icon(Icons.Default.Close, contentDescription = "Close")
                    }
                }
            )
        }
    ) {
        paddingValues ->
        Column(modifier = Modifier.fillMaxSize().padding(paddingValues).padding(16.dp)) {
            OutlinedTextField(
                value = searchQuery,
                onValueChange = { searchQuery = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Search by username, name, rank...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Search") },
                singleLine = true
            )
            Spacer(modifier = Modifier.height(16.dp))

            Box(modifier = Modifier.weight(1f)) {
                when (userListState) {
                    is UserListState.Idle -> {
                        Text("Enter search query to find users.", modifier = Modifier.align(Alignment.Center))
                    }
                    is UserListState.Loading -> {
                        CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                    }
                    is UserListState.Success -> {
                        val users = (userListState as UserListState.Success).users
                        if (users.isEmpty()) {
                             Text("No users found matching your query.", modifier = Modifier.align(Alignment.Center))
                        } else {
                            LazyColumn(modifier = Modifier.fillMaxSize()) {
                                items(users, key = { it.id }) { user ->
                                    UserListItem(user = user, onUserSelected = onUserSelected)
                                    Divider()
                                }
                            }
                        }
                    }
                    is UserListState.Error -> {
                         Text(
                            "Error: ${(userListState as UserListState.Error).message}",
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.align(Alignment.Center).padding(16.dp)
                         )
                    }
                }
            }
        }
    }
}

@Composable
fun UserListItem(user: User, onUserSelected: (User) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onUserSelected(user) }
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // TODO: Add avatar/icon?
        Column(modifier = Modifier.weight(1f)) {
            Text("${user.rank ?: ""} ${user.lastName ?: ""}, ${user.firstName ?: ""}".trim(), style = MaterialTheme.typography.bodyLarge)
            Text("@${user.username}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        // TODO: Add indicator if user selected?
    }
} 