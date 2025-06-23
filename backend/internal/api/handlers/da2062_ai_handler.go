package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/ai"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
	"github.com/toole-brendan/handreceipt-go/internal/services/ocr"
)

// DA2062AIHandler handles AI-enhanced DA 2062 processing
type DA2062AIHandler struct {
	enhancedDA2062 *ocr.EnhancedDA2062Service
	aiService      ai.DA2062AIService
	ledgerService  ledger.LedgerService
	repository     repository.Repository
	nsnService     *nsn.NSNService
}

// NewDA2062AIHandler creates a new DA 2062 AI handler
func NewDA2062AIHandler(
	enhancedDA2062 *ocr.EnhancedDA2062Service,
	aiService ai.DA2062AIService,
	ledgerService ledger.LedgerService,
	repository repository.Repository,
	nsnService *nsn.NSNService,
) *DA2062AIHandler {
	return &DA2062AIHandler{
		enhancedDA2062: enhancedDA2062,
		aiService:      aiService,
		ledgerService:  ledgerService,
		repository:     repository,
		nsnService:     nsnService,
	}
}

// ProcessDA2062WithAI handles AI-enhanced DA 2062 processing
// @Summary Process DA 2062 with AI enhancement
// @Description Process a scanned DA 2062 using OCR and AI for intelligent parsing
// @Tags da2062-ai
// @Accept multipart/form-data
// @Produce json
// @Param file formData file true "DA 2062 image file"
// @Success 200 {object} ProcessDA2062Response
// @Router /api/da2062/ai/process [post]
func (h *DA2062AIHandler) ProcessDA2062WithAI(c *gin.Context) {

	// Get uploaded file
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}
	defer file.Close()

	// Read file content
	fileBytes := make([]byte, header.Size)
	if _, err := file.Read(fileBytes); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	// Process with enhanced DA 2062 OCR + AI
	result, err := h.enhancedDA2062.ProcessDA2062WithAI(
		c.Request.Context(),
		fileBytes,
		header.Header.Get("Content-Type"),
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Enhance items with NSN data
	for i := range result.Items {
		if result.Items[i].NSN != "" {
			nsnData, _ := h.nsnService.LookupNSN(c.Request.Context(), result.Items[i].NSN)
			if nsnData != nil {
				// Enhance description if AI didn't get full nomenclature
				if result.Items[i].Description == "" || len(result.Items[i].Description) < len(nsnData.Nomenclature) {
					result.Items[i].Description = nsnData.Nomenclature
				}
			}
		}
	}

	// Log AI processing event
	h.ledgerService.LogEvent(c.Request.Context(), ledger.Event{
		Type:   "da2062_ai_processing",
		UserID: c.GetString("userID"),
		Metadata: map[string]interface{}{
			"form_number":     result.FormNumber,
			"confidence":      result.Confidence,
			"item_count":      len(result.Items),
			"grouped_items":   result.Metadata.GroupedItems,
			"processing_ms":   result.ProcessingTimeMs,
			"ai_enhanced":     true,
		},
	})

	// Prepare response
	response := ProcessDA2062Response{
		Success:        true,
		FormNumber:     result.FormNumber,
		UnitName:       result.UnitName,
		DODAAC:         result.DODAAC,
		Confidence:     result.Confidence,
		Items:          h.convertToResponseItems(result.Items),
		Metadata:       result.Metadata,
		ProcessingTime: result.ProcessingTimeMs,
	}

	c.JSON(http.StatusOK, response)
}

// GenerateDA2062 handles natural language DA 2062 generation
// @Summary Generate DA 2062 from description
// @Description Generate a DA 2062 based on natural language description
// @Tags da2062-ai
// @Accept json
// @Produce json
// @Param request body GenerateDA2062Request true "DA 2062 generation request"
// @Success 200 {object} GenerateDA2062Response
// @Router /api/da2062/ai/generate [post]
func (h *DA2062AIHandler) GenerateDA2062(c *gin.Context) {
	var req GenerateDA2062Request
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Generate DA 2062 using AI
	generated, err := h.aiService.GenerateDA2062(c.Request.Context(), req.Description)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate DA 2062"})
		return
	}

	// Validate and enhance with NSN data
	for i := range generated.Form.Items {
		item := &generated.Form.Items[i]

		// Look up NSN if we have a description but no NSN
		if item.NSN == "" && item.Description != "" {
			searchResults, _ := h.nsnService.SearchNSN(c.Request.Context(), item.Description, 5)
			if len(searchResults) > 0 {
				item.NSN = searchResults[0].NSN
				item.Suggestions = append(item.Suggestions, ai.Suggestion{
					Field:      "nsn",
					Type:       "completion",
					Value:      searchResults[0].NSN,
					Confidence: 0.9,
					Reasoning:  "NSN found via catalog search",
				})
			}
		}

		// Validate NSN format
		if item.NSN != "" {
			if normalized := ai.NormalizeNSN(item.NSN); normalized != "" {
				item.NSN = normalized
			}
		}
	}

	// Log generation event
	h.ledgerService.LogEvent(c.Request.Context(), ledger.Event{
		Type:   "da2062_ai_generation",
		UserID: c.GetString("userID"),
		Metadata: map[string]interface{}{
			"description": req.Description,
			"item_count":  len(generated.Form.Items),
			"success":     true,
		},
	})

	c.JSON(http.StatusOK, GenerateDA2062Response{
		Success:     true,
		Form:        generated.Form,
		Suggestions: generated.Suggestions,
		Confidence:  generated.Confidence,
	})
}

// ReviewAndConfirmDA2062 handles the review and confirmation of AI-processed DA 2062
// @Summary Review and confirm AI-processed DA 2062
// @Description Review AI-processed items, make corrections, and confirm for import
// @Tags da2062-ai
// @Accept json
// @Produce json
// @Param request body ReviewDA2062Request true "Review confirmation request"
// @Success 200 {object} ReviewDA2062Response
// @Router /api/da2062/ai/review-confirm [post]
func (h *DA2062AIHandler) ReviewAndConfirmDA2062(c *gin.Context) {
	var req ReviewDA2062Request
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Track corrections for continuous improvement
	corrections := []DA2062Correction{}
	for i, item := range req.Items {
		if item.WasModified {
			corrections = append(corrections, DA2062Correction{
				OriginalItem:   req.OriginalItems[i],
				CorrectedItem:  item,
				ModifiedFields: item.ModifiedFields,
				UserID:         c.GetString("userID"),
				Timestamp:      time.Now(),
			})
		}
	}

	// Store corrections for future training (if enabled)
	if len(corrections) > 0 {
		h.storeDA2062Corrections(c.Request.Context(), corrections)
	}

	// Create property items with DA 2062 metadata
	createdProperties := []domain.Property{}
	userID := c.GetUint("userID")
	
	for _, item := range req.Items {
		// Find or create property model
		propertyModel, err := h.repository.GetPropertyModelByNSN(item.NSN)
		if err != nil || propertyModel == nil {
			// Create a basic property model if not found
			// In a real implementation, you'd create the model first
			continue
		}

		property := domain.Property{
			Name:            item.Description,
			SerialNumber:    item.SerialNumber,
			CurrentStatus:   "Available",
			Condition:       item.Condition,
			NSN:             &item.NSN,
			Quantity:        item.Quantity,
			PropertyModelID: &propertyModel.ID,
			AssignedToUserID: &userID,
			Description:     &item.Description,
		}

		err = h.repository.CreateProperty(&property)
		if err != nil {
			// Log error but continue with other items
			continue
		}

		createdProperties = append(createdProperties, property)

		// Log to immutable ledger
		h.ledgerService.LogPropertyCreation(property, userID)
	}

	// Log DA 2062 import event
	h.ledgerService.LogDA2062Import(c.Request.Context(), ledger.DA2062Event{
		FormNumber:    req.FormNumber,
		UserID:        c.GetString("userID"),
		ItemCount:     len(createdProperties),
		ImportMethod:  "ai_enhanced",
		Corrections:   len(corrections),
	})

	c.JSON(http.StatusOK, ReviewDA2062Response{
		Success:       true,
		ImportedCount: len(createdProperties),
		Properties:    createdProperties,
		FormNumber:    req.FormNumber,
	})
}

// Helper methods

func (h *DA2062AIHandler) convertToResponseItems(items []ocr.UnifiedDA2062Item) []ResponseDA2062Item {
	responseItems := make([]ResponseDA2062Item, len(items))
	for i, item := range items {
		responseItems[i] = ResponseDA2062Item{
			LineNumber:       item.LineNumber,
			NSN:              item.NSN,
			Description:      item.Description,
			Quantity:         item.Quantity,
			SerialNumber:     item.SerialNumber,
			Condition:        item.Condition,
			Confidence:       item.Confidence,
			Suggestions:      item.Suggestions,
			NeedsReview:      item.RequiresReview,
			Source:           item.Source,
			ValidationIssues: item.ValidationIssues,
		}
	}
	return responseItems
}

func (h *DA2062AIHandler) storeDA2062Corrections(ctx context.Context, corrections []DA2062Correction) {
	// Store corrections for future model improvements
	// This could be saved to a database for analysis
	for _, correction := range corrections {
		h.ledgerService.LogEvent(ctx, ledger.Event{
			Type:   "da2062_correction",
			UserID: correction.UserID,
			Metadata: map[string]interface{}{
				"original":        correction.OriginalItem,
				"corrected":       correction.CorrectedItem,
				"modified_fields": correction.ModifiedFields,
			},
		})
	}
}

// Request/Response structures

type ProcessDA2062Response struct {
	Success        bool                    `json:"success"`
	FormNumber     string                  `json:"formNumber"`
	UnitName       string                  `json:"unitName"`
	DODAAC         string                  `json:"dodaac"`
	Confidence     float64                 `json:"confidence"`
	Items          []ResponseDA2062Item    `json:"items"`
	Metadata       ocr.DA2062Metadata      `json:"metadata"`
	ProcessingTime int64                   `json:"processingTimeMs"`
}

type ResponseDA2062Item struct {
	LineNumber       int             `json:"lineNumber"`
	NSN              string          `json:"nsn"`
	Description      string          `json:"description"`
	Quantity         int             `json:"quantity"`
	SerialNumber     string          `json:"serialNumber,omitempty"`
	Condition        string          `json:"condition"`
	Confidence       float64         `json:"confidence"`
	Suggestions      []ai.Suggestion `json:"suggestions"`
	NeedsReview      bool            `json:"needsReview"`
	Source           string          `json:"source"`
	ValidationIssues []string        `json:"validationIssues,omitempty"`
}

type GenerateDA2062Request struct {
	Description string `json:"description" binding:"required"`
}

type GenerateDA2062Response struct {
	Success     bool            `json:"success"`
	Form        *ai.ParsedDA2062   `json:"form"`
	Suggestions []ai.Suggestion `json:"suggestions"`
	Confidence  float64         `json:"confidence"`
}

type ReviewDA2062Request struct {
	FormNumber    string             `json:"formNumber"`
	UnitName      string             `json:"unitName"`
	DODAAC        string             `json:"dodaac"`
	Items         []ReviewDA2062Item `json:"items"`
	OriginalItems []ReviewDA2062Item `json:"originalItems"`
}

type ReviewDA2062Item struct {
	NSN            string   `json:"nsn"`
	Description    string   `json:"description"`
	Quantity       int      `json:"quantity"`
	SerialNumber   string   `json:"serialNumber"`
	Condition      string   `json:"condition"`
	Confidence     float64  `json:"confidence"`
	WasModified    bool     `json:"wasModified"`
	ModifiedFields []string `json:"modifiedFields,omitempty"`
}

type ReviewDA2062Response struct {
	Success       bool              `json:"success"`
	ImportedCount int               `json:"importedCount"`
	Properties    []domain.Property `json:"properties"`
	FormNumber    string            `json:"formNumber"`
}

type DA2062Correction struct {
	OriginalItem   ReviewDA2062Item `json:"original"`
	CorrectedItem  ReviewDA2062Item `json:"corrected"`
	ModifiedFields []string         `json:"modifiedFields"`
	UserID         string           `json:"userId"`
	Timestamp      time.Time        `json:"timestamp"`
}