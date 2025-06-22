package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// OfflineSyncEntry represents an entry in the offline sync queue
type OfflineSyncEntry struct {
	ID            int64           `json:"id" gorm:"primaryKey;column:id"`
	ClientID      string          `json:"clientId" gorm:"column:client_id;not null"`
	OperationType string          `json:"operationType" gorm:"column:operation_type;not null"`
	EntityType    string          `json:"entityType" gorm:"column:entity_type;not null"`
	EntityID      *int64          `json:"entityId,omitempty" gorm:"column:entity_id"`
	Payload       json.RawMessage `json:"payload" gorm:"column:payload;type:jsonb;not null"`
	SyncStatus    string          `json:"syncStatus" gorm:"column:sync_status;default:pending"`
	RetryCount    int             `json:"retryCount" gorm:"column:retry_count;default:0"`
	CreatedAt     time.Time       `json:"createdAt" gorm:"column:created_at;autoCreateTime"`
	SyncedAt      *time.Time      `json:"syncedAt,omitempty" gorm:"column:synced_at"`
}

// TableName specifies the table name for GORM
func (OfflineSyncEntry) TableName() string {
	return "offline_sync_queue"
}

// OfflineSyncHandler handles offline sync queue operations
type OfflineSyncHandler struct {
	db *gorm.DB
}

// NewOfflineSyncHandler creates a new offline sync handler
func NewOfflineSyncHandler(db *gorm.DB) *OfflineSyncHandler {
	return &OfflineSyncHandler{db: db}
}

// GetSyncQueue returns all pending sync entries for a client
func (h *OfflineSyncHandler) GetSyncQueue(c *gin.Context) {
	clientID := c.Query("clientId")
	status := c.DefaultQuery("status", "pending")

	var entries []OfflineSyncEntry
	query := h.db.Model(&OfflineSyncEntry{})

	if clientID != "" {
		query = query.Where("client_id = ?", clientID)
	}

	if status != "" {
		query = query.Where("sync_status = ?", status)
	}

	if err := query.Order("created_at ASC").Find(&entries).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch sync queue",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"entries": entries,
		"count":   len(entries),
	})
}

// GetSyncEntry returns a specific sync entry
func (h *OfflineSyncHandler) GetSyncEntry(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid sync entry ID",
		})
		return
	}

	var entry OfflineSyncEntry
	if err := h.db.First(&entry, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Sync entry not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch sync entry",
		})
		return
	}

	c.JSON(http.StatusOK, entry)
}

// CreateSyncEntry creates a new offline sync entry
func (h *OfflineSyncHandler) CreateSyncEntry(c *gin.Context) {
	var entry OfflineSyncEntry
	if err := c.ShouldBindJSON(&entry); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Validate required fields
	if entry.ClientID == "" || entry.OperationType == "" || entry.EntityType == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Missing required fields: clientId, operationType, entityType",
		})
		return
	}

	// Validate operation type
	if entry.OperationType != "create" && entry.OperationType != "update" && entry.OperationType != "delete" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid operation type. Must be: create, update, or delete",
		})
		return
	}

	// Set defaults
	if entry.SyncStatus == "" {
		entry.SyncStatus = "pending"
	}

	if err := h.db.Create(&entry).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create sync entry",
		})
		return
	}

	c.JSON(http.StatusCreated, entry)
}

// ProcessSyncQueue processes pending sync entries
func (h *OfflineSyncHandler) ProcessSyncQueue(c *gin.Context) {
	clientID := c.Query("clientId")
	if clientID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "clientId is required",
		})
		return
	}

	// Get pending entries for the client
	var entries []OfflineSyncEntry
	if err := h.db.Where("client_id = ? AND sync_status = ?", clientID, "pending").
		Order("created_at ASC").
		Limit(100).
		Find(&entries).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch pending entries",
		})
		return
	}

	// Process each entry
	processed := 0
	failed := 0
	
	for _, entry := range entries {
		// Here you would implement the actual sync logic based on entity_type and operation_type
		// For now, we'll just mark them as synced
		
		now := time.Now()
		if err := h.db.Model(&OfflineSyncEntry{}).
			Where("id = ?", entry.ID).
			Updates(map[string]interface{}{
				"sync_status": "synced",
				"synced_at":   now,
			}).Error; err != nil {
			failed++
			// Update retry count on failure
			h.db.Model(&OfflineSyncEntry{}).
				Where("id = ?", entry.ID).
				Update("retry_count", gorm.Expr("retry_count + ?", 1))
		} else {
			processed++
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"processed": processed,
		"failed":    failed,
		"total":     len(entries),
	})
}

// UpdateSyncEntry updates a sync entry's status
func (h *OfflineSyncHandler) UpdateSyncEntry(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid sync entry ID",
		})
		return
	}

	var update struct {
		SyncStatus string `json:"syncStatus"`
		RetryCount *int   `json:"retryCount,omitempty"`
	}

	if err := c.ShouldBindJSON(&update); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Validate sync status
	if update.SyncStatus != "" && 
	   update.SyncStatus != "pending" && 
	   update.SyncStatus != "synced" && 
	   update.SyncStatus != "failed" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid sync status. Must be: pending, synced, or failed",
		})
		return
	}

	updates := make(map[string]interface{})

	if update.SyncStatus != "" {
		updates["sync_status"] = update.SyncStatus
		
		if update.SyncStatus == "synced" {
			updates["synced_at"] = time.Now()
		}
	}

	if update.RetryCount != nil {
		updates["retry_count"] = *update.RetryCount
	}

	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No updates provided",
		})
		return
	}

	result := h.db.Model(&OfflineSyncEntry{}).Where("id = ?", id).Updates(updates)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update sync entry",
		})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Sync entry not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Sync entry updated successfully",
	})
}

// DeleteSyncEntry deletes a sync entry
func (h *OfflineSyncHandler) DeleteSyncEntry(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid sync entry ID",
		})
		return
	}

	result := h.db.Delete(&OfflineSyncEntry{}, id)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete sync entry",
		})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Sync entry not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Sync entry deleted successfully",
	})
}

// ClearSyncQueue clears all synced entries for a client
func (h *OfflineSyncHandler) ClearSyncQueue(c *gin.Context) {
	clientID := c.Query("clientId")
	if clientID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "clientId is required",
		})
		return
	}

	status := c.DefaultQuery("status", "synced")

	result := h.db.Where("client_id = ? AND sync_status = ?", clientID, status).
		Delete(&OfflineSyncEntry{})
	
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to clear sync queue",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Sync queue cleared successfully",
		"deleted": result.RowsAffected,
	})
}