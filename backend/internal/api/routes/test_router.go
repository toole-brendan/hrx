package routes

import (
	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
)

// SetupRouter creates a test router with minimal setup
// In a real implementation, this would set up all your routes
func SetupRouter(repo interface{}, ledgerService ledger.LedgerService, cfg *config.Config) *gin.Engine {
	router := gin.New()

	// Add test middleware
	router.Use(gin.Recovery())

	// Create API group
	api := router.Group("/api")

	// Add test routes
	api.POST("/auth/login", func(c *gin.Context) {
		// Mock login endpoint
		c.JSON(200, gin.H{
			"user": gin.H{
				"id":       1,
				"username": "testuser1",
			},
		})
		c.SetCookie("session", "test-session-token", 3600, "/", "", false, true)
	})

	api.POST("/inventory", func(c *gin.Context) {
		// Mock create inventory endpoint
		var input map[string]interface{}
		c.BindJSON(&input)

		c.Header("X-Ledger-TX-ID", "mock-tx-12345")
		c.JSON(201, gin.H{
			"id":             1,
			"name":           input["name"],
			"serial_number":  input["serial_number"],
			"current_status": input["current_status"],
		})
	})

	api.POST("/transfers", func(c *gin.Context) {
		// Mock create transfer endpoint
		c.JSON(200, gin.H{
			"id":     1,
			"status": "pending",
		})
	})

	api.PATCH("/transfers/:id/status", func(c *gin.Context) {
		// Mock approve/reject transfer endpoint
		var input map[string]interface{}
		c.BindJSON(&input)

		c.JSON(200, gin.H{
			"id":     1,
			"status": input["status"],
		})
	})

	api.GET("/inventory/:id", func(c *gin.Context) {
		// Mock get inventory item endpoint
		c.JSON(200, gin.H{
			"item": gin.H{
				"id":                  1,
				"assigned_to_user_id": 2, // Simulating ownership transfer
			},
		})
	})

	api.GET("/inventory/history/:serial", func(c *gin.Context) {
		// Mock get history endpoint
		c.JSON(200, gin.H{
			"history": []gin.H{
				{
					"event_type": "ITEM_CREATE",
					"timestamp":  "2024-01-01T00:00:00Z",
					"verified":   true,
				},
				{
					"event_type": "TRANSFER_ACCEPT",
					"timestamp":  "2024-01-02T00:00:00Z",
					"verified":   true,
				},
			},
		})
	})

	return router
}
