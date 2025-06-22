package handlers

import (
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
	"gorm.io/gorm"
)

// AttachmentsHandler handles attachment operations
type AttachmentsHandler struct {
	db              *gorm.DB
	storageService  storage.StorageService
	maxFileSize     int64
	allowedMimeTypes []string
}

// NewAttachmentsHandler creates a new attachments handler
func NewAttachmentsHandler(db *gorm.DB, storageService storage.StorageService) *AttachmentsHandler {
	return &AttachmentsHandler{
		db:             db,
		storageService: storageService,
		maxFileSize:    50 * 1024 * 1024, // 50MB default
		allowedMimeTypes: []string{
			"image/jpeg",
			"image/jpg",
			"image/png",
			"image/gif",
			"image/webp",
			"application/pdf",
			"application/msword",
			"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
			"application/vnd.ms-excel",
			"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		},
	}
}

// GetAttachments returns all attachments for a property
func (h *AttachmentsHandler) GetAttachments(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("propertyId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid property ID",
		})
		return
	}

	var attachments []domain.Attachment
	if err := h.db.Where("property_id = ?", propertyID).
		Order("created_at DESC").
		Find(&attachments).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch attachments",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"attachments": attachments,
		"count":       len(attachments),
	})
}

// GetAttachment returns a specific attachment
func (h *AttachmentsHandler) GetAttachment(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid attachment ID",
		})
		return
	}

	var attachment domain.Attachment
	if err := h.db.First(&attachment, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Attachment not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch attachment",
		})
		return
	}

	c.JSON(http.StatusOK, attachment)
}

// UploadAttachment handles file upload for a property
func (h *AttachmentsHandler) UploadAttachment(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("propertyId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid property ID",
		})
		return
	}

	// Get user ID from session
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Check if property exists
	var property domain.Property
	if err := h.db.First(&property, propertyID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Property not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to verify property",
		})
		return
	}

	// Parse multipart form
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No file provided",
		})
		return
	}
	defer file.Close()

	// Validate file size
	if header.Size > h.maxFileSize {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": fmt.Sprintf("File size exceeds maximum allowed size of %d MB", h.maxFileSize/(1024*1024)),
		})
		return
	}

	// Detect MIME type
	buffer := make([]byte, 512)
	_, err = file.Read(buffer)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to read file",
		})
		return
	}
	mimeType := http.DetectContentType(buffer)
	file.Seek(0, 0) // Reset file reader

	// Validate MIME type
	isAllowed := false
	for _, allowed := range h.allowedMimeTypes {
		if strings.HasPrefix(mimeType, allowed) {
			isAllowed = true
			break
		}
	}
	if !isAllowed {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "File type not allowed",
		})
		return
	}

	// Generate unique filename
	ext := filepath.Ext(header.Filename)
	filename := fmt.Sprintf("property_%d_%s%s", propertyID, uuid.New().String(), ext)
	
	// Upload to storage service
	err = h.storageService.UploadFile(c.Request.Context(), filename, file, header.Size, mimeType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to upload file",
		})
		return
	}
	
	// Generate file URL (assumes MinIO/S3 public access)
	// You may want to use GetPresignedURL for private access
	fileURL := fmt.Sprintf("/api/attachments/download/%s", filename)

	// Get description from form
	description := c.PostForm("description")

	// Create attachment record
	attachment := domain.Attachment{
		PropertyID:       uint(propertyID),
		FileName:         header.Filename,
		FileURL:          fileURL,
		FileSize:         &header.Size,
		MimeType:         &mimeType,
		UploadedByUserID: userID.(uint),
		Description:      &description,
	}

	if err := h.db.Create(&attachment).Error; err != nil {
		// Try to delete uploaded file if database insert fails
		h.storageService.DeleteFile(c.Request.Context(), filename)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to save attachment record",
		})
		return
	}

	c.JSON(http.StatusCreated, attachment)
}

// UpdateAttachment updates attachment metadata
func (h *AttachmentsHandler) UpdateAttachment(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid attachment ID",
		})
		return
	}

	var update struct {
		Description *string `json:"description"`
	}

	if err := c.ShouldBindJSON(&update); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	updates := make(map[string]interface{})

	if update.Description != nil {
		updates["description"] = *update.Description
	}

	if len(updates) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "No updates provided",
		})
		return
	}

	result := h.db.Model(&domain.Attachment{}).Where("id = ?", id).Updates(updates)
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update attachment",
		})
		return
	}

	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Attachment not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Attachment updated successfully",
	})
}

// DeleteAttachment deletes an attachment
func (h *AttachmentsHandler) DeleteAttachment(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid attachment ID",
		})
		return
	}

	// Get user ID from session
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "User not authenticated",
		})
		return
	}

	// Fetch attachment to get file info
	var attachment domain.Attachment
	if err := h.db.First(&attachment, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Attachment not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch attachment",
		})
		return
	}

	// Check if user has permission to delete (uploader or property owner)
	var property domain.Property
	h.db.First(&property, attachment.PropertyID)
	
	if attachment.UploadedByUserID != userID.(uint) && property.AssignedToUserID != nil && *property.AssignedToUserID != userID.(uint) {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "You don't have permission to delete this attachment",
		})
		return
	}

	// Extract filename from URL for deletion
	parts := strings.Split(attachment.FileURL, "/")
	filename := parts[len(parts)-1]

	// Delete from database
	if err := h.db.Delete(&attachment).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete attachment",
		})
		return
	}

	// Delete from storage (best effort - don't fail if storage deletion fails)
	go h.storageService.DeleteFile(c.Request.Context(), filename)

	c.JSON(http.StatusOK, gin.H{
		"message": "Attachment deleted successfully",
	})
}

// GetAllAttachments returns attachments with optional filtering
func (h *AttachmentsHandler) GetAllAttachments(c *gin.Context) {
	userID := c.Query("userId")
	mimeType := c.Query("mimeType")
	startDate := c.Query("startDate")
	endDate := c.Query("endDate")
	limit := c.DefaultQuery("limit", "100")
	offset := c.DefaultQuery("offset", "0")

	query := h.db.Model(&domain.Attachment{})

	if userID != "" {
		query = query.Where("uploaded_by_user_id = ?", userID)
	}

	if mimeType != "" {
		query = query.Where("mime_type LIKE ?", mimeType+"%")
	}

	if startDate != "" {
		if parsedDate, err := time.Parse("2006-01-02", startDate); err == nil {
			query = query.Where("created_at >= ?", parsedDate)
		}
	}

	if endDate != "" {
		if parsedDate, err := time.Parse("2006-01-02", endDate); err == nil {
			endDateTime := parsedDate.Add(24 * time.Hour)
			query = query.Where("created_at < ?", endDateTime)
		}
	}

	// Parse limit and offset
	limitInt, _ := strconv.Atoi(limit)
	offsetInt, _ := strconv.Atoi(offset)

	var total int64
	query.Count(&total)

	var attachments []domain.Attachment
	if err := query.Order("created_at DESC").
		Limit(limitInt).
		Offset(offsetInt).
		Preload("Property").
		Preload("UploadedByUser").
		Find(&attachments).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch attachments",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"attachments": attachments,
		"total":       total,
		"limit":       limitInt,
		"offset":      offsetInt,
	})
}

// GetAttachmentStats returns statistics about attachments
func (h *AttachmentsHandler) GetAttachmentStats(c *gin.Context) {
	type MimeTypeCount struct {
		MimeType string `json:"mimeType"`
		Count    int64  `json:"count"`
	}

	var mimeTypeCounts []MimeTypeCount
	h.db.Model(&domain.Attachment{}).
		Select("mime_type, COUNT(*) as count").
		Group("mime_type").
		Order("count DESC").
		Find(&mimeTypeCounts)

	var totalCount int64
	h.db.Model(&domain.Attachment{}).Count(&totalCount)

	var totalSize int64
	h.db.Model(&domain.Attachment{}).
		Select("COALESCE(SUM(file_size), 0)").
		Scan(&totalSize)

	// Get top uploaders
	type TopUploader struct {
		UserID uint  `json:"userId"`
		Count  int64 `json:"count"`
	}

	var topUploaders []TopUploader
	h.db.Model(&domain.Attachment{}).
		Select("uploaded_by_user_id as user_id, COUNT(*) as count").
		Group("uploaded_by_user_id").
		Order("count DESC").
		Limit(10).
		Find(&topUploaders)

	c.JSON(http.StatusOK, gin.H{
		"totalAttachments": totalCount,
		"totalSizeBytes":   totalSize,
		"totalSizeMB":      totalSize / (1024 * 1024),
		"byMimeType":       mimeTypeCounts,
		"topUploaders":     topUploaders,
	})
}

// DownloadAttachment handles attachment download
func (h *AttachmentsHandler) DownloadAttachment(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid attachment ID",
		})
		return
	}

	var attachment domain.Attachment
	if err := h.db.First(&attachment, id).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Attachment not found",
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch attachment",
		})
		return
	}

	// Extract filename from URL
	parts := strings.Split(attachment.FileURL, "/")
	storageFilename := parts[len(parts)-1]

	// Get file from storage
	reader, err := h.storageService.DownloadFile(c.Request.Context(), storageFilename)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to download file",
		})
		return
	}
	defer reader.Close()

	// Set headers
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", attachment.FileName))
	if attachment.MimeType != nil {
		c.Header("Content-Type", *attachment.MimeType)
	}
	if attachment.FileSize != nil {
		c.Header("Content-Length", strconv.FormatInt(*attachment.FileSize, 10))
	}

	// Stream the file
	io.Copy(c.Writer, reader)
}