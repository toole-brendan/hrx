package com.example.handreceipt.ui.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding // Required for padding modifier
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack // Correct import for back icon
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.MoreVert // For potential overflow menu
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue // Import getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel // Import hiltViewModel
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.navigation.navigation // Import navigation for nested graph
import com.example.handreceipt.data.model.ReferenceItem // Needed for detail args
import com.example.handreceipt.data.model.getExampleReferenceItem // For preview/placeholder detail
import com.example.handreceipt.ui.screens.LoginScreen
import com.example.handreceipt.ui.screens.ManualSNEntryScreen
import com.example.handreceipt.ui.screens.ReferenceDatabaseBrowserScreen
import com.example.handreceipt.ui.screens.ReferenceItemDetailScreen
import com.example.handreceipt.ui.screens.MyPropertiesScreen // Updated import
import com.example.handreceipt.ui.screens.PropertyDetailScreen // Import the new screen
import com.example.handreceipt.ui.screens.ScanScreen // Import ScanScreen
import com.example.handreceipt.ui.screens.TransfersScreen // Import TransfersScreen
import com.example.handreceipt.viewmodels.AuthViewModel
import com.example.handreceipt.viewmodels.LoginViewModel // Import LoginViewModel
import com.example.handreceipt.viewmodels.ManualSNViewModel // Import ManualSNViewModel
import com.example.handreceipt.viewmodels.ReferenceDbViewModel // Import ReferenceDbViewModel
import com.example.handreceipt.viewmodels.ReferenceItemDetailViewModel // Import Detail ViewModel
import com.example.handreceipt.viewmodels.MyPropertiesViewModel // Updated import
import com.example.handreceipt.viewmodels.PropertyDetailViewModel // Import ViewModel if needed
import java.util.UUID // If UUID is used for IDs
import androidx.compose.material.icons.filled.Inventory // Example Icon for Properties
import androidx.compose.material.icons.filled.MenuBook // Example Icon for Reference DB
import androidx.compose.material.icons.outlined.Inventory // Example Icon Outline
import androidx.compose.material.icons.outlined.MenuBook // Example Icon Outline
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.compose.material3.NavigationBar // Import Bottom Navigation Bar
import androidx.compose.material3.NavigationBarItem // Import Bottom Navigation Item

// Define navigation routes object (or sealed class)
object Routes {
    const val LOGIN = "login"
    const val LOADING = "loading" // Added loading route
    const val MAIN_APP_GRAPH = "mainAppGraph" // Route for the authenticated part
    const val REF_DB_BROWSER = "refDbBrowser"
    const val MANUAL_SN_ENTRY = "manualSnEntry"
    const val MY_PROPERTIES = "myProperties" // Updated route constant
    const val SCAN_SCREEN = "scanScreen" // Add Scan Screen Destination
    const val TRANSFERS_SCREEN = "transfersScreen" // Add Transfers Screen Destination
    const val TRANSFER_DETAIL_SCREEN = "transferDetail/{transferId}" // Add Detail Destination

    // Nested object for Reference Item Detail route and argument
    object ReferenceItemDetail {
        const val ROUTE_PATTERN = "refItemDetail/{itemId}"
        const val ARG_ITEM_ID = "itemId"

        // Helper function to create the route with the argument value
        fun destination(itemId: String) = "refItemDetail/$itemId"
    }

    // Nested object for Property Detail route (might reuse or differ from Ref Item Detail)
    object PropertyDetail {
        const val ROUTE_PATTERN = "propertyDetail/{propertyId}"
        const val ARG_PROPERTY_ID = "propertyId"
        fun destination(propertyId: String) = "propertyDetail/$propertyId"
    }
}

// Define items for Bottom Navigation
sealed class BottomNavItem(
    val route: String,
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    object MyProperties : BottomNavItem(
        route = Routes.MY_PROPERTIES,
        title = "My Properties",
        selectedIcon = Icons.Filled.Inventory,
        unselectedIcon = Icons.Outlined.Inventory
    )
    object ReferenceDb : BottomNavItem(
        route = Routes.REF_DB_BROWSER,
        title = "Reference DB",
        selectedIcon = Icons.Filled.MenuBook,
        unselectedIcon = Icons.Outlined.MenuBook
    )
    // Add other items like Scan, Transfers, Settings etc. here later
}

@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController()
    // AuthViewModel is now retrieved using hiltViewModel where needed
) {
    // Get AuthViewModel using Hilt
    val authViewModel: AuthViewModel = hiltViewModel()

    // Observe auth state from ViewModel
    val isLoading by authViewModel.isLoading
    val isAuthenticated by authViewModel.isAuthenticated
    val authError by authViewModel.authError

    // Determine the start destination based on auth state
    val startDestination = when {
        isLoading -> Routes.LOADING
        isAuthenticated -> Routes.MAIN_APP_GRAPH
        else -> Routes.LOGIN
    }

    // Effect to react to auth state changes after initial composition
    LaunchedEffect(isAuthenticated, isLoading) {
        if (!isLoading) {
            if (isAuthenticated) {
                 println("AppNavigation: Auth state changed -> Authenticated. Navigating to Main App Graph.")
                 // Ensure we are not already on the main graph to avoid loop
                 if (navController.currentDestination?.route != Routes.REF_DB_BROWSER) {
                    navController.navigate(Routes.MAIN_APP_GRAPH) {
                        popUpTo(navController.graph.startDestinationId) { inclusive = true }
                        launchSingleTop = true
                    }
                }
            } else {
                // If we are anywhere in the main graph and become unauthenticated (e.g., logout), go to Login
                 println("AppNavigation: Auth state changed -> Not Authenticated. Navigating to Login.")
                 if (navController.currentDestination?.parent?.route == Routes.MAIN_APP_GRAPH) {
                    navController.navigate(Routes.LOGIN) {
                        popUpTo(Routes.MAIN_APP_GRAPH) { inclusive = true }
                        launchSingleTop = true
                    }
                 } else if (navController.currentDestination?.route != Routes.LOGIN) {
                     // Handle cases where we might be on loading screen and session check fails
                      navController.navigate(Routes.LOGIN) {
                        popUpTo(navController.graph.startDestinationId) { inclusive = true }
                        launchSingleTop = true
                    }
                 }
            }
        }
    }

    NavHost(navController = navController, startDestination = startDestination) {

        // Loading Screen
        composable(Routes.LOADING) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        }

        // Login Screen
        composable(Routes.LOGIN) {
            val loginViewModel: LoginViewModel = hiltViewModel()
            LoginScreen(
                viewModel = loginViewModel,
                // authViewModel = authViewModel, // AuthViewModel retrieved via hiltViewModel now
                onLoginSuccess = { /* ... Navigation handled by LaunchedEffect ... */ }
            )
        }

        // Main App Navigation Graph (Authenticated Routes)
        navigation(startDestination = Routes.MY_PROPERTIES, route = Routes.MAIN_APP_GRAPH) {

            // My Properties Screen
            composable(Routes.MY_PROPERTIES) {
                val authViewModel: AuthViewModel = hiltViewModel()
                 // Pass content lambda that uses the padding
                MainAppScaffold(navController = navController, authViewModel = authViewModel) { paddingValues ->
                    MyPropertiesScreen(
                         modifier = Modifier.padding(paddingValues), // Apply padding
                        onItemClick = { propertyId ->
                            println("Navigating to Property Detail for ID: $propertyId")
                            navController.navigate(Routes.PropertyDetail.destination(propertyId))
                        }
                    )
                }
            }

            // Reference Database Browser Screen
            composable(Routes.REF_DB_BROWSER) {
                 val authViewModel: AuthViewModel = hiltViewModel()
                 MainAppScaffold(navController = navController, authViewModel = authViewModel) { paddingValues ->
                    ReferenceDatabaseBrowserScreen(
                         modifier = Modifier.padding(paddingValues), // Apply padding
                        onItemSelected = { itemId ->
                            println("Navigating from Ref DB Browser to Detail: $itemId")
                            navController.navigate(Routes.ReferenceItemDetail.destination(itemId))
                        },
                         // Navigation to Manual SN Entry is now handled by toolbar item/sheet inside the screen
                         // onNavigateToManualEntry = { ... } // Remove callback
                    )
                }
            }

            // Manual Serial Number Entry Screen (Now likely presented as a Sheet, maybe remove from NavHost?)
             // If keeping it as a navigable destination:
            composable(Routes.MANUAL_SN_ENTRY) {
                  val authViewModel: AuthViewModel = hiltViewModel()
                  MainAppScaffold(navController = navController, authViewModel = authViewModel) { paddingValues ->
                     ManualSNEntryScreen(
                         modifier = Modifier.padding(paddingValues), // Apply padding
                         onItemConfirmed = { property ->
                             println("Item confirmed in Manual SN Entry: ${property.serialNumber}, navigating back.")
                             navController.popBackStack()
                         },
                         onCancel = { // Add onCancel if presented modally
                            println("Navigating back from Manual SN Entry")
                            navController.popBackStack()
                         }
                         // onNavigateBack = { ... } // Replaced by onCancel or back button
                     )
                 }
            }

            // Reference Item Detail Screen
            composable(
                route = Routes.ReferenceItemDetail.ROUTE_PATTERN,
                arguments = listOf(navArgument(Routes.ReferenceItemDetail.ARG_ITEM_ID) { type = NavType.StringType })
            ) { backStackEntry ->
                 val authViewModel: AuthViewModel = hiltViewModel()
                 MainAppScaffold(navController = navController, authViewModel = authViewModel) { paddingValues ->
                    ReferenceItemDetailScreen(
                         modifier = Modifier.padding(paddingValues), // Apply padding
                         onNavigateBack = {
                            println("Navigating back from Ref Item Detail")
                            navController.popBackStack()
                        }
                    )
                }
            }

             // Property Detail Screen
             composable(
                 route = Routes.PropertyDetail.ROUTE_PATTERN,
                 arguments = listOf(navArgument(Routes.PropertyDetail.ARG_PROPERTY_ID) { type = NavType.StringType })
             ) { backStackEntry ->
                 val authViewModel: AuthViewModel = hiltViewModel()
                 MainAppScaffold(navController = navController, authViewModel = authViewModel) { paddingValues ->
                     PropertyDetailScreen(
                         modifier = Modifier.padding(paddingValues) // Apply padding
                     )
                 }
             }

             // Scan Screen
             composable(Routes.SCAN_SCREEN) {
                 ScanScreen(
                     onNavigateBack = { navController.popBackStack() }
                 )
             }

             // Transfers Screen
             composable(Routes.TRANSFERS_SCREEN) {
                 TransfersScreen(
                     onNavigateBack = { navController.popBackStack() },
                     onSelectTransfer = { transferId ->
                         println("Navigate to Transfer Detail for: $transferId")
                         navController.navigate(Routes.TRANSFER_DETAIL_SCREEN.replace("{transferId}", transferId))
                     }
                 )
             }

             // Transfer Detail Screen
             composable(
                 route = Routes.TRANSFER_DETAIL_SCREEN,
                 arguments = listOf(navArgument("transferId") { type = NavType.StringType })
             ) { backStackEntry ->
                 val transferId = backStackEntry.arguments?.getString("transferId")
                 if (transferId != null) {
                     TransferDetailScreen(
                         transferId = transferId,
                         onNavigateBack = { navController.popBackStack() }
                     )
                 } else {
                     // Handle error: transferId not found (e.g., show error message or navigate back)
                     Text("Error: Transfer ID missing")
                 }
             }
        } // End of Main App Nested Graph
    }
}

// Reusable Scaffold for Authenticated Screens with Bottom Navigation
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainAppScaffold(
    navController: NavHostController,
    authViewModel: AuthViewModel,
    content: @Composable (PaddingValues) -> Unit
) {
    var showMenu by remember { mutableStateOf(false) }

    // List of items for bottom navigation
    val bottomNavItems = listOf(
        BottomNavItem.MyProperties,
        BottomNavItem.ReferenceDb
        // Add other destinations here
    )

    // Observe current navigation destination
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    // Determine the current screen based on route hierarchy
    val currentScreen = bottomNavItems.find { item ->
        currentDestination?.hierarchy?.any { it.route == item.route } == true
    }

    val screenTitle = currentScreen?.title ?: run {
        // Attempt to get title from non-bottom-nav routes if needed
        when (currentDestination?.route) {
            Routes.PropertyDetail.ROUTE_PATTERN -> "Property Detail"
            Routes.ReferenceItemDetail.ROUTE_PATTERN -> "Reference Detail"
            Routes.MANUAL_SN_ENTRY -> "Manual SN Entry"
            Routes.SCAN_SCREEN -> "Scan"
            Routes.TRANSFERS_SCREEN -> "Transfers"
            Routes.TRANSFER_DETAIL_SCREEN -> "Transfer Detail"
            else -> "HandReceipt" // Default fallback
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(screenTitle) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    titleContentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    navigationIconContentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    actionIconContentColor = MaterialTheme.colorScheme.onPrimaryContainer
                ),
                // Show back arrow if not a top-level bottom nav destination
                // and if there's a previous entry in the back stack
                navigationIcon = {
                     val isTopLevel = bottomNavItems.any { it.route == currentDestination?.route }
                     if (!isTopLevel && navController.previousBackStackEntry != null) {
                        IconButton(onClick = { navController.popBackStack() }) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                },
                actions = {
                    // Optional: Add screen-specific actions here if needed

                    // Logout menu
                    IconButton(onClick = { showMenu = !showMenu }) {
                        Icon(Icons.Filled.MoreVert, contentDescription = "More options")
                    }
                    DropdownMenu(
                        expanded = showMenu,
                        onDismissRequest = { showMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("Logout") },
                            onClick = {
                                showMenu = false
                                authViewModel.logout()
                            },
                             leadingIcon = { Icon(Icons.Default.ExitToApp, contentDescription = "Logout") }
                        )
                    }
                }
            )
        },
        bottomBar = {
             // Only show bottom bar for the defined top-level destinations
             val shouldShowBottomBar = bottomNavItems.any { item ->
                 currentDestination?.hierarchy?.any { it.route == item.route } == true
             }
             if (shouldShowBottomBar) {
                NavigationBar {
                    bottomNavItems.forEach { screen ->
                        val isSelected = currentDestination?.hierarchy?.any { it.route == screen.route } == true
                        NavigationBarItem(
                            icon = {
                                Icon(
                                    imageVector = if (isSelected) screen.selectedIcon else screen.unselectedIcon,
                                    contentDescription = screen.title
                                )
                            },
                            label = { Text(screen.title) },
                            selected = isSelected,
                            onClick = {
                                navController.navigate(screen.route) {
                                    // Pop up to the start destination of the graph to avoid building up a large stack
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    // Avoid multiple copies of the same destination when reselecting the same item
                                    launchSingleTop = true
                                    // Restore state when reselecting a previously selected item
                                    restoreState = true
                                }
                            }
                        )
                    }
                }
             }
        }
    ) { innerPadding ->
         content(innerPadding)
    }
} 