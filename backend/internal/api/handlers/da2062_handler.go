package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"log"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/models"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/email"
	"github.com/toole-brendan/handreceipt-go/internal/services/ocr"
	"github.com/toole-brendan/handreceipt-go/internal/services/pdf"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
	"gorm.io/gorm"
)

// DA2062Handler handles DA2062-related operations
type DA2062Handler struct {
	Ledger         ledger.LedgerService
	Repo           repository.Repository
	PDFGenerator   *pdf.DA2062Generator
	EmailService   *email.DA2062EmailService
	OCRService     *ocr.AzureOCRService
	StorageService storage.StorageService
}

// NewDA2062Handler creates a new DA2062 handler
func NewDA2062Handler(
	ledgerService ledger.LedgerService,
	repo repository.Repository,
	pdfGenerator *pdf.DA2062Generator,
	emailService *email.DA2062EmailService,
	ocrService *ocr.AzureOCRService,
	storageService storage.StorageService,
) *DA2062Handler {
	return &DA2062Handler{
		Ledger:         ledgerService,
		Repo:           repo,
		PDFGenerator:   pdfGenerator,
		EmailService:   emailService,
		OCRService:     ocrService,
		StorageService: storageService,
	}
}

// BatchCreateInventory handles batch creation of properties from DA2062 import
func (h *DA2062Handler) BatchCreateInventory(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	var req models.BatchCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: " + err.Error()})
		return
	}

	// Process items and create Property objects
	var properties []domain.Property
	var createdProperties []domain.Property

	for _, item := range req.Items {
		// Check if this item needs quantity expansion
		if item.ImportMetadata != nil &&
			item.ImportMetadata.OriginalQuantity > 1 &&
			item.ImportMetadata.SerialSource == "generated" {
			// This item represents a multi-quantity entry
			// The frontend should have already done the expansion, but we double-check
		}

		// Convert ImportMetadata to JSON string for storage
		var metadataJSON string
		if item.ImportMetadata != nil {
			metadataBytes, err := json.Marshal(item.ImportMetadata)
			if err != nil {
				log.Printf("Failed to marshal import metadata: %v", err)
			} else {
				metadataJSON = string(metadataBytes)
			}
		}

		// Extract source document URL from metadata if available
		var sourceDocumentURL *string
		if item.ImportMetadata != nil && item.ImportMetadata.SourceDocumentURL != "" {
			sourceDocumentURL = &item.ImportMetadata.SourceDocumentURL
		}

		// Create Property object
		property := domain.Property{
			Name:              item.Name,
			SerialNumber:      item.SerialNumber,
			Description:       &item.Description,
			NSN:               &item.NSN,
			Quantity:          item.Quantity,
			CurrentStatus:     "Active",
			SourceType:        &req.Source,
			SourceRef:         &item.SourceRef,
			SourceDocumentURL: sourceDocumentURL,
			ImportMetadata:    &metadataJSON,
			AssignedToUserID:  &userID,
		}

		// Set defaults
		if property.CurrentStatus == "" {
			property.CurrentStatus = "Active"
		}

		// Mark for verification if needed
		if item.ImportMetadata != nil && item.ImportMetadata.RequiresVerification {
			property.Verified = false
		} else {
			property.Verified = true
			now := time.Now()
			property.VerifiedAt = &now
			property.VerifiedBy = &userID
		}

		properties = append(properties, property)
	}

	// Create properties in batch
	for i := range properties {
		if err := h.Repo.CreateProperty(&properties[i]); err != nil {
			// Check for duplicate serial number
			if strings.Contains(err.Error(), "duplicate") && strings.Contains(err.Error(), "serial_number") {
				c.JSON(http.StatusBadRequest, gin.H{
					"error":         fmt.Sprintf("Property with serial number '%s' already exists", properties[i].SerialNumber),
					"created_count": len(createdProperties),
				})
				return
			}
			log.Printf("Failed to create property: %v", err)
			continue
		}
		createdProperties = append(createdProperties, properties[i])
	}

	// Log batch creation to ledger - log first property as representative
	if len(createdProperties) > 0 {
		// Log the first item creation with batch metadata in description
		batchDescription := fmt.Sprintf("DA2062 Batch Import: %d items, Source: %s, Reference: %s",
			len(createdProperties), req.Source, req.SourceReference)

		// Create a property with batch metadata for logging
		batchProperty := createdProperties[0]
		batchProperty.Description = &batchDescription

		errLedger := h.Ledger.LogPropertyCreation(batchProperty, userID)
		if errLedger != nil {
			log.Printf("WARNING: Failed to log batch import to ledger: %v", errLedger)
		}
	}

	// Group items by verification status for response
	verificationNeeded := []domain.Property{}
	verified := []domain.Property{}

	for _, prop := range createdProperties {
		if prop.ImportMetadata != nil && !prop.Verified {
			verificationNeeded = append(verificationNeeded, prop)
		} else {
			verified = append(verified, prop)
		}
	}

	c.JSON(http.StatusCreated, gin.H{
		"items":               createdProperties,
		"count":               len(createdProperties),
		"verified_count":      len(verified),
		"verification_needed": verificationNeeded,
		"summary":             generateImportSummary(createdProperties),
	})
}

// VerifyImportedItem verifies an imported property
func (h *DA2062Handler) VerifyImportedItem(c *gin.Context) {
	itemID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid ID format"})
		return
	}

	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	var req models.VerifyItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Get the property
	property, err := h.Repo.GetPropertyByID(uint(itemID))
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property"})
		}
		return
	}

	// Check ownership
	if property.AssignedToUserID == nil || *property.AssignedToUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only verify your own properties"})
		return
	}

	// Update verification fields
	if req.SerialNumber != "" {
		property.SerialNumber = req.SerialNumber

		// Update import metadata if exists
		if property.ImportMetadata != nil {
			var metadata models.ImportMetadata
			if err := json.Unmarshal([]byte(*property.ImportMetadata), &metadata); err == nil {
				metadata.SerialSource = "manual"
				if metadataBytes, err := json.Marshal(metadata); err == nil {
					metadataStr := string(metadataBytes)
					property.ImportMetadata = &metadataStr
				}
			}
		}
	}

	if req.NSN != "" {
		property.NSN = &req.NSN
	}

	property.Verified = true
	now := time.Now()
	property.VerifiedAt = &now
	property.VerifiedBy = &userID
	property.UpdatedAt = now

	// Update in database
	if err := h.Repo.UpdateProperty(property); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update property"})
		return
	}

	// Log verification to ledger
	errLedger := h.Ledger.LogVerificationEvent(property.ID, property.SerialNumber, userID, "DA2062_VERIFICATION")
	if errLedger != nil {
		log.Printf("WARNING: Failed to log verification to ledger: %v", errLedger)
	}

	c.JSON(http.StatusOK, gin.H{
		"property": property,
		"message":  "Property verified successfully",
	})
}

// GetUnverifiedItems returns properties that need verification
func (h *DA2062Handler) GetUnverifiedItems(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Get all properties for the user and filter unverified ones
	allProperties, err := h.Repo.ListProperties(&userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch properties"})
		return
	}

	// Filter for unverified properties
	var properties []domain.Property
	for _, prop := range allProperties {
		if !prop.Verified {
			properties = append(properties, prop)
		}
	}

	// Group by verification reason
	grouped := make(map[string][]domain.Property)

	for _, prop := range properties {
		if prop.ImportMetadata != nil {
			var metadata models.ImportMetadata
			if err := json.Unmarshal([]byte(*prop.ImportMetadata), &metadata); err == nil {
				for _, reason := range metadata.VerificationReasons {
					grouped[reason] = append(grouped[reason], prop)
				}
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"items":             properties,
		"count":             len(properties),
		"grouped_by_reason": grouped,
	})
}

// UploadDA2062 handles DA2062 form upload with Azure OCR processing
func (h *DA2062Handler) UploadDA2062(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Get uploaded file
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}
	defer file.Close()

	// Validate file type
	contentType := header.Header.Get("Content-Type")
	if !isValidImageType(contentType) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file type. Only images and PDFs are supported"})
		return
	}

	// Read file data
	fileData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	// Upload to Azure Blob Storage for OCR processing
	ctx := context.Background()
	objectName := fmt.Sprintf("da2062-scans/%d/%d-%s", userID, time.Now().Unix(), header.Filename)

	err = h.StorageService.UploadFile(ctx, objectName, strings.NewReader(string(fileData)), int64(len(fileData)), contentType)
	if err != nil {
		log.Printf("Failed to upload file to storage: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store file"})
		return
	}

	// Get presigned URL for Azure OCR
	imageURL, err := h.StorageService.GetPresignedURL(ctx, objectName, 1*time.Hour)
	if err != nil {
		log.Printf("Failed to get presigned URL: %v", err)
		// Fallback to direct bytes processing
		parsedForm, err := h.OCRService.ProcessImageFromBytes(ctx, fileData, contentType)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "OCR processing failed: " + err.Error()})
			return
		}
		h.respondWithParsedForm(c, parsedForm, userID)
		return
	}

	// Process with Azure OCR using URL
	parsedForm, err := h.OCRService.ProcessImageFromURL(ctx, imageURL)
	if err != nil {
		log.Printf("Azure OCR failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "OCR processing failed: " + err.Error()})
		return
	}

	h.respondWithParsedForm(c, parsedForm, userID)
}

// isValidImageType checks if the content type is supported
func isValidImageType(contentType string) bool {
	supportedTypes := []string{
		"image/jpeg",
		"image/jpg",
		"image/png",
		"image/tiff",
		"image/bmp",
		"application/pdf",
	}

	for _, validType := range supportedTypes {
		if contentType == validType {
			return true
		}
	}
	return false
}

// respondWithParsedForm converts OCR results to API response format
func (h *DA2062Handler) respondWithParsedForm(c *gin.Context, parsedForm *ocr.DA2062ParsedForm, userID uint) {
	// Convert OCR parsed items to API format
	var items []models.DA2062ImportItem

	for _, ocrItem := range parsedForm.Items {
		// Generate or use existing serial number
		serialNumber := ocrItem.SerialNumber
		if serialNumber == "" {
			// Generate a placeholder serial for items without serials
			serialNumber = fmt.Sprintf("NOSERIAL-%s-%d", ocrItem.NSN, time.Now().Unix())
		}

		// Create import metadata
		importMetadata := models.ImportMetadata{
			Source:               "azure_ocr",
			FormNumber:           parsedForm.FormNumber,
			ScanConfidence:       ocrItem.Confidence,
			SerialSource:         getSerialSource(ocrItem),
			OriginalQuantity:     ocrItem.Quantity,
			RequiresVerification: len(ocrItem.VerificationReasons) > 0 || ocrItem.Confidence < 0.7,
			VerificationReasons:  ocrItem.VerificationReasons,
		}

		item := models.DA2062ImportItem{
			Name:           ocrItem.ItemDescription,
			Description:    ocrItem.ItemDescription,
			SerialNumber:   serialNumber,
			NSN:            ocrItem.NSN,
			Quantity:       ocrItem.Quantity,
			SourceRef:      parsedForm.FormNumber,
			ImportMetadata: &importMetadata,
		}

		items = append(items, item)
	}

	// Build response
	response := gin.H{
		"success": true,
		"form_info": gin.H{
			"unit_name":   parsedForm.UnitName,
			"dodaac":      parsedForm.DODAAC,
			"form_number": parsedForm.FormNumber,
			"confidence":  parsedForm.Confidence,
		},
		"items":       items,
		"total_items": len(items),
		"metadata":    parsedForm.Metadata,
		"next_steps": gin.H{
			"verification_needed": parsedForm.Metadata.RequiresVerification,
			"message":             "Review items and submit for creation",
		},
	}

	c.JSON(http.StatusOK, response)
}

// getSerialSource determines how the serial number was obtained
func getSerialSource(item ocr.DA2062ParsedItem) string {
	if item.SerialNumber == "" {
		return "none"
	}
	if item.HasExplicitSerial {
		return "ocr_explicit"
	}
	return "ocr_inferred"
}

// SearchDA2062Forms searches for DA2062 forms
func (h *DA2062Handler) SearchDA2062Forms(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Get search parameters
	sourceRef := c.Query("reference")
	formNumber := c.Query("form_number")

	// Get all properties for user and filter by source reference
	allProperties, err := h.Repo.ListProperties(&userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search forms"})
		return
	}

	// Filter properties by source reference and form number
	var properties []domain.Property
	for _, prop := range allProperties {
		if prop.SourceRef != nil && (sourceRef == "" || *prop.SourceRef == sourceRef) {
			// Check form number in metadata if provided
			if formNumber != "" && prop.ImportMetadata != nil {
				var metadata models.ImportMetadata
				if err := json.Unmarshal([]byte(*prop.ImportMetadata), &metadata); err == nil {
					if metadata.FormNumber == formNumber {
						properties = append(properties, prop)
					}
				}
			} else if formNumber == "" {
				properties = append(properties, prop)
			}
		}
	}

	// Group by source reference to represent forms
	forms := make(map[string][]domain.Property)
	for _, prop := range properties {
		if prop.SourceRef != nil {
			forms[*prop.SourceRef] = append(forms[*prop.SourceRef], prop)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"forms": forms,
		"count": len(forms),
	})
}

// GetDA2062Items gets items from a specific DA2062 form
func (h *DA2062Handler) GetDA2062Items(c *gin.Context) {
	reference := c.Param("reference")

	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Get all properties for user and filter by reference
	allProperties, err := h.Repo.ListProperties(&userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch items"})
		return
	}

	// Filter properties by source reference
	var properties []domain.Property
	for _, prop := range allProperties {
		if prop.SourceRef != nil && *prop.SourceRef == reference {
			properties = append(properties, prop)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"items":     properties,
		"count":     len(properties),
		"reference": reference,
	})
}

// GenerateDA2062PDF generates a PDF from selected properties
func (h *DA2062Handler) GenerateDA2062PDF(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	var req GeneratePDFRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: " + err.Error()})
		return
	}

	// Validate required fields
	if len(req.PropertyIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "At least one property ID is required"})
		return
	}

	// Fetch properties
	var properties []domain.Property
	for _, id := range req.PropertyIDs {
		property, err := h.Repo.GetPropertyByID(id)
		if err != nil {
			continue
		}
		// Verify user has access
		if property.AssignedToUserID != nil && *property.AssignedToUserID == userID {
			properties = append(properties, *property)
		}
	}

	if len(properties) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No valid properties found"})
		return
	}

	// Get user info for the form
	fromUser, err := h.Repo.GetUserByID(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get user information"})
		return
	}

	// Convert user info
	title := "Property Book Officer"
	if fromUser.Unit != "" {
		title = fromUser.Unit
	}

	fromUserInfo := pdf.UserInfo{
		Name:  fromUser.Name,
		Rank:  fromUser.Rank,
		Title: title,
		Phone: fromUser.Phone,
	}

	// Set to user info (same as from for self hand receipt)
	toUserInfo := fromUserInfo
	if req.ToUser.Name != "" {
		toUserInfo = req.ToUser
	}

	// Convert unit info
	unitInfo := pdf.UnitInfo{
		UnitName:    req.UnitInfo.UnitName,
		DODAAC:      req.UnitInfo.DODAAC,
		StockNumber: req.UnitInfo.StockNumber,
		Location:    req.UnitInfo.Location,
	}

	// Generate PDF
	options := pdf.GenerateOptions{
		GroupByCategory:   req.GroupByCategory,
		IncludeSignatures: true,
		IncludeQRCodes:    req.IncludeQRCodes,
	}

	pdfBuffer, err := h.PDFGenerator.GenerateDA2062(
		properties,
		fromUserInfo,
		toUserInfo,
		unitInfo,
		options,
	)

	if err != nil {
		log.Printf("PDF generation failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate PDF"})
		return
	}

	// Generate form number
	formNumber := fmt.Sprintf("HR-%s-%d", time.Now().Format("20060102"), userID)

	// Handle email or download
	if req.SendEmail && len(req.Recipients) > 0 {
		// Send email
		senderInfo := email.UserInfo{
			Name:  fromUserInfo.Name,
			Rank:  fromUserInfo.Rank,
			Title: fromUserInfo.Title,
			Phone: fromUserInfo.Phone,
		}

		err = h.EmailService.SendDA2062Email(req.Recipients, pdfBuffer, formNumber, senderInfo)
		if err != nil {
			log.Printf("Email sending failed: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send email"})
			return
		}

		// Log to ledger
		if err := h.Ledger.LogDA2062Export(userID, len(properties), "email", strings.Join(req.Recipients, ",")); err != nil {
			log.Printf("WARNING: Failed to log DA2062 export to ledger: %v", err)
		}

		c.JSON(http.StatusOK, gin.H{
			"message":     "DA 2062 emailed successfully",
			"form_number": formNumber,
			"recipients":  req.Recipients,
			"item_count":  len(properties),
		})
	} else {
		// Return PDF for download
		filename := fmt.Sprintf("DA2062_%s.pdf", time.Now().Format("20060102_150405"))

		// Log to ledger
		if err := h.Ledger.LogDA2062Export(userID, len(properties), "download", ""); err != nil {
			log.Printf("WARNING: Failed to log DA2062 export to ledger: %v", err)
		}

		c.Header("Content-Type", "application/pdf")
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filename))
		c.Data(http.StatusOK, "application/pdf", pdfBuffer.Bytes())
	}
}

// Helper function to safely get pointer values
func getValueOrDefault(ptr *string, defaultValue string) string {
	if ptr != nil {
		return *ptr
	}
	return defaultValue
}

// Request models for PDF generation
type GeneratePDFRequest struct {
	PropertyIDs     []uint       `json:"property_ids" binding:"required"`
	GroupByCategory bool         `json:"group_by_category"`
	IncludeQRCodes  bool         `json:"include_qr_codes"`
	SendEmail       bool         `json:"send_email"`
	Recipients      []string     `json:"recipients"`
	FromUser        pdf.UserInfo `json:"from_user" binding:"required"`
	ToUser          pdf.UserInfo `json:"to_user"`
	UnitInfo        pdf.UnitInfo `json:"unit_info" binding:"required"`
}

// Helper functions

func countVerificationNeeded(properties []domain.Property) int {
	count := 0
	for _, prop := range properties {
		if !prop.Verified {
			count++
		}
	}
	return count
}

func countGeneratedSerials(properties []domain.Property) int {
	count := 0
	for _, prop := range properties {
		if prop.ImportMetadata != nil {
			var metadata models.ImportMetadata
			if err := json.Unmarshal([]byte(*prop.ImportMetadata), &metadata); err == nil {
				if metadata.SerialSource == "generated" {
					count++
				}
			}
		}
	}
	return count
}

func generateImportSummary(properties []domain.Property) models.ImportSummary {
	summary := models.ImportSummary{
		TotalItems: len(properties),
		Categories: make(map[string]int),
		ConfidenceLevels: map[string]int{
			"high":   0,
			"medium": 0,
			"low":    0,
		},
	}

	for _, prop := range properties {
		// Count by category (using current status as proxy since category field doesn't exist)
		summary.Categories[prop.CurrentStatus]++

		// Count by confidence if metadata exists
		if prop.ImportMetadata != nil {
			var metadata models.ImportMetadata
			if err := json.Unmarshal([]byte(*prop.ImportMetadata), &metadata); err == nil {
				if metadata.ItemConfidence >= 0.8 {
					summary.ConfidenceLevels["high"]++
				} else if metadata.ItemConfidence >= 0.6 {
					summary.ConfidenceLevels["medium"]++
				} else {
					summary.ConfidenceLevels["low"]++
				}
			}
		}
	}

	return summary
}

// RegisterRoutes registers all DA2062-related routes
func (h *DA2062Handler) RegisterRoutes(router *gin.RouterGroup) {
	da2062 := router.Group("/da2062")
	{
		da2062.POST("/upload", h.UploadDA2062)
		da2062.POST("/generate-pdf", h.GenerateDA2062PDF)
		da2062.GET("/search", h.SearchDA2062Forms)
		da2062.GET("/:reference/items", h.GetDA2062Items)
		da2062.GET("/unverified", h.GetUnverifiedItems)
		da2062.PUT("/verify/:id", h.VerifyImportedItem)
	}

	inventory := router.Group("/inventory")
	{
		inventory.POST("/batch", h.BatchCreateInventory)
	}
}
