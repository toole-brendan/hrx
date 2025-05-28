package ledger

import (
	"database/sql"

	"github.com/toole-brendan/handreceipt-go/internal/domain"
)

// LedgerService defines the interface for interacting with an immutable ledger.
// This allows for different implementations (e.g., QLDB, Azure SQL Ledger, Mock).
type LedgerService interface {
	// LogItemCreation logs an item creation event.
	LogItemCreation(property domain.Property, userID uint) error

	// LogTransferEvent logs a transfer event (creation or update).
	LogTransferEvent(transfer domain.Transfer, serialNumber string) error

	// LogStatusChange logs a status change event for an item.
	LogStatusChange(itemID uint, serialNumber string, oldStatus string, newStatus string, userID uint) error

	// LogVerificationEvent logs a verification event for an item.
	LogVerificationEvent(itemID uint, serialNumber string, userID uint, verificationType string) error

	// LogMaintenanceEvent logs a maintenance event for an item.
	LogMaintenanceEvent(maintenanceRecordID string, itemID uint, initiatingUserID uint, performingUserID sql.NullInt64, eventType string, maintenanceType sql.NullString, description string) error

	// LogCorrectionEvent logs a correction event referencing a previous ledger event.
	LogCorrectionEvent(originalEventID string, eventType string, reason string, userID uint) error

	// GetItemHistory retrieves the history of an item based on its serial number.
	GetItemHistory(itemID uint) ([]map[string]interface{}, error)

	// VerifyDocument checks the integrity of a ledger document (implementation specific).
	// For mock/development, this might always return true.
	// For Azure SQL Ledger, this would involve calling verification stored procedures/functions.
	VerifyDocument(documentID string, tableName string) (bool, error)

	// Query Correction Events
	GetAllCorrectionEvents() ([]domain.CorrectionEvent, error)
	GetCorrectionEventsByOriginalID(originalEventID string) ([]domain.CorrectionEvent, error)
	GetCorrectionEventByID(eventID string) (*domain.CorrectionEvent, error)

	// GetGeneralHistory retrieves a consolidated view of all ledger event types.
	// TODO: Add filtering/pagination parameters (e.g., time range, event type, user ID, item ID).
	GetGeneralHistory() ([]domain.GeneralLedgerEvent, error)

	// Initialize prepares the ledger service (e.g., connects, ensures tables/ledger exist).
	Initialize() error

	// Close cleans up resources used by the ledger service.
	Close() error
}
