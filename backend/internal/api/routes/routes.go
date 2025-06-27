package routes

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"gorm.io/gorm"
	"github.com/toole-brendan/handreceipt-go/internal/api/handlers"
	"github.com/toole-brendan/handreceipt-go/internal/api/middleware"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services"
	"github.com/toole-brendan/handreceipt-go/internal/services/email"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
	"github.com/toole-brendan/handreceipt-go/internal/services/notification"
	"github.com/toole-brendan/handreceipt-go/internal/services/documents"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
)

// SetupRoutes configures all the API routes for the application
func SetupRoutes(router *gin.Engine, ledgerService ledger.LedgerService, repo repository.Repository, storageService storage.StorageService, nsnService *nsn.NSNService, notificationHub *notification.Hub) {
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

	// Create notification service with database support
	notificationService := notification.NewDBService(notificationHub, repo.DB().(*gorm.DB))

	// Add component service first (needed by transfer handler)
	componentService := services.NewComponentService(repo)

	// Create PDF and email services for DA2062 functionality
	pdfGenerator := documents.NewDA2062Generator(repo)
	emailService := &email.DA2062EmailService{} // TODO: Initialize with proper email service

	// Create handlers
	authHandler := handlers.NewAuthHandler(repo)
	propertyHandler := handlers.NewPropertyHandler(ledgerService, repo)
	transferHandler := handlers.NewTransferHandler(ledgerService, repo, componentService, pdfGenerator, emailService, storageService, notificationService)
	activityHandler := handlers.NewActivityHandler() // No ledger needed
	verificationHandler := handlers.NewVerificationHandler(ledgerService)
	correctionHandler := handlers.NewCorrectionHandler(ledgerService)
	ledgerHandler := handlers.NewLedgerHandler(ledgerService)                     // Create ledger handler
	referenceDBHandler := handlers.NewReferenceDBHandler(repo)                    // Add ReferenceDB handler
	userHandler := handlers.NewUserHandler(repo, storageService, notificationService)  // Added User handler with storage and notification service
	photoHandler := handlers.NewPhotoHandler(storageService, repo, ledgerService) // Add photo handler

	// Create DA2062 handler without OCR service
	da2062Handler := handlers.NewDA2062Handler(ledgerService, repo, pdfGenerator, emailService, storageService)

	// Add component handler
	componentHandler := handlers.NewComponentHandler(componentService, ledgerService)

	// Add document handler for maintenance forms
	documentHandler := handlers.NewDocumentHandler(repo, ledgerService, emailService, storageService)
	
	// Add offline sync handler
	offlineSyncHandler := handlers.NewOfflineSyncHandler(repo.DB().(*gorm.DB))
	
	// Add DA2062 imports handler
	da2062ImportsHandler := handlers.NewDA2062ImportsHandler(repo.DB().(*gorm.DB))
	
	// Add component events handler
	componentEventsHandler := handlers.NewComponentEventsHandler(repo.DB().(*gorm.DB))
	
	// Add attachments handler
	attachmentsHandler := handlers.NewAttachmentsHandler(repo.DB().(*gorm.DB), storageService)

	// Add NSN handler
	logger := logrus.New()
	nsnHandler := handlers.NewNSNHandler(nsnService, logger)
	
	// Add WebSocket handler
	webSocketHandler := handlers.NewWebSocketHandler(notificationHub)
	
	// Add notification handler
	notificationHandler := handlers.NewNotificationHandlers(notificationService)

	// TODO: Update other handlers to use repository when needed

	// Public routes (no authentication required)
	public := router.Group("/api")
	{
		// Authentication
		auth := public.Group("/auth")
		{
			auth.POST("/login", authHandler.Login)
			auth.POST("/register", authHandler.Register)
			auth.POST("/refresh", authHandler.RefreshToken)                                 // Added refresh token route
			auth.POST("/logout", authHandler.Logout)                                        // Added logout route
			auth.GET("/me", middleware.SessionAuthMiddleware(), authHandler.GetCurrentUser) // Use SessionAuthMiddleware
		}
	}

	// Protected routes (authentication required)
	// Use both JWT and session auth for flexibility
	protected := router.Group("/api")
	protected.Use(middleware.SessionAuthMiddleware())
	{
		// WebSocket route
		protected.GET("/ws", webSocketHandler.HandleWebSocket)
		
		// Current user route can now be removed as it's handled above

		// Property routes
		property := protected.Group("/property")
		{
			property.GET("", propertyHandler.GetAllProperties)
			property.POST("", propertyHandler.CreateProperty)
			property.GET("/user/:userId", propertyHandler.GetPropertysByUser)
			property.GET("/check-serial", propertyHandler.CheckSerialExists)
			property.GET("/history/:serialNumber", propertyHandler.GetPropertyHistory)
			property.GET("/serial/:serialNumber", propertyHandler.GetPropertyBySerialNumber)
			property.GET("/serial/:serialNumber/transfers", propertyHandler.GetPropertyTransferHistory)
			// Move specific routes BEFORE wildcard routes to prevent conflicts
			property.GET("/:id", propertyHandler.GetProperty)
			property.PATCH("/:id/status", propertyHandler.UpdatePropertyStatus)
			property.POST("/:id/verify", propertyHandler.VerifyProperty)

			// Component association routes
			property.GET("/:id/components", componentHandler.GetPropertyComponents)
			property.POST("/:id/components", componentHandler.AttachComponent)
			property.DELETE("/:id/components/:componentId", componentHandler.DetachComponent)
			property.GET("/:id/available-components", componentHandler.GetAvailableComponents)
			property.PUT("/:id/components/:componentId/position", componentHandler.UpdateComponentPosition)
		}

		// Transfer routes
		transfer := protected.Group("/transfers")
		{
			transfer.POST("", transferHandler.CreateTransfer)
			transfer.PATCH("/:id/status", transferHandler.UpdateTransferStatus)
			transfer.GET("", transferHandler.GetAllTransfers)
			transfer.GET("/:id", transferHandler.GetTransferByID)
			transfer.GET("/user/:userId", transferHandler.GetTransfersByUser)

			// New routes for serial number and offer functionality
			transfer.POST("/request-by-serial", transferHandler.RequestBySerial)
			transfer.POST("/offer", transferHandler.CreateOffer)
			transfer.GET("/offers/active", transferHandler.ListActiveOffers)
			transfer.POST("/offers/:offerId/accept", transferHandler.AcceptOffer)

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
			users.PATCH("/:id", userHandler.UpdateUserProfile)
			users.POST("/:id/password", userHandler.ChangePassword)
			// POST /api/users from Node is handled by POST /api/auth/register

			// Signature management routes
			users.POST("/signature", userHandler.UploadSignature)
			users.GET("/signature", userHandler.GetSignature)

			// User connections/friends routes
			connections := users.Group("/connections")
			{
				connections.GET("", userHandler.GetConnections)
				connections.GET("/export", userHandler.ExportConnections)
				connections.POST("", userHandler.SendConnectionRequest)
				connections.PATCH("/:connectionId", userHandler.UpdateConnectionStatus)
			}
			users.GET("/search", userHandler.SearchUsers)
		}

		// Photo routes
		photos := protected.Group("/photos")
		{
			photos.POST("/property/:propertyId", photoHandler.UploadPropertyPhoto)
			photos.GET("/property/:propertyId/verify", photoHandler.VerifyPhotoHash)
			photos.DELETE("/property/:propertyId", photoHandler.DeletePropertyPhoto)
		}

		// Document routes for maintenance forms
		documents := protected.Group("/documents")
		{
			documents.GET("", documentHandler.GetDocuments)
			documents.GET("/search", documentHandler.SearchDocuments)
			documents.POST("/bulk", documentHandler.BulkUpdateDocuments)
			documents.POST("/upload", documentHandler.UploadDocument)
			documents.POST("/maintenance-form", documentHandler.CreateMaintenanceForm)
			documents.GET("/:id", documentHandler.GetDocument)
			documents.PATCH("/:id/read", documentHandler.MarkDocumentRead)
			documents.POST("/:id/email", documentHandler.EmailDocument) // Email DA 2062 documents
		}

		// Offline sync routes
		sync := protected.Group("/sync")
		{
			sync.GET("/queue", offlineSyncHandler.GetSyncQueue)
			sync.GET("/queue/:id", offlineSyncHandler.GetSyncEntry)
			sync.POST("/queue", offlineSyncHandler.CreateSyncEntry)
			sync.POST("/process", offlineSyncHandler.ProcessSyncQueue)
			sync.PATCH("/queue/:id", offlineSyncHandler.UpdateSyncEntry)
			sync.DELETE("/queue/:id", offlineSyncHandler.DeleteSyncEntry)
			sync.DELETE("/clear", offlineSyncHandler.ClearSyncQueue)
		}

		// DA2062 imports routes
		da2062Imports := protected.Group("/da2062/imports")
		{
			da2062Imports.GET("", da2062ImportsHandler.GetImports)
			da2062Imports.GET("/:id", da2062ImportsHandler.GetImport)
			da2062Imports.GET("/:id/items", da2062ImportsHandler.GetImportItems)
			da2062Imports.POST("", da2062ImportsHandler.CreateImport)
			da2062Imports.PATCH("/:id", da2062ImportsHandler.UpdateImportStatus)
			da2062Imports.POST("/:id/items", da2062ImportsHandler.AddImportItem)
			da2062Imports.PATCH("/items/:itemId", da2062ImportsHandler.UpdateImportItem)
			da2062Imports.DELETE("/:id", da2062ImportsHandler.DeleteImport)
		}

		// Component events routes
		componentEvents := protected.Group("/components/events")
		{
			componentEvents.GET("", componentEventsHandler.GetComponentEvents)
			componentEvents.GET("/summary", componentEventsHandler.GetComponentEventSummary)
			componentEvents.GET("/export", componentEventsHandler.ExportComponentEvents)
			componentEvents.GET("/:id", componentEventsHandler.GetComponentEvent)
			componentEvents.GET("/property/:propertyId", componentEventsHandler.GetPropertyComponentHistory)
			componentEvents.POST("", componentEventsHandler.CreateComponentEvent)
		}

		// Attachments routes
		attachments := protected.Group("/attachments")
		{
			attachments.GET("", attachmentsHandler.GetAllAttachments)
			attachments.GET("/stats", attachmentsHandler.GetAttachmentStats)
			attachments.GET("/:id", attachmentsHandler.GetAttachment)
			attachments.GET("/:id/download", attachmentsHandler.DownloadAttachment)
			attachments.PATCH("/:id", attachmentsHandler.UpdateAttachment)
			attachments.DELETE("/:id", attachmentsHandler.DeleteAttachment)
			attachments.GET("/property/:propertyId", attachmentsHandler.GetAttachments)
			attachments.POST("/property/:propertyId", attachmentsHandler.UploadAttachment)
		}

		// Notification routes
		notifications := protected.Group("/notifications")
		{
			notifications.GET("", notificationHandler.GetNotifications)
			notifications.GET("/unread-count", notificationHandler.GetUnreadCount)
			notifications.PATCH("/:id/read", notificationHandler.MarkAsRead)
			notifications.POST("/mark-all-read", notificationHandler.MarkAllAsRead)
			notifications.DELETE("/:id", notificationHandler.DeleteNotification)
			notifications.DELETE("/clear-old", notificationHandler.ClearOldNotifications)
		}

		// Register NSN routes
		RegisterNSNRoutes(protected, nsnHandler, middleware.SessionAuthMiddleware())

		// Register DA2062 routes
		da2062Handler.RegisterRoutes(protected)
		
		// Always register AI routes - the handler will show configuration status
		handlers.RegisterAIRoutes(protected)
	}
}
