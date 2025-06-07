package handlers

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services"
	"github.com/toole-brendan/handreceipt-go/internal/services/email"
	"github.com/toole-brendan/handreceipt-go/internal/services/pdf"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
	"gorm.io/gorm"
)

// TransferHandler handles transfer operations
type TransferHandler struct {
	Ledger           ledger.LedgerService
	Repo             repository.Repository
	ComponentService services.ComponentService
	PDFGenerator     *pdf.DA2062Generator
	EmailService     *email.DA2062EmailService
	StorageService   storage.StorageService
}

// NewTransferHandler creates a new transfer handler
func NewTransferHandler(
	ledgerService ledger.LedgerService,
	repo repository.Repository,
	componentService services.ComponentService,
	pdfGenerator *pdf.DA2062Generator,
	emailService *email.DA2062EmailService,
	storageService storage.StorageService,
) *TransferHandler {
	return &TransferHandler{
		Ledger:           ledgerService,
		Repo:             repo,
		ComponentService: componentService,
		PDFGenerator:     pdfGenerator,
		EmailService:     emailService,
		StorageService:   storageService,
	}
}

// CreateTransfer creates a new transfer record
func (h *TransferHandler) CreateTransfer(c *gin.Context) {
	var input domain.CreateTransferInput

	// Validate request body
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input format: " + err.Error()})
		return
	}

	// Get user ID from context (set by auth middleware)
	// This represents the user *initiating* the request
	requestingUserIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	requestingUserID, ok := requestingUserIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Fetch the property using repository to get the serial number for Ledger logging
	item, err := h.Repo.GetPropertyByID(input.PropertyID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property: " + err.Error()})
		}
		return
	}

	// Prepare the transfer for database insertion
	transfer := &domain.Transfer{ // Changed to pointer
		PropertyID:        input.PropertyID,
		FromUserID:        requestingUserID, // Set FromUserID to the authenticated user
		ToUserID:          input.ToUserID,
		Status:            "Requested",              // Set initial status
		TransferType:      domain.TransferTypeOffer, // Add this
		InitiatorID:       &requestingUserID,        // Add this
		IncludeComponents: input.IncludeComponents,  // Include component transfer option
		Notes:             input.Notes,
		// RequestDate defaults to CURRENT_TIMESTAMP in DB
		// ResolvedDate is null initially
	}

	// Insert into database using repository
	if err := h.Repo.CreateTransfer(transfer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transfer: " + err.Error()})
		return
	}

	// Log to Ledger Service (use transfer *after* creation)
	errLedger := h.Ledger.LogTransferEvent(*transfer, item.SerialNumber)
	if errLedger != nil {
		log.Printf("WARNING: Failed to log transfer creation (ID: %d, ItemID: %d, SN: %s) to Ledger after DB creation: %v", transfer.ID, transfer.PropertyID, item.SerialNumber, errLedger)
		// Consider compensation logic here if ledger write fails, or at least alert
	} else {
		log.Printf("Successfully logged transfer creation (ID: %d, ItemID: %d) to Ledger", transfer.ID, transfer.PropertyID)
	}

	c.JSON(http.StatusCreated, transfer)
}

// UpdateTransferStatus godoc
// @Summary Update transfer status
// @Description Accept, reject, or cancel a transfer based on transfer type and user authorization
// @Tags Transfers
// @Accept json
// @Produce json
// @Param id path string true "Transfer ID"
// @Param request body object true "Status update"
// @Success 200 {object} domain.Transfer
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 403 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "Transfer not found"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /transfers/{id}/status [patch]
// @Security BearerAuth
func (h *TransferHandler) UpdateTransferStatus(c *gin.Context) {
	transferIDParam := c.Param("id")
	transferID, err := strconv.ParseUint(transferIDParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid transfer ID"})
		return
	}

	// Parse status from request body
	var req struct {
		Status string  `json:"status" binding:"required,oneof=accepted rejected cancelled"`
		Reason *string `json:"reason"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Convert to domain type for compatibility with existing code
	updateData := domain.UpdateTransferInput{
		Status: req.Status,
		Notes:  req.Reason,
	}

	// Validate status value (adjust allowed statuses as needed)
	allowedStatuses := map[string]bool{
		"pending": true, "accepted": true, "rejected": true, "cancelled": true,
		// Legacy statuses for backwards compatibility
		"Requested": true, "Approved": true, "Rejected": true, "Completed": true, "Cancelled": true,
	}
	if !allowedStatuses[updateData.Status] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status value"})
		return
	}

	// Get user ID from context (representing the user performing the update)
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	currentUserID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Fetch transfer from repository
	transfer, err := h.Repo.GetTransferByID(uint(transferID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Transfer not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch transfer: " + err.Error()})
		}
		return
	}

	// Authorization logic based on transfer type
	authorized := false
	if transfer.TransferType == domain.TransferTypeRequest {
		// For requests: property owner (from_user) approves/rejects
		authorized = (transfer.FromUserID == currentUserID && (updateData.Status == "accepted" || updateData.Status == "rejected"))
		// Requestor can cancel
		authorized = authorized || (transfer.ToUserID == currentUserID && updateData.Status == "cancelled")
	} else if transfer.TransferType == domain.TransferTypeOffer {
		// For offers: recipient (to_user) accepts/rejects
		authorized = (transfer.ToUserID == currentUserID && (updateData.Status == "accepted" || updateData.Status == "rejected"))
		// Offerer can cancel
		authorized = authorized || (transfer.FromUserID == currentUserID && updateData.Status == "cancelled")
	} else {
		// Legacy transfers (no transfer type) - use old logic
		switch updateData.Status {
		case "Approved", "Rejected":
			authorized = (currentUserID == transfer.ToUserID)
		case "Cancelled":
			authorized = (currentUserID == transfer.FromUserID && transfer.Status == "Requested")
		default:
			authorized = (currentUserID == transfer.FromUserID || currentUserID == transfer.ToUserID)
		}
	}

	if !authorized {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized to update this transfer"})
		return
	}

	// Fetch the related property using repository for serial number
	item, err := h.Repo.GetPropertyByID(transfer.PropertyID)
	if err != nil {
		log.Printf("Error fetching related item %d for transfer %d update: %v", transfer.PropertyID, transfer.ID, err)
		// Decide if this is fatal - maybe proceed without Ledger logging? For now, fail.
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch related property for logging"})
		return
	}

	// Update fields
	previousStatus := transfer.Status
	transfer.Status = updateData.Status

	// Append reason to existing notes if provided
	if req.Reason != nil && *req.Reason != "" {
		if transfer.Notes != nil && *transfer.Notes != "" {
			newNotes := *transfer.Notes + " | " + *req.Reason
			transfer.Notes = &newNotes
		} else {
			transfer.Notes = req.Reason
		}
	}

	// Update ResolvedDate based on status
	if transfer.Status == "accepted" || transfer.Status == "rejected" || transfer.Status == "cancelled" {
		now := time.Now().UTC()
		transfer.ResolvedDate = &now
	} else {
		transfer.ResolvedDate = nil // Reset if moved back to pending?
	}

	// Save updated transfer using repository
	if err := h.Repo.UpdateTransfer(transfer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update transfer status: " + err.Error()})
		return
	}

	// If accepted, update the property ownership
	if transfer.Status == "accepted" && previousStatus != "accepted" {
		// Update the property's current holder
		item.AssignedToUserID = &transfer.ToUserID
		item.UpdatedAt = time.Now().UTC()

		if err := h.Repo.UpdateProperty(item); err != nil {
			// Rollback transfer status change
			transfer.Status = previousStatus
			transfer.ResolvedDate = nil
			h.Repo.UpdateTransfer(transfer)

			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update property ownership"})
			return
		}

		log.Printf("Property %d ownership transferred from user %d to user %d", item.ID, transfer.FromUserID, transfer.ToUserID)

		// If the transfer includes components, transfer them too
		if transfer.IncludeComponents {
			if err := h.ComponentService.TransferComponents(c.Request.Context(), transfer.PropertyID, transfer.FromUserID, transfer.ToUserID); err != nil {
				log.Printf("WARNING: Failed to transfer components for property %d: %v", transfer.PropertyID, err)
				// Note: We continue with the transfer even if component transfer fails
				// The main property transfer has already succeeded
			} else {
				log.Printf("Successfully transferred components for property %d from user %d to user %d", transfer.PropertyID, transfer.FromUserID, transfer.ToUserID)
			}
		}

		// Generate and send DA 2062 Hand Receipt
		if err := h.generateAndSendDA2062(c.Request.Context(), transfer, item); err != nil {
			log.Printf("WARNING: Failed to generate/send DA 2062 for transfer %d: %v", transfer.ID, err)
			// Don't fail the transfer - just log the error
		}

		// Log successful transfer completion
		if err := h.Ledger.LogTransferEvent(*transfer, item.SerialNumber); err != nil {
			log.Printf("WARNING: Failed to log transfer completion to ledger: %v", err)
		}
	}

	// Log status updates (except for accepted status which is logged above with ownership change)
	if transfer.Status != "accepted" {
		if err := h.Ledger.LogTransferEvent(*transfer, item.SerialNumber); err != nil {
			log.Printf("WARNING: Failed to log transfer status update (ID: %d, SN: %s, NewStatus: %s) to Ledger: %v", transfer.ID, item.SerialNumber, transfer.Status, err)
		} else {
			log.Printf("Successfully logged transfer status update (ID: %d, NewStatus: %s) to Ledger", transfer.ID, transfer.Status)
		}
	}

	c.JSON(http.StatusOK, transfer)
}

// GetAllTransfers returns all transfers
func (h *TransferHandler) GetAllTransfers(c *gin.Context) {
	// Get user ID from context to filter transfers (optional)
	var requestingUserID uint
	userIDVal, exists := c.Get("userID")
	if exists {
		userID, ok := userIDVal.(uint)
		if ok {
			requestingUserID = userID
		} else {
			log.Printf("Warning: Invalid user ID format in context for GetAllTransfers")
			// Decide if this should be an error or just ignore filtering
		}
	}

	// Optional: Filter by status from query param
	statusQuery := c.Query("status")
	var statusFilter *string
	if statusQuery != "" {
		statusFilter = &statusQuery
	}

	// Fetch transfers using repository (passing 0 if user ID not found/valid for listing all relevant)
	transfers, err := h.Repo.ListTransfers(requestingUserID, statusFilter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch transfers: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"transfers": transfers})
}

// GetTransferByID returns a specific transfer
func (h *TransferHandler) GetTransferByID(c *gin.Context) {
	// Parse ID from URL parameter
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	// Fetch transfer using repository
	transfer, err := h.Repo.GetTransferByID(uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Transfer not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch transfer: " + err.Error()})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"transfer": transfer})
}

// GetTransfersByUser returns transfers associated with a user
func (h *TransferHandler) GetTransfersByUser(c *gin.Context) {
	// Parse user ID from URL parameter
	userID, err := strconv.ParseUint(c.Param("userId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Optional: Filter by status from query param
	statusQuery := c.Query("status")
	var statusFilter *string
	if statusQuery != "" {
		statusFilter = &statusQuery
	}

	// Fetch transfers using repository
	transfers, err := h.Repo.ListTransfers(uint(userID), statusFilter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch transfers for user: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"transfers": transfers})
}

// DEPRECATED: InitiateTransferByQR - QR code functionality has been removed
func (h *TransferHandler) InitiateTransferByQR(c *gin.Context) {
	c.JSON(http.StatusGone, gin.H{
		"error":   "QR code transfer functionality has been deprecated",
		"message": "Please use serial number search or friend-based transfers instead",
		"alternatives": []string{
			"Use POST /api/transfers/request-by-serial to request by serial number",
			"Use the friends network to offer/request transfers",
		},
	})
}

// RequestTransferBySerial godoc
// @Summary Request transfer by serial number
// @Description Request a property transfer by providing the serial number
// @Tags Transfers
// @Accept json
// @Produce json
// @Param request body object true "Transfer request"
// @Success 201 {object} map[string]interface{} "Transfer request created"
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 403 {object} map[string]string "Not connected to owner"
// @Failure 404 {object} map[string]string "Property not found"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /transfers/request [post]
// @Security BearerAuth
func (h *TransferHandler) RequestTransferBySerial(c *gin.Context) {
	// Get requestor ID from context
	requestorIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	requestorID, ok := requestorIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	var req struct {
		SerialNumber      string  `json:"serialNumber" binding:"required"`
		IncludeComponents bool    `json:"includeComponents"`
		Notes             *string `json:"notes"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Find property by serial number
	property, err := h.Repo.GetPropertyBySerialNumber(req.SerialNumber)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}

	// Check if property is assigned to someone
	if property.AssignedToUserID == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Property is not assigned to anyone"})
		return
	}

	// Prevent self-request
	if requestorID == *property.AssignedToUserID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot request property from yourself"})
		return
	}

	// Check if requestor and owner are connected
	isConnected, err := h.Repo.AreUsersConnected(requestorID, *property.AssignedToUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check user connection"})
		return
	}
	if !isConnected {
		c.JSON(http.StatusForbidden, gin.H{"error": "You must be connected to request this item"})
		return
	}

	// Create transfer request
	transfer := &domain.Transfer{
		PropertyID:            property.ID,
		FromUserID:            *property.AssignedToUserID,
		ToUserID:              requestorID,
		Status:                "pending",
		TransferType:          domain.TransferTypeRequest,
		InitiatorID:           &requestorID,
		RequestedSerialNumber: &req.SerialNumber,
		IncludeComponents:     req.IncludeComponents,
		Notes:                 req.Notes,
		RequestDate:           time.Now(),
	}

	if err := h.Repo.CreateTransfer(transfer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transfer request"})
		return
	}

	// Log to immutable ledger
	if err := h.Ledger.LogTransferEvent(*transfer, property.SerialNumber); err != nil {
		log.Printf("WARNING: Failed to log transfer request to ledger: %v", err)
	}

	// TODO: Notify property owner
	// h.notificationService.SendTransferRequest(transfer)

	c.JSON(http.StatusCreated, gin.H{
		"transferId": transfer.ID,
		"status":     "pending",
		"message":    "Transfer request sent to property owner",
	})
}

// OfferTransfer godoc
// @Summary Offer transfer to connection
// @Description Offer a property transfer to a connected user
// @Tags Transfers
// @Accept json
// @Produce json
// @Param request body object true "Transfer offer"
// @Success 201 {object} map[string]interface{} "Transfer offer created"
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 403 {object} map[string]string "Unauthorized or not connected"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /transfers/offer [post]
// @Security BearerAuth
func (h *TransferHandler) OfferTransfer(c *gin.Context) {
	// Get owner ID from context
	ownerIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	ownerID, ok := ownerIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	var req struct {
		PropertyID        uint    `json:"propertyId" binding:"required"`
		RecipientID       uint    `json:"recipientId" binding:"required"`
		IncludeComponents bool    `json:"includeComponents"`
		Notes             *string `json:"notes"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Prevent self-offer
	if ownerID == req.RecipientID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot offer property to yourself"})
		return
	}

	// Verify ownership
	property, err := h.Repo.GetPropertyByID(req.PropertyID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}
	if property.AssignedToUserID == nil || *property.AssignedToUserID != ownerID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You don't own this property"})
		return
	}

	// Check connection
	isConnected, err := h.Repo.AreUsersConnected(ownerID, req.RecipientID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check user connection"})
		return
	}
	if !isConnected {
		c.JSON(http.StatusForbidden, gin.H{"error": "You must be connected to offer items"})
		return
	}

	// Create transfer offer
	transfer := &domain.Transfer{
		PropertyID:        property.ID,
		FromUserID:        ownerID,
		ToUserID:          req.RecipientID,
		Status:            "pending",
		TransferType:      domain.TransferTypeOffer,
		InitiatorID:       &ownerID,
		IncludeComponents: req.IncludeComponents,
		Notes:             req.Notes,
		RequestDate:       time.Now(),
	}

	if err := h.Repo.CreateTransfer(transfer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transfer offer"})
		return
	}

	// Log and notify
	if err := h.Ledger.LogTransferEvent(*transfer, property.SerialNumber); err != nil {
		log.Printf("WARNING: Failed to log transfer offer to ledger: %v", err)
	}
	// TODO: h.notificationService.SendTransferOffer(transfer)

	c.JSON(http.StatusCreated, gin.H{
		"transferId": transfer.ID,
		"status":     "pending",
		"message":    "Transfer offer sent",
	})
}

// RequestBySerial allows users to request property by entering serial number
func (h *TransferHandler) RequestBySerial(c *gin.Context) {
	var input domain.RequestBySerialInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input: " + err.Error()})
		return
	}

	// Get requesting user from session
	requestingUserID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := requestingUserID.(uint)

	// Find property by serial number
	property, err := h.Repo.GetPropertyBySerial(input.SerialNumber)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property with this serial number not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to find property"})
		}
		return
	}

	// Check if property is assigned
	if property.AssignedToUserID == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Property is not currently assigned to anyone"})
		return
	}

	// Prevent self-transfer
	if *property.AssignedToUserID == userID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "You already own this property"})
		return
	}

	// Create transfer request
	transfer := &domain.Transfer{
		PropertyID:            property.ID,
		FromUserID:            *property.AssignedToUserID,
		ToUserID:              userID,
		Status:                "Requested",
		TransferType:          domain.TransferTypeRequest,
		InitiatorID:           &userID,
		RequestedSerialNumber: &input.SerialNumber,
		IncludeComponents:     input.IncludeComponents,
		Notes:                 input.Notes,
	}

	if err := h.Repo.CreateTransfer(transfer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transfer request"})
		return
	}

	// Log to ledger
	if err := h.Ledger.LogTransferEvent(*transfer, property.SerialNumber); err != nil {
		log.Printf("WARNING: Failed to log serial request transfer to ledger: %v", err)
	}

	// TODO: Send notification to property owner

	c.JSON(http.StatusCreated, gin.H{
		"transfer": transfer,
		"message":  fmt.Sprintf("Transfer request sent to %s", property.AssignedToUser.Name),
	})
}

// CreateOffer allows property owners to offer items to friends
func (h *TransferHandler) CreateOffer(c *gin.Context) {
	var input domain.CreateOfferInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input: " + err.Error()})
		return
	}

	// Get offering user from session
	offeringUserID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := offeringUserID.(uint)

	// Verify ownership
	property, err := h.Repo.GetPropertyByID(input.PropertyID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}

	if property.AssignedToUserID == nil || *property.AssignedToUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You don't own this property"})
		return
	}

	// Verify all recipients are connected friends
	connections, err := h.Repo.GetUserConnections(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify connections"})
		return
	}

	connectedUserIDs := make(map[uint]bool)
	for _, conn := range connections {
		if conn.ConnectionStatus == domain.ConnectionStatusAccepted {
			// Check both directions of the connection
			if conn.UserID == userID {
				connectedUserIDs[conn.ConnectedUserID] = true
			} else if conn.ConnectedUserID == userID {
				connectedUserIDs[conn.UserID] = true
			}
		}
	}

	// Validate all recipients are friends
	for _, recipientID := range input.RecipientIDs {
		if !connectedUserIDs[recipientID] {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": fmt.Sprintf("User %d is not in your connections", recipientID),
			})
			return
		}
	}

	// Calculate expiration
	var expiresAt *time.Time
	if input.ExpiresInDays != nil && *input.ExpiresInDays > 0 {
		exp := time.Now().AddDate(0, 0, *input.ExpiresInDays)
		expiresAt = &exp
	}

	// Create offer
	offer := &domain.TransferOffer{
		PropertyID:     property.ID,
		OfferingUserID: userID,
		OfferStatus:    domain.OfferStatusActive,
		Notes:          input.Notes,
		ExpiresAt:      expiresAt,
	}

	if err := h.Repo.CreateTransferOffer(offer, input.RecipientIDs); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create offer"})
		return
	}

	// TODO: Send notifications to all recipients

	c.JSON(http.StatusCreated, gin.H{
		"offer":   offer,
		"message": fmt.Sprintf("Offer sent to %d recipients", len(input.RecipientIDs)),
	})
}

// ListActiveOffers shows offers available to the current user
func (h *TransferHandler) ListActiveOffers(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	offers, err := h.Repo.ListActiveOffersForUser(userID.(uint))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch offers"})
		return
	}

	// Mark offers as viewed
	for _, offer := range offers {
		h.Repo.MarkOfferViewed(offer.ID, userID.(uint))
	}

	c.JSON(http.StatusOK, gin.H{"offers": offers})
}

// AcceptOffer allows a recipient to accept an offer
func (h *TransferHandler) AcceptOffer(c *gin.Context) {
	offerIDParam := c.Param("offerId")
	offerID, err := strconv.ParseUint(offerIDParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid offer ID"})
		return
	}

	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	acceptingUserID := userID.(uint)

	// Get offer details
	offer, err := h.Repo.GetTransferOfferByID(uint(offerID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Offer not found"})
		return
	}

	// Verify offer is still active
	if offer.OfferStatus != domain.OfferStatusActive {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Offer is no longer active"})
		return
	}

	// Verify user is a recipient
	isRecipient := false
	for _, recipient := range offer.Recipients {
		if recipient.RecipientUserID == acceptingUserID {
			isRecipient = true
			break
		}
	}

	if !isRecipient {
		c.JSON(http.StatusForbidden, gin.H{"error": "You are not a recipient of this offer"})
		return
	}

	// Create transfer record
	transfer := &domain.Transfer{
		PropertyID:        offer.PropertyID,
		FromUserID:        offer.OfferingUserID,
		ToUserID:          acceptingUserID,
		Status:            "Approved",
		TransferType:      domain.TransferTypeOffer,
		InitiatorID:       &offer.OfferingUserID,
		IncludeComponents: false, // TODO: Add IncludeComponents to TransferOffer model later
		Notes:             offer.Notes,
		ResolvedDate:      &time.Time{},
	}
	*transfer.ResolvedDate = time.Now()

	// Transaction: create transfer, update offer, update property ownership
	err = h.Repo.CreateTransfer(transfer)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transfer"})
		return
	}

	// Update offer status
	offer.OfferStatus = domain.OfferStatusAccepted
	offer.AcceptedByUserID = &acceptingUserID
	now := time.Now()
	offer.AcceptedAt = &now

	if err := h.Repo.UpdateTransferOffer(offer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update offer"})
		return
	}

	// Update property ownership
	property := offer.Property
	property.AssignedToUserID = &acceptingUserID
	property.UpdatedAt = time.Now()

	if err := h.Repo.UpdateProperty(property); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update property ownership"})
		return
	}

	// If the transfer includes components, transfer them too
	if transfer.IncludeComponents {
		if err := h.ComponentService.TransferComponents(c.Request.Context(), transfer.PropertyID, transfer.FromUserID, transfer.ToUserID); err != nil {
			log.Printf("WARNING: Failed to transfer components for property %d: %v", transfer.PropertyID, err)
			// Note: We continue with the transfer even if component transfer fails
		} else {
			log.Printf("Successfully transferred components for property %d from user %d to user %d", transfer.PropertyID, transfer.FromUserID, transfer.ToUserID)
		}
	}

	// Log to ledger
	if err := h.Ledger.LogTransferEvent(*transfer, property.SerialNumber); err != nil {
		log.Printf("WARNING: Failed to log offer acceptance to ledger: %v", err)
	}

	c.JSON(http.StatusOK, gin.H{
		"transfer": transfer,
		"message":  "Offer accepted successfully",
	})
}

func (h *TransferHandler) generateAndSendDA2062(ctx context.Context, transfer *domain.Transfer, property *domain.Property) error {
	// Fetch user information for both FROM and TO users
	fromUser, err := h.Repo.GetUserByID(transfer.FromUserID)
	if err != nil {
		return fmt.Errorf("failed to get FROM user: %w", err)
	}

	toUser, err := h.Repo.GetUserByID(transfer.ToUserID)
	if err != nil {
		return fmt.Errorf("failed to get TO user: %w", err)
	}

	// Gather all properties to include in the DA 2062 (main item + components)
	properties := []domain.Property{*property}

	// If transfer includes components, get all attached components
	if transfer.IncludeComponents {
		components, err := h.ComponentService.GetPropertyComponents(ctx, transfer.PropertyID)
		if err != nil {
			log.Printf("WARNING: Failed to get components for property %d: %v", transfer.PropertyID, err)
			// Continue without components rather than failing
		} else {
			// Add components to the properties list
			for _, comp := range components {
				if comp.ComponentProperty != nil {
					properties = append(properties, *comp.ComponentProperty)
				}
			}
		}
	}

	// Prepare user info for PDF generation
	fromInfo := pdf.UserInfo{
		Name:         fromUser.Name,
		Rank:         fromUser.Rank,
		Title:        fromUser.Unit, // Use unit as title
		Phone:        fromUser.Phone,
		SignatureURL: "",
	}
	if fromUser.SignatureURL != nil {
		fromInfo.SignatureURL = *fromUser.SignatureURL
	}

	toInfo := pdf.UserInfo{
		Name:         toUser.Name,
		Rank:         toUser.Rank,
		Title:        toUser.Unit, // Use unit as title
		Phone:        toUser.Phone,
		SignatureURL: "",
	}
	if toUser.SignatureURL != nil {
		toInfo.SignatureURL = *toUser.SignatureURL
	}

	// Prepare unit info (using FROM user's unit)
	unitInfo := pdf.UnitInfo{
		UnitName:    fromUser.Unit,
		DODAAC:      "", // Could be stored in user profile if needed
		StockNumber: "", // Could be property book number if available
		Location:    "", // Could be stored in user profile if needed
	}

	// Generate PDF options
	options := pdf.GenerateOptions{
		GroupByCategory:   false,
		IncludeSignatures: true,
		IncludeQRCodes:    false,
	}

	// Generate the DA 2062 PDF
	pdfBuffer, err := h.PDFGenerator.GenerateDA2062(
		properties,
		fromInfo,
		toInfo,
		unitInfo,
		options,
	)
	if err != nil {
		return fmt.Errorf("failed to generate DA 2062 PDF: %w", err)
	}

	// Generate form number
	formNumber := fmt.Sprintf("HR-%s-%d", time.Now().Format("20060102"), transfer.ID)

	// Upload PDF to storage once (shared by both documents)
	fileKey := fmt.Sprintf("da2062/transfer_%d.pdf", transfer.ID)
	err = h.StorageService.UploadFile(ctx, fileKey, bytes.NewReader(pdfBuffer.Bytes()), int64(pdfBuffer.Len()), "application/pdf")
	if err != nil {
		log.Printf("WARNING: Failed to upload PDF to storage: %v", err)
		return fmt.Errorf("failed to upload DA 2062 PDF: %w", err)
	}

	// Get presigned URL for access
	fileURL, err := h.StorageService.GetPresignedURL(ctx, fileKey, 7*24*time.Hour) // 7 days
	if err != nil {
		log.Printf("WARNING: Failed to get presigned URL for DA 2062: %v", err)
		fileURL = "" // Continue without URL
	}

	// Create in-app documents for BOTH sender and recipient
	// This gives both parties immediate access to the hand receipt in their inbox

	// Create document for recipient (TO user)
	if err := h.createInAppDocumentRecord(ctx, transfer, property, formNumber, fileURL, transfer.ToUserID, "received"); err != nil {
		log.Printf("WARNING: Failed to create in-app document for recipient: %v", err)
	}

	// Create document for sender (FROM user)
	if err := h.createInAppDocumentRecord(ctx, transfer, property, formNumber, fileURL, transfer.FromUserID, "sent"); err != nil {
		log.Printf("WARNING: Failed to create in-app document for sender: %v", err)
	}

	// Log DA 2062 export to ledger
	if err := h.Ledger.LogDA2062Export(transfer.ToUserID, len(properties), "email_and_app", toUser.Email); err != nil {
		log.Printf("WARNING: Failed to log DA 2062 export to ledger: %v", err)
	}

	log.Printf("Successfully generated and sent DA 2062 for transfer %d (%d items)", transfer.ID, len(properties))
	return nil
}

func (h *TransferHandler) createInAppDocumentRecord(ctx context.Context, transfer *domain.Transfer, property *domain.Property, formNumber string, fileURL string, recipientUserID uint, documentType string) error {

	// Create document record with appropriate title based on document type
	var title string
	if documentType == "received" {
		title = fmt.Sprintf("Hand Receipt Received - %s (SN:%s)", property.Name, property.SerialNumber)
	} else {
		title = fmt.Sprintf("Hand Receipt Sent - %s (SN:%s)", property.Name, property.SerialNumber)
	}

	doc := &domain.Document{
		Type:            domain.DocumentTypeTransferForm,
		Subtype:         stringPtr("DA2062"),
		Title:           title,
		SenderUserID:    transfer.FromUserID,
		RecipientUserID: recipientUserID,
		PropertyID:      &property.ID,
		Status:          domain.DocumentStatusUnread,
		SentAt:          time.Now(),
		FormData:        "{}",
		Attachments:     domain.JSONStringArray{}, // Initialize as empty JSONStringArray
	}

	// Add attachment URL if available
	if fileURL != "" {
		doc.Attachments = domain.JSONStringArray{fileURL}
	}

	if err := h.Repo.CreateDocument(doc); err != nil {
		return fmt.Errorf("failed to create document record: %w", err)
	}

	log.Printf("Created in-app document %d (%s) for transfer %d, recipient %d", doc.ID, documentType, transfer.ID, recipientUserID)
	return nil
}

// Helper function to create string pointer
func stringPtr(s string) *string {
	return &s
}
