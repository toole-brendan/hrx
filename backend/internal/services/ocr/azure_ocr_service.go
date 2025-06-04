package ocr

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// AzureOCRService handles Azure Computer Vision OCR operations
type AzureOCRService struct {
	endpoint string
	apiKey   string
	client   *http.Client
}

// NewAzureOCRService creates a new Azure OCR service instance
func NewAzureOCRService(endpoint, apiKey string) *AzureOCRService {
	return &AzureOCRService{
		endpoint: endpoint,
		apiKey:   apiKey,
		client: &http.Client{
			Timeout: 60 * time.Second,
		},
	}
}

// OCRResult represents the structured result from Azure OCR
type OCRResult struct {
	Status        string         `json:"status"`
	AnalyzeResult *AnalyzeResult `json:"analyzeResult,omitempty"`
	CreatedAt     time.Time      `json:"createdDateTime,omitempty"`
	LastUpdated   time.Time      `json:"lastUpdatedDateTime,omitempty"`
}

type AnalyzeResult struct {
	Version     string       `json:"version"`
	ReadResults []ReadResult `json:"readResults"`
}

type ReadResult struct {
	Page   int     `json:"page"`
	Angle  float64 `json:"angle"`
	Width  float64 `json:"width"`
	Height float64 `json:"height"`
	Unit   string  `json:"unit"`
	Lines  []Line  `json:"lines"`
}

type Line struct {
	BoundingBox []float64 `json:"boundingBox"`
	Text        string    `json:"text"`
	Words       []Word    `json:"words"`
}

type Word struct {
	BoundingBox []float64 `json:"boundingBox"`
	Text        string    `json:"text"`
	Confidence  float64   `json:"confidence"`
}

// DA2062ParsedForm represents the structured DA2062 form data
type DA2062ParsedForm struct {
	UnitName   string             `json:"unitName"`
	DODAAC     string             `json:"dodaac"`
	FormNumber string             `json:"formNumber"`
	Items      []DA2062ParsedItem `json:"items"`
	Confidence float64            `json:"confidence"`
	Metadata   DA2062FormMetadata `json:"metadata"`
}

type DA2062ParsedItem struct {
	LineNumber          int      `json:"lineNumber"`
	NSN                 string   `json:"nsn"`
	ItemDescription     string   `json:"itemDescription"`
	Quantity            int      `json:"quantity"`
	UnitOfIssue         string   `json:"unitOfIssue"`
	SerialNumber        string   `json:"serialNumber"`
	Condition           string   `json:"condition"`
	Confidence          float64  `json:"confidence"`
	HasExplicitSerial   bool     `json:"hasExplicitSerial"`
	VerificationReasons []string `json:"verificationReasons"`
}

type DA2062FormMetadata struct {
	TotalLines           int       `json:"totalLines"`
	ProcessedAt          time.Time `json:"processedAt"`
	SourceImageURL       string    `json:"sourceImageUrl"`
	OCRConfidence        float64   `json:"ocrConfidence"`
	RequiresVerification bool      `json:"requiresVerification"`
}

// ProcessImageFromURL performs OCR on an image via URL (Azure Blob)
func (s *AzureOCRService) ProcessImageFromURL(ctx context.Context, imageURL string) (*DA2062ParsedForm, error) {
	// Step 1: Start OCR operation
	operationURL, err := s.startOCROperation(ctx, imageURL)
	if err != nil {
		return nil, fmt.Errorf("failed to start OCR operation: %w", err)
	}

	// Step 2: Poll for results
	result, err := s.pollForResult(ctx, operationURL)
	if err != nil {
		return nil, fmt.Errorf("failed to get OCR result: %w", err)
	}

	// Step 3: Parse DA2062 structure
	parsedForm, err := s.parseDA2062Structure(result, imageURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse DA2062 structure: %w", err)
	}

	return parsedForm, nil
}

// ProcessImageFromBytes performs OCR on raw image bytes
func (s *AzureOCRService) ProcessImageFromBytes(ctx context.Context, imageData []byte, contentType string) (*DA2062ParsedForm, error) {
	// Step 1: Start OCR operation with bytes
	operationURL, err := s.startOCROperationWithBytes(ctx, imageData, contentType)
	if err != nil {
		return nil, fmt.Errorf("failed to start OCR operation: %w", err)
	}

	// Step 2: Poll for results
	result, err := s.pollForResult(ctx, operationURL)
	if err != nil {
		return nil, fmt.Errorf("failed to get OCR result: %w", err)
	}

	// Step 3: Parse DA2062 structure
	parsedForm, err := s.parseDA2062Structure(result, "direct_upload")
	if err != nil {
		return nil, fmt.Errorf("failed to parse DA2062 structure: %w", err)
	}

	return parsedForm, nil
}

// startOCROperation initiates the async OCR operation using image URL
func (s *AzureOCRService) startOCROperation(ctx context.Context, imageURL string) (string, error) {
	url := fmt.Sprintf("%s/vision/v3.2/read/analyze", strings.TrimSuffix(s.endpoint, "/"))

	payload := map[string]string{
		"url": imageURL,
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return "", err
	}

	req.Header.Set("Ocp-Apim-Subscription-Key", s.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("OCR request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Get operation location from headers
	operationURL := resp.Header.Get("Operation-Location")
	if operationURL == "" {
		return "", fmt.Errorf("no operation location header received")
	}

	return operationURL, nil
}

// startOCROperationWithBytes initiates the async OCR operation using raw bytes
func (s *AzureOCRService) startOCROperationWithBytes(ctx context.Context, imageData []byte, contentType string) (string, error) {
	url := fmt.Sprintf("%s/vision/v3.2/read/analyze", strings.TrimSuffix(s.endpoint, "/"))

	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(imageData))
	if err != nil {
		return "", err
	}

	req.Header.Set("Ocp-Apim-Subscription-Key", s.apiKey)
	req.Header.Set("Content-Type", contentType)

	resp, err := s.client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusAccepted {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("OCR request failed with status %d: %s", resp.StatusCode, string(body))
	}

	// Get operation location from headers
	operationURL := resp.Header.Get("Operation-Location")
	if operationURL == "" {
		return "", fmt.Errorf("no operation location header received")
	}

	return operationURL, nil
}

// pollForResult polls the operation URL until completion
func (s *AzureOCRService) pollForResult(ctx context.Context, operationURL string) (*OCRResult, error) {
	maxAttempts := 30
	pollInterval := 2 * time.Second

	for i := 0; i < maxAttempts; i++ {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		default:
		}

		req, err := http.NewRequestWithContext(ctx, "GET", operationURL, nil)
		if err != nil {
			return nil, err
		}

		req.Header.Set("Ocp-Apim-Subscription-Key", s.apiKey)

		resp, err := s.client.Do(req)
		if err != nil {
			return nil, err
		}

		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()

		if err != nil {
			return nil, err
		}

		if resp.StatusCode != http.StatusOK {
			return nil, fmt.Errorf("polling failed with status %d: %s", resp.StatusCode, string(body))
		}

		var result OCRResult
		if err := json.Unmarshal(body, &result); err != nil {
			return nil, err
		}

		switch result.Status {
		case "succeeded":
			return &result, nil
		case "failed":
			return nil, fmt.Errorf("OCR operation failed")
		case "running", "notStarted":
			// Continue polling
			time.Sleep(pollInterval)
			continue
		default:
			return nil, fmt.Errorf("unknown OCR status: %s", result.Status)
		}
	}

	return nil, fmt.Errorf("OCR operation timed out after %d attempts", maxAttempts)
}

// parseDA2062Structure converts OCR results into structured DA2062 data
func (s *AzureOCRService) parseDA2062Structure(result *OCRResult, sourceURL string) (*DA2062ParsedForm, error) {
	if result.AnalyzeResult == nil || len(result.AnalyzeResult.ReadResults) == 0 {
		return nil, fmt.Errorf("no OCR results found")
	}

	// Collect all text lines from all pages
	var allLines []string
	var totalConfidence float64
	var confidenceCount int

	for _, readResult := range result.AnalyzeResult.ReadResults {
		for _, line := range readResult.Lines {
			allLines = append(allLines, line.Text)

			// Calculate average confidence for the line
			lineConfidence := 0.0
			if len(line.Words) > 0 {
				for _, word := range line.Words {
					lineConfidence += word.Confidence
				}
				lineConfidence /= float64(len(line.Words))
				totalConfidence += lineConfidence
				confidenceCount++
			}
		}
	}

	averageConfidence := 0.0
	if confidenceCount > 0 {
		averageConfidence = totalConfidence / float64(confidenceCount)
	}

	// Parse header information
	unitName := s.extractHeaderField(allLines, []string{"UNIT:", "ORGANIZATION:"})
	dodaac := s.extractHeaderField(allLines, []string{"DODAAC:", "UIC:"})
	formNumber := s.extractFormNumber(allLines)

	// Parse line items
	items, err := s.parseLineItems(allLines)
	if err != nil {
		return nil, fmt.Errorf("failed to parse line items: %w", err)
	}

	// Determine if verification is required
	requiresVerification := averageConfidence < 0.7 || s.hasLowConfidenceItems(items)

	form := &DA2062ParsedForm{
		UnitName:   unitName,
		DODAAC:     dodaac,
		FormNumber: formNumber,
		Items:      items,
		Confidence: averageConfidence,
		Metadata: DA2062FormMetadata{
			TotalLines:           len(allLines),
			ProcessedAt:          time.Now(),
			SourceImageURL:       sourceURL,
			OCRConfidence:        averageConfidence,
			RequiresVerification: requiresVerification,
		},
	}

	return form, nil
}

// extractHeaderField extracts header fields like unit name, DODAAC
func (s *AzureOCRService) extractHeaderField(lines []string, keywords []string) string {
	for _, line := range lines {
		upperLine := strings.ToUpper(line)
		for _, keyword := range keywords {
			if strings.Contains(upperLine, keyword) {
				// Extract text after the keyword
				parts := strings.Split(line, ":")
				if len(parts) > 1 {
					return strings.TrimSpace(parts[1])
				}
			}
		}
	}
	return ""
}

// extractFormNumber extracts the DA form number
func (s *AzureOCRService) extractFormNumber(lines []string) string {
	pattern := regexp.MustCompile(`(?i)da\s*form\s*2062[\w\-]*|2062[\w\-]*`)

	for _, line := range lines {
		if matches := pattern.FindStringSubmatch(line); len(matches) > 0 {
			return strings.TrimSpace(matches[0])
		}
	}

	// Generate a default form number with timestamp
	return fmt.Sprintf("DA2062-OCR-%d", time.Now().Unix())
}

// parseLineItems parses individual property line items with improved multi-line grouping
func (s *AzureOCRService) parseLineItems(lines []string) ([]DA2062ParsedItem, error) {
	var items []DA2062ParsedItem
	var currentItem *DA2062ParsedItem
	lineNumber := 1

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || s.isHeaderLine(line) {
			continue
		}

		// Check if this line starts a new item
		if s.isNewItemLine(line) {
			// Save previous item if exists
			if currentItem != nil {
				items = append(items, *currentItem)
				lineNumber++
			}

			// Start new item
			currentItem = s.parseSimpleItem(line, lineNumber)
		} else if currentItem != nil {
			// This is a continuation line - check for serial number or additional info
			if currentItem.SerialNumber == "" {
				// Try to extract serial number from continuation line
				serialPatterns := []string{
					`(?i)s[\./\s]*n[\./\s]*:?\s*([A-Z0-9]{6,20})`,
					`(?i)serial[\s:]*([A-Z0-9]{6,20})`,
					`^([A-Z0-9]{6,20})$`, // Line with just alphanumeric could be serial
				}

				for _, pattern := range serialPatterns {
					re := regexp.MustCompile(pattern)
					if matches := re.FindStringSubmatch(line); len(matches) > 1 {
						currentItem.SerialNumber = strings.ToUpper(matches[1])
						currentItem.HasExplicitSerial = true
						break
					}
				}
			}

			// If not a serial number, append to description
			if currentItem.SerialNumber == "" || !strings.Contains(strings.ToUpper(line), currentItem.SerialNumber) {
				currentItem.ItemDescription = strings.TrimSpace(currentItem.ItemDescription + " " + line)
			}
		}
	}

	// Don't forget the last item
	if currentItem != nil {
		items = append(items, *currentItem)
	}

	return items, nil
}

// isNewItemLine checks if a line starts a new item (has NSN or starts with a number)
func (s *AzureOCRService) isNewItemLine(line string) bool {
	// Check for NSN pattern
	nsnPattern := regexp.MustCompile(`\b(\d{4}[\-\s]?\d{2}[\-\s]?\d{3}[\-\s]?\d{4})\b`)
	if nsnPattern.MatchString(line) {
		return true
	}

	// Check if line starts with a line number (1., 2., etc.)
	lineNumberPattern := regexp.MustCompile(`^\d+[\.\)]`)
	if lineNumberPattern.MatchString(line) {
		return true
	}

	// Check if line has typical item structure (quantity at beginning)
	quantityPattern := regexp.MustCompile(`^\d{1,3}\s+[A-Z]`)
	if quantityPattern.MatchString(strings.ToUpper(line)) {
		return true
	}

	return false
}

// isHeaderLine checks if a line is a form header
func (s *AzureOCRService) isHeaderLine(line string) bool {
	upperLine := strings.ToUpper(line)
	headerKeywords := []string{
		"HAND RECEIPT", "DA FORM", "STOCK NO", "ITEM DESCRIPTION",
		"UNIT:", "ORGANIZATION:", "DODAAC:", "UIC:", "SIGNATURE",
		"FROM:", "TO:", "QTY", "U/I", "PAGE",
	}

	for _, keyword := range headerKeywords {
		if strings.Contains(upperLine, keyword) {
			return true
		}
	}
	return false
}

// parseSimpleItem parses a single line into an item
func (s *AzureOCRService) parseSimpleItem(line string, lineNumber int) *DA2062ParsedItem {
	item := &DA2062ParsedItem{
		LineNumber:  lineNumber,
		Quantity:    1,
		UnitOfIssue: "EA",
		Condition:   "A",
		Confidence:  0.8,
	}

	// Extract NSN using pattern
	nsnPattern := regexp.MustCompile(`\b(\d{4}[\-\s]?\d{2}[\-\s]?\d{3}[\-\s]?\d{4})\b`)
	if matches := nsnPattern.FindStringSubmatch(line); len(matches) > 1 {
		nsn := regexp.MustCompile(`[\s\-]`).ReplaceAllString(matches[1], "")
		if len(nsn) == 13 {
			item.NSN = fmt.Sprintf("%s-%s-%s-%s", nsn[0:4], nsn[4:6], nsn[6:9], nsn[9:13])
		}
	}

	// Extract serial number
	serialPatterns := []string{
		`(?i)s[\./\s]*n[\./\s]*:?\s*([A-Z0-9]{6,20})`,
		`(?i)serial[\s:]*([A-Z0-9]{6,20})`,
	}

	for _, pattern := range serialPatterns {
		re := regexp.MustCompile(pattern)
		if matches := re.FindStringSubmatch(line); len(matches) > 1 {
			item.SerialNumber = strings.ToUpper(matches[1])
			item.HasExplicitSerial = true
			break
		}
	}

	// Extract quantity
	qtyPattern := regexp.MustCompile(`\b(\d{1,3})\b`)
	if matches := qtyPattern.FindStringSubmatch(line); len(matches) > 1 {
		if qty, err := strconv.Atoi(matches[1]); err == nil && qty > 0 && qty <= 999 {
			item.Quantity = qty
		}
	}

	// Extract condition code (A, B, C, etc.)
	conditionPattern := regexp.MustCompile(`\b([A-F])\b`)
	conditionMatches := conditionPattern.FindAllStringSubmatch(line, -1)
	if len(conditionMatches) > 0 {
		// Take the last single letter match as condition (often appears after quantity)
		item.Condition = conditionMatches[len(conditionMatches)-1][1]
	}

	// The rest becomes description
	description := line
	if item.NSN != "" {
		nsnPattern := regexp.MustCompile(`\d{4}[\-\s]?\d{2}[\-\s]?\d{3}[\-\s]?\d{4}`)
		description = nsnPattern.ReplaceAllString(description, "")
	}
	if item.SerialNumber != "" {
		for _, pattern := range serialPatterns {
			re := regexp.MustCompile(pattern)
			description = re.ReplaceAllString(description, "")
		}
	}

	description = regexp.MustCompile(`\s+`).ReplaceAllString(description, " ")
	item.ItemDescription = strings.TrimSpace(description)

	// Add verification reasons
	if item.NSN == "" {
		item.VerificationReasons = append(item.VerificationReasons, "missing_nsn")
	}
	if item.ItemDescription == "" {
		item.VerificationReasons = append(item.VerificationReasons, "missing_description")
	}

	// Only return if we have at least a description
	if item.ItemDescription != "" || item.NSN != "" {
		return item
	}
	return nil
}

// hasLowConfidenceItems checks if any items have low confidence
func (s *AzureOCRService) hasLowConfidenceItems(items []DA2062ParsedItem) bool {
	for _, item := range items {
		if item.Confidence < 0.7 || len(item.VerificationReasons) > 0 {
			return true
		}
	}
	return false
}
