# HRX DA 2062 AI Integration Quick Start Guide

## Implementation Progress

### ✅ Completed Tasks:

1. **Created DA2062 AI service directory structure** 
   - Created directories:
     - `/Users/brendantoole/projects2/handreceipt/backend/internal/services/ai/`
     - `/Users/brendantoole/projects2/handreceipt/backend/internal/services/ai/da2062/`
     - `/Users/brendantoole/projects2/handreceipt/backend/internal/services/ai/providers/`
   
2. **Implemented DA2062AIService interface**
   - Created file: `/Users/brendantoole/projects2/handreceipt/backend/internal/services/ai/da2062_ai_service.go`
   - Defined core interfaces and types
   - Created ParsedDA2062, Suggestion, ValidationResult structures
   
3. **Created Azure OpenAI DA2062 service**
   - Created file: `/Users/brendantoole/projects2/handreceipt/backend/internal/services/ai/azure_openai_da2062_service.go`
   - Implemented all interface methods
   - Added API integration with Azure OpenAI
   - Included post-processing and validation logic
   
4. **Implemented DA2062 prompt manager**
   - Created file: `/Users/brendantoole/projects2/handreceipt/backend/internal/services/ai/da2062_prompt_manager.go`
   - Created military-specific prompts
   - Added multi-line item grouping rules
   - Included example patterns for common equipment
   
5. **Created DA2062 utility functions**
   - Created file: `/Users/brendantoole/projects2/handreceipt/backend/internal/services/ai/da2062_utils.go`
   - NSN normalization and validation
   - Serial number extraction with military patterns
   - Equipment type identification
   - Condition code validation
   
6. **Implemented enhanced DA2062 OCR service**
   - Created file: `/Users/brendantoole/projects2/handreceipt/backend/internal/services/ocr/enhanced_da2062_service.go`
   - Combined OCR + AI processing
   - Added intelligent caching
   - Implemented result merging logic
   - Added military-specific validation

### 📝 Files Modified:
1. **Updated plan files to track progress**
   - Modified: `/Users/brendantoole/projects2/handreceipt/plan1.md` (marked completed tasks)
   - Modified: `/Users/brendantoole/projects2/handreceipt/plan4.md` (added implementation progress)

### 🔄 In Progress:
7. **Create DA2062 confidence scorer**
8. **Update configuration files for AI**

### ⏳ Pending Tasks:
9. Create DA2062 AI handler
10. Update routes to include AI endpoints  
11. Wire up services in main.go
12. Create tests for AI services

---

## 📁 Complete File List Created

### New Files Created (6 files):
```
/Users/brendantoole/projects2/handreceipt/backend/internal/services/ai/
├── da2062_ai_service.go              # Core AI service interface and types
├── azure_openai_da2062_service.go    # Azure OpenAI implementation
├── da2062_prompt_manager.go          # Military-specific prompts
└── da2062_utils.go                   # Utility functions for NSN/serial validation

/Users/brendantoole/projects2/handreceipt/backend/internal/services/ocr/
└── enhanced_da2062_service.go        # Combined OCR+AI service
```

### Modified Files (2 files):
```
/Users/brendantoole/projects2/handreceipt/
├── plan1.md                          # Updated task completion status
└── plan4.md                          # Added implementation progress tracking
```

### Other Changes:
- Created migration file: `/Users/brendantoole/projects2/handreceipt/sql/migrations/024_rename_immudb_to_ledger.sql`
- Removed ImmuDB references from multiple configuration and documentation files (separate from DA2062 AI work)

---

## Prerequisites

1. **Azure OpenAI Access**
   ```bash
   # Set up environment variables
   export AZURE_OPENAI_ENDPOINT="https://your-resource.openai.azure.com/"
   export AZURE_OPENAI_KEY="your-api-key"
   ```

2. **Go Dependencies**
   ```bash
   go get github.com/sashabaranov/go-openai
   go get github.com/patrickmn/go-cache
   ```

## Step 1: Create DA 2062 AI Service Structure ✅

```bash
# Create DA2062 AI service directories
mkdir -p backend/internal/services/ai/{da2062,providers}
mkdir -p backend/internal/api/handlers/da2062
```

## Step 2: Implement Base DA 2062 AI Service ✅

1. ✅ Copy `da2062_ai_service.go` from the Phase 1 implementation
2. ✅ Copy `azure_openai_da2062_service.go` 
3. ✅ Copy `da2062_prompt_manager.go`
4. ✅ Copy `da2062_utils.go`

## Step 3: Update Configuration 🔄

Add to `backend/configs/config.development.yaml`:

```yaml
ai:
  provider: "azure_openai"
  endpoint: "${AZURE_OPENAI_ENDPOINT}"
  api_key: "${AZURE_OPENAI_KEY}"
  model: "gpt-4-turbo-preview"
  max_tokens: 4000
  temperature: 0.1
  
  da2062:
    confidence:
      minimum_threshold: 0.7
      review_threshold: 0.85
    patterns:
      nsn_format: "####-##-###-####"
```

## Step 4: Create Enhanced DA 2062 Service ✅

1. ✅ Copy `enhanced_da2062_service.go` to `backend/internal/services/ocr/`
2. ✅ Update imports to match your project structure

## Step 5: Test DA 2062 AI Integration

Create a test file `backend/internal/services/ai/da2062_ai_test.go`:

```go
func TestDA2062AIIntegration(t *testing.T) {
    // Skip if no API key
    if os.Getenv("AZURE_OPENAI_KEY") == "" {
        t.Skip("AZURE_OPENAI_KEY not set")
    }
    
    cfg := Config{
        Provider: "azure_openai",
        Endpoint: os.Getenv("AZURE_OPENAI_ENDPOINT"),
        APIKey:   os.Getenv("AZURE_OPENAI_KEY"),
        Model:    "gpt-4-turbo-preview",
    }
    
    service, err := NewDA2062AIService(cfg)
    require.NoError(t, err)
    
    // Test with sample DA 2062 OCR text
    sampleText := `DA FORM 2062
    UNIT: ALPHA COMPANY, 1ST BATTALION
    DODAAC: W12345
    
    1. 1005-01-231-0973 RIFLE, 5.56MM, M4
    W/ RAIL ADAPTER SYSTEM
    S/N: FE123456
    QTY: 10 EA CONDITION: A
    
    2. 5855-01-432-0524 NIGHT VISION GOGGLE
    AN/PVS-14
    S/N: PVS14-87654`
    
    result, err := service.ParseDA2062Text(context.Background(), sampleText)
    require.NoError(t, err)
    assert.Equal(t, "ALPHA COMPANY, 1ST BATTALION", result.UnitName)
    assert.Equal(t, "W12345", result.DODAAC)
    assert.Len(t, result.Items, 2)
    
    // Check first item (M4 Rifle)
    item1 := result.Items[0]
    assert.Equal(t, "1005-01-231-0973", item1.NSN)
    assert.Equal(t, "RIFLE, 5.56MM, M4 W/ RAIL ADAPTER SYSTEM", item1.Description)
    assert.Equal(t, "FE123456", item1.SerialNumber)
    assert.True(t, item1.AIGrouped) // AI should group multi-line item
}
```

## Step 6: Run Initial Test

```bash
cd backend
go test ./internal/services/ai -v -run TestDA2062AI
```

## Step 7: Integrate with Existing DA2062 Handler

Update `backend/internal/api/handlers/da2062_handler.go`:

```go
// Add AI service to existing handler
type DA2062Handler struct {
    // ... existing fields
    enhancedDA2062 *ocr.EnhancedDA2062Service
    useAI          bool
}

// Update ProcessOCR method to use AI when available
func (h *DA2062Handler) ProcessOCR(c *gin.Context) {
    // ... existing file upload code
    
    // Check if AI enhancement is enabled
    if h.useAI && h.enhancedDA2062 != nil {
        result, err := h.enhancedDA2062.ProcessDA2062WithAI(
            c.Request.Context(), 
            fileBytes, 
            contentType,
        )
        if err == nil {
            // Use AI-enhanced result
            response := h.convertAIResultToResponse(result)
            c.JSON(http.StatusOK, response)
            return
        }
        // Fall back to traditional OCR on error
        log.Printf("AI enhancement failed, falling back to OCR: %v", err)
    }
    
    // Traditional OCR processing
    // ... existing OCR code
}
```

## Step 8: Test with Real DA 2062 Form

1. Use your existing DA 2062 test images
2. Test AI-enhanced endpoint:

```bash
# Traditional OCR
curl -X POST http://localhost:8080/api/da2062/process \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test-da2062.jpg"

# AI-enhanced processing
curl -X POST http://localhost:8080/api/da2062/ai/process \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test-da2062.jpg"
```

## Step 9: Monitor and Debug

Add detailed logging for DA 2062 AI processing:

```go
// In da2062_ai_service.go
func (s *AzureOpenAIDA2062Service) ParseDA2062Text(ctx context.Context, ocrText string) (*ParsedDA2062, error) {
    start := time.Now()
    defer func() {
        log.Printf("DA2062 AI parsing took %v", time.Since(start))
    }()
    
    log.Printf("Processing DA2062 with %d characters of OCR text", len(ocrText))
    
    // ... rest of implementation
    
    log.Printf("AI found %d items, %d were multi-line grouped", 
        len(result.Items), result.Metadata.GroupedItems)
    
    return result, nil
}
```

## Step 10: Test DA 2062 Generation

Test natural language form generation:

```bash
curl -X POST http://localhost:8080/api/da2062/ai/generate \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Issue 10 M4 rifles and 5 PVS-14 night vision goggles to Bravo Company"
  }'
```

## Common DA 2062 Issues and Solutions

### Issue: Multi-line Items Not Grouped
```go
// Adjust grouping parameters in config
da2062:
  grouping:
    max_lines_per_item: 5  # Increase if needed
    serial_distance: 3     # Allow more lines between item and serial
```

### Issue: Serial Numbers Not Detected
```go
// Add unit-specific serial patterns
func (m *DA2062PromptManager) addCustomSerialPatterns(patterns []string) {
    // Add patterns specific to your unit's equipment
    m.customPatterns = append(m.customPatterns, patterns...)
}
```

### Issue: High AI Costs
- Cache results for identical forms
- Use batch processing during off-hours
- Implement smart routing (only use AI for complex forms)

```go
// Simple complexity detector
func needsAIProcessing(ocrResult *DA2062ParsedForm) bool {
    // Use AI if OCR confidence is low
    if ocrResult.Confidence < 0.8 {
        return true
    }
    // Use AI if items are missing serial numbers
    for _, item := range ocrResult.Items {
        if item.SerialNumber == "" && requiresSerialNumber(item.NSN) {
            return true
        }
    }
    return false
}
```

## DA 2062-Specific Best Practices

1. **Serial Number Validation**
   - Always validate weapon serial numbers
   - Flag missing serials for sensitive items
   - Cross-reference with unit property book

2. **Multi-line Item Handling**
   - Train AI with unit-specific examples
   - Adjust grouping parameters based on form variations
   - Review grouped items during testing

3. **Confidence Thresholds**
   - Set higher thresholds for weapons (>0.9)
   - Lower thresholds acceptable for consumables
   - Always require human review for low confidence

## Performance Metrics

Track these DA 2062-specific metrics:

```go
type DA2062Metrics struct {
    TotalProcessed      int
    AIEnhanced         int
    MultiLineGrouped   int
    SerialNumbersFound int
    AverageConfidence  float64
    ProcessingTime     time.Duration
    CostPerForm        float64
}
```

## Next Steps

1. **Week 1**: Process 50 test DA 2062 forms
   - Compare OCR vs AI accuracy
   - Measure time savings
   - Calculate cost per form

2. **Week 2**: Refine prompts based on results
   - Add unit-specific patterns
   - Improve serial number detection
   - Optimize token usage

3. **Week 3**: Implement UI enhancements
   - Add confidence visualization
   - Create review interface
   - Enable batch processing

4. **Week 4**: Production rollout
   - Deploy to single supply room
   - Monitor performance
   - Gather user feedback

## Support Resources

- [DA 2062 Form Guide](https://armypubs.army.mil/ProductMaps/PubForm/Details.aspx?PUB_ID=89440)
- [NSN Format Reference](https://www.dla.mil/Info/FederalCatalogSystem/)
- Azure OpenAI Documentation
- HRX Internal DA2062 Documentation

## Troubleshooting Checklist

- [ ] Azure OpenAI credentials configured correctly
- [ ] DA 2062 test images available
- [ ] NSN service connected and working
- [ ] Ledger service logging enabled
- [ ] Confidence thresholds appropriate for your unit
- [ ] Multi-line grouping parameters tuned
- [ ] Serial number patterns updated for unit equipment

Remember: The AI enhancement should seamlessly improve DA 2062 processing without disrupting existing workflows!