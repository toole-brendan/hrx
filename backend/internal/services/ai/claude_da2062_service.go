package ai

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"
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
	_, err := io.ReadAll(r)
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

	// TODO: Implement actual Claude API call here
	// The Anthropic SDK v1.4.0 has a different API structure than expected
	// You'll need to:
	// 1. Base64 encode the image data
	// 2. Create the proper message structure for the SDK
	// 3. Parse the response JSON
	
	// Example structure (needs to be adapted to SDK v1.4.0):
	/*
	import (
		"encoding/base64"
		"encoding/json"
		"github.com/anthropics/anthropic-sdk-go"
		"github.com/anthropics/anthropic-sdk-go/option"
	)
	
	client := anthropic.NewClient(option.WithAPIKey(apiKey))
	
	// Base64 encode the data
	b64 := base64.StdEncoding.EncodeToString(data)
	
	// Create message with image and prompt
	// Parse response and extract JSON
	// Return parsed items
	*/
	
	log.Printf("Claude API integration pending - returning mock data")
	return getMockData()
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
		return "application/pdf"
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