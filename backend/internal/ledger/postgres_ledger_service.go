package ledger

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"crypto/sha256"
	"encoding/hex"

	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"gorm.io/gorm"
)

// Ensure PostgresLedgerService implements LedgerService interface at compile time
var _ LedgerService = (*PostgresLedgerService)(nil)

// PostgresLedgerService implements the LedgerService interface using PostgreSQL
type PostgresLedgerService struct {
	db  *gorm.DB
	ctx context.Context
}

// LedgerEntry represents an immutable ledger entry in PostgreSQL
type LedgerEntry struct {
	ID        uint      `gorm:"primaryKey;autoIncrement"`
	EventID   string    `gorm:"uniqueIndex;not null"`
	EventType string    `gorm:"not null;index"`
	EventData string    `gorm:"type:jsonb;not null"`
	Hash      string    `gorm:"not null"`
	PrevHash  string    `gorm:"not null"`
	CreatedAt time.Time `gorm:"not null;default:CURRENT_TIMESTAMP"`
	CreatedBy uint      `gorm:"not null"`
}

// NewPostgresLedgerService creates a new PostgreSQL ledger service
func NewPostgresLedgerService(db *gorm.DB) (*PostgresLedgerService, error) {
	log.Println("Creating PostgreSQL Ledger Service")

	service := &PostgresLedgerService{
		db:  db,
		ctx: context.Background(),
	}

	// Auto-migrate the ledger table
	if err := db.AutoMigrate(&LedgerEntry{}); err != nil {
		return nil, fmt.Errorf("failed to migrate ledger table: %w", err)
	}

	// Create immutability trigger
	if err := service.createImmutabilityTrigger(); err != nil {
		return nil, fmt.Errorf("failed to create immutability trigger: %w", err)
	}

	log.Println("Successfully initialized PostgreSQL Ledger Service")
	return service, nil
}

// createImmutabilityTrigger creates a PostgreSQL trigger to prevent updates and deletes
func (s *PostgresLedgerService) createImmutabilityTrigger() error {
	// Create function to prevent updates and deletes
	createFunctionSQL := `
	CREATE OR REPLACE FUNCTION prevent_ledger_modification()
	RETURNS TRIGGER AS $$
	BEGIN
		RAISE EXCEPTION 'Ledger entries are immutable and cannot be modified or deleted';
	END;
	$$ LANGUAGE plpgsql;
	`

	// Create triggers for UPDATE and DELETE
	createUpdateTriggerSQL := `
	CREATE OR REPLACE TRIGGER prevent_ledger_update
	BEFORE UPDATE ON ledger_entries
	FOR EACH ROW
	EXECUTE FUNCTION prevent_ledger_modification();
	`

	createDeleteTriggerSQL := `
	CREATE OR REPLACE TRIGGER prevent_ledger_delete
	BEFORE DELETE ON ledger_entries
	FOR EACH ROW
	EXECUTE FUNCTION prevent_ledger_modification();
	`

	// Create indexes for better query performance
	createIndexesSQL := []string{
		`CREATE INDEX IF NOT EXISTS idx_ledger_entries_event_type ON ledger_entries(event_type);`,
		`CREATE INDEX IF NOT EXISTS idx_ledger_entries_created_at ON ledger_entries(created_at);`,
		`CREATE INDEX IF NOT EXISTS idx_ledger_entries_created_by ON ledger_entries(created_by);`,
		`CREATE INDEX IF NOT EXISTS idx_ledger_entries_event_data ON ledger_entries USING gin(event_data::jsonb);`,
	}

	// Execute the SQL statements
	if err := s.db.Exec(createFunctionSQL).Error; err != nil {
		log.Printf("Warning: Could not create immutability function: %v", err)
	}

	if err := s.db.Exec(createUpdateTriggerSQL).Error; err != nil {
		log.Printf("Warning: Could not create update trigger: %v", err)
	}

	if err := s.db.Exec(createDeleteTriggerSQL).Error; err != nil {
		log.Printf("Warning: Could not create delete trigger: %v", err)
	}

	// Create indexes
	for _, indexSQL := range createIndexesSQL {
		if err := s.db.Exec(indexSQL).Error; err != nil {
			log.Printf("Warning: Could not create index: %v", err)
		}
	}

	return nil
}

// Initialize performs any setup needed for the ledger service
func (s *PostgresLedgerService) Initialize() error {
	log.Println("PostgresLedgerService Initialize: PostgreSQL Ledger is ready")
	return nil
}

// calculateHash calculates a SHA-256 hash for the event data including the previous hash
func (s *PostgresLedgerService) calculateHash(eventData string, prevHash string) string {
	// Create a string combining event data, previous hash, and timestamp for uniqueness
	data := fmt.Sprintf("%s:%s:%d", eventData, prevHash, time.Now().UnixNano())

	// Calculate SHA-256 hash
	hash := sha256.Sum256([]byte(data))

	// Return hex-encoded hash
	return hex.EncodeToString(hash[:])
}

// getLastHash retrieves the hash of the last entry in the ledger
func (s *PostgresLedgerService) getLastHash() string {
	var lastEntry LedgerEntry
	if err := s.db.Order("id DESC").First(&lastEntry).Error; err != nil {
		// If no entries exist, return genesis hash
		return "GENESIS"
	}
	return lastEntry.Hash
}

// storeEvent stores an event in the immutable ledger
func (s *PostgresLedgerService) storeEvent(eventID string, event map[string]interface{}) error {
	eventJSON, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("failed to marshal event: %w", err)
	}

	// Get the previous hash for chain integrity
	prevHash := s.getLastHash()

	// Calculate hash for this entry
	hash := s.calculateHash(string(eventJSON), prevHash)

	// Extract user ID from event if available
	var createdBy uint
	if userID, ok := event["user_id"].(uint); ok {
		createdBy = userID
	} else if userID, ok := event["user_id"].(float64); ok {
		createdBy = uint(userID)
	} else if userID, ok := event["initiating_user_id"].(uint); ok {
		createdBy = userID
	} else if userID, ok := event["sender_user_id"].(uint); ok {
		createdBy = userID
	}

	// Create ledger entry
	entry := LedgerEntry{
		EventID:   eventID,
		EventType: event["event_type"].(string),
		EventData: string(eventJSON),
		Hash:      hash,
		PrevHash:  prevHash,
		CreatedBy: createdBy,
	}

	// Store in database
	if err := s.db.Create(&entry).Error; err != nil {
		log.Printf("Error storing event to PostgreSQL Ledger: %v", err)
		return fmt.Errorf("failed to store event in ledger: %w", err)
	}

	log.Printf("Successfully logged %s event to PostgreSQL Ledger", event["event_type"])
	return nil
}

// LogPropertyCreation logs an equipment creation/registration event
func (s *PostgresLedgerService) LogPropertyCreation(property domain.Property, userID uint) error {
	event := map[string]interface{}{
		"event_type":    "ItemCreation",
		"item_id":       property.ID,
		"serial_number": property.SerialNumber,
		"user_id":       userID,
		"timestamp":     time.Now().UTC(),
		"details": map[string]interface{}{
			"name":        property.Name,
			"description": property.Description,
			"status":      property.CurrentStatus,
		},
	}

	return s.storeEvent(fmt.Sprintf("item_creation_%d_%d", property.ID, time.Now().Unix()), event)
}

// LogTransferEvent logs a transfer event
func (s *PostgresLedgerService) LogTransferEvent(transfer domain.Transfer, serialNumber string) error {
	event := map[string]interface{}{
		"event_type":    "TransferEvent",
		"transfer_id":   transfer.ID,
		"property_id":   transfer.PropertyID,
		"serial_number": serialNumber,
		"from_user_id":  transfer.FromUserID,
		"to_user_id":    transfer.ToUserID,
		"status":        transfer.Status,
		"timestamp":     time.Now().UTC(),
		"request_date":  transfer.RequestDate,
	}

	if transfer.Notes != nil {
		event["notes"] = *transfer.Notes
	}

	return s.storeEvent(fmt.Sprintf("transfer_%d_%d", transfer.ID, time.Now().Unix()), event)
}

// LogStatusChange logs a status change event
func (s *PostgresLedgerService) LogStatusChange(itemID uint, serialNumber string, oldStatus string, newStatus string, userID uint) error {
	event := map[string]interface{}{
		"event_type":    "StatusChange",
		"item_id":       itemID,
		"serial_number": serialNumber,
		"user_id":       userID,
		"old_status":    oldStatus,
		"new_status":    newStatus,
		"timestamp":     time.Now().UTC(),
	}

	return s.storeEvent(fmt.Sprintf("status_change_%d_%d", itemID, time.Now().Unix()), event)
}

// LogVerificationEvent logs a verification event
func (s *PostgresLedgerService) LogVerificationEvent(itemID uint, serialNumber string, userID uint, verificationType string) error {
	event := map[string]interface{}{
		"event_type":        "VerificationEvent",
		"item_id":           itemID,
		"serial_number":     serialNumber,
		"user_id":           userID,
		"verification_type": verificationType,
		"timestamp":         time.Now().UTC(),
	}

	return s.storeEvent(fmt.Sprintf("verification_%d_%d", itemID, time.Now().Unix()), event)
}

// LogMaintenanceEvent logs a maintenance event
func (s *PostgresLedgerService) LogMaintenanceEvent(maintenanceRecordID string, itemID uint, initiatingUserID uint, performingUserID sql.NullInt64, eventType string, maintenanceType sql.NullString, description string) error {
	event := map[string]interface{}{
		"event_type":            "MaintenanceEvent",
		"maintenance_record_id": maintenanceRecordID,
		"item_id":               itemID,
		"initiating_user_id":    initiatingUserID,
		"event_type_detail":     eventType,
		"description":           description,
		"timestamp":             time.Now().UTC(),
	}

	if performingUserID.Valid {
		event["performing_user_id"] = performingUserID.Int64
	}
	if maintenanceType.Valid {
		event["maintenance_type"] = maintenanceType.String
	}

	return s.storeEvent(fmt.Sprintf("maintenance_%s_%d", maintenanceRecordID, time.Now().Unix()), event)
}

// LogDA2062Export logs a DA Form 2062 export event
func (s *PostgresLedgerService) LogDA2062Export(userID uint, propertyCount int, exportType string, recipients string) error {
	event := map[string]interface{}{
		"event_type":     "DA2062Export",
		"user_id":        userID,
		"property_count": propertyCount,
		"export_type":    exportType,
		"timestamp":      time.Now().UTC(),
	}

	if recipients != "" {
		event["recipients"] = recipients
	}

	return s.storeEvent(fmt.Sprintf("da2062_export_%d_%d", userID, time.Now().Unix()), event)
}

// LogComponentAttached logs when a component is attached to a parent property
func (s *PostgresLedgerService) LogComponentAttached(parentPropertyID uint, componentPropertyID uint, userID uint, position string, notes string) error {
	event := map[string]interface{}{
		"event_type":            "ComponentAttached",
		"parent_property_id":    parentPropertyID,
		"component_property_id": componentPropertyID,
		"user_id":               userID,
		"timestamp":             time.Now().UTC(),
	}

	if position != "" {
		event["position"] = position
	}
	if notes != "" {
		event["notes"] = notes
	}

	return s.storeEvent(fmt.Sprintf("component_attached_%d_%d_%d", parentPropertyID, componentPropertyID, time.Now().Unix()), event)
}

// LogComponentDetached logs when a component is detached from a parent property
func (s *PostgresLedgerService) LogComponentDetached(parentPropertyID uint, componentPropertyID uint, userID uint) error {
	event := map[string]interface{}{
		"event_type":            "ComponentDetached",
		"parent_property_id":    parentPropertyID,
		"component_property_id": componentPropertyID,
		"user_id":               userID,
		"timestamp":             time.Now().UTC(),
	}

	return s.storeEvent(fmt.Sprintf("component_detached_%d_%d_%d", parentPropertyID, componentPropertyID, time.Now().Unix()), event)
}

// LogDocumentEvent logs a document event (creation, read, etc.)
func (s *PostgresLedgerService) LogDocumentEvent(documentID uint, eventType string, senderUserID uint, recipientUserID uint) error {
	event := map[string]interface{}{
		"event_type":        "DocumentEvent",
		"document_id":       documentID,
		"document_event":    eventType,
		"sender_user_id":    senderUserID,
		"recipient_user_id": recipientUserID,
		"timestamp":         time.Now().UTC(),
	}

	return s.storeEvent(fmt.Sprintf("document_%s_%d_%d", eventType, documentID, time.Now().Unix()), event)
}

// LogCorrectionEvent logs a correction event
func (s *PostgresLedgerService) LogCorrectionEvent(originalEventID string, eventType string, reason string, userID uint) error {
	event := map[string]interface{}{
		"event_type":        "CorrectionEvent",
		"original_event_id": originalEventID,
		"correction_type":   eventType,
		"reason":            reason,
		"user_id":           userID,
		"timestamp":         time.Now().UTC(),
	}

	return s.storeEvent(fmt.Sprintf("correction_%s_%d", originalEventID, time.Now().Unix()), event)
}

// GetPropertyHistory retrieves the history of an item from the ledger
func (s *PostgresLedgerService) GetPropertyHistory(itemID uint) ([]map[string]interface{}, error) {
	var entries []LedgerEntry

	// Query for all events related to this item
	query := s.db.Where("event_data::jsonb @> ?", fmt.Sprintf(`{"item_id": %d}`, itemID)).
		Or("event_data::jsonb @> ?", fmt.Sprintf(`{"property_id": %d}`, itemID)).
		Order("created_at ASC")

	if err := query.Find(&entries).Error; err != nil {
		return nil, fmt.Errorf("failed to retrieve property history: %w", err)
	}

	// Convert entries to map format
	var history []map[string]interface{}
	for _, entry := range entries {
		var eventData map[string]interface{}
		if err := json.Unmarshal([]byte(entry.EventData), &eventData); err != nil {
			continue
		}
		eventData["ledger_id"] = entry.ID
		eventData["ledger_hash"] = entry.Hash
		eventData["ledger_created_at"] = entry.CreatedAt
		history = append(history, eventData)
	}

	return history, nil
}

// VerifyDocument verifies the integrity of a document in the ledger
func (s *PostgresLedgerService) VerifyDocument(documentID string, tableName string) (bool, error) {
	var entry LedgerEntry

	// Check if document exists in ledger
	err := s.db.Where("event_id = ?", documentID).First(&entry).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return false, nil
		}
		return false, fmt.Errorf("failed to verify document: %w", err)
	}

	// Verify chain integrity by checking hash
	prevHash := "GENESIS"
	if entry.ID > 1 {
		var prevEntry LedgerEntry
		if err := s.db.Where("id = ?", entry.ID-1).First(&prevEntry).Error; err == nil {
			prevHash = prevEntry.Hash
		}
	}

	// Verify the hash matches
	expectedHash := s.calculateHash(entry.EventData, prevHash)
	if entry.Hash != expectedHash {
		log.Printf("Hash mismatch for document %s: expected %s, got %s", documentID, expectedHash, entry.Hash)
		return false, nil
	}

	return true, nil
}

// GetAllCorrectionEvents retrieves all correction events from the ledger
func (s *PostgresLedgerService) GetAllCorrectionEvents() ([]domain.CorrectionEvent, error) {
	var entries []LedgerEntry

	if err := s.db.Where("event_type = ?", "CorrectionEvent").Find(&entries).Error; err != nil {
		return nil, fmt.Errorf("failed to retrieve correction events: %w", err)
	}

	var events []domain.CorrectionEvent
	for _, entry := range entries {
		var eventData map[string]interface{}
		if err := json.Unmarshal([]byte(entry.EventData), &eventData); err != nil {
			continue
		}

		event := domain.CorrectionEvent{
			EventID:             entry.EventID,
			OriginalEventID:     eventData["original_event_id"].(string),
			OriginalEventType:   eventData["correction_type"].(string),
			Reason:              eventData["reason"].(string),
			CorrectingUserID:    uint64(eventData["user_id"].(float64)),
			CorrectionTimestamp: entry.CreatedAt,
		}
		events = append(events, event)
	}

	return events, nil
}

// GetCorrectionEventsByOriginalID retrieves correction events by original event ID
func (s *PostgresLedgerService) GetCorrectionEventsByOriginalID(originalEventID string) ([]domain.CorrectionEvent, error) {
	var entries []LedgerEntry

	query := fmt.Sprintf(`{"original_event_id": "%s"}`, originalEventID)
	if err := s.db.Where("event_type = ? AND event_data::jsonb @> ?", "CorrectionEvent", query).Find(&entries).Error; err != nil {
		return nil, fmt.Errorf("failed to retrieve correction events: %w", err)
	}

	var events []domain.CorrectionEvent
	for _, entry := range entries {
		var eventData map[string]interface{}
		if err := json.Unmarshal([]byte(entry.EventData), &eventData); err != nil {
			continue
		}

		event := domain.CorrectionEvent{
			EventID:             entry.EventID,
			OriginalEventID:     originalEventID,
			OriginalEventType:   eventData["correction_type"].(string),
			Reason:              eventData["reason"].(string),
			CorrectingUserID:    uint64(eventData["user_id"].(float64)),
			CorrectionTimestamp: entry.CreatedAt,
		}
		events = append(events, event)
	}

	return events, nil
}

// GetCorrectionEventByID retrieves a specific correction event by ID
func (s *PostgresLedgerService) GetCorrectionEventByID(eventID string) (*domain.CorrectionEvent, error) {
	var entry LedgerEntry

	if err := s.db.Where("event_id = ? AND event_type = ?", eventID, "CorrectionEvent").First(&entry).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, fmt.Errorf("correction event not found: %s", eventID)
		}
		return nil, fmt.Errorf("failed to retrieve correction event: %w", err)
	}

	var eventData map[string]interface{}
	if err := json.Unmarshal([]byte(entry.EventData), &eventData); err != nil {
		return nil, fmt.Errorf("failed to parse event data: %w", err)
	}

	event := &domain.CorrectionEvent{
		EventID:             entry.EventID,
		OriginalEventID:     eventData["original_event_id"].(string),
		OriginalEventType:   eventData["correction_type"].(string),
		Reason:              eventData["reason"].(string),
		CorrectingUserID:    uint64(eventData["user_id"].(float64)),
		CorrectionTimestamp: entry.CreatedAt,
	}

	return event, nil
}

// GetGeneralHistory retrieves a consolidated view of all ledger events
func (s *PostgresLedgerService) GetGeneralHistory() ([]domain.GeneralLedgerEvent, error) {
	var entries []LedgerEntry

	if err := s.db.Order("created_at DESC").Limit(1000).Find(&entries).Error; err != nil {
		return nil, fmt.Errorf("failed to retrieve general history: %w", err)
	}

	var events []domain.GeneralLedgerEvent
	for _, entry := range entries {
		// Parse the event data to extract user and item IDs
		var eventData map[string]interface{}
		if err := json.Unmarshal([]byte(entry.EventData), &eventData); err != nil {
			continue
		}

		// Extract user ID if present
		var userID *uint64
		if uid, ok := eventData["user_id"].(float64); ok {
			u := uint64(uid)
			userID = &u
		}

		// Extract item ID if present
		var itemID *uint64
		if iid, ok := eventData["item_id"].(float64); ok {
			i := uint64(iid)
			itemID = &i
		} else if pid, ok := eventData["property_id"].(float64); ok {
			p := uint64(pid)
			itemID = &p
		}

		event := domain.GeneralLedgerEvent{
			EventID:   entry.EventID,
			EventType: entry.EventType,
			Timestamp: entry.CreatedAt,
			UserID:    userID,
			ItemID:    itemID,
			Details:   eventData,
		}
		events = append(events, event)
	}

	return events, nil
}

// VerifyChainIntegrity verifies the integrity of the entire ledger chain
func (s *PostgresLedgerService) VerifyChainIntegrity() (bool, []string, error) {
	var entries []LedgerEntry
	var errors []string

	// Get all entries ordered by ID
	if err := s.db.Order("id ASC").Find(&entries).Error; err != nil {
		return false, nil, fmt.Errorf("failed to retrieve ledger entries: %w", err)
	}

	if len(entries) == 0 {
		return true, nil, nil // Empty ledger is valid
	}

	// Verify first entry
	if entries[0].PrevHash != "GENESIS" {
		errors = append(errors, fmt.Sprintf("First entry (ID: %d) does not have GENESIS as previous hash", entries[0].ID))
	}

	// Verify chain integrity
	for i := 0; i < len(entries); i++ {
		// Calculate expected hash
		prevHash := "GENESIS"
		if i > 0 {
			prevHash = entries[i-1].Hash
		}

		expectedHash := s.calculateHash(entries[i].EventData, prevHash)

		// Check if stored hash matches calculated hash
		if entries[i].Hash != expectedHash {
			errors = append(errors, fmt.Sprintf("Hash mismatch at entry ID: %d", entries[i].ID))
		}

		// Check if previous hash reference is correct
		if entries[i].PrevHash != prevHash {
			errors = append(errors, fmt.Sprintf("Previous hash mismatch at entry ID: %d", entries[i].ID))
		}
	}

	return len(errors) == 0, errors, nil
}

// Close cleans up resources
func (s *PostgresLedgerService) Close() error {
	log.Println("PostgreSQL Ledger Service closed")
	// GORM doesn't require explicit closing when using the shared DB instance
	return nil
}
