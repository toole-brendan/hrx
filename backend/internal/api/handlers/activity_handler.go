package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/platform/database"
)

// ActivityHandler handles activity log operations
type ActivityHandler struct{}

// NewActivityHandler creates a new activity handler
func NewActivityHandler() *ActivityHandler {
	return &ActivityHandler{}
}

// CreateActivity creates a new activity log entry
func (h *ActivityHandler) CreateActivity(c *gin.Context) {
	var input domain.CreateActivityInput

	// Validate request body
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input format: " + err.Error()})
		return
	}

	// Get user ID from context, but allow input to override if provided (e.g., system events)
	contextUserIDVal, _ := c.Get("userID")
	contextUserID, _ := contextUserIDVal.(uint)

	// Prepare the activity for database insertion
	activity := domain.Activity{
		Type:              input.Type,
		Description:       input.Description,
		UserID:            input.UserID, // Prioritize UserID from input if provided
		RelatedPropertyID: input.RelatedPropertyID,
		RelatedTransferID: input.RelatedTransferID,
		// Timestamp defaults to CURRENT_TIMESTAMP in DB
	}

	// If UserID wasn't provided in the input, use the one from the authenticated context
	if activity.UserID == nil && contextUserID != 0 {
		activity.UserID = &contextUserID
	}

	// Insert into PostgreSQL database
	result := database.DB.Create(&activity)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create activity: " + result.Error.Error()})
		return
	}

	// No QLDB logging for general activities
	c.JSON(http.StatusCreated, activity)
}

// GetAllActivities returns all activity log entries
func (h *ActivityHandler) GetAllActivities(c *gin.Context) {
	var activities []domain.Activity
	// Order by timestamp descending to show newest first
	result := database.DB.Order("timestamp desc").Find(&activities)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch activities: " + result.Error.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"activities": activities})
}

// GetActivitiesByUserId returns activity log entries for a specific user
func (h *ActivityHandler) GetActivitiesByUserId(c *gin.Context) {
	userID, err := strconv.ParseUint(c.Param("userId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID format"})
		return
	}

	var activities []domain.Activity
	// Find activities where the UserID matches, order by timestamp descending
	result := database.DB.Where("user_id = ?", uint(userID)).Order("timestamp desc").Find(&activities)
	if result.Error != nil {
		// Handle potential errors, though ErrRecordNotFound is unlikely for a list query
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch activities for user: " + result.Error.Error()})
		return
	}

	// Return the list (might be empty if no activities found for the user)
	c.JSON(http.StatusOK, gin.H{"activities": activities})
}
