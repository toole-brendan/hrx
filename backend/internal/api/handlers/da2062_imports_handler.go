package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// DA2062Import represents a DA2062 import job
type DA2062Import struct {
	ID             int64           `json:"id" gorm:"primaryKey;column:id"`
	FileName       string          `json:"fileName" gorm:"column:file_name;not null"`
	FileURL        *string         `json:"fileUrl,omitempty" gorm:"column:file_url"`
	ImportedByUser int64           `json:"importedByUserId" gorm:"column:imported_by_user_id;not null"`
	Status         string          `json:"status" gorm:"column:status;default:pending"`
	TotalItems     int             `json:"totalItems" gorm:"column:total_items;default:0"`
	ProcessedItems int             `json:"processedItems" gorm:"column:processed_items;default:0"`
	FailedItems    int             `json:"failedItems" gorm:"column:failed_items;default:0"`
	ErrorLog       json.RawMessage `json:"errorLog,omitempty" gorm:"column:error_log;type:jsonb"`
	CreatedAt      time.Time       `json:"createdAt" gorm:"column:created_at;autoCreateTime"`
	CompletedAt    *time.Time      `json:"completedAt,omitempty" gorm:"column:completed_at"`
}

// TableName specifies the table name for GORM
func (DA2062Import) TableName() string {
	return "da2062_imports"
}

// DA2062ImportItem represents an individual item from a DA2062 import
type DA2062ImportItem struct {
	ID           int64           `json:"id" gorm:"primaryKey;column:id"`
	ImportID     int64           `json:"importId" gorm:"column:import_id;not null"`
	LineNumber   int             `json:"lineNumber" gorm:"column:line_number;not null"`
	RawData      json.RawMessage `json:"rawData" gorm:"column:raw_data;type:jsonb;not null"`
	PropertyID   *int64          `json:"propertyId,omitempty" gorm:"column:property_id"`
	Status       string          `json:"status" gorm:"column:status;default:pending"`
	ErrorMessage *string         `json:"errorMessage,omitempty" gorm:"column:error_message"`
	CreatedAt    time.Time       `json:"createdAt" gorm:"column:created_at;autoCreateTime"`
}

// TableName specifies the table name for GORM
func (DA2062ImportItem) TableName() string {
	return "da2062_import_items"
}

// DA2062ImportsHandler handles DA2062 import operations
type DA2062ImportsHandler struct {
	db *gorm.DB
}

// NewDA2062ImportsHandler creates a new DA2062 imports handler
func NewDA2062ImportsHandler(db *gorm.DB) *DA2062ImportsHandler {
	return &DA2062ImportsHandler{db: db}
}

// GetImports returns all DA2062 imports with optional filtering
func (h *DA2062ImportsHandler) GetImports(c *gin.Context) {
	userID := c.Query("userId")
	status := c.Query("status")
	limit := c.DefaultQuery("limit", "50")
	offset := c.DefaultQuery("offset", "0")

	var imports []DA2062Import
	query := h.db.Model(&DA2062Import{})

	if userID != "" {
		query = query.Where("imported_by_user_id = ?", userID)
	}

	if status != "" {
		query = query.Where("status = ?", status)
	}

	// Parse limit and offset
	limitInt, _ := strconv.Atoi(limit)
	offsetInt, _ := strconv.Atoi(offset)

	var total int64
	query.Count(&total)

	if err := query.Order("created_at DESC").
		Limit(limitInt).
		Offset(offsetInt).
		Find(&imports).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch imports",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"imports": imports,
		"total":   total,
		"limit":   limitInt,
		"offset":  offsetInt,
	})
}

// GetImport returns a specific DA2062 import by ID
func (h *DA2062ImportsHandler) GetImport(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid import ID",
		})
		return
	}

	var importRecord DA2062Import
	if err := h.db.First(&importRecord, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Import not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch import",
		})
		return
	}

	c.JSON(http.StatusOK, importRecord)
}

// GetImportItems returns all items for a specific import
func (h *DA2062ImportsHandler) GetImportItems(c *gin.Context) {
	importID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid import ID",
		})
		return
	}

	status := c.Query("status")

	var items []DA2062ImportItem
	query := h.db.Model(&DA2062ImportItem{}).Where("import_id = ?", importID)

	if status != "" {
		query = query.Where("status = ?", status)
	}

	if err := query.Order("line_number ASC").Find(&items).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch import items",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"items": items,
		"count": len(items),
	})
}

// CreateImport creates a new DA2062 import job
func (h *DA2062ImportsHandler) CreateImport(c *gin.Context) {
	// Get user ID from session
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	var importRecord DA2062Import
	if err := c.ShouldBindJSON(&importRecord); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Validate required fields
	if importRecord.FileName == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "fileName is required",
		})
		return
	}

	// Set user ID and defaults
	importRecord.ImportedByUser = int64(userID.(uint))
	if importRecord.Status == "" {
		importRecord.Status = "pending"
	}

	if err := h.db.Create(&importRecord).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create import",
		})
		return
	}

	c.JSON(http.StatusCreated, importRecord)
}

// UpdateImportStatus updates the status of an import
func (h *DA2062ImportsHandler) UpdateImportStatus(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid import ID",
		})
		return
	}

	var update struct {
		Status         string          `json:"status"`
		TotalItems     *int            `json:"totalItems,omitempty"`
		ProcessedItems *int            `json:"processedItems,omitempty"`
		FailedItems    *int            `json:"failedItems,omitempty"`
		ErrorLog       json.RawMessage `json:"errorLog,omitempty"`
	}

	if err := c.ShouldBindJSON(&update); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Validate status
	if update.Status != "" &&
		update.Status != "pending" &&
		update.Status != "processing" &&
		update.Status != "completed" &&
		update.Status != "failed" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid status. Must be: pending, processing, completed, or failed",
		})
		return
	}

	updates := make(map[string]interface{})

	if update.Status != "" {
		updates["status"] = update.Status

		if update.Status == "completed" {
			updates["completed_at"] = time.Now()
		}
	}

	if update.TotalItems != nil {
		updates["total_items"] = *update.TotalItems
	}

	if update.ProcessedItems != nil {
		updates["processed_items"] = *update.ProcessedItems
	}

	if update.FailedItems != nil {
		updates["failed_items"] = *update.FailedItems
	}

	if update.ErrorLog != nil {
		updates["error_log"] = update.ErrorLog
	}

	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No updates provided",
		})
		return
	}

	result := h.db.Model(&DA2062Import{}).Where("id = ?", id).Updates(updates)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update import",
		})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Import not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Import updated successfully",
	})
}

// AddImportItem adds an item to an import
func (h *DA2062ImportsHandler) AddImportItem(c *gin.Context) {
	importID, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid import ID",
		})
		return
	}

	// Check if import exists
	var importRecord DA2062Import
	if err := h.db.First(&importRecord, importID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Import not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to verify import",
		})
		return
	}

	var item DA2062ImportItem
	if err := c.ShouldBindJSON(&item); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Set import ID and validate
	item.ImportID = importID
	if item.LineNumber == 0 || item.RawData == nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "lineNumber and rawData are required",
		})
		return
	}

	if item.Status == "" {
		item.Status = "pending"
	}

	if err := h.db.Create(&item).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create import item",
		})
		return
	}

	// Update total items count
	h.db.Model(&DA2062Import{}).Where("id = ?", importID).
		Update("total_items", gorm.Expr("total_items + ?", 1))

	c.JSON(http.StatusCreated, item)
}

// UpdateImportItem updates the status of an import item
func (h *DA2062ImportsHandler) UpdateImportItem(c *gin.Context) {
	itemID, err := strconv.ParseInt(c.Param("itemId"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid item ID",
		})
		return
	}

	var update struct {
		PropertyID   *int64  `json:"propertyId,omitempty"`
		Status       string  `json:"status"`
		ErrorMessage *string `json:"errorMessage,omitempty"`
	}

	if err := c.ShouldBindJSON(&update); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	// Validate status
	if update.Status != "" &&
		update.Status != "pending" &&
		update.Status != "processed" &&
		update.Status != "failed" &&
		update.Status != "duplicate" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid status. Must be: pending, processed, failed, or duplicate",
		})
		return
	}

	updates := make(map[string]interface{})

	if update.Status != "" {
		updates["status"] = update.Status
	}

	if update.PropertyID != nil {
		updates["property_id"] = *update.PropertyID
	}

	if update.ErrorMessage != nil {
		updates["error_message"] = *update.ErrorMessage
	}

	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No updates provided",
		})
		return
	}

	result := h.db.Model(&DA2062ImportItem{}).Where("id = ?", itemID).Updates(updates)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update import item",
		})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Import item not found",
		})
		return
	}

	// Update import counters if status changed
	if update.Status == "processed" || update.Status == "failed" {
		var item DA2062ImportItem
		h.db.First(&item, itemID)

		if update.Status == "processed" {
			h.db.Model(&DA2062Import{}).Where("id = ?", item.ImportID).
				Update("processed_items", gorm.Expr("processed_items + ?", 1))
		} else if update.Status == "failed" {
			h.db.Model(&DA2062Import{}).Where("id = ?", item.ImportID).
				Update("failed_items", gorm.Expr("failed_items + ?", 1))
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Import item updated successfully",
	})
}

// DeleteImport deletes a DA2062 import and all its items
func (h *DA2062ImportsHandler) DeleteImport(c *gin.Context) {
	id, err := strconv.ParseInt(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid import ID",
		})
		return
	}

	// Items will be deleted automatically due to CASCADE
	result := h.db.Delete(&DA2062Import{}, id)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete import",
		})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Import not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Import deleted successfully",
	})
}