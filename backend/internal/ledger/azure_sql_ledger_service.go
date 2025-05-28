package ledger

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	_ "github.com/microsoft/go-mssqldb" // Azure SQL Database driver
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	// Consider using Viper for configuration management if not already set up globally
)

// Ensure AzureSqlLedgerService implements LedgerService interface at compile time
var _ LedgerService = (*AzureSqlLedgerService)(nil)

// AzureSqlLedgerService implements the LedgerService interface for Azure SQL Database Ledger.
type AzureSqlLedgerService struct {
	db *sql.DB // Standard SQL database connection pool
	// Add configuration fields if needed (e.g., table names)
}

// NewAzureSqlLedgerService creates a new Azure SQL Database Ledger service.
// It requires database connection details, likely fetched from configuration.
func NewAzureSqlLedgerService(connectionString string) (*AzureSqlLedgerService, error) {
	// TODO: Make sure the correct Azure SQL driver is imported above
	// Use sql.Open() with the appropriate driver name ("sqlserver" for go-mssqldb)
	db, err := sql.Open("sqlserver", connectionString) // Replace "sqlserver" if using a different driver name
	if err != nil {
		return nil, fmt.Errorf("error opening Azure SQL connection: %w", err)
	}

	// Ping the database to verify the connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second) // Add timeout
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		db.Close() // Close the connection if ping fails
		return nil, fmt.Errorf("error pinging Azure SQL database: %w", err)
	}

	log.Println("Successfully connected to Azure SQL Database")

	service := &AzureSqlLedgerService{
		db: db,
	}

	return service, nil
}

// Initialize performs any setup needed for the ledger service.
// For Azure SQL, this might involve ensuring ledger tables exist or are configured.
func (s *AzureSqlLedgerService) Initialize() error {
	// TODO: Optionally, check if required ledger tables exist and create/configure if needed.
	// This might involve executing `CREATE TABLE ... WITH (SYSTEM_VERSIONING = ON, LEDGER = ON)` statements.
	// Be cautious about auto-creating tables in production environments.
	log.Println("AzureSqlLedgerService Initialize: No specific initialization actions implemented yet.")
	return nil
}

// LogItemCreation logs an equipment creation/registration event to the Azure SQL Ledger.
// This implementation assumes the event type is 'Created' based on the function name.
func (s *AzureSqlLedgerService) LogItemCreation(property domain.Property, userID uint) error {
	ctx := context.Background() // Or use a more specific context if available
	log.Printf("AzureSqlLedgerService: Logging Equipment Event - ItemID: %d, UserID: %d, Type: Created", property.ID, userID)

	// EventType is hardcoded to 'Created' for this function
	const eventType = "Created"
	// Notes are not provided by the interface, setting to NULL
	var notes sql.NullString

	_, err := s.db.ExecContext(ctx,
		`INSERT INTO HandReceipt.EquipmentEvents (ItemID, PerformingUserID, EventType, Notes, EventTimestamp)
		 VALUES (@p1, @p2, @p3, @p4, SYSUTCDATETIME())`, // Use SYSUTCDATETIME() for DB-generated timestamp
		property.ID, // Get ItemID from the domain.Property object
		userID,      // UserID passed as argument
		eventType,
		notes, // Pass NULL for notes
	)

	if err != nil {
		log.Printf("Error logging Equipment Event to Azure SQL Ledger: %v", err)
		return fmt.Errorf("failed to log Equipment Event: %w", err)
	}
	log.Printf("Successfully logged Equipment Event - ItemID: %d, Type: %s", property.ID, eventType)
	return nil
}

// LogTransferEvent logs a specific stage of an equipment transfer to the Azure SQL Ledger.
// It uses the transfer.Status as the EventType for the ledger entry.
func (s *AzureSqlLedgerService) LogTransferEvent(transfer domain.Transfer, serialNumber string) error {
	ctx := context.Background()
	eventType := transfer.Status // Map domain.Transfer.Status to EventType
	// Use transfer.ID as the grouping identifier for the request. Convert uint to string.
	transferRequestID := fmt.Sprintf("%d", transfer.ID)

	log.Printf("AzureSqlLedgerService: Logging Transfer Event - RequestID: %s, ItemID: %d, SN: %s, Type: %s", transferRequestID, transfer.PropertyID, serialNumber, eventType)

	// Validate EventType (derived from transfer.Status) against allowed values in the schema
	allowedTypes := map[string]bool{"Requested": true, "Approved": true, "Rejected": true, "Completed": true, "Cancelled": true}
	if !allowedTypes[eventType] {
		return fmt.Errorf("invalid EventType (from transfer.Status) '%s' for TransferEvents", eventType)
	}

	// Assumptions:
	// - InitiatingUserID is the FromUserID for this event log.
	// - ApprovingUserID is not provided by the interface, setting to NULL.
	initiatingUserID := transfer.FromUserID
	var approvingUserID sql.NullInt64 // Set to NULL
	// Handle optional notes from domain.Transfer
	notesDB := sql.NullString{}
	if transfer.Notes != nil {
		notesDB.String = *transfer.Notes
		notesDB.Valid = true
	}

	_, err := s.db.ExecContext(ctx,
		`INSERT INTO HandReceipt.TransferEvents (TransferRequestID, ItemID, FromUserID, ToUserID, InitiatingUserID, ApprovingUserID, EventType, Notes, EventTimestamp)
		 VALUES (@p1, @p2, @p3, @p4, @p5, @p6, @p7, @p8, SYSUTCDATETIME())`,
		transferRequestID,
		transfer.PropertyID,
		transfer.FromUserID,
		transfer.ToUserID,
		initiatingUserID, // Assumed initiator
		approvingUserID,  // Assumed NULL approver
		eventType,
		notesDB, // Use sql.NullString for nullable notes
	)

	if err != nil {
		log.Printf("Error logging Transfer Event to Azure SQL Ledger: %v", err)
		return fmt.Errorf("failed to log Transfer Event: %w", err)
	}
	log.Printf("Successfully logged Transfer Event - RequestID: %s, ItemID: %d, Type: %s", transferRequestID, transfer.PropertyID, eventType)
	return nil
}

// LogStatusChange logs a status change event for an item to the Azure SQL Ledger.
func (s *AzureSqlLedgerService) LogStatusChange(itemID uint, serialNumber string, oldStatus string, newStatus string, userID uint) error {
	ctx := context.Background() // Or use a more specific context if available
	// Log using provided parameters, including serialNumber even if not directly inserted
	log.Printf("AzureSqlLedgerService: Logging Status Change - ItemID: %d, SN: %s, UserID: %d, FromStatus: %s, ToStatus: %s", itemID, serialNumber, userID, oldStatus, newStatus)

	// Validate NewStatus against allowed values in the schema
	allowedStatuses := map[string]bool{"Operational": true, "Non-Operational": true, "Damaged": true, "Lost": true, "Found": true, "In Repair": true}
	if !allowedStatuses[newStatus] {
		return fmt.Errorf("invalid NewStatus '%s' for StatusChangeEvents", newStatus)
	}

	// Prepare parameters for DB insertion
	previousStatusDB := sql.NullString{String: oldStatus, Valid: oldStatus != ""}
	// Reason is not provided by the interface, set to NULL
	var reasonDB sql.NullString

	_, err := s.db.ExecContext(ctx,
		`INSERT INTO HandReceipt.StatusChangeEvents (ItemID, ReportingUserID, PreviousStatus, NewStatus, Reason, ChangeTimestamp)
		 VALUES (@p1, @p2, @p3, @p4, @p5, SYSUTCDATETIME())`,
		itemID,
		userID,           // Map userID from interface to ReportingUserID
		previousStatusDB, // Use sql.NullString for nullable PreviousStatus
		newStatus,
		reasonDB, // Pass NULL for Reason
	)

	if err != nil {
		log.Printf("Error logging Status Change event to Azure SQL Ledger: %v", err)
		return fmt.Errorf("failed to log Status Change event: %w", err)
	}
	log.Printf("Successfully logged Status Change - ItemID: %d, NewStatus: %s", itemID, newStatus)
	return nil
}

// LogVerificationEvent logs a verification event for an item to the Azure SQL Ledger.
// Maps the interface's verificationType to the DB's VerificationStatus.
func (s *AzureSqlLedgerService) LogVerificationEvent(itemID uint, serialNumber string, userID uint, verificationType string) error {
	ctx := context.Background()            // Or use a more specific context if available
	verificationStatus := verificationType // Map interface param to DB column meaning

	log.Printf("AzureSqlLedgerService: Logging Verification Event - ItemID: %d, SN: %s, UserID: %d, Status(Type): %s", itemID, serialNumber, userID, verificationStatus)

	// Validate VerificationStatus (from verificationType) against allowed values in the schema
	allowedStatuses := map[string]bool{"Verified Present": true, "Missing": true, "Requires Attention": true, "Status Unchanged": true}
	if !allowedStatuses[verificationStatus] {
		// Allow any string if validation needs to be less strict? Or return error?
		// Returning error for now to enforce schema constraints.
		return fmt.Errorf("invalid VerificationStatus (from verificationType) '%s' for VerificationEvents", verificationStatus)
	}

	// Notes are not provided by the interface, setting to NULL
	var notesDB sql.NullString

	_, err := s.db.ExecContext(ctx,
		`INSERT INTO HandReceipt.VerificationEvents (ItemID, VerifyingUserID, VerificationStatus, Notes, VerificationTimestamp)
		 VALUES (@p1, @p2, @p3, @p4, SYSUTCDATETIME())`,
		itemID,
		userID, // Map userID from interface to VerifyingUserID
		verificationStatus,
		notesDB, // Pass NULL for Notes
	)

	if err != nil {
		log.Printf("Error logging Verification event to Azure SQL Ledger: %v", err)
		return fmt.Errorf("failed to log Verification event: %w", err)
	}
	log.Printf("Successfully logged Verification Event - ItemID: %d, Status: %s", itemID, verificationStatus)
	return nil
}

// LogMaintenanceEvent logs a maintenance event for an item to the Azure SQL Ledger.
func (s *AzureSqlLedgerService) LogMaintenanceEvent(maintenanceRecordID string, itemID uint, initiatingUserID uint, performingUserID sql.NullInt64, eventType string, maintenanceType sql.NullString, description string) error {
	ctx := context.Background()
	log.Printf("AzureSqlLedgerService: Logging Maintenance Event - RecordID: %s, ItemID: %d, Type: %s", maintenanceRecordID, itemID, eventType)

	// Validate EventType against allowed values
	allowedTypes := map[string]bool{"Scheduled": true, "Started": true, "Completed": true, "Cancelled": true, "Reported Defect": true}
	if !allowedTypes[eventType] {
		return fmt.Errorf("invalid EventType '%s' for MaintenanceEvents", eventType)
	}

	// Ensure performingUserID is null if not applicable
	if eventType != "Started" && eventType != "Completed" {
		performingUserID = sql.NullInt64{}
	}

	_, err := s.db.ExecContext(ctx,
		`INSERT INTO HandReceipt.MaintenanceEvents (MaintenanceRecordID, ItemID, InitiatingUserID, PerformingUserID, EventType, MaintenanceType, Description, EventTimestamp)
		 VALUES (@p1, @p2, @p3, @p4, @p5, @p6, @p7, SYSUTCDATETIME())`,
		maintenanceRecordID,
		itemID,
		initiatingUserID,
		performingUserID,
		eventType,
		maintenanceType, // sql.NullString for nullable NVARCHAR
		sql.NullString{String: description, Valid: description != ""}, // Handle optional description
	)

	if err != nil {
		log.Printf("Error logging Maintenance event to Azure SQL Ledger: %v", err)
		return fmt.Errorf("failed to log Maintenance event: %w", err)
	}
	log.Printf("Successfully logged Maintenance Event - RecordID: %s, ItemID: %d, Type: %s", maintenanceRecordID, itemID, eventType)
	return nil
}

// LogCorrectionEvent logs a correction event referencing a previous ledger event.
// NOTE: How corrections are handled in Azure SQL Ledger needs a defined strategy.
// Common approaches include:
//  1. Using updatable ledger tables (requires specific table creation options).
//  2. Inserting a 'correction' record into a dedicated corrections table or the original table,
//     referencing the transaction ID or EventID of the record being corrected.
//
// This function implements Strategy A (Separate Correction Table).
func (s *AzureSqlLedgerService) LogCorrectionEvent(originalEventID string, eventType string, reason string, userID uint) error {
	ctx := context.Background()
	log.Printf("AzureSqlLedgerService: Logging correction event for Original Event: %s (Type: %s) by UserID: %d", originalEventID, eventType, userID)

	// Basic validation (consider adding more robust validation if needed)
	if originalEventID == "" || eventType == "" || reason == "" {
		return fmt.Errorf("missing required parameters for correction event")
	}

	// Assuming OriginalEventID is provided as a string representation of a UNIQUEIDENTIFIER
	// SQL Server will handle the conversion if the string format is correct.
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO HandReceipt.CorrectionEvents (OriginalEventID, OriginalEventType, Reason, CorrectingUserID, CorrectionTimestamp)
		 VALUES (@p1, @p2, @p3, @p4, SYSUTCDATETIME())`,
		originalEventID,
		eventType,
		reason,
		userID,
	)

	if err != nil {
		log.Printf("Error logging correction event to Azure SQL Ledger: %v", err)
		return fmt.Errorf("failed to log correction event: %w", err)
	}

	log.Printf("Successfully logged correction event for Original Event ID: %s", originalEventID)
	return nil
}

// GetItemHistory retrieves the history of an item from the Azure SQL Ledger tables based on its ItemID.
func (s *AzureSqlLedgerService) GetItemHistory(itemID uint) ([]map[string]interface{}, error) {
	ctx := context.Background()
	log.Printf("AzureSqlLedgerService: Getting history for ItemID: %d", itemID)
	var history []map[string]interface{}

	// Query across all relevant ledger history views using UNION ALL.
	// Filter each part of the UNION by ItemID.
	// Order the final result set by EventTimestamp.
	query := `
	SELECT
		'EquipmentEvent' as RecordType, EventID, ItemID, PerformingUserID, EventTimestamp, EventType, Notes,
		ledger_transaction_id, ledger_sequence_number, ledger_operation_type_desc
	FROM HandReceipt.EquipmentEvents_LedgerHistory
	WHERE ItemID = @p1
	UNION ALL
	SELECT
		'TransferEvent' as RecordType, EventID, ItemID, FromUserID, ToUserID, InitiatingUserID, ApprovingUserID, EventTimestamp, EventType, Notes,
		ledger_transaction_id, ledger_sequence_number, ledger_operation_type_desc
	FROM HandReceipt.TransferEvents_LedgerHistory
	WHERE ItemID = @p1
	UNION ALL
	SELECT
		'VerificationEvent' as RecordType, EventID, ItemID, VerifyingUserID, VerificationTimestamp AS EventTimestamp, VerificationStatus AS EventType, Notes, -- Aliasing columns for consistency
		ledger_transaction_id, ledger_sequence_number, ledger_operation_type_desc
	FROM HandReceipt.VerificationEvents_LedgerHistory
	WHERE ItemID = @p1
	UNION ALL
	SELECT
		'MaintenanceEvent' as RecordType, EventID, ItemID, InitiatingUserID, PerformingUserID, EventTimestamp, EventType, Description AS Notes, -- Aliasing Description to Notes
		ledger_transaction_id, ledger_sequence_number, ledger_operation_type_desc
	FROM HandReceipt.MaintenanceEvents_LedgerHistory
	WHERE ItemID = @p1
	UNION ALL
	SELECT
		'StatusChangeEvent' as RecordType, EventID, ItemID, ReportingUserID, ChangeTimestamp AS EventTimestamp, NewStatus AS EventType, Reason AS Notes, -- Aliasing columns
		ledger_transaction_id, ledger_sequence_number, ledger_operation_type_desc
	FROM HandReceipt.StatusChangeEvents_LedgerHistory
	WHERE ItemID = @p1
	ORDER BY EventTimestamp ASC;
	`

	rows, err := s.db.QueryContext(ctx, query, itemID) // Use itemID in query
	if err != nil {
		log.Printf("Error querying item history by ItemID from Azure SQL Ledger: %v", err)
		return nil, fmt.Errorf("failed to query item history by ItemID: %w", err)
	}
	defer rows.Close()

	cols, err := rows.Columns()
	if err != nil {
		log.Printf("Error getting columns for history query: %v", err)
		return nil, fmt.Errorf("failed to get history columns: %w", err)
	}

	for rows.Next() {
		// Create a slice of interface{}'s to represent the row's values.
		columns := make([]interface{}, len(cols))
		columnPointers := make([]interface{}, len(cols))
		for i := range columns {
			columnPointers[i] = &columns[i]
		}

		// Scan the result into the column pointers...
		if err := rows.Scan(columnPointers...); err != nil {
			log.Printf("Error scanning history row: %v", err)
			// Consider continuing and logging error vs returning partial history
			return nil, fmt.Errorf("failed to scan history row: %w", err)
		}

		// Create map for the row
		m := make(map[string]interface{})
		for i, colName := range cols {
			val := columnPointers[i].(*interface{})
			// Assign value, handling potential NULLs from the DB explicitly if necessary
			if *val == nil {
				m[colName] = nil
			} else {
				// Convert []byte to string for simplicity, handle other types as needed
				switch v := (*val).(type) {
				case []byte:
					m[colName] = string(v)
				case time.Time: // Format timestamps nicely
					m[colName] = v.Format(time.RFC3339)
				default:
					m[colName] = *val
				}
			}
		}
		history = append(history, m)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating history rows: %v", err)
		return nil, fmt.Errorf("failed during history row iteration: %w", err)
	}

	log.Printf("Retrieved %d history events for ItemID: %d", len(history), itemID)
	return history, nil
}

// GetAllCorrectionEvents retrieves all correction events from the ledger.
func (s *AzureSqlLedgerService) GetAllCorrectionEvents() ([]domain.CorrectionEvent, error) {
	ctx := context.Background()
	log.Println("AzureSqlLedgerService: Getting all correction events")

	query := `SELECT EventID, OriginalEventID, OriginalEventType, Reason, CorrectingUserID, CorrectionTimestamp, ledger_transaction_id, ledger_sequence_number
			 FROM HandReceipt.CorrectionEvents_LedgerHistory ORDER BY CorrectionTimestamp DESC` // Use history view

	rows, err := s.db.QueryContext(ctx, query)
	if err != nil {
		log.Printf("Error querying all correction events: %v", err)
		return nil, fmt.Errorf("failed to query correction events: %w", err)
	}
	defer rows.Close()

	return scanCorrectionEvents(rows)
}

// GetCorrectionEventsByOriginalID retrieves correction events related to a specific original event ID.
func (s *AzureSqlLedgerService) GetCorrectionEventsByOriginalID(originalEventID string) ([]domain.CorrectionEvent, error) {
	ctx := context.Background()
	log.Printf("AzureSqlLedgerService: Getting correction events for OriginalEventID: %s", originalEventID)

	query := `SELECT EventID, OriginalEventID, OriginalEventType, Reason, CorrectingUserID, CorrectionTimestamp, ledger_transaction_id, ledger_sequence_number
			 FROM HandReceipt.CorrectionEvents_LedgerHistory
			 WHERE OriginalEventID = @p1 ORDER BY CorrectionTimestamp DESC` // Use history view

	rows, err := s.db.QueryContext(ctx, query, originalEventID)
	if err != nil {
		log.Printf("Error querying correction events by original ID: %v", err)
		return nil, fmt.Errorf("failed to query correction events by original ID: %w", err)
	}
	defer rows.Close()

	return scanCorrectionEvents(rows)
}

// GetCorrectionEventByID retrieves a specific correction event by its own EventID.
func (s *AzureSqlLedgerService) GetCorrectionEventByID(eventID string) (*domain.CorrectionEvent, error) {
	ctx := context.Background()
	log.Printf("AzureSqlLedgerService: Getting correction event by EventID: %s", eventID)

	query := `SELECT TOP 1 EventID, OriginalEventID, OriginalEventType, Reason, CorrectingUserID, CorrectionTimestamp, ledger_transaction_id, ledger_sequence_number
			 FROM HandReceipt.CorrectionEvents_LedgerHistory
			 WHERE EventID = @p1` // Use history view

	rows, err := s.db.QueryContext(ctx, query, eventID)
	if err != nil {
		log.Printf("Error querying correction event by ID: %v", err)
		return nil, fmt.Errorf("failed to query correction event by ID: %w", err)
	}
	defer rows.Close()

	events, err := scanCorrectionEvents(rows)
	if err != nil {
		return nil, err
	}
	if len(events) == 0 {
		return nil, nil // Not found
	}
	return &events[0], nil
}

// scanCorrectionEvents is a helper function to scan sql.Rows into a slice of CorrectionEvent.
func scanCorrectionEvents(rows *sql.Rows) ([]domain.CorrectionEvent, error) {
	var events []domain.CorrectionEvent
	for rows.Next() {
		var event domain.CorrectionEvent
		// Need pointers for nullable ledger metadata
		var ledgerTxID sql.NullInt64
		var ledgerSeqNum sql.NullInt64
		// Need strings for GUIDs coming from DB
		var eventIDStr, originalEventIDStr string

		if err := rows.Scan(
			&eventIDStr,         // Scan GUID as string
			&originalEventIDStr, // Scan GUID as string
			&event.OriginalEventType,
			&event.Reason,
			&event.CorrectingUserID, // Scan BIGINT as uint64
			&event.CorrectionTimestamp,
			&ledgerTxID,
			&ledgerSeqNum,
		); err != nil {
			log.Printf("Error scanning correction event row: %v", err)
			return nil, fmt.Errorf("failed to scan correction event row: %w", err)
		}

		// Assign scanned strings to struct fields
		event.EventID = eventIDStr
		event.OriginalEventID = originalEventIDStr

		// Assign nullable ledger metadata
		if ledgerTxID.Valid {
			event.LedgerTransactionID = &ledgerTxID.Int64
		}
		if ledgerSeqNum.Valid {
			event.LedgerSequenceNumber = &ledgerSeqNum.Int64
		}

		events = append(events, event)
	}

	if err := rows.Err(); err != nil {
		log.Printf("Error iterating correction event rows: %v", err)
		return nil, fmt.Errorf("failed during correction event row iteration: %w", err)
	}
	return events, nil
}

// GetGeneralHistory retrieves a consolidated view of all ledger event types.
func (s *AzureSqlLedgerService) GetGeneralHistory() ([]domain.GeneralLedgerEvent, error) {
	ctx := context.Background()
	log.Println("AzureSqlLedgerService: Getting general ledger history")
	var history []domain.GeneralLedgerEvent

	// Combine history views using UNION ALL, mapping columns to GeneralLedgerEvent
	// NOTE: JSON_OBJECT requires SQL Server 2022+. Use string concatenation or fetch individual
	// fields and build JSON in Go for older versions.
	// Ensure correct column names based on your schema (e.g., UserID vs PerformingUserID)
	query := `
	WITH CombinedHistory AS (
		-- Equipment Events
		SELECT
			EventID AS eventId,
			'EquipmentEvent' AS eventType,
			EventTimestamp AS timestamp,
			TRY_CAST(PerformingUserID AS BIGINT) AS userId,
			TRY_CAST(ItemID AS BIGINT) AS itemId,
			JSON_OBJECT(
				'eventTypeDetail': EventType,
				'notes': Notes
			) AS detailsJson, -- Construct JSON details
			ledger_transaction_id AS ledgerTransactionId,
			ledger_sequence_number AS ledgerSequenceNumber
		FROM HandReceipt.EquipmentEvents_LedgerHistory

		UNION ALL

		-- Transfer Events
		SELECT
			EventID AS eventId,
			'TransferEvent' AS eventType,
			EventTimestamp AS timestamp,
			TRY_CAST(InitiatingUserID AS BIGINT) AS userId, -- Or ApprovingUserID depending on context needed
			TRY_CAST(ItemID AS BIGINT) AS itemId,
			JSON_OBJECT(
				'transferRequestId': TransferRequestID,
				'fromUserId': FromUserID,
				'toUserId': ToUserID,
				'eventTypeDetail': EventType,
				'notes': Notes
			) AS detailsJson,
			ledger_transaction_id AS ledgerTransactionId,
			ledger_sequence_number AS ledgerSequenceNumber
		FROM HandReceipt.TransferEvents_LedgerHistory

		UNION ALL

		-- Verification Events
		SELECT
			EventID AS eventId,
			'VerificationEvent' AS eventType,
			VerificationTimestamp AS timestamp,
			TRY_CAST(VerifyingUserID AS BIGINT) AS userId,
			TRY_CAST(ItemID AS BIGINT) AS itemId,
			JSON_OBJECT(
				'verificationStatus': VerificationStatus,
				'notes': Notes
			) AS detailsJson,
			ledger_transaction_id AS ledgerTransactionId,
			ledger_sequence_number AS ledgerSequenceNumber
		FROM HandReceipt.VerificationEvents_LedgerHistory

		UNION ALL

		-- Maintenance Events
		SELECT
			EventID AS eventId,
			'MaintenanceEvent' AS eventType,
			EventTimestamp AS timestamp,
			TRY_CAST(InitiatingUserID AS BIGINT) AS userId, -- Or PerformingUserID
			TRY_CAST(ItemID AS BIGINT) AS itemId,
			JSON_OBJECT(
				'maintenanceRecordId': MaintenanceRecordID,
				'eventTypeDetail': EventType,
				'maintenanceType': MaintenanceType,
				'description': Description
			) AS detailsJson,
			ledger_transaction_id AS ledgerTransactionId,
			ledger_sequence_number AS ledgerSequenceNumber
		FROM HandReceipt.MaintenanceEvents_LedgerHistory

		UNION ALL

		-- Status Change Events
		SELECT
			EventID AS eventId,
			'StatusChangeEvent' AS eventType,
			ChangeTimestamp AS timestamp,
			TRY_CAST(ReportingUserID AS BIGINT) AS userId,
			TRY_CAST(ItemID AS BIGINT) AS itemId,
			JSON_OBJECT(
				'previousStatus': PreviousStatus,
				'newStatus': NewStatus,
				'reason': Reason
			) AS detailsJson,
			ledger_transaction_id AS ledgerTransactionId,
			ledger_sequence_number AS ledgerSequenceNumber
		FROM HandReceipt.StatusChangeEvents_LedgerHistory
	)
	SELECT eventId, eventType, timestamp, userId, itemId, detailsJson, ledgerTransactionId, ledgerSequenceNumber
	FROM CombinedHistory
	ORDER BY timestamp DESC; -- Order by most recent first
	`

	rows, err := s.db.QueryContext(ctx, query)
	if err != nil {
		log.Printf("Error querying general history from Azure SQL Ledger: %v", err)
		return nil, fmt.Errorf("failed to query general history: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var event domain.GeneralLedgerEvent
		var detailsJSON string // Scan JSON details as string
		// Use sql.Null types for potentially null fields from the DB
		var eventIDStr sql.NullString
		var userID sql.NullInt64
		var itemID sql.NullInt64
		var ledgerTxID sql.NullInt64
		var ledgerSeqNum sql.NullInt64

		if err := rows.Scan(
			&eventIDStr,
			&event.EventType,
			&event.Timestamp,
			&userID,
			&itemID,
			&detailsJSON,
			&ledgerTxID,
			&ledgerSeqNum,
		); err != nil {
			log.Printf("Error scanning general history row: %v", err)
			return nil, fmt.Errorf("failed to scan general history row: %w", err)
		}

		// Assign scanned values, handling potential NULLs
		if eventIDStr.Valid {
			event.EventID = eventIDStr.String
		}
		if userID.Valid {
			u64 := uint64(userID.Int64)
			event.UserID = &u64
		}
		if itemID.Valid {
			i64 := uint64(itemID.Int64)
			event.ItemID = &i64
		}
		if ledgerTxID.Valid {
			event.LedgerTransactionID = &ledgerTxID.Int64
		}
		if ledgerSeqNum.Valid {
			event.LedgerSequenceNumber = &ledgerSeqNum.Int64
		}

		// Unmarshal the JSON details string into the 'any' field
		if detailsJSON != "" {
			// Use json.Unmarshal or a similar library
			// For simplicity, we might just assign the raw string if the frontend can handle it,
			// or unmarshal into a map[string]interface{}
			var detailsMap map[string]interface{}
			if err := json.Unmarshal([]byte(detailsJSON), &detailsMap); err == nil {
				event.Details = detailsMap
			} else {
				log.Printf("Warning: Failed to unmarshal details JSON for event %s: %v", event.EventID, err)
				event.Details = detailsJSON // Assign raw string as fallback
			}
		} else {
			event.Details = nil // Or an empty map: map[string]interface{}{}
		}

		history = append(history, event)
	}

	if err = rows.Err(); err != nil {
		log.Printf("Error iterating general history rows: %v", err)
		return nil, fmt.Errorf("failed during general history row iteration: %w", err)
	}

	log.Printf("Retrieved %d general history events", len(history))
	return history, nil
}

// VerifyDocument checks the integrity of the database ledger using Azure SQL Ledger's built-in procedure.
// NOTE: This implementation uses `sys.sp_verify_database_ledger` which verifies the *entire database*.
// The interface parameters `documentID` and `tableName` are currently ignored.
// True verification often involves comparing current database digests with previously stored, trusted digests.
func (s *AzureSqlLedgerService) VerifyDocument(documentID string, tableName string) (bool, error) {
	ctx := context.Background()
	log.Printf("AzureSqlLedgerService: Verifying ledger integrity (Database-wide check). Called with documentID: '%s', tableName: '%s' (parameters ignored).", documentID, tableName)

	// This procedure verifies the integrity of all ledger tables in the database.
	_, err := s.db.ExecContext(ctx, "EXEC sys.sp_verify_database_ledger")
	if err != nil {
		// The error message itself often indicates if verification passed but encountered issues,
		// or if it failed due to tampering. Parsing the specific error might be needed for robust handling.
		log.Printf("Ledger verification stored procedure failed or reported inconsistencies: %v", err)
		// For now, assume any error means verification failed or could not complete.
		return false, fmt.Errorf("ledger verification failed or could not be completed: %w", err)
	}

	// If the stored procedure executes without raising an error, the ledger structures are intact.
	log.Println("Ledger verification procedure executed successfully, indicating ledger integrity.")
	return true, nil
}

// Close cleans up resources, specifically closing the database connection pool.
func (s *AzureSqlLedgerService) Close() error {
	if s.db != nil {
		log.Println("Closing Azure SQL Database connection")
		return s.db.Close()
	}
	return nil
}
