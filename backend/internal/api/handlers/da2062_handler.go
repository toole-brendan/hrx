//backend/internal/api/handlers/da2062_handler.go

package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"log"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/models"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/ai"
	"github.com/toole-brendan/handreceipt-go/internal/services/email"
	"github.com/toole-brendan/handreceipt-go/internal/services/documents"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
	"gorm.io/gorm"
)

// DA2062Handler handles DA2062-related operations
type DA2062Handler struct {
	Ledger         ledger.LedgerService
	Repo           repository.Repository
	PDFGenerator   *documents.DA2062Generator
	EmailService   *email.DA2062EmailService
	StorageService storage.StorageService
}

// NewDA2062Handler creates a new DA2062 handler
func NewDA2062Handler(
	ledgerService ledger.LedgerService,
	repo repository.Repository,
	pdfGenerator *documents.DA2062Generator,
	emailService *email.DA2062EmailService,
	storageService storage.StorageService,
) *DA2062Handler {
	return &DA2062Handler{
		Ledger:         ledgerService,
		Repo:           repo,
		PDFGenerator:   pdfGenerator,
		EmailService:   emailService,
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
	var createdProperties []domain.Property
	var failedItems []models.BatchFailedItem

	for _, item := range req.Items {
		// Validate item before attempting creation
		if validationError := validateBatchItem(item); validationError != "" {
			failedItems = append(failedItems, models.BatchFailedItem{
				Item:   item,
				Error:  validationError,
				Reason: "validation_failed",
			})
			continue
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

		// Attempt to create the property
		if err := h.Repo.CreateProperty(&property); err != nil {
			// Log error but continue with other items
			log.Printf("Failed to create property %s (SN: %s): %v", property.Name, property.SerialNumber, err)

			var errorMessage string
			var reason string

			// Check for specific error types
			if strings.Contains(err.Error(), "duplicate") && strings.Contains(err.Error(), "serial_number") {
				errorMessage = fmt.Sprintf("Property with serial number '%s' already exists", property.SerialNumber)
				reason = "duplicate_serial"
			} else {
				errorMessage = err.Error()
				reason = "creation_failed"
			}

			failedItems = append(failedItems, models.BatchFailedItem{
				Item:   item,
				Error:  errorMessage,
				Reason: reason,
			})
			continue
		}

		// Successfully created
		createdProperties = append(createdProperties, property)

		// Log each individual property creation to ledger with DA2062 context
		errLedger := h.Ledger.LogPropertyCreation(property, userID)
		if errLedger != nil {
			log.Printf("WARNING: Failed to log property creation (SN: %s) to ledger: %v", property.SerialNumber, errLedger)
		} else {
			log.Printf("✅ Logged DA2062 property creation to immutable ledger: %s (SN: %s)",
				property.Name, property.SerialNumber)
		}
	}

	// Log comprehensive DA2062 import event to ledger
	if len(createdProperties) > 0 {
		// Create detailed import metadata for ledger
		importDescription := fmt.Sprintf("DA2062 Import: %d properties created from %s scan. Source: %s, Reference: %s. Properties: %s",
			len(createdProperties),
			req.Source,
			req.Source,
			req.SourceReference,
			buildPropertySummaryForLedger(createdProperties))

		// Log DA2062 export event with comprehensive metadata
		errLedger := h.Ledger.LogDA2062Export(userID, len(createdProperties), "import", importDescription)
		if errLedger != nil {
			log.Printf("WARNING: Failed to log DA2062 import event to ledger: %v", errLedger)
		} else {
			log.Printf("✅ Logged comprehensive DA2062 import event to immutable ledger: %d items", len(createdProperties))
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

	// Determine response status
	statusCode := http.StatusCreated
	if len(createdProperties) == 0 {
		statusCode = http.StatusBadRequest
	} else if len(failedItems) > 0 {
		statusCode = http.StatusPartialContent // 206 for partial success
	}

	response := gin.H{
		"items":               createdProperties,
		"created_count":       len(createdProperties),
		"failed_count":        len(failedItems),
		"total_attempted":     len(req.Items),
		"verified_count":      len(verified),
		"verification_needed": verificationNeeded,
		"failed_items":        failedItems,
		"summary":             generateImportSummary(createdProperties),
	}

	// Add error details if there are failures
	if len(failedItems) > 0 {
		response["errors"] = failedItems
		if len(createdProperties) == 0 {
			response["error"] = "No items were successfully imported"
		} else {
			response["message"] = fmt.Sprintf("Partial success: %d of %d items imported", len(createdProperties), len(req.Items))
		}
	}

	c.JSON(statusCode, response)
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

/* ------------------------------------------------------------------
   ⚠️ Legacy OCR upload removed – preserved for reference only
------------------------------------------------------------------ */
/*
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
		// Pass the blob storage path as document URL
		documentURL := fmt.Sprintf("/storage/%s", objectName)
		h.respondWithParsedForm(c, parsedForm, userID, documentURL)
		return
	}

	// Process with Azure OCR using URL
	parsedForm, err := h.OCRService.ProcessImageFromURL(ctx, imageURL)
	if err != nil {
		log.Printf("Azure OCR failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "OCR processing failed: " + err.Error()})
		return
	}

	// Pass the blob storage path as document URL
	documentURL := fmt.Sprintf("/storage/%s", objectName)
	h.respondWithParsedForm(c, parsedForm, userID, documentURL)
}
*/

/* ------------------------------------------------------------------
   ⭐ NEW: ImportDA2062 – upload + parse with Claude
------------------------------------------------------------------ */
func (h *DA2062Handler) ImportDA2062(c *gin.Context) {
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

	// Upload to storage for record keeping
	ctx := context.Background()
	objectName := fmt.Sprintf("da2062-scans/%d/%d-%s", userID, time.Now().Unix(), header.Filename)
	err = h.StorageService.UploadFile(ctx, objectName, bytes.NewReader(fileData), int64(len(fileData)), contentType)
	if err != nil {
		log.Printf("Failed to upload file to storage: %v", err)
		// Continue anyway - storage is not critical for import
	}

	// Parse with Claude AI
	items, meta, err := ai.ParseDA2062WithRetry(bytes.NewReader(fileData), contentType, 3)
	if err != nil {
		log.Printf("Claude AI parsing failed: %v", err)
		c.JSON(http.StatusBadGateway, gin.H{"error": "Failed to parse DA 2062: " + err.Error()})
		return
	}

	// Convert parsed items to API format
	documentURL := fmt.Sprintf("/storage/%s", objectName)
	var importItems []models.DA2062ImportItem
	for _, item := range items {
		importMetadata := models.ImportMetadata{
			Source:               "claude_ai",
			FormNumber:           meta.FormNumber,
			ScanConfidence:       item.Confidence,
			SerialSource:         "ai_extracted",
			OriginalQuantity:     item.Quantity,
			RequiresVerification: item.Confidence < 0.8,
			VerificationReasons:  []string{},
			SourceDocumentURL:    documentURL,
		}

		if item.SerialNumber == "" || item.SerialNumber == "N/A" {
			importMetadata.VerificationReasons = append(importMetadata.VerificationReasons, "missing_serial_number")
			importMetadata.RequiresVerification = true
		}

		importItem := models.DA2062ImportItem{
			Name:           item.Name,
			Description:    item.Name,
			SerialNumber:   item.SerialNumber,
			NSN:            item.NSN,
			Quantity:       item.Quantity,
			SourceRef:      meta.FormNumber,
			ImportMetadata: &importMetadata,
		}
		importItems = append(importItems, importItem)
	}

	// Log the import with monitoring
	log.Printf("Claude API DA2062 import: %d items extracted, confidence avg: %.2f", 
		len(items), calculateAverageConfidence(items))

	// Build response
	response := gin.H{
		"success": true,
		"form_info": gin.H{
			"from_unit":   meta.From,
			"to_unit":     meta.To,
			"date":        meta.Date,
			"form_number": meta.FormNumber,
		},
		"items":       importItems,
		"total_items": len(importItems),
		"metadata": gin.H{
			"parsed_by": "claude_ai",
			"timestamp": time.Now().Format(time.RFC3339),
		},
		"next_steps": gin.H{
			"verification_needed":  countItemsNeedingReview(importItems),
			"suggested_action":     "Review items and submit for creation",
		},
	}

	c.JSON(http.StatusOK, response)
}

// calculateAverageConfidence calculates the average confidence score
func calculateAverageConfidence(items []ai.ParsedItem) float64 {
	if len(items) == 0 {
		return 0
	}
	total := 0.0
	for _, item := range items {
		total += item.Confidence
	}
	return total / float64(len(items))
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

/* ------------------------------------------------------------------
   ⚠️ Legacy OCR helper functions - preserved for reference
------------------------------------------------------------------ */
/*
// respondWithParsedForm converts OCR results to API response format
func (h *DA2062Handler) respondWithParsedForm(c *gin.Context, parsedForm *ocr.DA2062ParsedForm, userID uint, sourceDocumentURL string) {
	// Convert OCR parsed items to API format
	var items []models.DA2062ImportItem

	for _, ocrItem := range parsedForm.Items {
		// Use existing serial number or mark for manual entry
		serialNumber := strings.TrimSpace(ocrItem.SerialNumber)

		// Skip items without any description (completely empty)
		if strings.TrimSpace(ocrItem.ItemDescription) == "" {
			log.Printf("Skipping empty item with no description")
			continue
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
			SourceDocumentURL:    sourceDocumentURL,
		}

		// Ensure VerificationReasons is not nil – initialize as empty slice if no reasons were added
		if len(importMetadata.VerificationReasons) == 0 {
			importMetadata.VerificationReasons = []string{}
		}

		// Add verification reasons for missing or suspicious serial numbers
		if serialNumber == "" {
			importMetadata.VerificationReasons = append(importMetadata.VerificationReasons, "missing_serial_number")
			importMetadata.RequiresVerification = true
		} else if strings.Contains(strings.ToUpper(serialNumber), "NOSERIAL") ||
			strings.Contains(strings.ToUpper(serialNumber), "TEMP") ||
			strings.Contains(strings.ToUpper(serialNumber), "PLACEHOLDER") {
			importMetadata.RequiresVerification = true
			importMetadata.VerificationReasons = append(importMetadata.VerificationReasons, "Generated or placeholder serial number")
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
			"verification_needed":  parsedForm.Metadata.RequiresVerification,
			"items_needing_review": countItemsNeedingReview(items),
			"suggested_action":     "Review items and submit for creation",
			"message":              "Review items and submit for creation", // Keep for backwards compatibility
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
*/

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

/* ------------------------------------------------------------------
   ⭐ NEW: ExportDA2062 – generate printable HTML + return as download
------------------------------------------------------------------ */
func (h *DA2062Handler) ExportDA2062(c *gin.Context) {
	// Version check for debugging deployment issues
	if c.Query("version_check") == "true" {
		c.JSON(http.StatusOK, gin.H{
			"version":                "2024-06-07-v2-with-document-table",
			"has_document_migration": true,
			"attachments_type":       "array",
		})
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

	// Use user info from request (which includes signature URL from iOS client)
	fromUserInfo := req.FromUser

	// If no signature URL in request, fall back to database
	if fromUserInfo.SignatureURL == "" {
		if fromUser.SignatureURL != nil && *fromUser.SignatureURL != "" {
			fromUserInfo.SignatureURL = *fromUser.SignatureURL
		}
	}

	// Ensure we have fallback values from database if request doesn't include them
	if fromUserInfo.Name == "" {
		fromUserInfo.Name = fromUser.FirstName + " " + fromUser.LastName
	}
	if fromUserInfo.Rank == "" {
		fromUserInfo.Rank = fromUser.Rank
	}
	if fromUserInfo.Phone == "" {
		fromUserInfo.Phone = fromUser.Phone
	}
	if fromUserInfo.Title == "" {
		fromUserInfo.Title = "Property Book Officer"
		if fromUser.Unit != "" {
			fromUserInfo.Title = fromUser.Unit
		}
	}

	// Set to user info
	toUserInfo := req.ToUser
	if req.ToUserID != 0 {
		// For in-app delivery, fetch recipient's signature from database if not in request
		toUserData, err := h.Repo.GetUserByID(req.ToUserID)
		if err == nil {
			// Use recipient data from database for missing fields
			if toUserInfo.Name == "" {
				toUserInfo.Name = toUserData.FirstName + " " + toUserData.LastName
			}
			if toUserInfo.Rank == "" {
				toUserInfo.Rank = toUserData.Rank
			}
			if toUserInfo.Phone == "" {
				toUserInfo.Phone = toUserData.Phone
			}
			if toUserInfo.Title == "" {
				toUserInfo.Title = "Property Book Officer"
				if toUserData.Unit != "" {
					toUserInfo.Title = toUserData.Unit
				}
			}
			// Use signature from database if not provided in request
			if toUserInfo.SignatureURL == "" && toUserData.SignatureURL != nil && *toUserData.SignatureURL != "" {
				toUserInfo.SignatureURL = *toUserData.SignatureURL
			}
		}
	} else if toUserInfo.Name == "" {
		// For self hand receipt, use from user info
		toUserInfo = fromUserInfo
	}

	// Convert unit info
	unitInfo := documents.UnitInfo{
		UnitName:    req.UnitInfo.UnitName,
		DODAAC:      req.UnitInfo.DODAAC,
		StockNumber: req.UnitInfo.StockNumber,
		Location:    req.UnitInfo.Location,
	}

	// Generate form number first
	formNumber := fmt.Sprintf("HR-%s-%d", time.Now().Format("20060102"), userID)
	
	// Generate HTML for ALL export types
	htmlContent := h.PDFGenerator.GenerateDA2062HTML(
		properties,
		fromUserInfo,
		toUserInfo,
		unitInfo,
		formNumber,
	)
	
	log.Printf("DA2062 Export: HTML generated, length=%d bytes", len(htmlContent))

	// Store signature data if signatures are included (signatures are always included per options above)
	if fromUserInfo.SignatureURL != "" || toUserInfo.SignatureURL != "" {
		// Create signature metadata for logging
		signatureMetadata := map[string]interface{}{
			"from": map[string]interface{}{
				"angle":      -90,
				"x":          10,
				"y":          245,
				"width":      70,
				"height":     15,
				"applied_at": time.Now(),
			},
			"to": map[string]interface{}{
				"angle":      -90,
				"x":          110,
				"y":          245,
				"width":      70,
				"height":     15,
				"applied_at": time.Now(),
			},
		}

		// TODO: Implement da2062_signatures table insertion
		// This would require adding the table operations to the repository
		log.Printf("Signature data would be stored: from_user=%d, to_user=%d", userID, req.ToUserID)
		log.Printf("Signature metadata: %+v", signatureMetadata)
	}

	// Handle in-app delivery to another user
	if req.ToUserID != 0 {
		// Verify the recipient is a connection/friend of the sender
		connected, err := h.Repo.CheckUserConnection(userID, req.ToUserID)
		if err != nil || !connected {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Recipient must be in your connections"})
			return
		}
		// Fetch recipient details
		recipient, err := h.Repo.GetUserByID(req.ToUserID)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Recipient not found"})
			return
		}
		// Upload HTML to storage
		ctx := c.Request.Context()
		fileKey := fmt.Sprintf("da2062/export_%d_%d.html", userID, time.Now().UnixNano())
		err = h.StorageService.UploadFile(ctx, fileKey, strings.NewReader(htmlContent), int64(len(htmlContent)), "text/html")
		if err != nil {
			log.Printf("Failed to upload DA2062 HTML: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store HTML"})
			return
		}
		// Get a presigned URL for the HTML (for attachments)
		fileURL, err := h.StorageService.GetPresignedURL(ctx, fileKey, 7*24*time.Hour)
		if err != nil {
			log.Printf("Warning: could not get presigned URL, proceeding without it: %v", err)
			fileURL = ""
		}

		// Prepare title for document(s)
		var title string
		if len(properties) == 1 {
			// Single item – include item name
			title = fmt.Sprintf("Hand Receipt for %s", properties[0].Name)
		} else {
			title = fmt.Sprintf("Hand Receipt - %d Items", len(properties))
		}

		// Create document record for recipient (inbox)
		subtype := "DA2062"
		recipientDoc := &domain.Document{
			Type:            domain.DocumentTypeTransferForm,
			Subtype:         &subtype,
			Title:           fmt.Sprintf("Received: %s", title),
			SenderUserID:    userID,
			RecipientUserID: req.ToUserID,
			PropertyID:      nil,  // no single property association for multiple items
			FormData:        "{}", // could include metadata if needed
			Description:     nil,
			Attachments:     domain.JSONStringArray{}, // Initialize as empty JSONStringArray
			Status:          domain.DocumentStatusUnread,
			SentAt:          time.Now(),
		}
		// Attach PDF URL if available
		if fileURL != "" {
			recipientDoc.Attachments = domain.JSONStringArray{fileURL}
		}
		if err := h.Repo.CreateDocument(recipientDoc); err != nil {
			log.Printf("ERROR: Failed to create document record for recipient: %v", err)
			log.Printf("Document details: Type=%s, Title=%s, SenderID=%d, RecipientID=%d, Attachments=%v",
				recipientDoc.Type, recipientDoc.Title, recipientDoc.SenderUserID, recipientDoc.RecipientUserID, recipientDoc.Attachments)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create document record for recipient", "details": err.Error()})
			return
		}

		// Create document record for sender (copy in their inbox)
		senderDoc := &domain.Document{
			Type:            domain.DocumentTypeTransferForm,
			Subtype:         &subtype,
			Title:           fmt.Sprintf("Sent: %s", title),
			SenderUserID:    userID,
			RecipientUserID: userID, // Sender gets a copy
			PropertyID:      nil,
			FormData:        "{}",
			Description:     nil,
			Attachments:     domain.JSONStringArray{},
			Status:          domain.DocumentStatusRead, // Mark as read since sender created it
			SentAt:          time.Now(),
		}
		// Attach PDF URL if available
		if fileURL != "" {
			senderDoc.Attachments = domain.JSONStringArray{fileURL}
		}
		if err := h.Repo.CreateDocument(senderDoc); err != nil {
			log.Printf("WARNING: Failed to create document record for sender: %v", err)
			// Don't fail the request if sender copy creation fails
		}

		// Log the export action to the ledger
		if err := h.Ledger.LogDA2062Export(userID, len(properties), "app", recipient.Email); err != nil {
			log.Printf("WARNING: Failed to log DA2062 export to ledger: %v", err)
		}

		// Respond with the created document (recipient's document)
		c.JSON(http.StatusCreated, gin.H{
			"document": recipientDoc,
			"message":  fmt.Sprintf("DA 2062 sent to %s %s (copy saved to your Documents)", recipient.Rank, recipient.LastName),
		})
		return
	}

	// Handle email or download
	if req.SendEmail && len(req.Recipients) > 0 {
		// Send email
		senderInfo := email.UserInfo{
			Name:  fromUserInfo.Name,
			Rank:  fromUserInfo.Rank,
			Title: fromUserInfo.Title,
			Phone: fromUserInfo.Phone,
		}

		// Convert HTML to buffer for email attachment
		htmlBuffer := bytes.NewBufferString(htmlContent)
		
		// TODO: Update email service to send HTML attachments
		// For now, we'll use the existing email service but note it needs updating
		err = h.EmailService.SendDA2062Email(req.Recipients, htmlBuffer, formNumber, senderInfo)
		if err != nil {
			log.Printf("Email sending failed: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send email"})
			return
		}

		// Upload HTML to storage for sender's Documents inbox
		ctx := c.Request.Context()
		fileKey := fmt.Sprintf("da2062/email_%d_%d.html", userID, time.Now().UnixNano())
		err = h.StorageService.UploadFile(ctx, fileKey, strings.NewReader(htmlContent), int64(len(htmlContent)), "text/html")
		if err != nil {
			log.Printf("WARNING: Failed to upload HTML for sender's Documents: %v", err)
		} else {
			// Get a presigned URL for the HTML
			fileURL, err := h.StorageService.GetPresignedURL(ctx, fileKey, 7*24*time.Hour)
			if err != nil {
				log.Printf("Warning: could not get presigned URL for sender's copy: %v", err)
				fileURL = ""
			}

			// Create document record for sender's inbox
			var title string
			if len(properties) == 1 {
				title = fmt.Sprintf("Emailed Hand Receipt for %s", properties[0].Name)
			} else {
				title = fmt.Sprintf("Emailed Hand Receipt - %d Items", len(properties))
			}

			subtype := "DA2062"
			senderDoc := &domain.Document{
				Type:            domain.DocumentTypeTransferForm,
				Subtype:         &subtype,
				Title:           title,
				SenderUserID:    userID,
				RecipientUserID: userID, // Sender gets a copy
				PropertyID:      nil,
				FormData:        "{}",
				Description:     nil,
				Attachments:     domain.JSONStringArray{},
				Status:          domain.DocumentStatusRead, // Mark as read since sender created it
				SentAt:          time.Now(),
			}
			// Attach HTML URL if available
			if fileURL != "" {
				senderDoc.Attachments = domain.JSONStringArray{fileURL}
			}
			if err := h.Repo.CreateDocument(senderDoc); err != nil {
				log.Printf("WARNING: Failed to create document record for sender's email copy: %v", err)
			}
		}

		// Log to ledger
		if err := h.Ledger.LogDA2062Export(userID, len(properties), "email", strings.Join(req.Recipients, ",")); err != nil {
			log.Printf("WARNING: Failed to log DA2062 export to ledger: %v", err)
		}

		c.JSON(http.StatusOK, gin.H{
			"message":     "DA 2062 emailed successfully (copy saved to your Documents)",
			"form_number": formNumber,
			"recipients":  req.Recipients,
			"item_count":  len(properties),
		})
	} else {
		// Return HTML for download
		// Log to ledger
		if err := h.Ledger.LogDA2062Export(userID, len(properties), "download", ""); err != nil {
			log.Printf("WARNING: Failed to log DA2062 export to ledger: %v", err)
		}

		// Return HTML for download
		log.Printf("DA2062 Export: Returning HTML for download, SendEmail=%v, Recipients=%d, ToUserID=%d", 
			req.SendEmail, len(req.Recipients), req.ToUserID)
		
		htmlFilename := fmt.Sprintf("DA2062_%s.html", time.Now().Format("20060102_150405"))
		c.Header("Content-Type", "text/html; charset=utf-8")
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", htmlFilename))
		c.Header("Content-Length", fmt.Sprintf("%d", len(htmlContent)))
		c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(htmlContent))
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
	FromUser        documents.UserInfo `json:"from_user" binding:"required"`
	ToUser          documents.UserInfo `json:"to_user"`
	UnitInfo        documents.UnitInfo `json:"unit_info" binding:"required"`
	ToUserID        uint         `json:"to_user_id"`
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
		TotalItems:       len(properties),
		Categories:       make(map[string]int),
		ConfidenceLevels: make(map[string]int),
	}

	// Initialize confidence levels
	summary.ConfidenceLevels["high"] = 0
	summary.ConfidenceLevels["medium"] = 0
	summary.ConfidenceLevels["low"] = 0

	for _, prop := range properties {
		// Count by category (using current status as proxy)
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
		} else {
			// Default to medium confidence if no metadata
			summary.ConfidenceLevels["medium"]++
		}
	}

	return summary
}

// buildPropertySummaryForLedger creates a concise summary of properties for ledger logging
func buildPropertySummaryForLedger(properties []domain.Property) string {
	if len(properties) == 0 {
		return "No properties"
	}

	// For large batches, provide summary statistics
	if len(properties) > 10 {
		hasNSN := 0
		hasSerial := 0
		requiresVerification := 0

		for _, prop := range properties {
			if prop.NSN != nil && *prop.NSN != "" {
				hasNSN++
			}
			if !strings.HasPrefix(prop.SerialNumber, "TEMP-") {
				hasSerial++
			}
			if !prop.Verified {
				requiresVerification++
			}
		}

		return fmt.Sprintf("Batch summary: %d total, %d with NSN, %d with explicit serial, %d requiring verification",
			len(properties), hasNSN, hasSerial, requiresVerification)
	}

	// For smaller batches, list individual items
	var summaries []string
	for _, prop := range properties {
		summary := fmt.Sprintf("%s (SN: %s)", prop.Name, prop.SerialNumber)
		if prop.NSN != nil && *prop.NSN != "" {
			summary += fmt.Sprintf(" [NSN: %s]", *prop.NSN)
		}
		summaries = append(summaries, summary)
	}

	return strings.Join(summaries, "; ")
}

// countItemsNeedingReview counts how many items need user verification
func countItemsNeedingReview(items []models.DA2062ImportItem) int {
	count := 0
	for _, item := range items {
		if item.ImportMetadata != nil && item.ImportMetadata.RequiresVerification {
			count++
		}
	}
	return count
}

// validateBatchItem validates an item before attempting creation
func validateBatchItem(item models.DA2062ImportItem) string {
	// Check for required fields
	if strings.TrimSpace(item.Name) == "" && strings.TrimSpace(item.Description) == "" {
		return "Item name or description is required"
	}

	// Check for valid serial number (must not be empty or whitespace only)
	if strings.TrimSpace(item.SerialNumber) == "" {
		return "Serial number is required and cannot be empty"
	}

	// Check for valid quantity
	if item.Quantity <= 0 {
		return "Quantity must be greater than 0"
	}

	// Validate NSN format if provided
	if item.NSN != "" {
		nsn := strings.TrimSpace(item.NSN)
		if len(nsn) > 0 && !isValidNSNFormat(nsn) {
			return "Invalid NSN format (should be XXXX-XX-XXX-XXXX)"
		}
	}

	return "" // No validation errors
}

// isValidNSNFormat checks if NSN follows the standard format
func isValidNSNFormat(nsn string) bool {
	// NSN format: XXXX-XX-XXX-XXXX (4-2-3-4 digits separated by hyphens)
	// Allow some flexibility for OCR variations
	nsnPattern := `^\d{4}-?\d{2}-?\d{3}-?\d{4}$`
	matched, err := regexp.MatchString(nsnPattern, nsn)
	return err == nil && matched
}

// RegisterRoutes registers all DA2062-related routes
func (h *DA2062Handler) RegisterRoutes(router *gin.RouterGroup) {
	da2062 := router.Group("/da2062")
	{
		da2062.POST("/import", h.ImportDA2062) // New Claude-powered import
		da2062.POST("/upload", h.ImportDA2062) // Keep old route for compatibility
		da2062.POST("/generate-pdf", h.ExportDA2062) // Keep old route name for compatibility
		da2062.GET("/search", h.SearchDA2062Forms)
		da2062.GET("/unverified", h.GetUnverifiedItems)
		da2062.PUT("/verify/:id", h.VerifyImportedItem)
		da2062.GET("/table-check", h.CheckDocumentTable)
		// Export routes moved to avoid conflict
		da2062.GET("/export/:id", h.ExportDA2062) // Changed from /:id/export
		da2062.GET("/items/:reference", h.GetDA2062Items) // Changed from /:reference/items
		
		// Debug endpoints for template verification
		da2062.GET("/debug/template-check", h.CheckTemplateStatus)
		da2062.GET("/debug/test-html", h.TestHTMLGeneration)
	}

	inventory := router.Group("/inventory")
	{
		inventory.POST("/batch", h.BatchCreateInventory)
	}
}

// RegisterAIRoutes registers AI-enhanced DA2062 routes
func RegisterAIRoutes(router *gin.RouterGroup) {
	aiGroup := router.Group("/da2062/ai")
	{
		// Always register the health endpoint
		aiGroup.GET("/health", func(c *gin.Context) {
			// AI is now handled by Claude in the main import endpoint
			c.JSON(200, gin.H{
				"available": false,
				"message": "AI features are now integrated into the main import endpoint",
				"note": "Use POST /api/da2062/import for Claude AI processing",
			})
		})
	}
}

// CheckDocumentTable checks if the documents table exists
func (h *DA2062Handler) CheckDocumentTable(c *gin.Context) {
	// Try to get document count - if table doesn't exist, it will error
	docs, err := h.Repo.GetDocumentsForUser(1, nil, nil)

	if err != nil {
		// Check if error contains table not found message
		errMsg := err.Error()
		if strings.Contains(errMsg, "documents") && (strings.Contains(errMsg, "does not exist") || strings.Contains(errMsg, "doesn't exist")) {
			c.JSON(http.StatusOK, gin.H{
				"documents_table_exists": false,
				"error":                  "Table does not exist",
				"details":                errMsg,
				"timestamp":              time.Now().Format(time.RFC3339),
			})
			return
		}

		// Some other error occurred
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":     "Failed to check table",
			"details":   errMsg,
			"timestamp": time.Now().Format(time.RFC3339),
		})
		return
	}

	// If we got here, table exists
	c.JSON(http.StatusOK, gin.H{
		"documents_table_exists": true,
		"document_count":         len(docs),
		"timestamp":              time.Now().Format(time.RFC3339),
		"message":                "Table exists and is accessible",
	})
}

// CheckTemplateStatus verifies HTML template is available
func (h *DA2062Handler) CheckTemplateStatus(c *gin.Context) {
	hasEmbedded := documents.HasEmbeddedTemplate()
	c.JSON(http.StatusOK, gin.H{
		"has_embedded_template": hasEmbedded,
		"backend_version": "2024-12-html-only",
		"template_path": "internal/services/documents/templates/da2062.html.tmpl",
		"generation_mode": "HTML",
	})
}

// TestHTMLGeneration tests HTML generation with sample data
func (h *DA2062Handler) TestHTMLGeneration(c *gin.Context) {
	// Generate test HTML
	testProps := []domain.Property{
		{
			ID:           1,
			Name:         "Test Item 1",
			SerialNumber: "TEST123",
			Quantity:     1,
			NSN:          stringPtr("1234-56-789-0123"),
		},
		{
			ID:           2,
			Name:         "Test Item 2",
			SerialNumber: "TEST456",
			Quantity:     2,
			NSN:          stringPtr("9876-54-321-0987"),
		},
	}
	
	html := h.PDFGenerator.GenerateDA2062HTML(
		testProps,
		documents.UserInfo{Name: "Test User", Rank: "SGT", Title: "Test Title"},
		documents.UserInfo{Name: "Test Receiver", Rank: "CPT", Title: "Receiver Title"},
		documents.UnitInfo{UnitName: "Test Unit", DODAAC: "W12345"},
		"TEST-FORM-001",
	)
	
	c.Header("Content-Type", "text/html; charset=utf-8")
	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(html))
}

// Helper function for creating string pointers
func stringPtr(s string) *string {
	return &s
}
