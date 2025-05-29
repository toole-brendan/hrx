package ledger

import (
	"database/sql"
	"fmt"
	"sync"
	"time"

	"github.com/toole-brendan/handreceipt-go/internal/domain"
)

// MockLedgerService is a mock implementation of LedgerService for testing
type MockLedgerService struct {
	mu     sync.Mutex
	events []map[string]interface{}
}

// NewMockLedgerService creates a new mock ledger service
func NewMockLedgerService() LedgerService {
	return &MockLedgerService{
		events: make([]map[string]interface{}, 0),
	}
}

// LogItemCreation logs an item creation event
func (m *MockLedgerService) LogItemCreation(property domain.Property, userID uint) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	event := map[string]interface{}{
		"eventId":      fmt.Sprintf("evt-%d", time.Now().UnixNano()),
		"eventType":    "ITEM_CREATE",
		"timestamp":    time.Now(),
		"userID":       userID,
		"propertyID":   property.ID,
		"serialNumber": property.SerialNumber,
		"details": map[string]interface{}{
			"name":        property.Name,
			"status":      property.CurrentStatus,
			"description": property.Description,
		},
	}

	m.events = append(m.events, event)
	return nil
}

// LogTransferEvent logs a transfer event
func (m *MockLedgerService) LogTransferEvent(transfer domain.Transfer, serialNumber string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	eventType := "TRANSFER_REQUEST"
	if transfer.Status == "Approved" {
		eventType = "TRANSFER_ACCEPT"
	} else if transfer.Status == "Rejected" {
		eventType = "TRANSFER_REJECT"
	}

	event := map[string]interface{}{
		"eventId":      fmt.Sprintf("evt-%d", time.Now().UnixNano()),
		"eventType":    eventType,
		"timestamp":    time.Now(),
		"transferID":   transfer.ID,
		"propertyID":   transfer.PropertyID,
		"fromUserID":   transfer.FromUserID,
		"toUserID":     transfer.ToUserID,
		"status":       transfer.Status,
		"serialNumber": serialNumber,
	}

	m.events = append(m.events, event)
	return nil
}

// LogStatusChange logs a status change event
func (m *MockLedgerService) LogStatusChange(itemID uint, serialNumber string, oldStatus string, newStatus string, userID uint) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	event := map[string]interface{}{
		"eventId":      fmt.Sprintf("evt-%d", time.Now().UnixNano()),
		"eventType":    "STATUS_CHANGE",
		"timestamp":    time.Now(),
		"userID":       userID,
		"itemID":       itemID,
		"serialNumber": serialNumber,
		"oldStatus":    oldStatus,
		"newStatus":    newStatus,
	}

	m.events = append(m.events, event)
	return nil
}

// LogVerificationEvent logs a verification event
func (m *MockLedgerService) LogVerificationEvent(itemID uint, serialNumber string, userID uint, verificationType string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	event := map[string]interface{}{
		"eventId":          fmt.Sprintf("evt-%d", time.Now().UnixNano()),
		"eventType":        "ITEM_VERIFY",
		"timestamp":        time.Now(),
		"userID":           userID,
		"itemID":           itemID,
		"serialNumber":     serialNumber,
		"verificationType": verificationType,
	}

	m.events = append(m.events, event)
	return nil
}

// LogMaintenanceEvent logs a maintenance event
func (m *MockLedgerService) LogMaintenanceEvent(maintenanceRecordID string, itemID uint, initiatingUserID uint, performingUserID sql.NullInt64, eventType string, maintenanceType sql.NullString, description string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	event := map[string]interface{}{
		"eventId":             fmt.Sprintf("evt-%d", time.Now().UnixNano()),
		"eventType":           "MAINTENANCE_" + eventType,
		"timestamp":           time.Now(),
		"maintenanceRecordID": maintenanceRecordID,
		"itemID":              itemID,
		"initiatingUserID":    initiatingUserID,
		"performingUserID":    performingUserID,
		"maintenanceType":     maintenanceType,
		"description":         description,
	}

	m.events = append(m.events, event)
	return nil
}

// LogCorrectionEvent logs a correction event
func (m *MockLedgerService) LogCorrectionEvent(originalEventID string, eventType string, reason string, userID uint) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	event := map[string]interface{}{
		"eventId":           fmt.Sprintf("evt-%d", time.Now().UnixNano()),
		"eventType":         "CORRECTION",
		"timestamp":         time.Now(),
		"userID":            userID,
		"originalEventID":   originalEventID,
		"originalEventType": eventType,
		"reason":            reason,
	}

	m.events = append(m.events, event)
	return nil
}

// GetItemHistory retrieves the history of an item
func (m *MockLedgerService) GetItemHistory(itemID uint) ([]map[string]interface{}, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	history := []map[string]interface{}{}
	for _, event := range m.events {
		if event["itemID"] == itemID || event["propertyID"] == itemID {
			history = append(history, event)
		}
	}

	return history, nil
}

// VerifyDocument checks the integrity of a ledger document
func (m *MockLedgerService) VerifyDocument(documentID string, tableName string) (bool, error) {
	// Mock always returns true for testing
	return true, nil
}

// GetAllCorrectionEvents retrieves all correction events
func (m *MockLedgerService) GetAllCorrectionEvents() ([]domain.CorrectionEvent, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	corrections := []domain.CorrectionEvent{}
	for _, event := range m.events {
		if event["eventType"] == "CORRECTION" {
			corrections = append(corrections, domain.CorrectionEvent{
				EventID:             event["eventId"].(string),
				OriginalEventID:     event["originalEventID"].(string),
				OriginalEventType:   event["originalEventType"].(string),
				Reason:              event["reason"].(string),
				CorrectingUserID:    uint64(event["userID"].(uint)),
				CorrectionTimestamp: event["timestamp"].(time.Time),
			})
		}
	}

	return corrections, nil
}

// GetCorrectionEventsByOriginalID retrieves correction events by original event ID
func (m *MockLedgerService) GetCorrectionEventsByOriginalID(originalEventID string) ([]domain.CorrectionEvent, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	corrections := []domain.CorrectionEvent{}
	for _, event := range m.events {
		if event["eventType"] == "CORRECTION" && event["originalEventID"] == originalEventID {
			corrections = append(corrections, domain.CorrectionEvent{
				EventID:             event["eventId"].(string),
				OriginalEventID:     event["originalEventID"].(string),
				OriginalEventType:   event["originalEventType"].(string),
				Reason:              event["reason"].(string),
				CorrectingUserID:    uint64(event["userID"].(uint)),
				CorrectionTimestamp: event["timestamp"].(time.Time),
			})
		}
	}

	return corrections, nil
}

// GetCorrectionEventByID retrieves a correction event by ID
func (m *MockLedgerService) GetCorrectionEventByID(eventID string) (*domain.CorrectionEvent, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, event := range m.events {
		if event["eventType"] == "CORRECTION" && event["eventId"] == eventID {
			return &domain.CorrectionEvent{
				EventID:             event["eventId"].(string),
				OriginalEventID:     event["originalEventID"].(string),
				OriginalEventType:   event["originalEventType"].(string),
				Reason:              event["reason"].(string),
				CorrectingUserID:    uint64(event["userID"].(uint)),
				CorrectionTimestamp: event["timestamp"].(time.Time),
			}, nil
		}
	}

	return nil, fmt.Errorf("correction event not found")
}

// GetGeneralHistory retrieves a consolidated view of all ledger event types
func (m *MockLedgerService) GetGeneralHistory() ([]domain.GeneralLedgerEvent, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	history := []domain.GeneralLedgerEvent{}
	for _, event := range m.events {
		userID := uint64(0)
		if uid, ok := event["userID"].(uint); ok {
			userID = uint64(uid)
		}

		itemID := uint64(0)
		if iid, ok := event["itemID"].(uint); ok {
			itemID = uint64(iid)
		} else if pid, ok := event["propertyID"].(uint); ok {
			itemID = uint64(pid)
		}

		generalEvent := domain.GeneralLedgerEvent{
			EventID:   event["eventId"].(string),
			EventType: event["eventType"].(string),
			Timestamp: event["timestamp"].(time.Time),
			Details:   event,
		}

		if userID > 0 {
			generalEvent.UserID = &userID
		}
		if itemID > 0 {
			generalEvent.ItemID = &itemID
		}

		history = append(history, generalEvent)
	}

	return history, nil
}

// Initialize prepares the ledger service
func (m *MockLedgerService) Initialize() error {
	// Nothing to initialize for mock
	return nil
}

// Close cleans up resources
func (m *MockLedgerService) Close() error {
	// Nothing to close for mock
	return nil
}
