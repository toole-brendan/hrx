package handlers

import (
	"net/http"

	"log"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
)

// LedgerHandler holds dependencies for ledger-related handlers.
type LedgerHandler struct {
	LedgerService ledger.LedgerService
}

// NewLedgerHandler creates a new LedgerHandler.
func NewLedgerHandler(ledgerService ledger.LedgerService) *LedgerHandler {
	return &LedgerHandler{LedgerService: ledgerService}
}

// GetLedgerHistoryHandler handles requests to retrieve the general ledger history.
func (h *LedgerHandler) GetLedgerHistoryHandler(c *gin.Context) {
	log.Println("Handler: GetLedgerHistoryHandler invoked")
	history, err := h.LedgerService.GetGeneralHistory()
	if err != nil {
		log.Printf("Error getting general history from service: %v", err)
		// Consider mapping specific service errors to HTTP statuses if needed
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve ledger history"})
		return
	}

	// Return empty array instead of null if history is empty
	if history == nil {
		history = []domain.GeneralLedgerEvent{}
	}

	log.Printf("Handler: Returning %d general history events", len(history))
	c.JSON(http.StatusOK, history)
}
