package routes

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"github.com/toole-brendan/handreceipt-go/internal/api/handlers"
	"github.com/toole-brendan/handreceipt-go/internal/api/middleware"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
)

// SetupRoutes configures all the API routes for the application
func SetupRoutes(router *gin.Engine, ledgerService ledger.LedgerService, repo repository.Repository, storageService *storage.MinIOService, nsnService *nsn.NSNService) {
	// Health check endpoint (no authentication required)
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "handreceipt-api",
			"version": "1.0.0",
		})
	})

	// Initialize session middleware
	middleware.SetupSession(router)

	// Create handlers
	authHandler := handlers.NewAuthHandler(repo)
	inventoryHandler := handlers.NewInventoryHandler(ledgerService, repo)
	transferHandler := handlers.NewTransferHandler(ledgerService, repo)
	activityHandler := handlers.NewActivityHandler() // No ledger needed
	verificationHandler := handlers.NewVerificationHandler(ledgerService)
	correctionHandler := handlers.NewCorrectionHandler(ledgerService)
	ledgerHandler := handlers.NewLedgerHandler(ledgerService)                     // Create ledger handler
	referenceDBHandler := handlers.NewReferenceDBHandler(repo)                    // Add ReferenceDB handler
	userHandler := handlers.NewUserHandler(repo)                                  // Added User handler
	photoHandler := handlers.NewPhotoHandler(storageService, repo, ledgerService) // Add photo handler

	// Add NSN handler
	logger := logrus.New()
	nsnHandler := handlers.NewNSNHandler(nsnService, logger)
	// ... more handlers will be added in the future

	// TODO: Update other handlers to use repository when needed

	// Public routes (no authentication required)
	public := router.Group("/api")
	{
		// Authentication
		auth := public.Group("/auth")
		{
			auth.POST("/login", authHandler.Login)
			auth.POST("/register", authHandler.Register)
			auth.POST("/logout", authHandler.Logout)                                        // Added logout route
			auth.GET("/me", middleware.SessionAuthMiddleware(), authHandler.GetCurrentUser) // Use SessionAuthMiddleware
		}
	}

	// Protected routes (authentication required)
	// Use both JWT and session auth for flexibility
	protected := router.Group("/api")
	protected.Use(middleware.SessionAuthMiddleware())
	{
		// Current user route can now be removed as it's handled above

		// Inventory routes
		inventory := protected.Group("/inventory")
		{
			inventory.GET("", inventoryHandler.GetAllInventoryItems)
			inventory.POST("", inventoryHandler.CreateInventoryItem)
			inventory.GET("/user/:userId", inventoryHandler.GetInventoryItemsByUser)
			inventory.GET("/history/:serialNumber", inventoryHandler.GetInventoryItemHistory)
			inventory.GET("/serial/:serialNumber", inventoryHandler.GetPropertyBySerialNumber)
			inventory.POST("/qrcode/:propertyId", inventoryHandler.GeneratePropertyQRCode) // Moved QR code generation before wildcard routes
			inventory.GET("/:id", inventoryHandler.GetInventoryItem)
			inventory.PATCH("/:id/status", inventoryHandler.UpdateInventoryItemStatus)
			inventory.POST("/:id/verify", inventoryHandler.VerifyInventoryItem)
		}

		// Transfer routes
		transfer := protected.Group("/transfers")
		{
			transfer.POST("", transferHandler.CreateTransfer)
			transfer.PATCH("/:id/status", transferHandler.UpdateTransferStatus)
			transfer.GET("", transferHandler.GetAllTransfers)
			transfer.GET("/:id", transferHandler.GetTransferByID)
			transfer.GET("/user/:userId", transferHandler.GetTransfersByUser)
			transfer.POST("/qr-initiate", transferHandler.InitiateTransferByQR) // New QR-based transfer endpoint
		}

		// Activity routes
		activity := protected.Group("/activities")
		{
			activity.POST("", activityHandler.CreateActivity)
			activity.GET("", activityHandler.GetAllActivities)
			activity.GET("/user/:userId", activityHandler.GetActivitiesByUserId)
		}

		// Verification routes (for checking ledger status/integrity)
		verification := protected.Group("/verification")
		{
			verification.GET("/database", verificationHandler.VerifyDatabaseLedger)
			// TODO: Add route for full cryptographic document verification
		}

		// Correction routes
		correction := protected.Group("/corrections")
		{
			correction.POST("", correctionHandler.CreateCorrection)
			correction.GET("", correctionHandler.GetAllCorrections)
			correction.GET("/:event_id", correctionHandler.GetCorrectionEventByID)
			correction.GET("/original/:original_event_id", correctionHandler.GetCorrectionsByOriginalID)
			// TODO: Add routes for querying/viewing correction events?
		}

		// Ledger routes (Consolidated general ledger access)
		ledgerRoutes := protected.Group("/ledger") // New group for general ledger
		{
			ledgerRoutes.GET("/history", ledgerHandler.GetLedgerHistoryHandler) // New route
			// TODO: Add route for item-specific history (/ledger/item/:itemId/history) ?
		}

		// Reference Database routes
		reference := protected.Group("/reference")
		{
			reference.GET("/types", referenceDBHandler.ListPropertyTypes)
			reference.GET("/models", referenceDBHandler.ListPropertyModels)
			reference.GET("/models/nsn/:nsn", referenceDBHandler.GetPropertyModelByNSN)
		}

		// User management routes
		users := protected.Group("/users")
		{
			users.GET("", userHandler.GetAllUsers)
			users.GET("/:id", userHandler.GetUserByID)
			// POST /api/users from Node is handled by POST /api/auth/register
		}

		// Photo routes
		photos := protected.Group("/photos")
		{
			photos.POST("/property/:propertyId", photoHandler.UploadPropertyPhoto)
			photos.GET("/property/:propertyId/verify", photoHandler.VerifyPhotoHash)
			photos.DELETE("/property/:propertyId", photoHandler.DeletePropertyPhoto)
		}

		// Register NSN routes
		RegisterNSNRoutes(protected, nsnHandler, middleware.SessionAuthMiddleware())
	}
}
