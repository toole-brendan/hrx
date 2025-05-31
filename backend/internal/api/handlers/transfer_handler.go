package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
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
	"gorm.io/gorm"
)

// TransferHandler handles transfer operations
type TransferHandler struct {
	Ledger ledger.LedgerService
	Repo   repository.Repository
}

// NewTransferHandler creates a new transfer handler
func NewTransferHandler(ledgerService ledger.LedgerService, repo repository.Repository) *TransferHandler {
	return &TransferHandler{Ledger: ledgerService, Repo: repo}
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

	// Fetch the inventory item using repository to get the serial number for Ledger logging
	item, err := h.Repo.GetPropertyByID(input.PropertyID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Inventory item not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory item: " + err.Error()})
		}
		return
	}

	// Prepare the transfer for database insertion
	transfer := &domain.Transfer{ // Changed to pointer
		PropertyID: input.PropertyID,
		FromUserID: requestingUserID, // Set FromUserID to the authenticated user
		ToUserID:   input.ToUserID,
		Status:     "Requested", // Set initial status
		Notes:      input.Notes,
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

	// Fetch the related inventory item using repository for serial number
	item, err := h.Repo.GetPropertyByID(transfer.PropertyID)
	if err != nil {
		log.Printf("Error fetching related item %d for transfer %d update: %v", transfer.PropertyID, transfer.ID, err)
		// Decide if this is fatal - maybe proceed without Ledger logging? For now, fail.
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch related inventory item for logging"})
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

// InitiateTransferByQR initiates a transfer by scanning a QR code
func (h *TransferHandler) InitiateTransferByQR(c *gin.Context) {
	var req domain.QRTransferRequest

	// Validate request body
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input format: " + err.Error()})
		return
	}

	// Get scanner user ID from context
	scannerUserIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	scannerUserID, ok := scannerUserIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Verify QR code hash
	qrDataWithoutHash := make(map[string]interface{})
	for k, v := range req.QRData {
		if k != "qrHash" {
			qrDataWithoutHash[k] = v
		}
	}

	// Marshal data for hashing
	qrJSON, err := json.Marshal(qrDataWithoutHash)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid QR data format"})
		return
	}

	// Compute hash
	hash := sha256.Sum256(qrJSON)
	computedHash := hex.EncodeToString(hash[:])

	// Get expected hash from QR data
	expectedHash, ok := req.QRData["qrHash"].(string)
	if !ok || computedHash != expectedHash {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid QR code - hash verification failed"})
		return
	}

	// Extract item ID from QR data
	itemIDStr, ok := req.QRData["itemId"].(string)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid QR code - missing item ID"})
		return
	}

	itemID, err := strconv.ParseUint(itemIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid item ID in QR code"})
		return
	}

	// Fetch property to verify current holder
	property, err := h.Repo.GetPropertyByID(uint(itemID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property"})
		}
		return
	}

	// Extract current holder ID from QR data
	currentHolderIDStr, ok := req.QRData["currentHolderId"].(string)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid QR code - missing current holder ID"})
		return
	}

	currentHolderID, err := strconv.ParseUint(currentHolderIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid current holder ID in QR code"})
		return
	}

	// Verify current holder matches
	if property.AssignedToUserID == nil || *property.AssignedToUserID != uint(currentHolderID) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "QR code is outdated - property holder has changed"})
		return
	}

	// Prevent self-transfer
	if scannerUserID == *property.AssignedToUserID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot transfer to yourself"})
		return
	}

	// Create transfer request
	transfer := &domain.Transfer{
		PropertyID:  property.ID,
		FromUserID:  *property.AssignedToUserID,
		ToUserID:    scannerUserID,
		Status:      "Requested",
		Notes:       &[]string{fmt.Sprintf("Transfer initiated via QR scan at %s", req.ScannedAt)}[0],
		RequestDate: time.Now(),
	}

	// Save transfer
	if err := h.Repo.CreateTransfer(transfer); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transfer"})
		return
	}

	// Log to ledger
	if err := h.Ledger.LogTransferEvent(*transfer, property.SerialNumber); err != nil {
		log.Printf("WARNING: Failed to log QR transfer to ledger: %v", err)
	}

	// TODO: Send notification to current holder

	c.JSON(http.StatusOK, gin.H{
		"transferId": fmt.Sprintf("%d", transfer.ID),
		"status":     transfer.Status,
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
		SerialNumber string  `json:"serialNumber" binding:"required"`
		Notes        *string `json:"notes"`
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
		PropertyID  uint    `json:"propertyId" binding:"required"`
		RecipientID uint    `json:"recipientId" binding:"required"`
		Notes       *string `json:"notes"`
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
		PropertyID:   property.ID,
		FromUserID:   ownerID,
		ToUserID:     req.RecipientID,
		Status:       "pending",
		TransferType: domain.TransferTypeOffer,
		InitiatorID:  &ownerID,
		Notes:        req.Notes,
		RequestDate:  time.Now(),
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
