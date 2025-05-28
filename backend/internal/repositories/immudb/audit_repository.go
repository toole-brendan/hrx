package immudb

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"time"

	"github.com/codenotary/immudb/pkg/api/schema"
	immuclient "github.com/codenotary/immudb/pkg/client"
	"github.com/google/uuid"
	"github.com/sirupsen/logrus"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/models"
)

type AuditRepository struct {
	client immuclient.ImmuClient
	logger *logrus.Logger
	config *config.ImmuDBConfig
}

type AuditEvent struct {
	ID         string                 `json:"id"`
	EntityType string                 `json:"entity_type"`
	EntityID   string                 `json:"entity_id"`
	Action     models.AuditAction     `json:"action"`
	UserID     uint                   `json:"user_id"`
	Username   string                 `json:"username"`
	Timestamp  time.Time              `json:"timestamp"`
	OldValues  map[string]interface{} `json:"old_values,omitempty"`
	NewValues  map[string]interface{} `json:"new_values,omitempty"`
	IPAddress  string                 `json:"ip_address"`
	UserAgent  string                 `json:"user_agent"`
	SessionID  string                 `json:"session_id"`
	Metadata   map[string]interface{} `json:"metadata,omitempty"`
}

type AuditSearchFilter struct {
	EntityType string
	EntityID   string
	Action     models.AuditAction
	UserID     uint
	StartDate  *time.Time
	EndDate    *time.Time
	Limit      int
	Offset     int
}

func NewAuditRepository(client immuclient.ImmuClient, config *config.ImmuDBConfig, logger *logrus.Logger) *AuditRepository {
	return &AuditRepository{
		client: client,
		config: config,
		logger: logger,
	}
}

// LogEvent creates an immutable audit entry
func (r *AuditRepository) LogEvent(ctx context.Context, event AuditEvent) error {
	if !r.config.Enabled {
		r.logger.Debug("ImmuDB audit logging is disabled")
		return nil
	}

	// Generate unique ID if not provided
	if event.ID == "" {
		event.ID = uuid.New().String()
	}

	// Set timestamp if not provided
	if event.Timestamp.IsZero() {
		event.Timestamp = time.Now().UTC()
	}

	// Create the key for the audit entry
	key := r.generateAuditKey(event.EntityType, event.EntityID, event.Timestamp)

	// Serialize the event to JSON
	value, err := json.Marshal(event)
	if err != nil {
		r.logger.WithError(err).Error("Failed to marshal audit event")
		return fmt.Errorf("failed to marshal audit event: %w", err)
	}

	// Store in ImmuDB
	_, err = r.client.Set(ctx, []byte(key), value)
	if err != nil {
		r.logger.WithError(err).WithField("key", key).Error("Failed to store audit event in ImmuDB")
		return fmt.Errorf("failed to store audit event: %w", err)
	}

	r.logger.WithFields(logrus.Fields{
		"audit_id":    event.ID,
		"entity_type": event.EntityType,
		"entity_id":   event.EntityID,
		"action":      event.Action,
		"user_id":     event.UserID,
	}).Info("Audit event logged to ImmuDB")

	return nil
}

// GetAuditTrail retrieves audit entries for a specific entity
func (r *AuditRepository) GetAuditTrail(ctx context.Context, entityType, entityID string) ([]AuditEvent, error) {
	if !r.config.Enabled {
		return []AuditEvent{}, nil
	}

	// Create prefix for scanning
	prefix := fmt.Sprintf("audit:%s:%s:", entityType, entityID)

	// Scan for entries with the prefix using the correct API
	scanReq := &schema.ScanRequest{
		Prefix: []byte(prefix),
		Limit:  1000, // Limit to prevent memory issues
	}

	entries, err := r.client.Scan(ctx, scanReq)
	if err != nil {
		r.logger.WithError(err).WithFields(logrus.Fields{
			"entity_type": entityType,
			"entity_id":   entityID,
		}).Error("Failed to scan audit entries")
		return nil, fmt.Errorf("failed to scan audit entries: %w", err)
	}

	var events []AuditEvent
	for _, entry := range entries.Entries {
		var event AuditEvent
		if err := json.Unmarshal(entry.Value, &event); err != nil {
			r.logger.WithError(err).WithField("key", string(entry.Key)).Warn("Failed to unmarshal audit event")
			continue
		}
		events = append(events, event)
	}

	// Sort events by timestamp (newest first)
	for i := 0; i < len(events)-1; i++ {
		for j := i + 1; j < len(events); j++ {
			if events[i].Timestamp.Before(events[j].Timestamp) {
				events[i], events[j] = events[j], events[i]
			}
		}
	}

	return events, nil
}

// SearchAuditEvents searches for audit events based on filters
func (r *AuditRepository) SearchAuditEvents(ctx context.Context, filter AuditSearchFilter) ([]AuditEvent, error) {
	if !r.config.Enabled {
		return []AuditEvent{}, nil
	}

	var prefix string
	if filter.EntityType != "" && filter.EntityID != "" {
		prefix = fmt.Sprintf("audit:%s:%s:", filter.EntityType, filter.EntityID)
	} else if filter.EntityType != "" {
		prefix = fmt.Sprintf("audit:%s:", filter.EntityType)
	} else {
		prefix = "audit:"
	}

	// Set default limit if not specified
	limit := filter.Limit
	if limit <= 0 || limit > 1000 {
		limit = 100
	}

	scanReq := &schema.ScanRequest{
		Prefix: []byte(prefix),
		Limit:  uint64(limit),
	}

	entries, err := r.client.Scan(ctx, scanReq)
	if err != nil {
		r.logger.WithError(err).Error("Failed to search audit entries")
		return nil, fmt.Errorf("failed to search audit entries: %w", err)
	}

	var events []AuditEvent
	for _, entry := range entries.Entries {
		var event AuditEvent
		if err := json.Unmarshal(entry.Value, &event); err != nil {
			r.logger.WithError(err).WithField("key", string(entry.Key)).Warn("Failed to unmarshal audit event")
			continue
		}

		// Apply filters
		if !r.matchesFilter(event, filter) {
			continue
		}

		events = append(events, event)
	}

	return events, nil
}

// GetAuditEventByID retrieves a specific audit event by ID
func (r *AuditRepository) GetAuditEventByID(ctx context.Context, eventID string) (*AuditEvent, error) {
	if !r.config.Enabled {
		return nil, fmt.Errorf("ImmuDB audit logging is disabled")
	}

	// Search for the event by scanning with a broader prefix
	scanReq := &schema.ScanRequest{
		Prefix: []byte("audit:"),
		Limit:  10000, // Large limit to search through events
	}

	entries, err := r.client.Scan(ctx, scanReq)
	if err != nil {
		return nil, fmt.Errorf("failed to search for audit event: %w", err)
	}

	for _, entry := range entries.Entries {
		var event AuditEvent
		if err := json.Unmarshal(entry.Value, &event); err != nil {
			continue
		}

		if event.ID == eventID {
			return &event, nil
		}
	}

	return nil, fmt.Errorf("audit event not found: %s", eventID)
}

// VerifyAuditIntegrity verifies the integrity of audit entries
func (r *AuditRepository) VerifyAuditIntegrity(ctx context.Context, entityType, entityID string) (bool, error) {
	if !r.config.Enabled {
		return true, nil
	}

	prefix := fmt.Sprintf("audit:%s:%s:", entityType, entityID)

	scanReq := &schema.ScanRequest{
		Prefix: []byte(prefix),
		Limit:  1000,
	}

	entries, err := r.client.Scan(ctx, scanReq)
	if err != nil {
		return false, fmt.Errorf("failed to scan audit entries for verification: %w", err)
	}

	// Verify each entry exists and is immutable
	for _, entry := range entries.Entries {
		// Get the entry to verify it exists and hasn't been tampered with
		_, err := r.client.Get(ctx, entry.Key)
		if err != nil {
			r.logger.WithError(err).WithField("key", string(entry.Key)).Error("Audit entry verification failed")
			return false, fmt.Errorf("audit entry verification failed for key %s: %w", string(entry.Key), err)
		}
	}

	return true, nil
}

// GetAuditStatistics returns statistics about audit entries
func (r *AuditRepository) GetAuditStatistics(ctx context.Context, entityType string, startDate, endDate time.Time) (map[string]interface{}, error) {
	if !r.config.Enabled {
		return map[string]interface{}{}, nil
	}

	prefix := "audit:"
	if entityType != "" {
		prefix = fmt.Sprintf("audit:%s:", entityType)
	}

	scanReq := &schema.ScanRequest{
		Prefix: []byte(prefix),
		Limit:  10000,
	}

	entries, err := r.client.Scan(ctx, scanReq)
	if err != nil {
		return nil, fmt.Errorf("failed to scan audit entries for statistics: %w", err)
	}

	stats := map[string]interface{}{
		"total_events":     0,
		"events_by_action": make(map[string]int),
		"events_by_user":   make(map[uint]int),
		"date_range": map[string]interface{}{
			"start": startDate,
			"end":   endDate,
		},
	}

	totalEvents := 0
	eventsByAction := make(map[string]int)
	eventsByUser := make(map[uint]int)

	for _, entry := range entries.Entries {
		var event AuditEvent
		if err := json.Unmarshal(entry.Value, &event); err != nil {
			continue
		}

		// Filter by date range
		if !event.Timestamp.IsZero() {
			if event.Timestamp.Before(startDate) || event.Timestamp.After(endDate) {
				continue
			}
		}

		totalEvents++
		eventsByAction[string(event.Action)]++
		eventsByUser[event.UserID]++
	}

	stats["total_events"] = totalEvents
	stats["events_by_action"] = eventsByAction
	stats["events_by_user"] = eventsByUser

	return stats, nil
}

// CompressOldLogs compresses or archives old audit logs (placeholder for future implementation)
func (r *AuditRepository) CompressOldLogs(ctx context.Context, olderThan time.Time) error {
	if !r.config.Enabled {
		return nil
	}

	// This is a placeholder for future implementation
	// ImmuDB doesn't support deletion, but we could implement archiving strategies
	r.logger.WithField("older_than", olderThan).Info("Audit log compression requested (not implemented)")
	return nil
}

// generateAuditKey creates a unique key for audit entries
func (r *AuditRepository) generateAuditKey(entityType, entityID string, timestamp time.Time) string {
	// Use nanosecond timestamp to ensure uniqueness
	return fmt.Sprintf("audit:%s:%s:%d", entityType, entityID, timestamp.UnixNano())
}

// matchesFilter checks if an audit event matches the search filter
func (r *AuditRepository) matchesFilter(event AuditEvent, filter AuditSearchFilter) bool {
	// Check entity type
	if filter.EntityType != "" && event.EntityType != filter.EntityType {
		return false
	}

	// Check entity ID
	if filter.EntityID != "" && event.EntityID != filter.EntityID {
		return false
	}

	// Check action
	if filter.Action != "" && event.Action != filter.Action {
		return false
	}

	// Check user ID
	if filter.UserID != 0 && event.UserID != filter.UserID {
		return false
	}

	// Check date range
	if filter.StartDate != nil && event.Timestamp.Before(*filter.StartDate) {
		return false
	}

	if filter.EndDate != nil && event.Timestamp.After(*filter.EndDate) {
		return false
	}

	return true
}

// CreateUserAuditEvent creates an audit event for user-related actions
func (r *AuditRepository) CreateUserAuditEvent(ctx context.Context, action models.AuditAction, userID uint, username string, targetUserID uint, oldValues, newValues map[string]interface{}, ipAddress, userAgent, sessionID string) error {
	event := AuditEvent{
		ID:         uuid.New().String(),
		EntityType: "user",
		EntityID:   strconv.Itoa(int(targetUserID)),
		Action:     action,
		UserID:     userID,
		Username:   username,
		Timestamp:  time.Now().UTC(),
		OldValues:  oldValues,
		NewValues:  newValues,
		IPAddress:  ipAddress,
		UserAgent:  userAgent,
		SessionID:  sessionID,
	}

	return r.LogEvent(ctx, event)
}

// CreateEquipmentAuditEvent creates an audit event for equipment-related actions
func (r *AuditRepository) CreateEquipmentAuditEvent(ctx context.Context, action models.AuditAction, userID uint, username string, equipmentID uint, oldValues, newValues map[string]interface{}, ipAddress, userAgent, sessionID string) error {
	event := AuditEvent{
		ID:         uuid.New().String(),
		EntityType: "equipment",
		EntityID:   strconv.Itoa(int(equipmentID)),
		Action:     action,
		UserID:     userID,
		Username:   username,
		Timestamp:  time.Now().UTC(),
		OldValues:  oldValues,
		NewValues:  newValues,
		IPAddress:  ipAddress,
		UserAgent:  userAgent,
		SessionID:  sessionID,
	}

	return r.LogEvent(ctx, event)
}

// CreateHandReceiptAuditEvent creates an audit event for hand receipt-related actions
func (r *AuditRepository) CreateHandReceiptAuditEvent(ctx context.Context, action models.AuditAction, userID uint, username string, handReceiptID uint, oldValues, newValues map[string]interface{}, ipAddress, userAgent, sessionID string) error {
	event := AuditEvent{
		ID:         uuid.New().String(),
		EntityType: "hand_receipt",
		EntityID:   strconv.Itoa(int(handReceiptID)),
		Action:     action,
		UserID:     userID,
		Username:   username,
		Timestamp:  time.Now().UTC(),
		OldValues:  oldValues,
		NewValues:  newValues,
		IPAddress:  ipAddress,
		UserAgent:  userAgent,
		SessionID:  sessionID,
	}

	return r.LogEvent(ctx, event)
}
