package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ComponentEvent represents a component attachment/detachment event
type ComponentEvent struct {
	EventID             string    `json:"eventId" gorm:"primaryKey;column:event_id;type:uuid;default:gen_random_uuid()"`
	ParentPropertyID    int       `json:"parentPropertyId" gorm:"column:parent_property_id;not null"`
	ComponentPropertyID int       `json:"componentPropertyId" gorm:"column:component_property_id;not null"`
	AttachingUserID     int       `json:"attachingUserId" gorm:"column:attaching_user_id;not null"`
	EventType           string    `json:"eventType" gorm:"column:event_type;not null"`
	Position            *string   `json:"position,omitempty" gorm:"column:position"`
	Notes               *string   `json:"notes,omitempty" gorm:"column:notes"`
	EventTimestamp      time.Time `json:"eventTimestamp" gorm:"column:event_timestamp;autoCreateTime"`
}

// TableName specifies the table name for GORM
func (ComponentEvent) TableName() string {
	return "component_events"
}

// ComponentEventsHandler handles component event operations
type ComponentEventsHandler struct {
	db *gorm.DB
}

// NewComponentEventsHandler creates a new component events handler
func NewComponentEventsHandler(db *gorm.DB) *ComponentEventsHandler {
	return &ComponentEventsHandler{db: db}
}

// GetComponentEvents returns all component events with optional filtering
func (h *ComponentEventsHandler) GetComponentEvents(c *gin.Context) {
	parentPropertyID := c.Query("parentPropertyId")
	componentPropertyID := c.Query("componentPropertyId")
	userID := c.Query("userId")
	eventType := c.Query("eventType")
	startDate := c.Query("startDate")
	endDate := c.Query("endDate")
	limit := c.DefaultQuery("limit", "100")
	offset := c.DefaultQuery("offset", "0")

	var events []ComponentEvent
	query := h.db.Model(&ComponentEvent{})

	if parentPropertyID != "" {
		query = query.Where("parent_property_id = ?", parentPropertyID)
	}

	if componentPropertyID != "" {
		query = query.Where("component_property_id = ?", componentPropertyID)
	}

	if userID != "" {
		query = query.Where("attaching_user_id = ?", userID)
	}

	if eventType != "" {
		query = query.Where("event_type = ?", eventType)
	}

	if startDate != "" {
		if parsedDate, err := time.Parse("2006-01-02", startDate); err == nil {
			query = query.Where("event_timestamp >= ?", parsedDate)
		}
	}

	if endDate != "" {
		if parsedDate, err := time.Parse("2006-01-02", endDate); err == nil {
			// Add 1 day to include the entire end date
			endDateTime := parsedDate.Add(24 * time.Hour)
			query = query.Where("event_timestamp < ?", endDateTime)
		}
	}

	// Parse limit and offset
	limitInt, _ := strconv.Atoi(limit)
	offsetInt, _ := strconv.Atoi(offset)

	var total int64
	query.Count(&total)

	if err := query.Order("event_timestamp DESC").
		Limit(limitInt).
		Offset(offsetInt).
		Find(&events).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch component events",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"events": events,
		"total":  total,
		"limit":  limitInt,
		"offset": offsetInt,
	})
}

// GetComponentEvent returns a specific component event by ID
func (h *ComponentEventsHandler) GetComponentEvent(c *gin.Context) {
	eventID := c.Param("id")

	// Validate UUID format
	if _, err := uuid.Parse(eventID); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid event ID format",
		})
		return
	}

	var event ComponentEvent
	if err := h.db.First(&event, "event_id = ?", eventID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Component event not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch component event",
		})
		return
	}

	c.JSON(http.StatusOK, event)
}

// GetPropertyComponentHistory returns all component events for a specific property
func (h *ComponentEventsHandler) GetPropertyComponentHistory(c *gin.Context) {
	propertyID, err := strconv.Atoi(c.Param("propertyId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid property ID",
		})
		return
	}

	var events []ComponentEvent
	if err := h.db.Where("parent_property_id = ? OR component_property_id = ?", propertyID, propertyID).
		Order("event_timestamp DESC").
		Find(&events).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch property component history",
		})
		return
	}

	// Separate events by role
	var asParent []ComponentEvent
	var asComponent []ComponentEvent

	for _, event := range events {
		if event.ParentPropertyID == propertyID {
			asParent = append(asParent, event)
		}
		if event.ComponentPropertyID == propertyID {
			asComponent = append(asComponent, event)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"asParent":    asParent,
		"asComponent": asComponent,
		"total":       len(events),
	})
}

// CreateComponentEvent creates a new component event
func (h *ComponentEventsHandler) CreateComponentEvent(c *gin.Context) {
	// Get user ID from session
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	var event ComponentEvent
	if err := c.ShouldBindJSON(&event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Validate required fields
	if event.ParentPropertyID == 0 || event.ComponentPropertyID == 0 || event.EventType == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Missing required fields: parentPropertyId, componentPropertyId, eventType",
		})
		return
	}

	// Validate event type
	if event.EventType != "ATTACHED" && event.EventType != "DETACHED" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid event type. Must be: ATTACHED or DETACHED",
		})
		return
	}

	// Validate that parent and component are different
	if event.ParentPropertyID == event.ComponentPropertyID {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Parent property and component property must be different",
		})
		return
	}

	// Set user ID
	event.AttachingUserID = int(userID.(uint))

	// Generate UUID if not provided
	if event.EventID == "" {
		event.EventID = uuid.New().String()
	}

	if err := h.db.Create(&event).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create component event",
		})
		return
	}

	c.JSON(http.StatusCreated, event)
}

// GetComponentEventSummary returns a summary of component events
func (h *ComponentEventsHandler) GetComponentEventSummary(c *gin.Context) {
	type Summary struct {
		EventType string `json:"eventType"`
		Count     int64  `json:"count"`
	}

	var summaries []Summary

	// Get counts by event type
	if err := h.db.Model(&ComponentEvent{}).
		Select("event_type as event_type, COUNT(*) as count").
		Group("event_type").
		Find(&summaries).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch component event summary",
		})
		return
	}

	// Get total count
	var total int64
	h.db.Model(&ComponentEvent{}).Count(&total)

	// Get counts for last 30 days
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)
	var last30Days int64
	h.db.Model(&ComponentEvent{}).Where("event_timestamp >= ?", thirtyDaysAgo).Count(&last30Days)

	// Get most active properties
	type PropertyActivity struct {
		PropertyID int   `json:"propertyId"`
		EventCount int64 `json:"eventCount"`
	}

	var mostActiveParents []PropertyActivity
	h.db.Model(&ComponentEvent{}).
		Select("parent_property_id as property_id, COUNT(*) as event_count").
		Group("parent_property_id").
		Order("event_count DESC").
		Limit(10).
		Find(&mostActiveParents)

	c.JSON(http.StatusOK, gin.H{
		"byEventType":       summaries,
		"totalEvents":       total,
		"eventsLast30Days":  last30Days,
		"mostActiveParents": mostActiveParents,
	})
}

// ExportComponentEvents exports component events in CSV format
func (h *ComponentEventsHandler) ExportComponentEvents(c *gin.Context) {
	// Get query parameters for filtering
	parentPropertyID := c.Query("parentPropertyId")
	componentPropertyID := c.Query("componentPropertyId")
	startDate := c.Query("startDate")
	endDate := c.Query("endDate")

	query := h.db.Model(&ComponentEvent{})

	if parentPropertyID != "" {
		query = query.Where("parent_property_id = ?", parentPropertyID)
	}

	if componentPropertyID != "" {
		query = query.Where("component_property_id = ?", componentPropertyID)
	}

	if startDate != "" {
		if parsedDate, err := time.Parse("2006-01-02", startDate); err == nil {
			query = query.Where("event_timestamp >= ?", parsedDate)
		}
	}

	if endDate != "" {
		if parsedDate, err := time.Parse("2006-01-02", endDate); err == nil {
			endDateTime := parsedDate.Add(24 * time.Hour)
			query = query.Where("event_timestamp < ?", endDateTime)
		}
	}

	var events []ComponentEvent
	if err := query.Order("event_timestamp DESC").Find(&events).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch component events for export",
		})
		return
	}

	// Set CSV headers
	c.Header("Content-Type", "text/csv")
	c.Header("Content-Disposition", "attachment; filename=\"component_events.csv\"")

	// Write CSV header
	c.Writer.Write([]byte("Event ID,Parent Property ID,Component Property ID,User ID,Event Type,Position,Notes,Timestamp\n"))

	// Write CSV rows
	for _, event := range events {
		position := ""
		if event.Position != nil {
			position = *event.Position
		}
		notes := ""
		if event.Notes != nil {
			notes = *event.Notes
		}

		row := fmt.Sprintf("%s,%d,%d,%d,%s,\"%s\",\"%s\",%s\n",
			event.EventID,
			event.ParentPropertyID,
			event.ComponentPropertyID,
			event.AttachingUserID,
			event.EventType,
			position,
			notes,
			event.EventTimestamp.Format(time.RFC3339),
		)
		c.Writer.Write([]byte(row))
	}
}