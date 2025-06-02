package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/api/handlers"
)

// RegisterNSNRoutes registers NSN-related routes
func RegisterNSNRoutes(router *gin.RouterGroup, handler *handlers.NSNHandler, authMiddleware gin.HandlerFunc) {
	// NSN lookup routes (authenticated users)
	nsnGroup := router.Group("/nsn")
	nsnGroup.Use(authMiddleware)
	{
		// Public endpoints
		nsnGroup.GET("/:nsn", handler.LookupNSN)
		nsnGroup.GET("/search", handler.SearchNSN)
		nsnGroup.GET("/universal-search", handler.UniversalSearch)
		nsnGroup.POST("/bulk", handler.BulkLookup)

		// Statistics (available to all authenticated users)
		nsnGroup.GET("/stats", handler.GetStatistics)
		nsnGroup.GET("/cache/stats", handler.GetCacheStats)

		// Admin operations
		adminGroup := nsnGroup.Group("")
		// TODO: Implement role-based access control middleware
		// adminGroup.Use(middleware.RequireRole("admin", "super_admin"))
		{
			adminGroup.POST("/import", handler.ImportCSV)
			adminGroup.POST("/refresh", handler.RefreshCache)
		}
	}

	// LIN lookup routes
	linGroup := router.Group("/lin")
	linGroup.Use(authMiddleware)
	{
		linGroup.GET("/:lin", handler.LookupLIN)
	}
}
