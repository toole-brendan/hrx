package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
)

// PhotoHandler handles photo upload operations
type PhotoHandler struct {
	Storage storage.StorageService
	Repo    repository.Repository
	Ledger  ledger.LedgerService
}

// NewPhotoHandler creates a new photo handler
func NewPhotoHandler(storage storage.StorageService, repo repository.Repository, ledger ledger.LedgerService) *PhotoHandler {
	return &PhotoHandler{
		Storage: storage,
		Repo:    repo,
		Ledger:  ledger,
	}
}

// UploadPropertyPhoto handles photo upload for a property
func (h *PhotoHandler) UploadPropertyPhoto(c *gin.Context) {
	// Parse property ID from URL
	propertyIDStr := c.Param("propertyId")
	propertyID, err := strconv.ParseUint(propertyIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	// Get user ID from context
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := userIDVal.(uint)

	// Get the property to verify ownership
	property, err := h.Repo.GetPropertyByID(uint(propertyID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}

	// Check if user owns the property or has permission to upload
	if property.AssignedToUserID == nil || *property.AssignedToUserID != userID {
		// Check if user is transferring the property (sender can upload photos)
		// This would require additional logic to check pending transfers
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized to upload photo for this property"})
		return
	}

	// Parse multipart form
	file, header, err := c.Request.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No photo provided"})
		return
	}
	defer file.Close()

	// Validate file size (max 10MB)
	if header.Size > 10*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo size exceeds 10MB limit"})
		return
	}

	// Validate content type
	contentType := header.Header.Get("Content-Type")
	if contentType != "image/jpeg" && contentType != "image/png" && contentType != "image/webp" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file type. Only JPEG, PNG, and WebP are allowed"})
		return
	}

	// Read file data for hashing
	fileData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	// Calculate SHA-256 hash
	hash := sha256.Sum256(fileData)
	hashString := hex.EncodeToString(hash[:])

	// Generate unique filename
	timestamp := time.Now().Unix()
	filename := fmt.Sprintf("properties/%d/%d_%s_%s", propertyID, timestamp, hashString[:8], header.Filename)

	// Reset file reader
	file.Seek(0, 0)

	// Upload to MinIO
	err = h.Storage.UploadFile(c.Request.Context(), filename, file, header.Size, contentType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload photo"})
		return
	}

	// Generate presigned URL for accessing the photo
	photoURL, err := h.Storage.GetPresignedURL(c.Request.Context(), filename, 24*time.Hour*365) // 1 year
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate photo URL"})
		return
	}

	// Log photo upload to ledger with hash
	// Using LogVerificationEvent for photo upload tracking
	// The verificationType field will indicate it's a photo upload
	verificationType := fmt.Sprintf("PHOTO_UPLOAD|%s|%s", filename, hashString)
	err = h.Ledger.LogVerificationEvent(uint(propertyID), property.SerialNumber, userID, verificationType)
	if err != nil {
		// Log error but don't fail the upload since file is already in MinIO
		fmt.Printf("WARNING: Failed to log photo upload to ledger: %v\n", err)
	}

	c.JSON(http.StatusOK, gin.H{
		"message":  "Photo uploaded successfully",
		"photoUrl": photoURL,
		"hash":     hashString,
		"filename": filename,
	})
}

// VerifyPhotoHash verifies that a photo's hash matches the ledger record
func (h *PhotoHandler) VerifyPhotoHash(c *gin.Context) {
	// Parse property ID
	propertyIDStr := c.Param("propertyId")
	propertyID, err := strconv.ParseUint(propertyIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	// Get user ID from context (for logging purposes)
	userIDVal, _ := c.Get("userID")
	userID := uint(0)
	if uid, ok := userIDVal.(uint); ok {
		userID = uid
	}

	// Get expected hash from query param
	expectedHash := c.Query("hash")
	if expectedHash == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Hash parameter required"})
		return
	}

	// Get filename from query param
	filename := c.Query("filename")
	if filename == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Filename parameter required"})
		return
	}

	// Download file from MinIO
	object, err := h.Storage.DownloadFile(c.Request.Context(), filename)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Photo not found"})
		return
	}
	defer object.Close()

	// Read and hash the file
	fileData, err := io.ReadAll(object)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read photo"})
		return
	}

	// Calculate hash
	hash := sha256.Sum256(fileData)
	actualHash := hex.EncodeToString(hash[:])

	// Compare hashes
	isValid := actualHash == expectedHash

	// Log verification attempt
	verificationType := fmt.Sprintf("PHOTO_VERIFY|%s|%v", filename, isValid)
	err = h.Ledger.LogVerificationEvent(uint(propertyID), "", userID, verificationType)
	if err != nil {
		fmt.Printf("WARNING: Failed to log photo verification: %v\n", err)
	}

	c.JSON(http.StatusOK, gin.H{
		"valid":        isValid,
		"expectedHash": expectedHash,
		"actualHash":   actualHash,
	})
}

// DeletePropertyPhoto handles photo deletion
func (h *PhotoHandler) DeletePropertyPhoto(c *gin.Context) {
	// Parse property ID
	propertyIDStr := c.Param("propertyId")
	propertyID, err := strconv.ParseUint(propertyIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	// Get user ID from context
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID := userIDVal.(uint)

	// Get the property to verify ownership
	property, err := h.Repo.GetPropertyByID(uint(propertyID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}

	// Check if user owns the property
	if property.AssignedToUserID == nil || *property.AssignedToUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized to delete photo for this property"})
		return
	}

	// Get filename from request
	var deleteReq struct {
		Filename string `json:"filename" binding:"required"`
	}
	if err := c.ShouldBindJSON(&deleteReq); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Filename required"})
		return
	}

	// Delete from MinIO
	err = h.Storage.DeleteFile(c.Request.Context(), deleteReq.Filename)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete photo"})
		return
	}

	// Log deletion using status change event
	// Using old and new status to indicate photo deletion
	oldStatus := fmt.Sprintf("PHOTO|%s", deleteReq.Filename)
	newStatus := "PHOTO_DELETED"
	err = h.Ledger.LogStatusChange(uint(propertyID), property.SerialNumber, oldStatus, newStatus, userID)
	if err != nil {
		fmt.Printf("WARNING: Failed to log photo deletion: %v\n", err)
	}

	c.JSON(http.StatusOK, gin.H{"message": "Photo deleted successfully"})
}
