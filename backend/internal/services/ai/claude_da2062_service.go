package ai

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"

	"github.com/anthropics/anthropic-sdk-go"
	"github.com/anthropics/anthropic-sdk-go/option"
)

// ParsedItem represents a single item extracted from DA 2062
type ParsedItem struct {
	NSN          string  `json:"nsn"`
	Name         string  `json:"name"`
	SerialNumber string  `json:"serialNumber"`
	Quantity     int     `json:"quantity"`
	OwnerID      string  `json:"ownerId"`
	AssignedToID string  `json:"assignedToId"`
	Confidence   float64 `json:"confidence"`
}

// ParseMeta contains form-level metadata
type ParseMeta struct {
	From       string `json:"from"`
	To         string `json:"to"`
	Date       string `json:"date"`
	FormNumber string `json:"formNumber"`
}

// DA2062Response represents the expected JSON response from Claude
type DA2062Response struct {
	Meta  ParseMeta    `json:"meta"`
	Items []ParsedItem `json:"items"`
}

// ParseDA2062 streams the PDF/PNG/JPG file to Claude and returns items
func ParseDA2062(r io.Reader, contentType string) ([]ParsedItem, ParseMeta, error) {
	// Read file data
	data, err := io.ReadAll(r)
	if err != nil {
		return nil, ParseMeta{}, fmt.Errorf("failed to read file: %w", err)
	}

	// Get API key from environment
	apiKey := os.Getenv("ANTHROPIC_API_KEY")
	if apiKey == "" {
		// Return mock data if no API key
		log.Printf("ANTHROPIC_API_KEY not set - returning mock data")
		return getMockData()
	}

	// Initialize Claude client
	client := anthropic.NewClient(option.WithAPIKey(apiKey))
	
	// Check if content is PDF - Claude doesn't support PDF directly
	if strings.Contains(contentType, "pdf") {
		log.Printf("PDF upload detected - Claude API doesn't support PDF directly, would need PDF to image conversion")
		return nil, ParseMeta{}, fmt.Errorf("PDF files need to be converted to images first")
	}
	
	// Base64 encode the image data
	b64Image := base64.StdEncoding.EncodeToString(data)
	
	// Determine media type
	mediaType := determineMediaType(contentType)
	
	log.Printf("Processing DA 2062 with Claude API - content type: %s, media type: %s, data size: %d bytes", contentType, mediaType, len(data))
	
	// Create the prompt for Claude
	prompt := `You are analyzing a DA Form 2062 (Hand Receipt/Annex Number). Extract all items from the form and return them as JSON.

For each item, extract:
- NSN (National Stock Number) - format: XXXX-XX-XXX-XXXX
- Name/Description of the item
- Serial number(s) if present
- Quantity
- Any other relevant details

Also extract form metadata:
- From (issuing unit/person)
- To (receiving unit/person)
- Date
- Form number

Return the data in this exact JSON format:
{
  "meta": {
    "from": "string",
    "to": "string",
    "date": "YYYY-MM-DD",
    "formNumber": "string"
  },
  "items": [
    {
      "nsn": "string or empty",
      "name": "string",
      "serialNumber": "string or empty",
      "quantity": number,
      "ownerId": "",
      "assignedToId": "",
      "confidence": 0.0-1.0
    }
  ]
}

Be thorough and extract ALL items listed on the form. If you cannot read a field clearly, use an empty string but still include the item.`

	// Create the message request
	ctx := context.Background()
	
	// Create the image block based on media type
	var imageBlock anthropic.ContentBlockParamUnion
	switch mediaType {
	case "image/jpeg":
		imageBlock = anthropic.NewImageBlockBase64(string(anthropic.Base64ImageSourceMediaTypeImageJPEG), b64Image)
	case "image/png":
		imageBlock = anthropic.NewImageBlockBase64(string(anthropic.Base64ImageSourceMediaTypeImagePNG), b64Image)
	default:
		imageBlock = anthropic.NewImageBlockBase64(string(anthropic.Base64ImageSourceMediaTypeImageJPEG), b64Image)
	}
	
	messageReq := anthropic.MessageNewParams{
		Model:     anthropic.ModelClaude3_5Sonnet20241022,
		MaxTokens: 4096,
		Messages: []anthropic.MessageParam{
			anthropic.NewUserMessage(
				imageBlock,
				anthropic.NewTextBlock(prompt),
			),
		},
	}
	
	// Call Claude API
	response, err := client.Messages.New(ctx, messageReq)
	if err != nil {
		log.Printf("Claude API error: %v", err)
		return nil, ParseMeta{}, fmt.Errorf("Claude API error: %w", err)
	}
	
	// Extract the text response
	if len(response.Content) == 0 {
		return nil, ParseMeta{}, fmt.Errorf("empty response from Claude")
	}
	
	// Get the text content from the response
	var responseText string
	for _, content := range response.Content {
		// Check if this is a text block
		if content.Type == "text" && content.Text != "" {
			responseText = content.Text
			break
		}
	}
	
	if responseText == "" {
		return nil, ParseMeta{}, fmt.Errorf("no text content in Claude response")
	}
	
	// Extract JSON from the response
	jsonStr := extractJSON(responseText)
	
	// Parse the JSON response
	var da2062Response DA2062Response
	if err := json.Unmarshal([]byte(jsonStr), &da2062Response); err != nil {
		log.Printf("Failed to parse Claude response as JSON: %v", err)
		log.Printf("Raw response: %s", responseText)
		return nil, ParseMeta{}, fmt.Errorf("failed to parse response: %w", err)
	}
	
	// Set confidence scores based on Claude's extraction
	for i := range da2062Response.Items {
		if da2062Response.Items[i].Confidence == 0 {
			// Default confidence if not set
			da2062Response.Items[i].Confidence = 0.85
		}
	}
	
	log.Printf("Successfully parsed %d items from DA 2062", len(da2062Response.Items))
	return da2062Response.Items, da2062Response.Meta, nil
}

// getMockData returns mock data for testing
func getMockData() ([]ParsedItem, ParseMeta, error) {
	mockItems := []ParsedItem{
		{
			NSN:          "1234-56-789-0123",
			Name:         "SAMPLE ITEM - Configure ANTHROPIC_API_KEY for real data",
			SerialNumber: "MOCK-12345",
			Quantity:     1,
			OwnerID:      "",
			AssignedToID: "",
			Confidence:   0.95,
		},
	}

	mockMeta := ParseMeta{
		From:       "Mock Unit",
		To:         "Mock Recipient",
		Date:       time.Now().Format("2006-01-02"),
		FormNumber: "MOCK-2062-001",
	}

	return mockItems, mockMeta, nil
}

// ParseDA2062WithRetry adds retry logic with exponential backoff
func ParseDA2062WithRetry(r io.Reader, contentType string, maxRetries int) ([]ParsedItem, ParseMeta, error) {
	var lastErr error
	
	// Read data once to avoid re-reading on retries
	data, err := io.ReadAll(r)
	if err != nil {
		return nil, ParseMeta{}, fmt.Errorf("failed to read file: %w", err)
	}

	for i := 0; i < maxRetries; i++ {
		// Create new reader for each attempt
		items, meta, err := ParseDA2062(bytes.NewReader(data), contentType)
		if err == nil {
			return items, meta, nil
		}
		
		lastErr = err
		log.Printf("Claude API attempt %d failed: %v", i+1, err)
		
		// Don't retry on certain errors
		if strings.Contains(err.Error(), "ANTHROPIC_API_KEY") ||
			strings.Contains(err.Error(), "failed to read file") {
			return nil, ParseMeta{}, err
		}
		
		// Exponential backoff
		if i < maxRetries-1 {
			sleepDuration := time.Second * time.Duration(1<<uint(i)) // 1s, 2s, 4s...
			log.Printf("Retrying in %v...", sleepDuration)
			time.Sleep(sleepDuration)
		}
	}
	
	return nil, ParseMeta{}, fmt.Errorf("failed after %d retries: %w", maxRetries, lastErr)
}

// determineMediaType converts content type to Claude's expected format
func determineMediaType(contentType string) string {
	switch {
	case strings.Contains(contentType, "jpeg") || strings.Contains(contentType, "jpg"):
		return "image/jpeg"
	case strings.Contains(contentType, "png"):
		return "image/png"
	case strings.Contains(contentType, "pdf"):
		// Claude doesn't support PDF directly, we'll need to handle this differently
		return "image/jpeg"
	default:
		// Default to JPEG if unknown
		return "image/jpeg"
	}
}

// extractJSON attempts to extract JSON from a text that might contain other text
func extractJSON(text string) string {
	// Find the first { and last }
	start := strings.Index(text, "{")
	end := strings.LastIndex(text, "}")
	
	if start != -1 && end != -1 && end > start {
		return text[start : end+1]
	}
	
	return text
}

// ValidateParsedItems validates the extracted items
func ValidateParsedItems(items []ParsedItem) error {
	if len(items) == 0 {
		return fmt.Errorf("no items extracted")
	}

	for i, item := range items {
		// Check for required fields
		if item.Name == "" {
			return fmt.Errorf("item %d missing name/description", i+1)
		}
		
		// Validate quantity
		if item.Quantity <= 0 {
			return fmt.Errorf("item %d has invalid quantity: %d", i+1, item.Quantity)
		}
		
		// Validate NSN format if provided
		if item.NSN != "" && !isValidNSN(item.NSN) {
			log.Printf("Warning: item %d has invalid NSN format: %s", i+1, item.NSN)
		}
	}
	
	return nil
}

// isValidNSN checks if the NSN follows standard format
func isValidNSN(nsn string) bool {
	// Remove any spaces or dashes
	cleaned := strings.ReplaceAll(nsn, "-", "")
	cleaned = strings.ReplaceAll(cleaned, " ", "")
	
	// NSN should be 13 digits
	if len(cleaned) != 13 {
		return false
	}
	
	// Check if all characters are digits
	for _, c := range cleaned {
		if c < '0' || c > '9' {
			return false
		}
	}
	
	return true
}