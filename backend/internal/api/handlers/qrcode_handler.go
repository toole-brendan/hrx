package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
)

// QRCodeHandler handles QR code operations
type QRCodeHandler struct {
	Ledger ledger.LedgerService
	Repo   repository.Repository
}

// NewQRCodeHandler creates a new QR code handler
func NewQRCodeHandler(ledgerService ledger.LedgerService, repo repository.Repository) *QRCodeHandler {
	return &QRCodeHandler{Ledger: ledgerService, Repo: repo}
}

// GetAllQRCodes returns all QR codes with their inventory items
func (h *QRCodeHandler) GetAllQRCodes(c *gin.Context) {
	qrCodes, err := h.Repo.ListAllQRCodes()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch QR codes"})
		return
	}

	// Fetch associated inventory items
	var qrCodesWithItems []map[string]interface{}
	for _, qrCode := range qrCodes {
		// Get the inventory item
		property, err := h.Repo.GetPropertyByID(qrCode.PropertyID)
		if err != nil {
			// Skip this QR code if property not found
			continue
		}

		// Determine QR code status
		qrCodeStatus := "active"
		if !qrCode.IsActive {
			qrCodeStatus = "replaced"
		}

		qrCodeWithItem := map[string]interface{}{
			"id":                fmt.Sprintf("%d", qrCode.ID),
			"inventoryItemId":   fmt.Sprintf("%d", qrCode.PropertyID),
			"qrCodeData":        qrCode.QRCodeData,
			"qrCodeHash":        qrCode.QRCodeHash,
			"generatedByUserId": fmt.Sprintf("%d", qrCode.GeneratedByUserID),
			"isActive":          qrCode.IsActive,
			"createdAt":         qrCode.CreatedAt.Format(time.RFC3339),
			"deactivatedAt":     nil,
			"qrCodeStatus":      qrCodeStatus,
			"lastPrinted":       qrCode.CreatedAt.Format("2006-01-02"),
			"lastUpdated":       qrCode.CreatedAt.Format("2006-01-02"),
			"inventoryItem": map[string]interface{}{
				"id":           fmt.Sprintf("%d", property.ID),
				"name":         property.Name,
				"serialNumber": property.SerialNumber,
				"description":  property.Description,
				"category":     "other", // You may want to determine this from property model
				"status":       property.CurrentStatus,
				"assignedTo":   fmt.Sprintf("%d", *property.AssignedToUserID),
				"assignedDate": property.CreatedAt.Format("2006-01-02"),
				"location":     "A Co, 2-1 INF", // You may want to get this from a location field
			},
		}

		if qrCode.DeactivatedAt != nil {
			qrCodeWithItem["deactivatedAt"] = qrCode.DeactivatedAt.Format(time.RFC3339)
		}

		qrCodesWithItems = append(qrCodesWithItems, qrCodeWithItem)
	}

	c.JSON(http.StatusOK, gin.H{"qrcodes": qrCodesWithItems})
}

// GetPropertyQRCodes returns QR codes for a specific property
func (h *QRCodeHandler) GetPropertyQRCodes(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("propertyId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID format"})
		return
	}

	qrCodes, err := h.Repo.ListQRCodesForProperty(uint(propertyID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch QR codes for property"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"qrCodes": qrCodes})
}

// ReportQRCodeDamaged reports a QR code as damaged
func (h *QRCodeHandler) ReportQRCodeDamaged(c *gin.Context) {
	qrCodeID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid QR code ID format"})
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

	var req struct {
		Reason string `json:"reason" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Reason is required"})
		return
	}

	// Get the QR code
	qrCode, err := h.Repo.GetQRCodeByID(uint(qrCodeID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "QR code not found"})
		return
	}

	// Deactivate the QR code
	now := time.Now()
	qrCode.IsActive = false
	qrCode.DeactivatedAt = &now

	if err := h.Repo.UpdateQRCode(qrCode); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update QR code"})
		return
	}

	// Get the property for logging
	property, err := h.Repo.GetPropertyByID(qrCode.PropertyID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property"})
		return
	}

	// Log to ledger
	if err := h.Ledger.LogVerificationEvent(property.ID, property.SerialNumber, userID, fmt.Sprintf("QR_CODE_REPORTED_DAMAGED: %s", req.Reason)); err != nil {
		// Log warning but don't fail the request
		fmt.Printf("WARNING: Failed to log QR code damage report to ledger: %v\n", err)
	}

	c.JSON(http.StatusOK, gin.H{"message": "QR code reported as damaged"})
}
