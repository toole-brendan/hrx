package handlers

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"log"

	"github.com/gin-gonic/gin"
	"github.com/skip2/go-qrcode"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"gorm.io/gorm"
)

// InventoryHandler handles inventory operations
type InventoryHandler struct {
	Ledger ledger.LedgerService
	Repo   repository.Repository
}

// NewInventoryHandler creates a new inventory handler
func NewInventoryHandler(ledgerService ledger.LedgerService, repo repository.Repository) *InventoryHandler {
	return &InventoryHandler{Ledger: ledgerService, Repo: repo}
}

// GetAllInventoryItems returns all inventory items
func (h *InventoryHandler) GetAllInventoryItems(c *gin.Context) {
	// Check if filtering by assigned user ID
	var userID *uint
	userIDStr := c.Query("assignedToUserId")
	if userIDStr != "" {
		uID, err := strconv.ParseUint(userIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid assignedToUserId format"})
			return
		}
		tempID := uint(uID)
		userID = &tempID
	}

	items, err := h.Repo.ListProperties(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory items"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"items": items})
}

// GetInventoryItem returns a specific inventory item
func (h *InventoryHandler) GetInventoryItem(c *gin.Context) {
	// Parse ID from URL parameter
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	// Fetch item from repository
	item, err := h.Repo.GetPropertyByID(uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory item"})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"item": item})
}

// CreateInventoryItem creates a new inventory item
func (h *InventoryHandler) CreateInventoryItem(c *gin.Context) {
	var input domain.CreatePropertyInput

	// Validate request body
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input format: " + err.Error()})
		return
	}

	// Get user ID from context (set by auth middleware)
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Check for duplicate serial number
	existingItem, err := h.Repo.GetPropertyBySerialNumber(input.SerialNumber)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check for existing serial number"})
		return
	}
	if existingItem != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("A digital twin with serial number '%s' already exists", input.SerialNumber)})
		return
	}

	// Prepare the inventory item for database insertion
	item := &domain.Property{ // Changed to pointer
		Name:             input.Name,
		SerialNumber:     input.SerialNumber,
		Description:      input.Description,
		CurrentStatus:    input.CurrentStatus,
		PropertyModelID:  input.PropertyModelID,
		AssignedToUserID: input.AssignedToUserID,
	}

	// Insert into database using repository
	if err := h.Repo.CreateProperty(item); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create inventory item: " + err.Error()})
		return
	}

	// Log to Ledger Service (use the item *after* creation to ensure ID is populated)
	errLedger := h.Ledger.LogItemCreation(*item, userID)
	if errLedger != nil {
		// Log the error but don't fail the primary operation
		log.Printf("WARNING: Failed to log item creation (ID: %d, SN: %s) to Ledger: %v", item.ID, item.SerialNumber, errLedger)
	}

	c.JSON(http.StatusCreated, item)
}

// UpdateInventoryItemStatus updates the status of an inventory item
func (h *InventoryHandler) UpdateInventoryItemStatus(c *gin.Context) {
	// Parse ID from URL parameter
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	// Parse status from request body
	var updateData struct {
		Status string `json:"status" binding:"required"`
	}

	if err := c.ShouldBindJSON(&updateData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input format"})
		return
	}

	// Fetch item from repository
	item, err := h.Repo.GetPropertyByID(uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory item"})
		}
		return
	}

	// Store old status for logging
	oldStatus := item.CurrentStatus

	// Update status
	item.CurrentStatus = updateData.Status
	if err := h.Repo.UpdateProperty(item); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update inventory item status"})
		return
	}

	// Get user ID from context
	userIDVal, exists := c.Get("userID")
	if exists {
		userID, ok := userIDVal.(uint)
		if ok {
			// Log to Ledger Service
			errLedger := h.Ledger.LogStatusChange(item.ID, item.SerialNumber, oldStatus, updateData.Status, userID)
			if errLedger != nil {
				// Log error but don't fail the request
				log.Printf("WARNING: Failed to log status change (ItemID: %d, SN: %s) to Ledger: %v", item.ID, item.SerialNumber, errLedger)
				c.Writer.Write([]byte("\nWarning: Failed to log status update to immutable ledger")) // Optionally notify client
			}
		} else {
			log.Printf("WARNING: Could not assert userID to uint for ledger logging in UpdateInventoryItemStatus")
		}
	} else {
		log.Printf("WARNING: UserID not found in context for ledger logging in UpdateInventoryItemStatus")
	}

	c.JSON(http.StatusOK, gin.H{"item": item})
}

// GetInventoryItemsByUser returns inventory items assigned to a specific user
func (h *InventoryHandler) GetInventoryItemsByUser(c *gin.Context) {
	// Parse user ID from URL parameter
	userID, err := strconv.ParseUint(c.Param("userId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Fetch items using repository
	userIDUint := uint(userID)
	items, err := h.Repo.ListProperties(&userIDUint)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory items"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"items": items})
}

// GetInventoryItemHistory returns the history of an inventory item from the Ledger
func (h *InventoryHandler) GetInventoryItemHistory(c *gin.Context) {
	// Parse serial number from URL parameter
	serialNumber := c.Param("serialNumber")
	if serialNumber == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Serial number parameter is required"})
		return
	}

	// Fetch the item by serial number to get its ID
	item, err := h.Repo.GetPropertyBySerialNumber(serialNumber)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found for serial number: " + serialNumber})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch item by serial number: " + err.Error()})
		}
		return
	}

	// Get item history from Ledger Service using ItemID
	history, err := h.Ledger.GetItemHistory(item.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch item history from ledger: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"history": history})
}

// VerifyInventoryItem logs a verification event for an inventory item
func (h *InventoryHandler) VerifyInventoryItem(c *gin.Context) {
	// Parse ID from URL parameter
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	// Parse verification details from request body
	var verificationInput struct {
		VerificationType string `json:"verificationType" binding:"required"`
		// Add other relevant fields if needed, e.g., location, condition
	}

	if err := c.ShouldBindJSON(&verificationInput); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input format: " + err.Error()})
		return
	}

	// Get user ID from context (representing the user performing the verification)
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Fetch item from repository to get serial number
	item, err := h.Repo.GetPropertyByID(uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory item: " + err.Error()})
		}
		return
	}

	// Log verification event to Ledger Service
	errLedger := h.Ledger.LogVerificationEvent(item.ID, item.SerialNumber, userID, verificationInput.VerificationType)
	if errLedger != nil {
		// Log error but don't necessarily fail the request, depending on requirements
		log.Printf("WARNING: Failed to log verification event (ItemID: %d, SN: %s, Type: %s) to Ledger: %v", item.ID, item.SerialNumber, verificationInput.VerificationType, errLedger)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log verification event to ledger"}) // Or return 200 with warning?
		return
	}

	log.Printf("Successfully logged verification event for ItemID: %d, SN: %s", item.ID, item.SerialNumber)
	c.JSON(http.StatusOK, gin.H{"message": "Verification event logged successfully"})
}

// GetPropertyBySerialNumber godoc
// @Summary Get property by serial number
// @Description Get details for a specific property item by its unique serial number
// @Tags Inventory
// @Produce json
// @Param serialNumber path string true "Serial Number"
// @Success 200 {object} domain.Property "Successfully retrieved property"
// @Failure 400 {object} map[string]string "error: Invalid Serial Number parameter"
// @Failure 404 {object} map[string]string "error: Property not found"
// @Failure 500 {object} map[string]string "error: Failed to fetch property"
// @Router /inventory/serial/{serialNumber} [get]
// @Security BearerAuth
func (h *InventoryHandler) GetPropertyBySerialNumber(c *gin.Context) {
	serialNumber := c.Param("serialNumber")
	if serialNumber == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Serial number parameter cannot be empty"})
		return
	}

	property, err := h.Repo.GetPropertyBySerialNumber(serialNumber)
	if err != nil {
		// Check if the error indicates the record was not found
		// Note: The repository might return nil, nil or a specific error for not found
		// Assuming the repository returns gorm.ErrRecordNotFound or equivalent
		if errors.Is(err, gorm.ErrRecordNotFound) { // Adjust if your repo uses a different not-found indicator
			c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("Property with serial number '%s' not found", serialNumber)})
		} else {
			log.Printf("Error fetching property by serial number %s: %v", serialNumber, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property by serial number"})
		}
		return
	}

	// Handle the case where the repository returns nil, nil explicitly (if applicable)
	if property == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": fmt.Sprintf("Property with serial number '%s' not found", serialNumber)})
		return
	}

	c.JSON(http.StatusOK, property) // Return the found property directly
}

// GeneratePropertyQRCode generates a QR code for a property item
// Only the current holder can generate QR codes
func (h *InventoryHandler) GeneratePropertyQRCode(c *gin.Context) {
	// Parse property ID from URL parameter
	propertyID, err := strconv.ParseUint(c.Param("propertyId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID format"})
		return
	}

	// Get user ID from context
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Fetch property to verify ownership
	property, err := h.Repo.GetPropertyByID(uint(propertyID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property"})
		}
		return
	}

	// Verify user is current holder
	if property.AssignedToUserID == nil || *property.AssignedToUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Only current holder can generate QR codes"})
		return
	}

	// Determine category (you may need to adjust this based on your actual data model)
	category := "other"
	if property.PropertyModelID != nil {
		// You might want to fetch the property model to get the actual category
		// For now, we'll use a simple categorization based on name
		if property.Name != "" {
			// This is a simplified categorization - adjust based on your needs
			category = h.getCategoryFromName(property.Name)
		}
	}

	// Create QR data structure
	qrData := map[string]interface{}{
		"type":            "handreceipt_property",
		"itemId":          fmt.Sprintf("%d", property.ID),
		"serialNumber":    property.SerialNumber,
		"itemName":        property.Name,
		"category":        category,
		"currentHolderId": fmt.Sprintf("%d", userID),
		"timestamp":       time.Now().UTC().Format(time.RFC3339),
	}

	// Generate hash for verification
	qrJSON, err := json.Marshal(qrData)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to marshal QR data"})
		return
	}

	hash := sha256.Sum256(qrJSON)
	qrData["qrHash"] = hex.EncodeToString(hash[:])

	// Marshal again with hash included
	qrJSONWithHash, err := json.Marshal(qrData)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to marshal QR data with hash"})
		return
	}

	// Deactivate any existing active QR codes for this property
	if err := h.Repo.DeactivateQRCodesForProperty(property.ID); err != nil {
		log.Printf("WARNING: Failed to deactivate old QR codes for property %d: %v", property.ID, err)
		// Continue anyway - we don't want to fail the operation
	}

	// Save QR record to database
	qrRecord := &domain.QRCode{
		PropertyID:        property.ID,
		QRCodeData:        string(qrJSONWithHash),
		QRCodeHash:        qrData["qrHash"].(string),
		GeneratedByUserID: userID,
		IsActive:          true,
	}

	if err := h.Repo.CreateQRCode(qrRecord); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save QR code record"})
		return
	}

	// Generate actual QR code image using skip2/go-qrcode
	qrCodeImage, err := qrcode.Encode(string(qrJSONWithHash), qrcode.Medium, 256)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate QR code image"})
		return
	}

	// Convert to base64
	qrCodeBase64 := base64.StdEncoding.EncodeToString(qrCodeImage)

	// Log to ledger
	if err := h.Ledger.LogVerificationEvent(property.ID, property.SerialNumber, userID, "QR_CODE_GENERATED"); err != nil {
		log.Printf("WARNING: Failed to log QR generation to ledger: %v", err)
	}

	c.JSON(http.StatusOK, gin.H{
		"qrCodeData": string(qrJSONWithHash),
		"qrCodeUrl":  "data:image/png;base64," + qrCodeBase64,
	})
}

// Helper method to determine category from item name
func (h *InventoryHandler) getCategoryFromName(name string) string {
	nameLower := strings.ToLower(name)

	switch {
	case strings.Contains(nameLower, "m4") || strings.Contains(nameLower, "m16") ||
		strings.Contains(nameLower, "rifle") || strings.Contains(nameLower, "carbine") ||
		strings.Contains(nameLower, "pistol") || strings.Contains(nameLower, "weapon"):
		return "weapons"
	case strings.Contains(nameLower, "radio") || strings.Contains(nameLower, "prc") ||
		strings.Contains(nameLower, "sincgars") || strings.Contains(nameLower, "comm"):
		return "communications"
	case strings.Contains(nameLower, "nvg") || strings.Contains(nameLower, "acog") ||
		strings.Contains(nameLower, "optic") || strings.Contains(nameLower, "scope"):
		return "optics"
	case strings.Contains(nameLower, "vest") || strings.Contains(nameLower, "plate") ||
		strings.Contains(nameLower, "helmet") || strings.Contains(nameLower, "ach") ||
		strings.Contains(nameLower, "iotv") || strings.Contains(nameLower, "armor"):
		return "protective-gear"
	case strings.Contains(nameLower, "ifak") || strings.Contains(nameLower, "medical") ||
		strings.Contains(nameLower, "aid"):
		return "medical"
	default:
		return "other"
	}
}
