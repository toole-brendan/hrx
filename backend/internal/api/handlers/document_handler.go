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
		"message":  fmt.Sprintf("Maintenance form sent to %s %s", recipient.Rank, recipient.Name),
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
	unreadCount, _ := h.Repo.GetUnreadDocumentCount(userID)

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
		Name:  user.Name,
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
