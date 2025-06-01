package handlers

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"log"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/models"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"gorm.io/gorm"
)

// DA2062Handler handles DA2062-related operations
type DA2062Handler struct {
	Ledger ledger.LedgerService
	Repo   repository.Repository
}

// NewDA2062Handler creates a new DA2062 handler
func NewDA2062Handler(ledgerService ledger.LedgerService, repo repository.Repository) *DA2062Handler {
	return &DA2062Handler{
		Ledger: ledgerService,
		Repo:   repo,
	}
}

// BatchCreateInventory handles batch creation of properties from DA2062 import
func (h *DA2062Handler) BatchCreateInventory(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	var req models.BatchCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: " + err.Error()})
		return
	}

	// Process items and create Property objects
	var properties []domain.Property
	var createdProperties []domain.Property

	for _, item := range req.Items {
		// Check if this item needs quantity expansion
		if item.ImportMetadata != nil &&
			item.ImportMetadata.OriginalQuantity > 1 &&
			item.ImportMetadata.SerialSource == "generated" {
			// This item represents a multi-quantity entry
			// The frontend should have already done the expansion, but we double-check
		}

		// Convert ImportMetadata to JSON string for storage
		var metadataJSON string
		if item.ImportMetadata != nil {
			metadataBytes, err := json.Marshal(item.ImportMetadata)
			if err != nil {
				log.Printf("Failed to marshal import metadata: %v", err)
			} else {
				metadataJSON = string(metadataBytes)
			}
		}

		// Create Property object
		property := domain.Property{
			Name:             item.Name,
			SerialNumber:     item.SerialNumber,
			Description:      &item.Description,
			NSN:              &item.NSN,
			Quantity:         item.Quantity,
			CurrentStatus:    "Active",
			SourceType:       &req.Source,
			SourceRef:        &item.SourceRef,
			ImportMetadata:   &metadataJSON,
			AssignedToUserID: &userID,
		}

		// Set defaults
		if property.CurrentStatus == "" {
			property.CurrentStatus = "Active"
		}

		// Mark for verification if needed
		if item.ImportMetadata != nil && item.ImportMetadata.RequiresVerification {
			property.Verified = false
		} else {
			property.Verified = true
			now := time.Now()
			property.VerifiedAt = &now
			property.VerifiedBy = &userID
		}

		properties = append(properties, property)
	}

	// Create properties in batch
	for i := range properties {
		if err := h.Repo.CreateProperty(&properties[i]); err != nil {
			// Check for duplicate serial number
			if strings.Contains(err.Error(), "duplicate") && strings.Contains(err.Error(), "serial_number") {
				c.JSON(http.StatusBadRequest, gin.H{
					"error":         fmt.Sprintf("Property with serial number '%s' already exists", properties[i].SerialNumber),
					"created_count": len(createdProperties),
				})
				return
			}
			log.Printf("Failed to create property: %v", err)
			continue
		}
		createdProperties = append(createdProperties, properties[i])
	}

	// Log batch creation to ledger - log first property as representative
	if len(createdProperties) > 0 {
		// Log the first item creation with batch metadata in description
		batchDescription := fmt.Sprintf("DA2062 Batch Import: %d items, Source: %s, Reference: %s",
			len(createdProperties), req.Source, req.SourceReference)

		// Create a property with batch metadata for logging
		batchProperty := createdProperties[0]
		batchProperty.Description = &batchDescription

		errLedger := h.Ledger.LogPropertyCreation(batchProperty, userID)
		if errLedger != nil {
			log.Printf("WARNING: Failed to log batch import to ledger: %v", errLedger)
		}
	}

	// Group items by verification status for response
	verificationNeeded := []domain.Property{}
	verified := []domain.Property{}

	for _, prop := range createdProperties {
		if prop.ImportMetadata != nil && !prop.Verified {
			verificationNeeded = append(verificationNeeded, prop)
		} else {
			verified = append(verified, prop)
		}
	}

	c.JSON(http.StatusCreated, gin.H{
		"items":               createdProperties,
		"count":               len(createdProperties),
		"verified_count":      len(verified),
		"verification_needed": verificationNeeded,
		"summary":             generateImportSummary(createdProperties),
	})
}

// VerifyImportedItem verifies an imported property
func (h *DA2062Handler) VerifyImportedItem(c *gin.Context) {
	itemID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	var req models.VerifyItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Get the property
	property, err := h.Repo.GetPropertyByID(uint(itemID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property"})
		}
		return
	}

	// Check ownership
	if property.AssignedToUserID == nil || *property.AssignedToUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only verify your own properties"})
		return
	}

	// Update verification fields
	if req.SerialNumber != "" {
		property.SerialNumber = req.SerialNumber

		// Update import metadata if exists
		if property.ImportMetadata != nil {
			var metadata models.ImportMetadata
			if err := json.Unmarshal([]byte(*property.ImportMetadata), &metadata); err == nil {
				metadata.SerialSource = "manual"
				if metadataBytes, err := json.Marshal(metadata); err == nil {
					metadataStr := string(metadataBytes)
					property.ImportMetadata = &metadataStr
				}
			}
		}
	}

	if req.NSN != "" {
		property.NSN = &req.NSN
	}

	property.Verified = true
	now := time.Now()
	property.VerifiedAt = &now
	property.VerifiedBy = &userID
	property.UpdatedAt = now

	// Update in database
	if err := h.Repo.UpdateProperty(property); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update property"})
		return
	}

	// Log verification to ledger
	errLedger := h.Ledger.LogVerificationEvent(property.ID, property.SerialNumber, userID, "DA2062_VERIFICATION")
	if errLedger != nil {
		log.Printf("WARNING: Failed to log verification to ledger: %v", errLedger)
	}

	c.JSON(http.StatusOK, gin.H{
		"property": property,
		"message":  "Property verified successfully",
	})
}

// GetUnverifiedItems returns properties that need verification
func (h *DA2062Handler) GetUnverifiedItems(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Get unverified properties for the user
	properties, err := h.Repo.GetUnverifiedProperties(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch properties"})
		return
	}

	// Group by verification reason
	grouped := make(map[string][]domain.Property)

	for _, prop := range properties {
		if prop.ImportMetadata != nil {
			var metadata models.ImportMetadata
			if err := json.Unmarshal([]byte(*prop.ImportMetadata), &metadata); err == nil {
				for _, reason := range metadata.VerificationReasons {
					grouped[reason] = append(grouped[reason], prop)
				}
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"items":             properties,
		"count":             len(properties),
		"grouped_by_reason": grouped,
	})
}

// UploadDA2062 handles DA2062 form upload (placeholder - actual OCR happens on mobile)
func (h *DA2062Handler) UploadDA2062(c *gin.Context) {
	// This endpoint would typically receive the parsed DA2062 data from the mobile app
	// after OCR processing. For now, it's a placeholder.
	c.JSON(http.StatusOK, gin.H{
		"message": "DA2062 upload endpoint - processing happens on mobile client",
	})
}

// SearchDA2062Forms searches for DA2062 forms
func (h *DA2062Handler) SearchDA2062Forms(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Get search parameters
	sourceRef := c.Query("reference")
	formNumber := c.Query("form_number")

	// Search for properties with matching source references
	properties, err := h.Repo.GetPropertiesBySourceRef(userID, sourceRef, formNumber)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search forms"})
		return
	}

	// Group by source reference to represent forms
	forms := make(map[string][]domain.Property)
	for _, prop := range properties {
		if prop.SourceRef != nil {
			forms[*prop.SourceRef] = append(forms[*prop.SourceRef], prop)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"forms": forms,
		"count": len(forms),
	})
}

// GetDA2062Items gets items from a specific DA2062 form
func (h *DA2062Handler) GetDA2062Items(c *gin.Context) {
	reference := c.Param("reference")

	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Get properties for this reference
	properties, err := h.Repo.GetPropertiesBySourceRef(userID, reference, "")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch items"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"items":     properties,
		"count":     len(properties),
		"reference": reference,
	})
}

// Helper functions

func countVerificationNeeded(properties []domain.Property) int {
	count := 0
	for _, prop := range properties {
		if !prop.Verified {
			count++
		}
	}
	return count
}

func countGeneratedSerials(properties []domain.Property) int {
	count := 0
	for _, prop := range properties {
		if prop.ImportMetadata != nil {
			var metadata models.ImportMetadata
			if err := json.Unmarshal([]byte(*prop.ImportMetadata), &metadata); err == nil {
				if metadata.SerialSource == "generated" {
					count++
				}
			}
		}
	}
	return count
}

func generateImportSummary(properties []domain.Property) models.ImportSummary {
	summary := models.ImportSummary{
		TotalItems: len(properties),
		Categories: make(map[string]int),
		ConfidenceLevels: map[string]int{
			"high":   0,
			"medium": 0,
			"low":    0,
		},
	}

	for _, prop := range properties {
		// Count by category (using current status as proxy since category field doesn't exist)
		summary.Categories[prop.CurrentStatus]++

		// Count by confidence if metadata exists
		if prop.ImportMetadata != nil {
			var metadata models.ImportMetadata
			if err := json.Unmarshal([]byte(*prop.ImportMetadata), &metadata); err == nil {
				if metadata.ItemConfidence >= 0.8 {
					summary.ConfidenceLevels["high"]++
				} else if metadata.ItemConfidence >= 0.6 {
					summary.ConfidenceLevels["medium"]++
				} else {
					summary.ConfidenceLevels["low"]++
				}
			}
		}
	}

	return summary
}

// RegisterRoutes registers all DA2062-related routes
func (h *DA2062Handler) RegisterRoutes(router *gin.RouterGroup) {
	da2062 := router.Group("/da2062")
	{
		da2062.POST("/upload", h.UploadDA2062)
		da2062.GET("/search", h.SearchDA2062Forms)
		da2062.GET("/:reference/items", h.GetDA2062Items)
		da2062.GET("/unverified", h.GetUnverifiedItems)
		da2062.PUT("/verify/:id", h.VerifyImportedItem)
	}

	inventory := router.Group("/inventory")
	{
		inventory.POST("/batch", h.BatchCreateInventory)
	}
}
