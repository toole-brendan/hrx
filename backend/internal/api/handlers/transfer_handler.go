package handlers

import (
	"errors"
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

// UpdateTransferStatus updates the status of a transfer
func (h *TransferHandler) UpdateTransferStatus(c *gin.Context) {
	// Parse ID from URL parameter
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	// Parse status from request body
	var updateData domain.UpdateTransferInput // Use domain type

	if err := c.ShouldBindJSON(&updateData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input format: " + err.Error()})
		return
	}

	// Validate status value (adjust allowed statuses as needed)
	allowedStatuses := map[string]bool{"Requested": true, "Approved": true, "Rejected": true, "Completed": true, "Cancelled": true} // Added more statuses
	if !allowedStatuses[updateData.Status] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid status value"})
		return
	}

	// Get user ID from context (representing the user performing the update)
	_, exists := c.Get("userID") // TODO: Use this userID for authorization check
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	// TODO: Add authorization logic here - does this user have permission to update this transfer?

	// Fetch transfer from repository
	transfer, err := h.Repo.GetTransferByID(uint(id))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Transfer not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch transfer: " + err.Error()})
		}
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
	transfer.Status = updateData.Status
	if updateData.Notes != nil {
		transfer.Notes = updateData.Notes
	}

	// Update ResolvedDate based on status
	if transfer.Status == "Approved" || transfer.Status == "Rejected" || transfer.Status == "Completed" || transfer.Status == "Cancelled" {
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

	// Log the updated state to Ledger Service
	errLedger := h.Ledger.LogTransferEvent(*transfer, item.SerialNumber)
	if errLedger != nil {
		// Log error but don't fail the request as DB update succeeded
		log.Printf("WARNING: Failed to log transfer status update (ID: %d, SN: %s, NewStatus: %s) to Ledger: %v", transfer.ID, item.SerialNumber, transfer.Status, errLedger)
		c.Writer.Write([]byte("\nWarning: Failed to log status update to immutable ledger")) // Optionally notify client
	} else {
		log.Printf("Successfully logged transfer status update (ID: %d, NewStatus: %s) to Ledger", transfer.ID, transfer.Status)
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
