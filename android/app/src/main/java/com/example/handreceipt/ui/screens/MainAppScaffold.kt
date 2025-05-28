package com.example.handreceipt.ui.screens

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.*
import com.example.handreceipt.ui.navigation.Destinations // Import Destinations
import com.example.handreceipt.viewmodels.AuthViewModel

// Data class for bottom navigation items
data class BottomNavItem(val label: String, val icon: ImageVector, val route: String)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainAppScaffold(
    navController: NavHostController, // Receive NavController
    authViewModel: AuthViewModel = hiltViewModel()
) {
    // State to track the current screen for the title
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    // Define bottom navigation items
    val items = listOf(
        BottomNavItem("Ref DB", Icons.Filled.MenuBook, Destinations.REF_DB_BROWSER),
        BottomNavItem("Properties", Icons.Filled.Inventory, Destinations.MY_PROPERTIES),
        BottomNavItem("Transfers", Icons.AutoMirrored.Filled.CompareArrows, Destinations.TRANSFERS_SCREEN)
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(currentDestination?.route ?: "HandReceipt") }, // Simple title for now
                actions = {
                    IconButton(onClick = { /* TODO: Implement Profile/Settings */ }) {
                        Icon(Icons.Filled.AccountCircle, contentDescription = "Profile")
                    }
                    IconButton(onClick = { authViewModel.logout() }) {
                        Icon(Icons.Filled.Logout, contentDescription = "Logout")
                    }
                }
            )
        },
        bottomBar = {
            NavigationBar {
                items.forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.label) },
                        label = { Text(screen.label) },
                        selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true,
                        onClick = {
                            navController.navigate(screen.route) {
                                // Pop up to the start destination of the graph to
                                // avoid building up a large stack of destinations
                                // on the back stack as users select items
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                // Avoid multiple copies of the same destination when
                                // reselecting the same item
                                launchSingleTop = true
                                // Restore state when reselecting a previously selected item
                                restoreState = true
                            }
                        }
                    )
                }
            }
        },
        floatingActionButton = { // Add FAB for scanning
             FloatingActionButton(onClick = { navController.navigate(Destinations.SCAN_SCREEN) }) {
                 Icon(Icons.Filled.QrCodeScanner, contentDescription = "Scan Item")
             }
        }
    ) { innerPadding ->
        // This is where the content for the selected bottom nav item goes.
        // The actual navigation between screens defined in AppNavigation is handled
        // by the NavHost called within MainActivity or AppNavigation itself.
        // We just provide the scaffold structure here.
        // The NavHost using this scaffold needs to be set up correctly.
        // Example: Put a NavHost inside this content area if this scaffold
        // manages its own nested navigation.
        // For now, we assume the main NavHost is outside this composable.
        Text("Main App Content Area", Modifier.padding(innerPadding)) // Placeholder content

    }
} 