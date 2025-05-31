package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"strconv"

	"log"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"gorm.io/gorm"
)

// PropertyHandler handles property operations
type PropertyHandler struct {
	Ledger ledger.LedgerService
	Repo   repository.Repository
}

// NewPropertyHandler creates a new property handler
func NewPropertyHandler(ledgerService ledger.LedgerService, repo repository.Repository) *PropertyHandler {
	return &PropertyHandler{Ledger: ledgerService, Repo: repo}
}

// GetAllProperties returns all propertys
func (h *PropertyHandler) GetAllProperties(c *gin.Context) {
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

	properties, err := h.Repo.ListProperties(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch properties"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"properties": properties})
}

// GetProperty returns a specific property
func (h *PropertyHandler) GetProperty(c *gin.Context) {
	// Parse ID from URL parameter
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	// Fetch property from repository
	property, err := h.Repo.GetPropertyByID(uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property"})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{"property": property})
}

// CreateProperty creates a new property
func (h *PropertyHandler) CreateProperty(c *gin.Context) {
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
	existingProperty, err := h.Repo.GetPropertyBySerialNumber(input.SerialNumber)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check for existing serial number"})
		return
	}
	if existingProperty != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("A digital twin with serial number '%s' already exists", input.SerialNumber)})
		return
	}

	// Prepare the property for database insertion
	property := &domain.Property{
		Name:             input.Name,
		SerialNumber:     input.SerialNumber,
		Description:      input.Description,
		CurrentStatus:    input.CurrentStatus,
		PropertyModelID:  input.PropertyModelID,
		AssignedToUserID: input.AssignedToUserID,
	}

	// Insert into database using repository
	if err := h.Repo.CreateProperty(property); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create property: " + err.Error()})
		return
	}

	// Log to Ledger Service (use the property *after* creation to ensure ID is populated)
	errLedger := h.Ledger.LogPropertyCreation(*property, userID)
	if errLedger != nil {
		// Log the error but don't fail the primary operation
		log.Printf("WARNING: Failed to log property creation (ID: %d, SN: %s) to Ledger: %v", property.ID, property.SerialNumber, errLedger)
	}

	c.JSON(http.StatusCreated, property)
}

// UpdatePropertyStatus updates the status of an property
func (h *PropertyHandler) UpdatePropertyStatus(c *gin.Context) {
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

	// Fetch property from repository
	property, err := h.Repo.GetPropertyByID(uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property"})
		}
		return
	}

	// Store old status for logging
	oldStatus := property.CurrentStatus

	// Update status
	property.CurrentStatus = updateData.Status
	if err := h.Repo.UpdateProperty(property); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update property status"})
		return
	}

	// Get user ID from context
	userIDVal, exists := c.Get("userID")
	if exists {
		userID, ok := userIDVal.(uint)
		if ok {
			// Log to Ledger Service
			errLedger := h.Ledger.LogStatusChange(property.ID, property.SerialNumber, oldStatus, updateData.Status, userID)
			if errLedger != nil {
				// Log error but don't fail the request
				log.Printf("WARNING: Failed to log status change (PropertyID: %d, SN: %s) to Ledger: %v", property.ID, property.SerialNumber, errLedger)
				c.Writer.Write([]byte("\nWarning: Failed to log status update to immutable ledger")) // Optionally notify client
			}
		} else {
			log.Printf("WARNING: Could not assert userID to uint for ledger logging in UpdatePropertyStatus")
		}
	} else {
		log.Printf("WARNING: UserID not found in context for ledger logging in UpdatePropertyStatus")
	}

	c.JSON(http.StatusOK, gin.H{"property": property})
}

// GetPropertysByUser returns propertys assigned to a specific user
func (h *PropertyHandler) GetPropertysByUser(c *gin.Context) {
	// Parse user ID from URL parameter
	userID, err := strconv.ParseUint(c.Param("userId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Fetch properties using repository
	userIDUint := uint(userID)
	properties, err := h.Repo.ListProperties(&userIDUint)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch properties"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"properties": properties})
}

// GetPropertyHistory returns the history of an property from the Ledger
func (h *PropertyHandler) GetPropertyHistory(c *gin.Context) {
	// Parse serial number from URL parameter
	serialNumber := c.Param("serialNumber")
	if serialNumber == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Serial number parameter is required"})
		return
	}

	// Fetch the property by serial number to get its ID
	property, err := h.Repo.GetPropertyBySerialNumber(serialNumber)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found for serial number: " + serialNumber})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property by serial number: " + err.Error()})
		}
		return
	}

	// Get property history from Ledger Service using PropertyID
	history, err := h.Ledger.GetPropertyHistory(property.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property history from ledger: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"history": history})
}

// VerifyProperty logs a verification event for an property
func (h *PropertyHandler) VerifyProperty(c *gin.Context) {
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

	// Fetch property from repository to get serial number
	property, err := h.Repo.GetPropertyByID(uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property: " + err.Error()})
		}
		return
	}

	// Log verification event to Ledger Service
	errLedger := h.Ledger.LogVerificationEvent(property.ID, property.SerialNumber, userID, verificationInput.VerificationType)
	if errLedger != nil {
		// Log error but don't necessarily fail the request, depending on requirements
		log.Printf("WARNING: Failed to log verification event (PropertyID: %d, SN: %s, Type: %s) to Ledger: %v", property.ID, property.SerialNumber, verificationInput.VerificationType, errLedger)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log verification event to ledger"}) // Or return 200 with warning?
		return
	}

	log.Printf("Successfully logged verification event for PropertyID: %d, SN: %s", property.ID, property.SerialNumber)
	c.JSON(http.StatusOK, gin.H{"message": "Verification event logged successfully"})
}

// GetPropertyBySerialNumber godoc
// @Summary Get property by serial number
// @Description Get details for a specific property by its unique serial number
// @Tags Property
// @Produce json
// @Param serialNumber path string true "Serial Number"
// @Success 200 {object} domain.Property "Successfully retrieved property"
// @Failure 400 {object} map[string]string "error: Invalid Serial Number parameter"
// @Failure 404 {object} map[string]string "error: Property not found"
// @Failure 500 {object} map[string]string "error: Failed to fetch property"
// @Router /property/serial/{serialNumber} [get]
// @Security BearerAuth
func (h *PropertyHandler) GetPropertyBySerialNumber(c *gin.Context) {
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
