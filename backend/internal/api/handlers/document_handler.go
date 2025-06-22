package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/email"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
)

// DocumentHandler handles document operations
type DocumentHandler struct {
	Repo           repository.Repository
	Ledger         ledger.LedgerService
	EmailService   *email.DA2062EmailService
	StorageService storage.StorageService
}

// NewDocumentHandler creates a new document handler
func NewDocumentHandler(repo repository.Repository, ledger ledger.LedgerService, emailService *email.DA2062EmailService, storageService storage.StorageService) *DocumentHandler {
	return &DocumentHandler{
		Repo:           repo,
		Ledger:         ledger,
		EmailService:   emailService,
		StorageService: storageService,
	}
}

// CreateMaintenanceForm generates and sends a maintenance form
func (h *DocumentHandler) CreateMaintenanceForm(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	var req domain.CreateMaintenanceFormInput
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get property details
	property, err := h.Repo.GetPropertyByID(req.PropertyID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}

	// Verify property ownership
	if property.AssignedToUserID == nil || *property.AssignedToUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only create maintenance forms for your own properties"})
		return
	}

	// Check if recipient is in connections
	connected, err := h.Repo.CheckUserConnection(userID, req.RecipientUserID)
	if err != nil || !connected {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Recipient must be in your connections"})
		return
	}

	// Get recipient details
	recipient, err := h.Repo.GetUserByID(req.RecipientUserID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Recipient not found"})
		return
	}

	// Generate form data based on form type
	formData := h.generateMaintenanceFormData(req.FormType, property, req.Description, req.FaultDescription)
	formDataJSON, err := json.Marshal(formData)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate form"})
		return
	}

	// Create document
	document := &domain.Document{
		Type:            domain.DocumentTypeMaintenanceForm,
		Subtype:         &req.FormType,
		Title:           fmt.Sprintf("%s Maintenance Request - %s", req.FormType, property.Name),
		SenderUserID:    userID,
		RecipientUserID: req.RecipientUserID,
		PropertyID:      &req.PropertyID,
		FormData:        string(formDataJSON),
		Description:     &req.Description,
		Attachments:     req.Attachments,
		Status:          domain.DocumentStatusUnread,
		SentAt:          time.Now(),
	}

	if err := h.Repo.CreateDocument(document); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send document"})
		return
	}

	// Log to ImmuDB
	h.Ledger.LogDocumentEvent(document.ID, "MAINTENANCE_FORM_SENT", userID, req.RecipientUserID)

	c.JSON(http.StatusCreated, gin.H{
		"document": document,
		"message":  fmt.Sprintf("Maintenance form sent to %s %s", recipient.Rank, recipient.LastName),
	})
}

// GetDocuments retrieves documents for a user
func (h *DocumentHandler) GetDocuments(c *gin.Context) {
	userID := c.MustGet("userID").(uint)

	box := c.Query("box")       // "inbox", "sent", "all"
	status := c.Query("status") // "unread", "read", "archived"
	docType := c.Query("type")  // "maintenance_form", etc.

	var statusPtr, docTypePtr *string
	if status != "" {
		statusPtr = &status
	}
	if docType != "" {
		docTypePtr = &docType
	}

	var documents []domain.Document
	var err error

	switch box {
	case "inbox":
		documents, err = h.Repo.GetDocumentsByRecipient(userID, statusPtr, docTypePtr)
	case "sent":
		documents, err = h.Repo.GetDocumentsBySender(userID, statusPtr, docTypePtr)
	default:
		documents, err = h.Repo.GetDocumentsForUser(userID, statusPtr, docTypePtr)
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch documents"})
		return
	}

	// Get unread count
	unreadCount, err := h.Repo.GetUnreadDocumentCount(userID)
	if err != nil {
		// Log the error but don't fail the request
		fmt.Printf("WARNING: Failed to get unread count for user %d: %v\n", userID, err)
		unreadCount = 0
	}

	c.JSON(http.StatusOK, gin.H{
		"documents":    documents,
		"count":        len(documents),
		"unread_count": unreadCount,
	})
}

// GetDocument retrieves a single document by ID
func (h *DocumentHandler) GetDocument(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	docID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid document ID"})
		return
	}

	document, err := h.Repo.GetDocumentByID(uint(docID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Document not found"})
		return
	}

	// Verify user has access to this document
	if document.SenderUserID != userID && document.RecipientUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You don't have access to this document"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"document": document})
}

// MarkDocumentRead marks a document as read
func (h *DocumentHandler) MarkDocumentRead(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	docID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid document ID"})
		return
	}

	document, err := h.Repo.GetDocumentByID(uint(docID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Document not found"})
		return
	}

	// Verify recipient
	if document.RecipientUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You can only mark your own documents as read"})
		return
	}

	// Update status
	now := time.Now()
	document.Status = domain.DocumentStatusRead
	document.ReadAt = &now

	if err := h.Repo.UpdateDocument(document); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update document"})
		return
	}

	// Log to ImmuDB
	h.Ledger.LogDocumentEvent(document.ID, "DOCUMENT_READ", userID, document.SenderUserID)

	c.JSON(http.StatusOK, gin.H{"message": "Document marked as read"})
}

// EmailDocument allows users to email DA 2062 documents to themselves
func (h *DocumentHandler) EmailDocument(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	docID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid document ID"})
		return
	}

	var req struct {
		Email string `json:"email" binding:"required,email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Valid email address required"})
		return
	}

	// Get document
	document, err := h.Repo.GetDocumentByID(uint(docID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Document not found"})
		return
	}

	// Verify user has access to this document
	if document.SenderUserID != userID && document.RecipientUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You don't have access to this document"})
		return
	}

	// Only allow emailing DA 2062 documents
	if document.Type != domain.DocumentTypeTransferForm || (document.Subtype == nil || *document.Subtype != "DA2062") {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Only DA 2062 documents can be emailed"})
		return
	}

	// Extract PDF URL from attachments
	var pdfURL string
	if len(document.Attachments) > 0 {
		pdfURL = document.Attachments[0]
	}

	if pdfURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Document has no PDF attachment"})
		return
	}

	// Extract file key from URL (assuming URL contains the file key)
	// For now, we'll need to implement a way to extract the file key from the presigned URL
	// or store the file key separately. For simplicity, let's assume the URL is the file key
	fileKey := fmt.Sprintf("da2062/transfer_%d.pdf", document.ID) // Reconstruct file key

	// Download PDF from storage
	reader, err := h.StorageService.DownloadFile(c.Request.Context(), fileKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve document"})
		return
	}
	defer reader.Close()

	// Read PDF content into a buffer
	pdfData := &bytes.Buffer{}
	if _, err := io.Copy(pdfData, reader); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read document"})
		return
	}

	// Get user info for email
	user, err := h.Repo.GetUserByID(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get user information"})
		return
	}

	// Generate form number from document title or use document ID
	formNumber := fmt.Sprintf("DOC-%d", document.ID)

	// Send email
	senderInfo := email.UserInfo{
		Name:  user.FirstName + " " + user.LastName,
		Rank:  user.Rank,
		Title: user.Unit,
		Phone: user.Phone,
	}

	if err := h.EmailService.SendDA2062Email([]string{req.Email}, pdfData, formNumber, senderInfo); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send email"})
		return
	}

	// Log the email action
	h.Ledger.LogDocumentEvent(document.ID, "DOCUMENT_EMAILED", userID, 0)

	c.JSON(http.StatusOK, gin.H{
		"message": fmt.Sprintf("DA 2062 emailed successfully to %s", req.Email),
	})
}

// SearchDocuments searches documents by query string
// @Summary Search documents
// @Description Search documents by title, description, or sender name
// @Tags Documents
// @Produce json
// @Param q query string true "Search query"
// @Success 200 {object} map[string]interface{} "documents"
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /documents/search [get]
// @Security BearerAuth
func (h *DocumentHandler) SearchDocuments(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	query := c.Query("q")
	
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query is required"})
		return
	}

	// Search documents that the user has access to
	documents, err := h.Repo.SearchDocuments(userID, query)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search documents"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"documents": documents,
		"count":     len(documents),
		"query":     query,
	})
}

// UploadDocument handles general document uploads
// @Summary Upload a document
// @Description Upload a general document (PDF, image, etc.)
// @Tags Documents
// @Accept multipart/form-data
// @Produce json
// @Param file formData file true "Document file"
// @Param title formData string true "Document title"
// @Param type formData string false "Document type"
// @Param description formData string false "Document description"
// @Success 201 {object} map[string]interface{} "document"
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /documents/upload [post]
// @Security BearerAuth
func (h *DocumentHandler) UploadDocument(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	
	// Parse form data
	title := c.PostForm("title")
	docType := c.DefaultPostForm("type", "general")
	description := c.PostForm("description")
	
	if title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Document title is required"})
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
	allowedTypes := map[string]bool{
		"application/pdf":  true,
		"image/jpeg":       true,
		"image/png":        true,
		"image/gif":        true,
		"application/msword": true,
		"application/vnd.openxmlformats-officedocument.wordprocessingml.document": true,
	}
	
	if !allowedTypes[contentType] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "File type not allowed"})
		return
	}
	
	// Read file data
	fileData := &bytes.Buffer{}
	if _, err := io.Copy(fileData, file); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}
	
	// Generate unique file key
	timestamp := time.Now().Unix()
	fileKey := fmt.Sprintf("documents/%d/%d-%s", userID, timestamp, header.Filename)
	
	// Upload to storage
	err = h.StorageService.UploadFile(c.Request.Context(), fileKey, bytes.NewReader(fileData.Bytes()), int64(fileData.Len()), contentType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload file"})
		return
	}
	
	// Get presigned URL
	fileURL, err := h.StorageService.GetPresignedURL(c.Request.Context(), fileKey, 7*24*time.Hour)
	if err != nil {
		fileURL = fmt.Sprintf("/storage/%s", fileKey)
	}
	
	// Create document record
	document := &domain.Document{
		Type:            docType,
		Title:           title,
		SenderUserID:    userID,
		RecipientUserID: userID, // Self-uploaded documents
		Description:     &description,
		Attachments:     domain.JSONStringArray{fileURL},
		Status:          domain.DocumentStatusRead,
		SentAt:          time.Now(),
		FormData:        "{}",
	}
	
	if err := h.Repo.CreateDocument(document); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save document"})
		return
	}
	
	// Log to ImmuDB
	h.Ledger.LogDocumentEvent(document.ID, "DOCUMENT_UPLOADED", userID, 0)
	
	c.JSON(http.StatusCreated, gin.H{
		"document": document,
		"message":  "Document uploaded successfully",
	})
}

// BulkUpdateDocuments performs bulk operations on multiple documents
// @Summary Bulk update documents
// @Description Perform bulk operations on multiple documents (mark as read, archive, delete)
// @Tags Documents
// @Accept json
// @Produce json
// @Param request body domain.BulkDocumentOperationRequest true "Bulk operation request"
// @Success 200 {object} map[string]interface{} "result"
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /documents/bulk [post]
// @Security BearerAuth
func (h *DocumentHandler) BulkUpdateDocuments(c *gin.Context) {
	userID := c.MustGet("userID").(uint)
	
	var req domain.BulkDocumentOperationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if len(req.DocumentIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No documents selected"})
		return
	}

	successCount := 0
	failedCount := 0
	
	for _, docID := range req.DocumentIDs {
		document, err := h.Repo.GetDocumentByID(docID)
		if err != nil {
			failedCount++
			continue
		}

		// Verify user has access
		if document.RecipientUserID != userID && document.SenderUserID != userID {
			failedCount++
			continue
		}

		switch req.Operation {
		case "read":
			if document.RecipientUserID == userID && document.Status == domain.DocumentStatusUnread {
				now := time.Now()
				document.Status = domain.DocumentStatusRead
				document.ReadAt = &now
				if err := h.Repo.UpdateDocument(document); err == nil {
					h.Ledger.LogDocumentEvent(document.ID, "DOCUMENT_READ", userID, document.SenderUserID)
					successCount++
				} else {
					failedCount++
				}
			} else {
				failedCount++
			}
			
		case "archive":
			if document.RecipientUserID == userID {
				document.Status = domain.DocumentStatusArchived
				if err := h.Repo.UpdateDocument(document); err == nil {
					h.Ledger.LogDocumentEvent(document.ID, "DOCUMENT_ARCHIVED", userID, 0)
					successCount++
				} else {
					failedCount++
				}
			} else {
				failedCount++
			}
			
		case "delete":
			if document.RecipientUserID == userID || document.SenderUserID == userID {
				if err := h.Repo.DeleteDocument(docID); err == nil {
					h.Ledger.LogDocumentEvent(document.ID, "DOCUMENT_DELETED", userID, 0)
					successCount++
				} else {
					failedCount++
				}
			} else {
				failedCount++
			}
			
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid operation"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      fmt.Sprintf("Operation completed: %d succeeded, %d failed", successCount, failedCount),
		"successCount": successCount,
		"failedCount":  failedCount,
	})
}

// Helper method to generate form data
func (h *DocumentHandler) generateMaintenanceFormData(
	formType string,
	property *domain.Property,
	description string,
	faultDescription *string,
) domain.MaintenanceFormData {

	formData := domain.MaintenanceFormData{
		FormType:         formType,
		EquipmentName:    property.Name,
		SerialNumber:     property.SerialNumber,
		NSN:              *property.NSN,
		Location:         *property.Location,
		Description:      description,
		FaultDescription: "",
		RequestDate:      time.Now(),
		FormFields:       make(map[string]interface{}),
	}

	if faultDescription != nil {
		formData.FaultDescription = *faultDescription
	}

	// Add form-specific fields based on type
	switch formType {
	case "DA2404":
		formData.FormFields["equipment_model"] = property.Name
		formData.FormFields["admin_number"] = property.SerialNumber
		formData.FormFields["deficiency_class"] = "O" // Default to Operational
		formData.FormFields["inspection_type"] = "Operator Request"

	case "DA5988E":
		formData.FormFields["equipment_model"] = property.Name
		formData.FormFields["registration_num"] = property.SerialNumber
		formData.FormFields["fault_date"] = time.Now().Format("2006-01-02")
		formData.FormFields["fault_time"] = time.Now().Format("15:04")
	}

	return formData
}
