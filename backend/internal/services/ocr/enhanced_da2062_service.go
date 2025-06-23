package ocr

import (
	"context"
	"fmt"
	"strings"
	"time"
	"log"
	
	"github.com/toole-brendan/handreceipt-go/internal/services/ai"
	"github.com/patrickmn/go-cache"
)

// EnhancedDA2062Service combines traditional OCR with AI for DA 2062 processing
type EnhancedDA2062Service struct {
	azureOCR  *AzureOCRService
	aiService ai.DA2062AIService
	cache     *cache.Cache
}

// NewEnhancedDA2062Service creates a new enhanced DA 2062 service
func NewEnhancedDA2062Service(azureOCR *AzureOCRService, aiService ai.DA2062AIService) *EnhancedDA2062Service {
	return &EnhancedDA2062Service{
		azureOCR:  azureOCR,
		aiService: aiService,
		cache:     cache.New(5*time.Minute, 10*time.Minute), // 5 min default, 10 min cleanup
	}
}

// ProcessDA2062WithAI processes a DA 2062 using OCR and AI
func (s *EnhancedDA2062Service) ProcessDA2062WithAI(ctx context.Context, imageData []byte, contentType string) (*UnifiedDA2062Result, error) {
	startTime := time.Now()
	
	// Check cache first (using hash of image data)
	cacheKey := fmt.Sprintf("da2062:%x", hashBytes(imageData[:min(1024, len(imageData))]))
	if cached, found := s.cache.Get(cacheKey); found {
		log.Printf("DA2062 cache hit for key: %s", cacheKey)
		return cached.(*UnifiedDA2062Result), nil
	}
	
	// Step 1: Traditional OCR
	ocrResult, err := s.azureOCR.ProcessImageFromBytes(ctx, imageData, contentType)
	if err != nil {
		return nil, fmt.Errorf("OCR processing failed: %w", err)
	}
	
	// Step 2: Extract full text for AI processing
	fullText := s.extractFullText(ocrResult)
	
	// Step 3: Check if AI enhancement is needed
	if !s.needsAIProcessing(ocrResult) {
		log.Printf("DA2062 has high OCR confidence (%.2f), skipping AI enhancement", ocrResult.Confidence)
		result := s.convertToUnifiedResult(ocrResult, nil)
		s.cache.Set(cacheKey, result, cache.DefaultExpiration)
		return result, nil
	}
	
	// Step 4: Send to AI for enhancement
	aiResult, err := s.aiService.ParseDA2062Text(ctx, fullText)
	if err != nil {
		// Fall back to OCR-only result
		log.Printf("AI enhancement failed, falling back to OCR: %v", err)
		return s.convertToUnifiedResult(ocrResult, nil), nil
	}
	
	// Step 5: Merge OCR and AI results
	unified := s.mergeDA2062Results(ocrResult, aiResult)
	
	// Step 6: Validate with military rules
	validated := s.validateDA2062(unified)
	
	// Set processing time
	validated.ProcessingTimeMs = time.Since(startTime).Milliseconds()
	
	// Cache the result
	s.cache.Set(cacheKey, validated, cache.DefaultExpiration)
	
	log.Printf("DA2062 processing completed in %v ms (OCR: %.2f, AI: %.2f, Final: %.2f)", 
		validated.ProcessingTimeMs, ocrResult.Confidence, aiResult.Confidence, validated.Confidence)
	
	return validated, nil
}

// needsAIProcessing determines if AI enhancement is needed
func (s *EnhancedDA2062Service) needsAIProcessing(ocrResult *DA2062ParsedForm) bool {
	// Use AI if OCR confidence is low
	if ocrResult.Confidence < 0.85 {
		return true
	}
	
	// Use AI if any items are missing critical fields
	for _, item := range ocrResult.Items {
		// Missing serial number for items that need it
		if item.SerialNumber == "" && s.requiresSerialNumber(item.NSN) {
			return true
		}
		
		// Low confidence on individual items
		if item.Confidence < 0.8 {
			return true
		}
		
		// Incomplete NSN
		if item.NSN != "" && !s.isValidNSN(item.NSN) {
			return true
		}
	}
	
	// Use AI if form appears to have multi-line items (heuristic)
	if s.hasMultiLineItems(ocrResult) {
		return true
	}
	
	return false
}

// extractFullText extracts all text from OCR result
func (s *EnhancedDA2062Service) extractFullText(ocr *DA2062ParsedForm) string {
	var lines []string
	
	// Add header information
	if ocr.UnitName != "" {
		lines = append(lines, fmt.Sprintf("UNIT: %s", ocr.UnitName))
	}
	if ocr.DODAAC != "" {
		lines = append(lines, fmt.Sprintf("DODAAC: %s", ocr.DODAAC))
	}
	if ocr.FromUnit != "" {
		lines = append(lines, fmt.Sprintf("FROM: %s", ocr.FromUnit))
	}
	if ocr.ToUnit != "" {
		lines = append(lines, fmt.Sprintf("TO: %s", ocr.ToUnit))
	}
	
	// Add all raw text lines if available
	if ocr.RawTextLines != nil {
		lines = append(lines, ocr.RawTextLines...)
	} else {
		// Reconstruct from items if raw text not available
		for _, item := range ocr.Items {
			line := fmt.Sprintf("%s %s", item.NSN, item.ItemDescription)
			if item.SerialNumber != "" {
				line += fmt.Sprintf(" S/N: %s", item.SerialNumber)
			}
			if item.Quantity > 0 {
				line += fmt.Sprintf(" QTY: %d", item.Quantity)
			}
			lines = append(lines, line)
		}
	}
	
	return strings.Join(lines, "\n")
}

// mergeDA2062Results intelligently combines OCR and AI results
func (s *EnhancedDA2062Service) mergeDA2062Results(ocr *DA2062ParsedForm, ai *ai.ParsedDA2062) *UnifiedDA2062Result {
	result := &UnifiedDA2062Result{
		FormNumber: coalesce(ai.FormNumber, ocr.FormNumber),
		UnitName:   coalesce(ai.UnitName, ocr.UnitName),
		DODAAC:     coalesce(ai.DODAAC, ocr.DODAAC),
		FromUnit:   ai.FromUnit, // Only available from AI
		ToUnit:     ai.ToUnit,   // Only available from AI
		Date:       ai.Date,     // Only available from AI
		Confidence: (ocr.Confidence + ai.Confidence) / 2,
		Metadata: DA2062Metadata{
			ProcessedAt:      time.Now(),
			OCRProvider:      "azure_computer_vision",
			AIProvider:       "azure_openai",
			OCRConfidence:    ocr.Confidence,
			AIConfidence:     ai.Confidence,
			ItemCount:        len(ai.Items),
			GroupedItems:     0,
			HandwrittenItems: 0,
		},
	}
	
	// Merge items with AI enhancements
	itemMap := make(map[int]*UnifiedDA2062Item)
	
	// Start with OCR items
	for _, ocrItem := range ocr.Items {
		itemMap[ocrItem.LineNumber] = &UnifiedDA2062Item{
			LineNumber:   ocrItem.LineNumber,
			NSN:          ocrItem.NSN,
			Description:  ocrItem.ItemDescription,
			Quantity:     ocrItem.Quantity,
			SerialNumber: ocrItem.SerialNumber,
			Condition:    ocrItem.Condition,
			Confidence:   ocrItem.Confidence,
			Source:       "ocr",
		}
	}
	
	// Enhance with AI data
	for _, aiItem := range ai.Items {
		if existing, ok := itemMap[aiItem.LineNumber]; ok {
			// Merge, preferring AI data when it grouped multiple lines
			if aiItem.AIGrouped {
				existing.Description = aiItem.Description
				existing.SerialNumber = coalesce(aiItem.SerialNumber, existing.SerialNumber)
				existing.Source = "ai_enhanced"
				result.Metadata.GroupedItems++
			}
			
			// Always use AI's normalized NSN if valid
			if aiItem.NSN != "" && s.isValidNSN(aiItem.NSN) {
				existing.NSN = aiItem.NSN
			}
			
			// Use AI confidence if higher
			if aiItem.Confidence > existing.Confidence {
				existing.Confidence = aiItem.Confidence
			}
			
			existing.Suggestions = aiItem.Suggestions
		} else {
			// New item found by AI
			itemMap[aiItem.LineNumber] = &UnifiedDA2062Item{
				LineNumber:   aiItem.LineNumber,
				NSN:          aiItem.NSN,
				Description:  aiItem.Description,
				Quantity:     aiItem.Quantity,
				SerialNumber: aiItem.SerialNumber,
				Condition:    aiItem.Condition,
				Confidence:   aiItem.Confidence,
				Source:       "ai_only",
				Suggestions:  aiItem.Suggestions,
			}
			
			if aiItem.AIGrouped {
				result.Metadata.GroupedItems++
			}
		}
	}
	
	// Convert map to slice
	for _, item := range itemMap {
		result.Items = append(result.Items, *item)
	}
	
	return result
}

// validateDA2062 applies military-specific validation rules
func (s *EnhancedDA2062Service) validateDA2062(result *UnifiedDA2062Result) *UnifiedDA2062Result {
	for i := range result.Items {
		item := &result.Items[i]
		
		// Validate NSN format
		if !s.isValidNSN(item.NSN) && item.NSN != "" {
			item.RequiresReview = true
			item.ValidationIssues = append(item.ValidationIssues, "Invalid NSN format")
		}
		
		// Validate condition code
		if item.Condition != "A" && item.Condition != "B" && item.Condition != "C" && item.Condition != "" {
			item.Condition = "A" // Default
			item.ValidationIssues = append(item.ValidationIssues, "Invalid condition code, defaulted to A")
		}
		
		// Flag items without serial numbers for weapons
		if s.isWeapon(item.NSN) && item.SerialNumber == "" {
			item.RequiresReview = true
			item.ValidationIssues = append(item.ValidationIssues, "Weapon missing serial number")
		}
		
		// Set unit of issue default
		if item.UnitOfIssue == "" {
			item.UnitOfIssue = "EA"
		}
		
		// Validate quantity
		if item.Quantity <= 0 {
			item.Quantity = 1
		}
	}
	
	// Update overall confidence based on validation
	validItems := 0
	for _, item := range result.Items {
		if !item.RequiresReview {
			validItems++
		}
	}
	
	if len(result.Items) > 0 {
		validationRatio := float64(validItems) / float64(len(result.Items))
		result.Confidence = result.Confidence * validationRatio
	}
	
	return result
}

// convertToUnifiedResult converts OCR-only result to unified format
func (s *EnhancedDA2062Service) convertToUnifiedResult(ocr *DA2062ParsedForm, ai *ai.ParsedDA2062) *UnifiedDA2062Result {
	result := &UnifiedDA2062Result{
		FormNumber: ocr.FormNumber,
		UnitName:   ocr.UnitName,
		DODAAC:     ocr.DODAAC,
		FromUnit:   "", // Not in OCR model, would need to extract
		ToUnit:     "", // Not in OCR model, would need to extract
		Date:       "", // Not in OCR model, would need to extract
		Confidence: ocr.Confidence,
		Metadata: DA2062Metadata{
			ProcessedAt:   time.Now(),
			OCRProvider:   "azure_computer_vision",
			OCRConfidence: ocr.Confidence,
			ItemCount:     len(ocr.Items),
		},
	}
	
	// Convert OCR items
	for _, ocrItem := range ocr.Items {
		result.Items = append(result.Items, UnifiedDA2062Item{
			LineNumber:   ocrItem.LineNumber,
			NSN:          ocrItem.NSN,
			Description:  ocrItem.ItemDescription,
			Quantity:     ocrItem.Quantity,
			SerialNumber: ocrItem.SerialNumber,
			Condition:    ocrItem.Condition,
			UnitOfIssue:  ocrItem.UnitOfIssue,
			Confidence:   ocrItem.Confidence,
			Source:       "ocr",
		})
	}
	
	return result
}

// Helper methods

func (s *EnhancedDA2062Service) isValidNSN(nsn string) bool {
	return ai.IsValidNSN(nsn)
}

func (s *EnhancedDA2062Service) isWeapon(nsn string) bool {
	return ai.IsWeapon(nsn)
}

func (s *EnhancedDA2062Service) requiresSerialNumber(nsn string) bool {
	return ai.RequiresSerialNumber(nsn)
}

func (s *EnhancedDA2062Service) hasMultiLineItems(ocr *DA2062ParsedForm) bool {
	// Simple heuristic: if we have items without NSNs or descriptions that look incomplete
	incompleteItems := 0
	for _, item := range ocr.Items {
		if item.NSN == "" || len(item.ItemDescription) < 10 {
			incompleteItems++
		}
	}
	return incompleteItems > len(ocr.Items)/4 // More than 25% incomplete
}

// Utility functions

func coalesce(values ...string) string {
	for _, v := range values {
		if v != "" {
			return v
		}
	}
	return ""
}

func hashBytes(data []byte) uint32 {
	// Simple hash for cache key
	var hash uint32 = 2166136261
	for _, b := range data {
		hash = (hash ^ uint32(b)) * 16777619
	}
	return hash
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// UnifiedDA2062Result represents the combined OCR and AI result for DA 2062
type UnifiedDA2062Result struct {
	FormNumber       string               `json:"formNumber"`
	UnitName         string               `json:"unitName"`
	DODAAC           string               `json:"dodaac"`
	FromUnit         string               `json:"fromUnit"`
	ToUnit           string               `json:"toUnit"`
	Date             string               `json:"date"`
	Items            []UnifiedDA2062Item  `json:"items"`
	Confidence       float64              `json:"confidence"`
	Suggestions      []ai.Suggestion      `json:"suggestions"`
	Metadata         DA2062Metadata       `json:"metadata"`
	ProcessingTimeMs int64                `json:"processingTimeMs"`
}

// UnifiedDA2062Item represents a merged item from DA 2062
type UnifiedDA2062Item struct {
	LineNumber       int             `json:"lineNumber"`
	NSN              string          `json:"nsn"`
	Description      string          `json:"description"`
	Quantity         int             `json:"quantity"`
	UnitOfIssue      string          `json:"unitOfIssue"`
	SerialNumber     string          `json:"serialNumber,omitempty"`
	Condition        string          `json:"condition"`
	Confidence       float64         `json:"confidence"`
	Source           string          `json:"source"` // ocr, ai_enhanced, ai_only
	Suggestions      []ai.Suggestion `json:"suggestions"`
	RequiresReview   bool            `json:"requiresReview"`
	ValidationIssues []string        `json:"validationIssues,omitempty"`
}

// DA2062Metadata contains processing metadata
type DA2062Metadata struct {
	ProcessedAt       time.Time `json:"processedAt"`
	OCRProvider       string    `json:"ocrProvider"`
	AIProvider        string    `json:"aiProvider,omitempty"`
	OCRConfidence     float64   `json:"ocrConfidence"`
	AIConfidence      float64   `json:"aiConfidence,omitempty"`
	ItemCount         int       `json:"itemCount"`
	GroupedItems      int       `json:"groupedItems"`
	HandwrittenItems  int       `json:"handwrittenItems"`
}