// backend/internal/services/ai/da2062_ai_service.go
package ai

import (
    "context"
    "encoding/json"
    "fmt"
    "time"
    
    "github.com/toole-brendan/hrx/backend/internal/models"
)

// ParsedDA2062 represents the AI-parsed DA 2062 form data
type ParsedDA2062 struct {
    FormNumber    string                 `json:"formNumber"`
    UnitName      string                 `json:"unitName"`
    DODAAC        string                 `json:"dodaac"`
    FromUnit      string                 `json:"fromUnit"`
    ToUnit        string                 `json:"toUnit"`
    Date          string                 `json:"date"`
    Items         []ParsedDA2062Item     `json:"items"`
    Confidence    float64                `json:"confidence"`
    Metadata      DA2062Metadata         `json:"metadata"`
    Suggestions   []Suggestion           `json:"suggestions"`
}

// ParsedDA2062Item represents a single item from DA 2062
type ParsedDA2062Item struct {
    LineNumber     int                    `json:"lineNumber"`
    NSN            string                 `json:"nsn"`
    LIN            string                 `json:"lin,omitempty"`
    Description    string                 `json:"description"`
    Quantity       int                    `json:"quantity"`
    UnitOfIssue    string                 `json:"unitOfIssue"`
    SerialNumber   string                 `json:"serialNumber,omitempty"`
    Condition      string                 `json:"condition"`
    Confidence     float64                `json:"confidence"`
    AIGrouped      bool                   `json:"aiGrouped"`      // True if AI grouped multi-line item
    Suggestions    []Suggestion           `json:"suggestions"`
}

// DA2062Metadata contains processing metadata
type DA2062Metadata struct {
    ProcessedAt       time.Time `json:"processedAt"`
    OCRConfidence     float64   `json:"ocrConfidence"`
    AIConfidence      float64   `json:"aiConfidence"`
    ItemCount         int       `json:"itemCount"`
    GroupedItems      int       `json:"groupedItems"`     // Items that spanned multiple lines
    HandwrittenItems  int       `json:"handwrittenItems"`
}

// Suggestion represents an AI-generated suggestion
type Suggestion struct {
    Field       string  `json:"field"`
    Type        string  `json:"type"` // correction, completion, validation
    Value       string  `json:"value"`
    Confidence  float64 `json:"confidence"`
    Reasoning   string  `json:"reasoning"`
}

// DA2062AIService interface defines AI operations for DA 2062
type DA2062AIService interface {
    // ParseDA2062Text parses OCR text into structured DA 2062 data
    ParseDA2062Text(ctx context.Context, ocrText string) (*ParsedDA2062, error)
    
    // EnhanceDA2062OCR improves OCR results with AI understanding
    EnhanceDA2062OCR(ctx context.Context, ocrResult interface{}) (*ParsedDA2062, error)
    
    // GenerateDA2062 creates a DA 2062 from natural language description
    GenerateDA2062(ctx context.Context, description string) (*GeneratedDA2062, error)
    
    // ValidateDA2062 provides validation and suggestions
    ValidateDA2062(ctx context.Context, formData *ParsedDA2062) (*ValidationResult, error)
}

// GeneratedDA2062 represents an AI-generated DA 2062 form
type GeneratedDA2062 struct {
    Form        *ParsedDA2062 `json:"form"`
    Suggestions []Suggestion  `json:"suggestions"`
    Confidence  float64       `json:"confidence"`
}

// Config holds AI service configuration
type Config struct {
    Provider        string                 `yaml:"provider"`
    Endpoint        string                 `yaml:"endpoint"`
    APIKey          string                 `yaml:"api_key"`
    Model           string                 `yaml:"model"`
    MaxTokens       int                    `yaml:"max_tokens"`
    Temperature     float64                `yaml:"temperature"`
    TimeoutSeconds  int                    `yaml:"timeout_seconds"`
    RetryAttempts   int                    `yaml:"retry_attempts"`
    CacheEnabled    bool                   `yaml:"cache_enabled"`
    CacheTTL        time.Duration          `yaml:"cache_ttl"`
}

// NewDA2062AIService creates a new DA 2062 AI service based on configuration
func NewDA2062AIService(cfg Config) (DA2062AIService, error) {
    switch cfg.Provider {
    case "azure_openai":
        return NewAzureOpenAIDA2062Service(cfg)
    case "openai":
        return NewOpenAIDA2062Service(cfg)
    default:
        return nil, fmt.Errorf("unsupported AI provider: %s", cfg.Provider)
    }
}

// backend/internal/services/ai/azure_openai_da2062_service.go
package ai

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "time"
)

// AzureOpenAIDA2062Service implements DA2062AIService using Azure OpenAI
type AzureOpenAIDA2062Service struct {
    config     Config
    client     *http.Client
    promptMgr  *DA2062PromptManager
}

// NewAzureOpenAIDA2062Service creates a new Azure OpenAI service for DA 2062
func NewAzureOpenAIDA2062Service(cfg Config) (*AzureOpenAIDA2062Service, error) {
    return &AzureOpenAIDA2062Service{
        config: cfg,
        client: &http.Client{
            Timeout: time.Duration(cfg.TimeoutSeconds) * time.Second,
        },
        promptMgr: NewDA2062PromptManager(),
    }, nil
}

// ParseDA2062Text implements DA 2062 parsing using Azure OpenAI
func (s *AzureOpenAIDA2062Service) ParseDA2062Text(ctx context.Context, ocrText string) (*ParsedDA2062, error) {
    // Get DA 2062-specific prompts
    systemPrompt := s.promptMgr.GetSystemPrompt()
    userPrompt := s.promptMgr.BuildParsingPrompt(ocrText)
    
    // Prepare the API request
    requestBody := map[string]interface{}{
        "messages": []map[string]string{
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userPrompt},
        },
        "temperature": s.config.Temperature,
        "max_tokens": s.config.MaxTokens,
        "response_format": map[string]string{"type": "json_object"},
    }
    
    // Make the API call
    response, err := s.callAPI(ctx, requestBody)
    if err != nil {
        return nil, fmt.Errorf("AI API call failed: %w", err)
    }
    
    // Parse the response
    var parsedForm ParsedDA2062
    if err := json.Unmarshal(response, &parsedForm); err != nil {
        return nil, fmt.Errorf("failed to parse AI response: %w", err)
    }
    
    // Post-process for DA 2062 specifics
    s.postProcessDA2062(&parsedForm)
    
    return &parsedForm, nil
}

// GenerateDA2062 creates a DA 2062 from natural language
func (s *AzureOpenAIDA2062Service) GenerateDA2062(ctx context.Context, description string) (*GeneratedDA2062, error) {
    systemPrompt := s.promptMgr.GetGenerationPrompt()
    userPrompt := fmt.Sprintf("Generate a DA Form 2062 based on this description: %s", description)
    
    requestBody := map[string]interface{}{
        "messages": []map[string]string{
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userPrompt},
        },
        "temperature": 0.3, // Higher for generation
        "max_tokens": s.config.MaxTokens,
        "response_format": map[string]string{"type": "json_object"},
    }
    
    response, err := s.callAPI(ctx, requestBody)
    if err != nil {
        return nil, fmt.Errorf("AI generation failed: %w", err)
    }
    
    var generated GeneratedDA2062
    if err := json.Unmarshal(response, &generated); err != nil {
        return nil, fmt.Errorf("failed to parse generated form: %w", err)
    }
    
    return &generated, nil
}

// callAPI makes the actual API call to Azure OpenAI
func (s *AzureOpenAIDA2062Service) callAPI(ctx context.Context, body interface{}) ([]byte, error) {
    url := fmt.Sprintf("%s/openai/deployments/%s/chat/completions?api-version=2024-02-15-preview",
        s.config.Endpoint, s.config.Model)
    
    jsonBody, err := json.Marshal(body)
    if err != nil {
        return nil, err
    }
    
    req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonBody))
    if err != nil {
        return nil, err
    }
    
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("api-key", s.config.APIKey)
    
    resp, err := s.client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        body, _ := io.ReadAll(resp.Body)
        return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode, string(body))
    }
    
    // Extract the content from the response
    var apiResponse struct {
        Choices []struct {
            Message struct {
                Content string `json:"content"`
            } `json:"message"`
        } `json:"choices"`
    }
    
    if err := json.NewDecoder(resp.Body).Decode(&apiResponse); err != nil {
        return nil, err
    }
    
    if len(apiResponse.Choices) == 0 {
        return nil, fmt.Errorf("no response from AI")
    }
    
    return []byte(apiResponse.Choices[0].Message.Content), nil
}

// postProcessDA2062 applies DA 2062-specific post-processing
func (s *AzureOpenAIDA2062Service) postProcessDA2062(form *ParsedDA2062) {
    // Normalize NSNs to standard format
    for i := range form.Items {
        if nsn := normalizeNSN(form.Items[i].NSN); nsn != "" {
            form.Items[i].NSN = nsn
        }
        
        // Set military defaults
        if form.Items[i].UnitOfIssue == "" {
            form.Items[i].UnitOfIssue = "EA"
        }
        if form.Items[i].Condition == "" {
            form.Items[i].Condition = "A"
        }
        if form.Items[i].Quantity == 0 {
            form.Items[i].Quantity = 1
        }
        
        // Detect common military equipment patterns
        s.enhanceItemDescription(&form.Items[i])
    }
    
    // Set metadata
    form.Metadata.ItemCount = len(form.Items)
    form.Metadata.ProcessedAt = time.Now()
}

// enhanceItemDescription improves item descriptions based on military patterns
func (s *AzureOpenAIDA2062Service) enhanceItemDescription(item *ParsedDA2062Item) {
    // Common military equipment abbreviations
    abbreviations := map[string]string{
        "NVG": "NIGHT VISION GOGGLE",
        "ACH": "ADVANCED COMBAT HELMET",
        "IOTV": "IMPROVED OUTER TACTICAL VEST",
        "M4": "RIFLE, 5.56MM, M4",
        "M16": "RIFLE, 5.56MM, M16A4",
        "M9": "PISTOL, 9MM, M9",
    }
    
    // Check if description contains abbreviations
    for abbr, full := range abbreviations {
        if item.Description == abbr {
            item.Description = full
        }
    }
}

// backend/internal/services/ai/da2062_prompt_manager.go
package ai

import (
    "fmt"
)

// DA2062PromptManager manages prompts specific to DA 2062 processing
type DA2062PromptManager struct {
    systemPrompt      string
    parsingRules      string
    generationPrompt  string
    examples          []DA2062Example
}

// DA2062Example represents example items for training
type DA2062Example struct {
    Input    string
    Expected ParsedDA2062Item
}

// NewDA2062PromptManager creates a new prompt manager
func NewDA2062PromptManager() *DA2062PromptManager {
    mgr := &DA2062PromptManager{}
    mgr.initializePrompts()
    mgr.loadExamples()
    return mgr
}

// initializePrompts sets up DA 2062-specific prompts
func (m *DA2062PromptManager) initializePrompts() {
    // System prompt for parsing DA 2062
    m.systemPrompt = `You are an expert military supply specialist with extensive experience processing DA Form 2062 (Hand Receipt/Annex Number) documents. Your expertise includes:

1. Military Equipment Knowledge:
   - National Stock Numbers (NSN) in format ####-##-###-####
   - Line Item Numbers (LIN) for Army equipment
   - Standard military nomenclature (e.g., RIFLE, 5.56MM, M4)
   - Common abbreviations (EA, BX, CS, DZ, PR, SE for units of issue)

2. DA 2062 Structure Understanding:
   - Header information: Unit names, DODAAC/UIC, dates
   - Line items that often span multiple lines
   - Serial numbers that may appear on separate lines
   - Handwritten annotations and corrections

3. Military Context:
   - Condition codes: A (Serviceable), B (Serviceable with qualification), C (Unserviceable)
   - Common equipment serial number patterns
   - Standard issue quantities for military units

You must output valid JSON matching the exact structure provided. Be intelligent about grouping multi-line items and identifying serial numbers that may not be on the same line as the item description.`

    // Parsing rules and instructions
    m.parsingRules = `Extract all information from this DA Form 2062 OCR text following these rules:

1. Item Grouping:
   - If a line starts with an NSN, it begins a new item
   - Serial numbers often appear on the line below the item description
   - Descriptions may span multiple lines - group them intelligently
   - Look for patterns like "S/N:", "SN:", or standalone alphanumeric strings as serial numbers

2. Data Normalization:
   - Convert NSNs to format: ####-##-###-####
   - Standardize condition codes to A, B, or C
   - Default quantity to 1 if not specified
   - Default unit of issue to "EA" if not specified

3. Confidence Scoring:
   - High confidence (>0.9): Complete NSN, description, and serial number
   - Medium confidence (0.7-0.9): Missing serial number or partial information
   - Low confidence (<0.7): Missing critical fields or unclear text

4. Multi-line Item Example:
   Line 1: "1005-01-123-4567 RIFLE, 5.56MM, M4"
   Line 2: "W/ RAIL SYSTEM"
   Line 3: "S/N: M4123456"
   Should be grouped as one item with full description and serial number.

Return structured JSON with all extracted items and metadata.`

    // Generation prompt for creating DA 2062 from description
    m.generationPrompt = `You are creating a DA Form 2062 based on a natural language description. Generate the form data following military standards:

1. Parse the description to extract:
   - Equipment types and quantities
   - Receiving unit/person
   - Transfer type (temporary or permanent)

2. For each item, provide:
   - Correct NSN (use your knowledge of military equipment)
   - Full military nomenclature
   - Appropriate condition code (default to A)
   - Realistic serial number format for that equipment type

3. Common Equipment NSNs:
   - M4 Rifle: 1005-01-231-0973
   - M16A4 Rifle: 1005-01-383-2872
   - M9 Pistol: 1005-01-118-2640
   - PVS-14 NVG: 5855-01-432-0524
   - ACH Helmet: 8470-01-523-8127

4. Serial Number Patterns:
   - Weapons: Alphanumeric, typically 6-8 characters
   - Optics: Start with equipment prefix (e.g., PVS14-xxxxx)
   - Body armor: Date code + sequential number

Generate complete DA 2062 data in the required JSON format.`
}

// loadExamples loads example patterns for better parsing
func (m *DA2062PromptManager) loadExamples() {
    m.examples = []DA2062Example{
        {
            Input: "1005-01-231-0973 RIFLE, 5.56MM, M4\nW/ RAIL ADAPTER SYSTEM\nS/N: FE123456",
            Expected: ParsedDA2062Item{
                NSN:          "1005-01-231-0973",
                Description:  "RIFLE, 5.56MM, M4 W/ RAIL ADAPTER SYSTEM",
                SerialNumber: "FE123456",
                Quantity:     1,
                UnitOfIssue:  "EA",
                Condition:    "A",
                AIGrouped:    true,
            },
        },
        {
            Input: "5855-01-432-0524 NIGHT VISION GOGGLE\nAN/PVS-14\nPVS14-87654",
            Expected: ParsedDA2062Item{
                NSN:          "5855-01-432-0524",
                Description:  "NIGHT VISION GOGGLE AN/PVS-14",
                SerialNumber: "PVS14-87654",
                Quantity:     1,
                UnitOfIssue:  "EA",
                Condition:    "A",
                AIGrouped:    true,
            },
        },
    }
}

// GetSystemPrompt returns the system prompt for DA 2062 parsing
func (m *DA2062PromptManager) GetSystemPrompt() string {
    return m.systemPrompt
}

// BuildParsingPrompt builds the user prompt for parsing OCR text
func (m *DA2062PromptManager) BuildParsingPrompt(ocrText string) string {
    return fmt.Sprintf(`%s

OCR Text to parse:
%s

Expected JSON structure:
{
  "formNumber": "DA2062-YYYYMMDD-####",
  "unitName": "unit name from form",
  "dodaac": "6 character code",
  "fromUnit": "issuing unit",
  "toUnit": "receiving unit",
  "date": "YYYY-MM-DD",
  "items": [
    {
      "lineNumber": 1,
      "nsn": "####-##-###-####",
      "description": "complete item description",
      "quantity": 1,
      "unitOfIssue": "EA",
      "serialNumber": "serial if found",
      "condition": "A",
      "confidence": 0.95,
      "aiGrouped": true,
      "suggestions": []
    }
  ],
  "confidence": 0.90,
  "metadata": {
    "itemCount": 1,
    "groupedItems": 1,
    "handwrittenItems": 0
  },
  "suggestions": []
}`, m.parsingRules, ocrText)
}

// GetGenerationPrompt returns the prompt for generating DA 2062
func (m *DA2062PromptManager) GetGenerationPrompt() string {
    return m.generationPrompt
}

// backend/internal/services/ai/da2062_utils.go
package ai

import (
    "regexp"
    "strings"
)

// normalizeNSN normalizes NSN to standard format ####-##-###-####
func normalizeNSN(nsn string) string {
    // Remove all non-numeric characters
    cleaned := regexp.MustCompile(`[^0-9]`).ReplaceAllString(nsn, "")
    
    // Check if we have exactly 13 digits
    if len(cleaned) != 13 {
        return ""
    }
    
    // Format as ####-##-###-####
    return fmt.Sprintf("%s-%s-%s-%s", 
        cleaned[0:4], 
        cleaned[4:6], 
        cleaned[6:9], 
        cleaned[9:13])
}

// extractDA2062SerialNumber attempts to extract serial numbers from text
func extractDA2062SerialNumber(text string, itemType string) string {
    // Weapon-specific patterns
    weaponPatterns := []string{
        `(?i)s[\./\s]*n[\./\s]*:?\s*([A-Z0-9]{6,10})`,
        `(?i)serial[\s:]*([A-Z0-9]{6,10})`,
        `\b(FE[0-9]{6})\b`, // M4 pattern
        `\b(W[0-9]{6,7})\b`, // M16 pattern
    }
    
    // Optics patterns
    opticsPatterns := []string{
        `\b(PVS14-[0-9]{5,6})\b`,
        `\b(PAS13-[0-9]{5,6})\b`,
        `\b(M68-[0-9]{6})\b`,
    }
    
    // Try weapon patterns first
    for _, pattern := range weaponPatterns {
        re := regexp.MustCompile(pattern)
        if matches := re.FindStringSubmatch(text); len(matches) > 1 {
            return strings.ToUpper(matches[1])
        }
    }
    
    // Try optics patterns
    for _, pattern := range opticsPatterns {
        re := regexp.MustCompile(pattern)
        if matches := re.FindStringSubmatch(text); len(matches) > 1 {
            return strings.ToUpper(matches[1])
        }
    }
    
    // Generic alphanumeric pattern as fallback
    genericPattern := regexp.MustCompile(`\b([A-Z0-9]{6,12})\b`)
    if matches := genericPattern.FindStringSubmatch(strings.ToUpper(text)); len(matches) > 1 {
        return matches[1]
    }
    
    return ""
}

// identifyMilitaryEquipmentType attempts to identify equipment type from NSN or description
func identifyMilitaryEquipmentType(nsn string, description string) string {
    // NSN prefix to equipment type mapping
    nsnPrefixes := map[string]string{
        "1005": "weapon",
        "5855": "optics",
        "8470": "armor",
        "8465": "clothing",
        "5180": "tool",
    }
    
    if nsn != "" && len(nsn) >= 4 {
        prefix := nsn[0:4]
        if equipType, ok := nsnPrefixes[prefix]; ok {
            return equipType
        }
    }
    
    // Check description for keywords
    descUpper := strings.ToUpper(description)
    switch {
    case strings.Contains(descUpper, "RIFLE") || strings.Contains(descUpper, "PISTOL"):
        return "weapon"
    case strings.Contains(descUpper, "NIGHT VISION") || strings.Contains(descUpper, "SCOPE"):
        return "optics"
    case strings.Contains(descUpper, "HELMET") || strings.Contains(descUpper, "VEST"):
        return "armor"
    default:
        return "general"
    }
}

// backend/internal/services/ocr/enhanced_da2062_service.go
package ocr

import (
    "context"
    "fmt"
    "time"
    
    "github.com/toole-brendan/hrx/backend/internal/services/ai"
)

// EnhancedDA2062Service combines traditional OCR with AI for DA 2062 processing
type EnhancedDA2062Service struct {
    azureOCR  *AzureOCRService
    aiService ai.DA2062AIService
}

// NewEnhancedDA2062Service creates a new enhanced DA 2062 service
func NewEnhancedDA2062Service(azureOCR *AzureOCRService, aiService ai.DA2062AIService) *EnhancedDA2062Service {
    return &EnhancedDA2062Service{
        azureOCR:  azureOCR,
        aiService: aiService,
    }
}

// ProcessDA2062WithAI processes a DA 2062 using OCR and AI
func (s *EnhancedDA2062Service) ProcessDA2062WithAI(ctx context.Context, imageData []byte, contentType string) (*UnifiedDA2062Result, error) {
    startTime := time.Now()
    
    // Step 1: Traditional OCR
    ocrResult, err := s.azureOCR.ProcessImageFromBytes(ctx, imageData, contentType)
    if err != nil {
        return nil, fmt.Errorf("OCR processing failed: %w", err)
    }
    
    // Step 2: Extract full text for AI processing
    fullText := s.extractFullText(ocrResult)
    
    // Step 3: Send to AI for enhancement
    aiResult, err := s.aiService.ParseDA2062Text(ctx, fullText)
    if err != nil {
        // Fall back to OCR-only result
        return s.convertToUnifiedResult(ocrResult, nil), nil
    }
    
    // Step 4: Merge OCR and AI results
    unified := s.mergeDA2062Results(ocrResult, aiResult)
    
    // Step 5: Validate with military rules
    validated := s.validateDA2062(unified)
    
    // Set processing time
    validated.ProcessingTimeMs = time.Since(startTime).Milliseconds()
    
    return validated, nil
}

// extractFullText extracts all text from OCR result
func (s *EnhancedDA2062Service) extractFullText(ocr *DA2062ParsedForm) string {
    // Implementation would extract all text lines from OCR result
    // This is simplified for the example
    var lines []string
    // Extract text from OCR result structure
    return strings.Join(lines, "\n")
}

// mergeDA2062Results intelligently combines OCR and AI results
func (s *EnhancedDA2062Service) mergeDA2062Results(ocr *DA2062ParsedForm, ai *ai.ParsedDA2062) *UnifiedDA2062Result {
    result := &UnifiedDA2062Result{
        FormNumber: ai.FormNumber,
        UnitName:   ai.UnitName,
        DODAAC:     ai.DODAAC,
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
                existing.SerialNumber = aiItem.SerialNumber
                existing.Source = "ai_enhanced"
                result.Metadata.GroupedItems++
            }
            
            // Always use AI's normalized NSN
            if aiItem.NSN != "" {
                existing.NSN = aiItem.NSN
            }
            
            existing.Suggestions = aiItem.Suggestions
            existing.Confidence = (existing.Confidence + aiItem.Confidence) / 2
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
        if !isValidNSN(item.NSN) {
            item.RequiresReview = true
            item.ValidationIssues = append(item.ValidationIssues, "Invalid NSN format")
        }
        
        // Validate condition code
        if item.Condition != "A" && item.Condition != "B" && item.Condition != "C" {
            item.Condition = "A" // Default
            item.ValidationIssues = append(item.ValidationIssues, "Invalid condition code, defaulted to A")
        }
        
        // Flag items without serial numbers for weapons
        if isWeapon(item.NSN) && item.SerialNumber == "" {
            item.RequiresReview = true
            item.ValidationIssues = append(item.ValidationIssues, "Weapon missing serial number")
        }
    }
    
    return result
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
    SerialNumber     string          `json:"serialNumber,omitempty"`
    Condition        string          `json:"condition"`
    Confidence       float64         `json:"confidence"`
    Source           string          `json:"source"` // ocr, ai_enhanced, ai_only
    Suggestions      []ai.Suggestion `json:"suggestions"`
    RequiresReview   bool            `json:"requiresReview"`
    ValidationIssues []string        `json:"validationIssues,omitempty"`
}