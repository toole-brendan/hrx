package ai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
	"log"
	
	"github.com/toole-brendan/handreceipt-go/internal/domain"
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
	startTime := time.Now()
	
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
	
	log.Printf("DA2062 AI parsing completed in %v, found %d items (%d grouped)", 
		time.Since(startTime), parsedForm.Metadata.ItemCount, parsedForm.Metadata.GroupedItems)
	
	return &parsedForm, nil
}

// EnhanceDA2062OCR improves OCR results with AI understanding
func (s *AzureOpenAIDA2062Service) EnhanceDA2062OCR(ctx context.Context, ocrResult interface{}) (*ParsedDA2062, error) {
	// Convert OCR result to text for AI processing
	ocrText := fmt.Sprintf("%v", ocrResult) // Simplified - would extract actual text
	return s.ParseDA2062Text(ctx, ocrText)
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
	
	// Post-process generated form
	if generated.Form != nil {
		s.postProcessDA2062(generated.Form)
	}
	
	return &generated, nil
}

// ValidateDA2062 provides validation and suggestions
func (s *AzureOpenAIDA2062Service) ValidateDA2062(ctx context.Context, formData *ParsedDA2062) (*ValidationResult, error) {
	result := &ValidationResult{
		IsValid: true,
		Items:   formData.Items,
		Issues:  []ValidationIssue{},
	}
	
	// Validate each item
	for i, item := range formData.Items {
		// Check NSN format
		if item.NSN != "" && !isValidNSN(item.NSN) {
			result.Issues = append(result.Issues, ValidationIssue{
				Field:      "nsn",
				ItemIndex:  i,
				Issue:      "Invalid NSN format",
				Severity:   "error",
				Suggestion: "NSN should be in format ####-##-###-####",
			})
			result.IsValid = false
		}
		
		// Check serial number for weapons
		if isWeapon(item.NSN) && item.SerialNumber == "" {
			result.Issues = append(result.Issues, ValidationIssue{
				Field:      "serialNumber",
				ItemIndex:  i,
				Issue:      "Weapon missing serial number",
				Severity:   "error",
				Suggestion: "All weapons must have serial numbers recorded",
			})
			result.IsValid = false
		}
		
		// Validate condition code
		if item.Condition != "A" && item.Condition != "B" && item.Condition != "C" {
			result.Issues = append(result.Issues, ValidationIssue{
				Field:      "condition",
				ItemIndex:  i,
				Issue:      "Invalid condition code",
				Severity:   "warning",
				Suggestion: "Use A (Serviceable), B (Serviceable with qualification), or C (Unserviceable)",
			})
		}
	}
	
	return result, nil
}

// ExtractAndValidateItems extracts military equipment entities
func (s *AzureOpenAIDA2062Service) ExtractAndValidateItems(ctx context.Context, text string) (*ValidationResult, error) {
	// Parse the text first
	parsed, err := s.ParseDA2062Text(ctx, text)
	if err != nil {
		return nil, err
	}
	
	// Validate the parsed items
	return s.ValidateDA2062(ctx, parsed)
}

// SuggestCompletions gets AI suggestions for incomplete DA 2062 fields
func (s *AzureOpenAIDA2062Service) SuggestCompletions(ctx context.Context, partialForm *domain.DA2062Data) (*Suggestions, error) {
	// Convert domain model to our format
	formData := &ParsedDA2062{
		FormNumber: partialForm.FormNumber,
		UnitName:   partialForm.UnitName,
		DODAAC:     partialForm.DODAAC,
	}
	
	// Build prompt for suggestions
	prompt := fmt.Sprintf("Suggest completions for this partial DA Form 2062:\n%+v", partialForm)
	
	requestBody := map[string]interface{}{
		"messages": []map[string]string{
			{"role": "system", "content": "You are a military supply expert. Suggest completions for missing DA Form 2062 fields."},
			{"role": "user", "content": prompt},
		},
		"temperature": 0.3,
		"max_tokens": 1000,
	}
	
	response, err := s.callAPI(ctx, requestBody)
	if err != nil {
		return nil, err
	}
	
	var suggestions Suggestions
	if err := json.Unmarshal(response, &suggestions); err != nil {
		return nil, err
	}
	
	return &suggestions, nil
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
		"PVS-14": "NIGHT VISION GOGGLE, AN/PVS-14",
		"M240": "MACHINE GUN, 7.62MM, M240B",
	}
	
	// Check if description contains abbreviations
	for abbr, full := range abbreviations {
		if item.Description == abbr {
			item.Description = full
		}
	}
}

// NewOpenAIDA2062Service creates OpenAI service (placeholder for interface completeness)
func NewOpenAIDA2062Service(cfg Config) (*AzureOpenAIDA2062Service, error) {
	// For now, just use the Azure implementation
	// In future, could have different implementation for direct OpenAI
	return NewAzureOpenAIDA2062Service(cfg)
}