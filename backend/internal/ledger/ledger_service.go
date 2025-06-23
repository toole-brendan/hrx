package ledger

import (
	"context"
	"database/sql"
	"time"

	"github.com/toole-brendan/handreceipt-go/internal/domain"
)

// Event represents a generic ledger event
type Event struct {
	Type      string                 `json:"type"`
	UserID    string                 `json:"userId"`
	Metadata  map[string]interface{} `json:"metadata"`
	Timestamp time.Time              `json:"timestamp"`
}

// LedgerService defines the interface for interacting with an immutable ledger.
// This allows for different implementations (e.g., QLDB, Azure SQL Ledger, ImmuDB).
type LedgerService interface {
	// LogPropertyCreation logs a property creation event.
	LogPropertyCreation(property domain.Property, userID uint) error

	// LogTransferEvent logs a transfer event (creation or update).
	LogTransferEvent(transfer domain.Transfer, serialNumber string) error

	// LogStatusChange logs a status change event for a property.
	LogStatusChange(propertyID uint, serialNumber string, oldStatus string, newStatus string, userID uint) error

	// LogVerificationEvent logs a verification event for a property.
	LogVerificationEvent(propertyID uint, serialNumber string, userID uint, verificationType string) error

	// LogMaintenanceEvent logs a maintenance event for a property.
	LogMaintenanceEvent(maintenanceRecordID string, propertyID uint, initiatingUserID uint, performingUserID sql.NullInt64, eventType string, maintenanceType sql.NullString, description string) error

	// LogDA2062Export logs a DA Form 2062 export event.
	LogDA2062Export(userID uint, propertyCount int, exportType string, recipients string) error

	// LogComponentAttached logs when a component is attached to a parent property.
	LogComponentAttached(parentPropertyID uint, componentPropertyID uint, userID uint, position string, notes string) error

	// LogComponentDetached logs when a component is detached from a parent property.
	LogComponentDetached(parentPropertyID uint, componentPropertyID uint, userID uint) error

	// LogDocumentEvent logs a document event (creation, read, etc.).
	LogDocumentEvent(documentID uint, eventType string, senderUserID uint, recipientUserID uint) error

	// LogCorrectionEvent logs a correction event referencing a previous ledger event.
	LogCorrectionEvent(originalEventID string, eventType string, reason string, userID uint) error

	// LogEvent logs a generic event for flexibility
	LogEvent(ctx context.Context, event Event) error

	// LogDA2062Import logs a complete DA2062 import event
	LogDA2062Import(ctx context.Context, event DA2062Event) error


	// GetPropertyHistory retrieves the history of a property based on its ID.
	GetPropertyHistory(propertyID uint) ([]map[string]interface{}, error)

	// VerifyDocument checks the integrity of a ledger document (implementation specific).
	// For development, this might always return true.
	// For Azure SQL Ledger, this would involve calling verification stored procedures/functions.
	VerifyDocument(documentID string, tableName string) (bool, error)

	// Query Correction Events
	GetAllCorrectionEvents() ([]domain.CorrectionEvent, error)
	GetCorrectionEventsByOriginalID(originalEventID string) ([]domain.CorrectionEvent, error)
	GetCorrectionEventByID(eventID string) (*domain.CorrectionEvent, error)

	// GetGeneralHistory retrieves a consolidated view of all ledger event types.
	// TODO: Add filtering/pagination parameters (e.g., time range, event type, user ID, property ID).
	GetGeneralHistory() ([]domain.GeneralLedgerEvent, error)

	// Initialize prepares the ledger service (e.g., connects, ensures tables/ledger exist).
	Initialize() error

	// Close cleans up resources used by the ledger service.
	Close() error
}
