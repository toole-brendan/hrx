package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin" // Assuming user ID comes from context
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
)

// CorrectionHandler handles correction-related API requests
type CorrectionHandler struct {
	Ledger ledger.LedgerService
}

// CorrectionInput defines the expected JSON input for creating a correction
type CorrectionInput struct {
	OriginalEventID   string `json:"originalEventId" binding:"required"`   // UUID string of the event to correct
	OriginalEventType string `json:"originalEventType" binding:"required"` // Type hint (e.g., "TransferEvent")
	Reason            string `json:"reason" binding:"required"`            // Explanation for the correction
}

// NewCorrectionHandler creates a new CorrectionHandler
func NewCorrectionHandler(ledgerService ledger.LedgerService) *CorrectionHandler {
	return &CorrectionHandler{Ledger: ledgerService}
}

// CreateCorrection godoc
// @Summary Log a correction event
// @Description Logs a correction against a previously recorded ledger event.
// @Tags Corrections
// @Accept json
// @Produce json
// @Param correction body CorrectionInput true "Correction Details"
// @Success 201 {object} map[string]string "message: Correction logged successfully"
// @Failure 400 {object} map[string]string "error: Invalid input data"
// @Failure 401 {object} map[string]string "error: Unauthorized"
// @Failure 500 {object} map[string]string "error: Failed to log correction"
// @Router /corrections [post]
// @Security BearerAuth
func (h *CorrectionHandler) CreateCorrection(c *gin.Context) {
	var input CorrectionInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input data: " + err.Error()})
		return
	}

	// Get user ID from context (set by authentication middleware)
	userIDRaw, exists := c.Get("userID") // Use the string key "userID"
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized: User ID not found in context"})
		return
	}
	userID, ok := userIDRaw.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Internal Server Error: User ID has unexpected type in context"})
		return
	}

	err := h.Ledger.LogCorrectionEvent(input.OriginalEventID, input.OriginalEventType, input.Reason, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to log correction: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Correction logged successfully"})
}

// GetAllCorrections godoc
// @Summary Get all correction events
// @Description Retrieves a list of all correction events logged in the ledger.
// @Tags Corrections
// @Produce json
// @Success 200 {array} domain.CorrectionEvent
// @Failure 500 {object} map[string]string "error: Failed to retrieve correction events"
// @Router /corrections [get]
// @Security BearerAuth
func (h *CorrectionHandler) GetAllCorrections(c *gin.Context) {
	events, err := h.Ledger.GetAllCorrectionEvents()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve correction events: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, events)
}

// GetCorrectionEventByID godoc
// @Summary Get correction event by its ID
// @Description Retrieves details of a specific correction event by its unique EventID.
// @Tags Corrections
// @Produce json
// @Param event_id path string true "Correction Event ID (UUID)"
// @Success 200 {object} domain.CorrectionEvent
// @Failure 400 {object} map[string]string "error: Invalid Event ID format"
// @Failure 404 {object} map[string]string "error: Correction event not found"
// @Failure 500 {object} map[string]string "error: Failed to retrieve correction event"
// @Router /corrections/{event_id} [get]
// @Security BearerAuth
func (h *CorrectionHandler) GetCorrectionEventByID(c *gin.Context) {
	eventID := c.Param("event_id")
	// Basic validation - could add UUID format check
	if eventID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Event ID cannot be empty"})
		return
	}

	event, err := h.Ledger.GetCorrectionEventByID(eventID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve correction event: " + err.Error()})
		return
	}
	if event == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Correction event not found"})
		return
	}
	c.JSON(http.StatusOK, event)
}

// GetCorrectionsByOriginalID godoc
// @Summary Get correction events by original event ID
// @Description Retrieves a list of correction events associated with a specific original ledger event ID.
// @Tags Corrections
// @Produce json
// @Param original_event_id path string true "Original Event ID (UUID)"
// @Success 200 {array} domain.CorrectionEvent
// @Failure 400 {object} map[string]string "error: Invalid Original Event ID format"
// @Failure 500 {object} map[string]string "error: Failed to retrieve correction events"
// @Router /corrections/original/{original_event_id} [get]
// @Security BearerAuth
func (h *CorrectionHandler) GetCorrectionsByOriginalID(c *gin.Context) {
	originalEventID := c.Param("original_event_id")
	// Basic validation - could add UUID format check
	if originalEventID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Original Event ID cannot be empty"})
		return
	}

	events, err := h.Ledger.GetCorrectionEventsByOriginalID(originalEventID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve correction events: " + err.Error()})
		return
	}
	// Return empty list if no corrections found, not an error
	c.JSON(http.StatusOK, events)
}

// TODO: Implement handlers for querying correction events (e.g., GetCorrectionsByOriginalEventID, GetAllCorrections)
