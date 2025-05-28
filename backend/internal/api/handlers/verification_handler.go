package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
)

// VerificationHandler handles ledger verification operations
type VerificationHandler struct {
	Ledger ledger.LedgerService
}

// NewVerificationHandler creates a new verification handler
func NewVerificationHandler(ledgerService ledger.LedgerService) *VerificationHandler {
	return &VerificationHandler{Ledger: ledgerService}
}

// VerifyDatabaseLedger performs a full cryptographic verification of the database ledger.
// It calls the underlying LedgerService's verification function, which for Azure SQL
// typically executes sys.sp_verify_database_ledger.
// @Summary Verify Database Ledger
// @Description Performs a full cryptographic verification of the entire database ledger.
// @Tags Verification
// @Produce json
// @Success 200 {object} map[string]string "status: ok, message: Ledger verification successful."
// @Failure 500 {object} map[string]string "status: error, message: Ledger verification failed or could not be completed, error: ..."
// @Failure 503 {object} map[string]string "status: unhealthy, message: Ledger verification reported inconsistencies."
// @Router /verification/database [get]
// @Security BearerAuth
func (h *VerificationHandler) VerifyDatabaseLedger(c *gin.Context) {
	// The underlying Azure implementation currently ignores these parameters
	// as it verifies the whole database.
	documentID := "database-wide"
	tableName := "all"

	ok, err := h.Ledger.VerifyDocument(documentID, tableName)

	if err != nil {
		// Specific error might indicate tampering vs. other issues.
		// Returning 503 Service Unavailable if verification procedure ran but reported issues.
		// Returning 500 Internal Server Error for other errors (e.g., connection problems).
		// Consider more robust error parsing based on Azure SQL error messages if needed.
		statusCode := http.StatusInternalServerError
		statusMsg := "error"
		message := "Ledger verification failed or could not be completed"
		// Simple check: If 'ok' is false but error is non-nil, assume verification ran but failed.
		if !ok {
			statusCode = http.StatusServiceUnavailable // 503
			statusMsg = "unhealthy"
			message = "Ledger verification reported inconsistencies."
		}

		c.JSON(statusCode, gin.H{
			"status":  statusMsg,
			"message": message,
			"error":   err.Error(),
		})
		return
	}

	// If ok is false even without an error (shouldn't happen with current Azure impl),
	// return 503 as well.
	if !ok {
		c.JSON(http.StatusServiceUnavailable, gin.H{
			"status":  "unhealthy",
			"message": "Ledger verification reported inconsistencies (no specific error returned).",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"message": "Ledger verification successful.",
	})
}
