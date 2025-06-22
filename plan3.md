# backend/configs/config.development.yaml - AI Configuration for DA 2062
ai:
  # Provider selection: azure_openai or openai
  provider: "azure_openai"
  
  # Azure OpenAI Configuration
  endpoint: "${AZURE_OPENAI_ENDPOINT}"
  api_key: "${AZURE_OPENAI_KEY}"
  model: "gpt-4-turbo-preview"  # or your deployment name
  api_version: "2024-02-15-preview"
  
  # Model Parameters
  max_tokens: 4000
  temperature: 0.1  # Low temperature for consistent DA 2062 parsing
  timeout_seconds: 30
  retry_attempts: 3
  
  # Caching Configuration
  cache_enabled: true
  cache_ttl: 24h
  
  # DA 2062 Specific Settings
  da2062:
    # Confidence Thresholds
    confidence:
      ocr_weight: 0.4
      ai_weight: 0.4
      validation_weight: 0.2
      minimum_threshold: 0.7
      review_threshold: 0.85
      
    # Item Grouping Settings  
    grouping:
      max_lines_per_item: 4  # Maximum lines to group as single item
      serial_distance: 2     # Max lines between item and serial number
      
    # Military Equipment Patterns
    patterns:
      nsn_format: "####-##-###-####"
      weapon_serials: ["FE", "W", "M4", "M16", "M9"]
      optics_serials: ["PVS14-", "PAS13-", "M68-"]
      
    # Common Military Abbreviations
    abbreviations:
      NVG: "NIGHT VISION GOGGLE"
      ACH: "ADVANCED COMBAT HELMET"
      IOTV: "IMPROVED OUTER TACTICAL VEST"
      RFI: "RAPID FIELDING INITIATIVE"
      
  # Feature Flags
  features:
    enhanced_da2062_ocr: true
    da2062_generation: true
    multi_line_grouping: true
    handwriting_support: true
    continuous_learning: false
    
  # Cost Controls
  limits:
    max_requests_per_minute: 60
    max_tokens_per_day: 500000  # ~2000 DA 2062 forms
    alert_threshold_usd: 50

# Update existing OCR configuration
ocr:
  azure:
    endpoint: "${AZURE_COMPUTER_VISION_ENDPOINT}"
    api_key: "${AZURE_COMPUTER_VISION_KEY}"
    api_version: "v3.2"
  
  # DA 2062 AI enhancement
  da2062_ai_enhancement: true

---
# backend/internal/api/handlers/da2062_ai_handler.go
package handlers

import (
    "encoding/json"
    "net/http"
    "time"
    
    "github.com/gin-gonic/gin"
    "github.com/toole-brendan/hrx/backend/internal/services/ai"
    "github.com/toole-brendan/hrx/backend/internal/services/ocr"
    "github.com/toole-brendan/hrx/backend/internal/services/ledger"
)

// DA2062AIHandler handles AI-enhanced DA 2062 processing
type DA2062AIHandler struct {
    enhancedDA2062 *ocr.EnhancedDA2062Service
    aiService      ai.DA2062AIService
    ledgerService  ledger.Service
    inventoryRepo  repository.InventoryRepository
    nsnService     services.NSNService
}

// NewDA2062AIHandler creates a new DA 2062 AI handler
func NewDA2062AIHandler(
    enhancedDA2062 *ocr.EnhancedDA2062Service,
    aiService ai.DA2062AIService,
    ledgerService ledger.Service,
    inventoryRepo repository.InventoryRepository,
    nsnService services.NSNService,
) *DA2062AIHandler {
    return &DA2062AIHandler{
        enhancedDA2062: enhancedDA2062,
        aiService:      aiService,
        ledgerService:  ledgerService,
        inventoryRepo:  inventoryRepo,
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
    startTime := time.Now()
    
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
            nsnData, _ := h.nsnService.GetNSNDetails(c.Request.Context(), result.Items[i].NSN)
            if nsnData != nil {
                // Enhance description if AI didn't get full nomenclature
                if result.Items[i].Description == "" || len(result.Items[i].Description) < len(nsnData.ItemName) {
                    result.Items[i].Description = nsnData.ItemName
                }
            }
        }
    }
    
    // Log AI processing event
    h.ledgerService.LogEvent(c.Request.Context(), ledger.Event{
        Type:      "da2062_ai_processing",
        UserID:    c.GetString("userID"),
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
            searchResults, _ := h.nsnService.SearchByDescription(c.Request.Context(), item.Description)
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
        Success:  true,
        Form:     generated.Form,
        Suggestions: generated.Suggestions,
        Confidence: generated.Confidence,
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
    
    // Create inventory items with DA 2062 metadata
    createdItems := []models.InventoryItem{}
    for _, item := range req.Items {
        invItem := models.InventoryItem{
            NSN:          item.NSN,
            Description:  item.Description,
            Quantity:     item.Quantity,
            SerialNumber: item.SerialNumber,
            Condition:    item.Condition,
            Metadata: map[string]interface{}{
                "source":        "da2062_ai_import",
                "form_number":   req.FormNumber,
                "unit_name":     req.UnitName,
                "dodaac":        req.DODAAC,
                "confidence":    item.Confidence,
                "import_date":   time.Now(),
                "ai_processed":  true,
            },
        }
        
        created, err := h.inventoryRepo.Create(c.Request.Context(), &invItem)
        if err != nil {
            // Log error but continue with other items
            continue
        }
        
        createdItems = append(createdItems, *created)
        
        // Log to immutable ledger
        h.ledgerService.LogPropertyCreation(c.Request.Context(), ledger.PropertyEvent{
            ItemID:       created.ID,
            NSN:          created.NSN,
            SerialNumber: created.SerialNumber,
            UserID:       c.GetString("userID"),
            Action:       "created_via_da2062_ai",
            Metadata:     invItem.Metadata,
        })
    }
    
    // Log DA 2062 import event
    h.ledgerService.LogDA2062Import(c.Request.Context(), ledger.DA2062Event{
        FormNumber:    req.FormNumber,
        UserID:        c.GetString("userID"),
        ItemCount:     len(createdItems),
        ImportMethod:  "ai_enhanced",
        Corrections:   len(corrections),
    })
    
    c.JSON(http.StatusOK, ReviewDA2062Response{
        Success:       true,
        ImportedCount: len(createdItems),
        Items:         createdItems,
        FormNumber:    req.FormNumber,
    })
}

// Helper methods

func (h *DA2062AIHandler) convertToResponseItems(items []ocr.UnifiedDA2062Item) []ResponseDA2062Item {
    responseItems := make([]ResponseDA2062Item, len(items))
    for i, item := range items {
        responseItems[i] = ResponseDA2062Item{
            LineNumber:     item.LineNumber,
            NSN:            item.NSN,
            Description:    item.Description,
            Quantity:       item.Quantity,
            SerialNumber:   item.SerialNumber,
            Condition:      item.Condition,
            Confidence:     item.Confidence,
            Suggestions:    item.Suggestions,
            NeedsReview:    item.RequiresReview,
            Source:         item.Source,
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
    Success        bool                     `json:"success"`
    FormNumber     string                   `json:"formNumber"`
    UnitName       string                   `json:"unitName"`
    DODAAC         string                   `json:"dodaac"`
    Confidence     float64                  `json:"confidence"`
    Items          []ResponseDA2062Item     `json:"items"`
    Metadata       ocr.DA2062Metadata       `json:"metadata"`
    ProcessingTime int64                    `json:"processingTimeMs"`
}

type ResponseDA2062Item struct {
    LineNumber       int                    `json:"lineNumber"`
    NSN              string                 `json:"nsn"`
    Description      string                 `json:"description"`
    Quantity         int                    `json:"quantity"`
    SerialNumber     string                 `json:"serialNumber,omitempty"`
    Condition        string                 `json:"condition"`
    Confidence       float64                `json:"confidence"`
    Suggestions      []ai.Suggestion        `json:"suggestions"`
    NeedsReview      bool                   `json:"needsReview"`
    Source           string                 `json:"source"`
    ValidationIssues []string               `json:"validationIssues,omitempty"`
}

type GenerateDA2062Request struct {
    Description string `json:"description" binding:"required"`
}

type GenerateDA2062Response struct {
    Success     bool               `json:"success"`
    Form        *ai.ParsedDA2062   `json:"form"`
    Suggestions []ai.Suggestion    `json:"suggestions"`
    Confidence  float64            `json:"confidence"`
}

type ReviewDA2062Request struct {
    FormNumber     string              `json:"formNumber"`
    UnitName       string              `json:"unitName"`
    DODAAC         string              `json:"dodaac"`
    Items          []ReviewDA2062Item  `json:"items"`
    OriginalItems  []ReviewDA2062Item  `json:"originalItems"`
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
    Success       bool                   `json:"success"`
    ImportedCount int                    `json:"importedCount"`
    Items         []models.InventoryItem `json:"items"`
    FormNumber    string                 `json:"formNumber"`
}

type DA2062Correction struct {
    OriginalItem   ReviewDA2062Item `json:"original"`
    CorrectedItem  ReviewDA2062Item `json:"corrected"`
    ModifiedFields []string         `json:"modifiedFields"`
    UserID         string           `json:"userId"`
    Timestamp      time.Time        `json:"timestamp"`
}

---
# backend/internal/api/routes/routes.go - Update to add DA2062 AI routes
package routes

import (
    "github.com/gin-gonic/gin"
    // ... other imports
)

func SetupRoutes(
    router *gin.Engine,
    // ... existing parameters
    da2062AIHandler *handlers.DA2062AIHandler, // Add this
) {
    // ... existing routes
    
    // DA2062 AI-Enhanced Processing Routes
    da2062Group := api.Group("/da2062")
    da2062Group.Use(authMiddleware.RequireAuth())
    {
        // Existing DA2062 routes
        da2062Group.POST("/process", da2062Handler.ProcessOCR)
        da2062Group.GET("/imports", da2062Handler.GetImports)
        
        // AI-Enhanced DA2062 routes
        aiGroup := da2062Group.Group("/ai")
        {
            aiGroup.POST("/process", da2062AIHandler.ProcessDA2062WithAI)
            aiGroup.POST("/generate", da2062AIHandler.GenerateDA2062)
            aiGroup.POST("/review-confirm", da2062AIHandler.ReviewAndConfirmDA2062)
        }
    }
}

---
# backend/cmd/server/main.go - Wire up DA2062 AI services
package main

import (
    // ... existing imports
    "github.com/toole-brendan/hrx/backend/internal/services/ai"
    "github.com/toole-brendan/hrx/backend/internal/services/ocr"
)

func main() {
    // ... existing setup
    
    // Initialize DA2062 AI Service
    da2062AIConfig := ai.Config{
        Provider:       cfg.AI.Provider,
        Endpoint:       cfg.AI.Endpoint,
        APIKey:         cfg.AI.APIKey,
        Model:          cfg.AI.Model,
        MaxTokens:      cfg.AI.MaxTokens,
        Temperature:    cfg.AI.Temperature,
        TimeoutSeconds: cfg.AI.TimeoutSeconds,
        RetryAttempts:  cfg.AI.RetryAttempts,
        CacheEnabled:   cfg.AI.CacheEnabled,
        CacheTTL:       cfg.AI.CacheTTL,
    }
    
    da2062AIService, err := ai.NewDA2062AIService(da2062AIConfig)
    if err != nil {
        log.Fatal("Failed to initialize DA2062 AI service:", err)
    }
    
    // Create enhanced DA2062 OCR service
    enhancedDA2062 := ocr.NewEnhancedDA2062Service(azureOCRService, da2062AIService)
    
    // Create DA2062 AI handler
    da2062AIHandler := handlers.NewDA2062AIHandler(
        enhancedDA2062,
        da2062AIService,
        ledgerService,
        inventoryRepo,
        nsnService,
    )
    
    // Setup routes with DA2062 AI handler
    routes.SetupRoutes(
        router,
        // ... existing handlers
        da2062AIHandler,
    )
    
    // ... rest of main
}

---
# backend/internal/services/ai/da2062_confidence_scorer.go
package ai

import (
    "strings"
)

// DA2062ConfidenceScorer calculates confidence scores for DA2062 items
type DA2062ConfidenceScorer struct {
    nsnPatterns    map[string]float64
    fieldWeights   DA2062FieldWeights
}

// DA2062FieldWeights defines importance of each field
type DA2062FieldWeights struct {
    NSN          float64
    SerialNumber float64
    Description  float64
    Quantity     float64
    Condition    float64
}

// NewDA2062ConfidenceScorer creates a new confidence scorer
func NewDA2062ConfidenceScorer() *DA2062ConfidenceScorer {
    return &DA2062ConfidenceScorer{
        nsnPatterns: map[string]float64{
            "1005": 0.95, // Weapons - high confidence
            "5855": 0.90, // Night vision - high confidence
            "8470": 0.85, // Helmets/armor
            "8465": 0.80, // Clothing
        },
        fieldWeights: DA2062FieldWeights{
            NSN:          0.35,
            SerialNumber: 0.30,
            Description:  0.20,
            Quantity:     0.10,
            Condition:    0.05,
        },
    }
}

// ScoreItem calculates confidence for a DA2062 item
func (s *DA2062ConfidenceScorer) ScoreItem(item ParsedDA2062Item) ItemConfidence {
    scores := ItemConfidence{
        NSN:          s.scoreNSN(item.NSN),
        SerialNumber: s.scoreSerialNumber(item.SerialNumber, item.NSN),
        Description:  s.scoreDescription(item.Description),
        Quantity:     s.scoreQuantity(item.Quantity),
        Overall:      0.0,
    }
    
    // Calculate weighted overall score
    scores.Overall = scores.NSN * s.fieldWeights.NSN +
                    scores.SerialNumber * s.fieldWeights.SerialNumber +
                    scores.Description * s.fieldWeights.Description +
                    scores.Quantity * s.fieldWeights.Quantity
    
    // Boost confidence if AI grouped multiple lines
    if item.AIGrouped {
        scores.Overall = min(scores.Overall * 1.1, 1.0)
    }
    
    return scores
}

// scoreNSN validates and scores NSN format
func (s *DA2062ConfidenceScorer) scoreNSN(nsn string) float64 {
    if nsn == "" {
        return 0.0
    }
    
    // Check format (####-##-###-####)
    if !isValidNSNFormat(nsn) {
        return 0.3
    }
    
    // Check if NSN prefix matches known patterns
    prefix := nsn[0:4]
    if confidence, ok := s.nsnPatterns[prefix]; ok {
        return confidence
    }
    
    // Valid format but unknown prefix
    return 0.7
}

// scoreSerialNumber validates serial number based on equipment type
func (s *DA2062ConfidenceScorer) scoreSerialNumber(serial string, nsn string) float64 {
    if serial == "" {
        // Some items don't require serial numbers
        if !requiresSerialNumber(nsn) {
            return 1.0
        }
        return 0.0
    }
    
    // Validate format based on equipment type
    equipType := identifyMilitaryEquipmentType(nsn, "")
    switch equipType {
    case "weapon":
        // Weapons typically have 6-10 character serials
        if len(serial) >= 6 && len(serial) <= 10 {
            return 0.95
        }
        return 0.5
    case "optics":
        // Optics often have prefix-based serials
        if strings.Contains(serial, "-") {
            return 0.9
        }
        return 0.7
    default:
        // Any alphanumeric serial is likely valid
        if len(serial) >= 4 {
            return 0.8
        }
        return 0.4
    }
}

// scoreDescription evaluates description completeness
func (s *DA2062ConfidenceScorer) scoreDescription(desc string) float64 {
    if desc == "" {
        return 0.0
    }
    
    // Check for military nomenclature patterns
    upperDesc := strings.ToUpper(desc)
    
    // Full nomenclature (e.g., "RIFLE, 5.56MM, M4")
    if strings.Contains(upperDesc, ",") {
        return 0.95
    }
    
    // Contains key military terms
    militaryTerms := []string{"RIFLE", "PISTOL", "NIGHT VISION", "HELMET", "VEST", "RADIO"}
    for _, term := range militaryTerms {
        if strings.Contains(upperDesc, term) {
            return 0.85
        }
    }
    
    // Has some description
    if len(desc) > 10 {
        return 0.7
    }
    
    return 0.5
}

// scoreQuantity validates quantity reasonableness
func (s *DA2062ConfidenceScorer) scoreQuantity(qty int) float64 {
    if qty == 0 {
        return 0.0
    }
    
    // Most military items are issued in reasonable quantities
    if qty >= 1 && qty <= 100 {
        return 1.0
    }
    
    // Large quantities might be valid but less common
    if qty > 100 && qty <= 1000 {
        return 0.7
    }
    
    // Very large quantities are suspicious
    return 0.3
}

// Helper functions

func isValidNSNFormat(nsn string) bool {
    // Check ####-##-###-#### format
    if len(nsn) != 16 {
        return false
    }
    
    return nsn[4] == '-' && nsn[7] == '-' && nsn[11] == '-'
}

func requiresSerialNumber(nsn string) bool {
    // Weapons and sensitive items require serial numbers
    prefix := nsn[0:4]
    sensitiveItems := []string{"1005", "5855", "5965"} // Weapons, NVGs, Radios
    
    for _, item := range sensitiveItems {
        if prefix == item {
            return true
        }
    }
    return false
}

func min(a, b float64) float64 {
    if a < b {
        return a
    }
    return b
}

// ItemConfidence represents confidence scores for each field
type ItemConfidence struct {
    NSN          float64 `json:"nsn"`
    SerialNumber float64 `json:"serialNumber"`
    Description  float64 `json:"description"`
    Quantity     float64 `json:"quantity"`
    Overall      float64 `json:"overall"`
}

---
# backend/internal/services/ledger/da2062_events.go
package ledger

import (
    "context"
    "encoding/json"
    "time"
)

// DA2062Event represents a DA2062-specific ledger event
type DA2062Event struct {
    FormNumber    string    `json:"formNumber"`
    UserID        string    `json:"userId"`
    UnitName      string    `json:"unitName"`
    DODAAC        string    `json:"dodaac"`
    ItemCount     int       `json:"itemCount"`
    ImportMethod  string    `json:"importMethod"` // manual, ocr, ai_enhanced
    Confidence    float64   `json:"confidence"`
    Corrections   int       `json:"corrections"`
    ProcessingMs  int64     `json:"processingMs"`
    Timestamp     time.Time `json:"timestamp"`
}

// LogDA2062Import logs a complete DA2062 import event
func (s *Service) LogDA2062Import(ctx context.Context, event DA2062Event) error {
    event.Timestamp = time.Now()
    
    data, err := json.Marshal(event)
    if err != nil {
        return err
    }
    
    return s.immuClient.Set(ctx, []byte("da2062:import:"+event.FormNumber), data)
}

// LogDA2062AIProcessing logs AI processing metrics for DA2062
func (s *Service) LogDA2062AIProcessing(ctx context.Context, metrics DA2062AIMetrics) error {
    data, err := json.Marshal(metrics)
    if err != nil {
        return err
    }
    
    key := fmt.Sprintf("da2062:ai:metrics:%d", time.Now().Unix())
    return s.immuClient.Set(ctx, []byte(key), data)
}

// DA2062AIMetrics captures AI processing metrics
type DA2062AIMetrics struct {
    FormNumber        string    `json:"formNumber"`
    OCRConfidence     float64   `json:"ocrConfidence"`
    AIConfidence      float64   `json:"aiConfidence"`
    ItemsDetected     int       `json:"itemsDetected"`
    ItemsGrouped      int       `json:"itemsGrouped"`
    ProcessingTimeMs  int64     `json:"processingTimeMs"`
    TokensUsed        int       `json:"tokensUsed"`
    CostEstimateUSD   float64   `json:"costEstimateUsd"`
    Timestamp         time.Time `json:"timestamp"`
}