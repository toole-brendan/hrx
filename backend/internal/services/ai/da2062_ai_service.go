package ai

import (
	"context"
	"fmt"
	"time"
)

// ParsedDA2062 represents the AI-parsed DA 2062 form data
type ParsedDA2062 struct {
	FormNumber  string             `json:"formNumber"`
	UnitName    string             `json:"unitName"`
	DODAAC      string             `json:"dodaac"`
	FromUnit    string             `json:"fromUnit"`
	ToUnit      string             `json:"toUnit"`
	Date        string             `json:"date"`
	Items       []ParsedDA2062Item `json:"items"`
	Confidence  float64            `json:"confidence"`
	Metadata    DA2062Metadata     `json:"metadata"`
	Suggestions []Suggestion       `json:"suggestions"`
}

// ParsedDA2062Item represents a single item from DA 2062
type ParsedDA2062Item struct {
	LineNumber   int          `json:"lineNumber"`
	NSN          string       `json:"nsn"`
	LIN          string       `json:"lin,omitempty"`
	Description  string       `json:"description"`
	Quantity     int          `json:"quantity"`
	UnitOfIssue  string       `json:"unitOfIssue"`
	SerialNumber string       `json:"serialNumber,omitempty"`
	Condition    string       `json:"condition"`
	Confidence   float64      `json:"confidence"`
	AIGrouped    bool         `json:"aiGrouped"` // True if AI grouped multi-line item
	Suggestions  []Suggestion `json:"suggestions"`
}

// DA2062Metadata contains processing metadata
type DA2062Metadata struct {
	ProcessedAt      time.Time `json:"processedAt"`
	OCRConfidence    float64   `json:"ocrConfidence"`
	AIConfidence     float64   `json:"aiConfidence"`
	ItemCount        int       `json:"itemCount"`
	GroupedItems     int       `json:"groupedItems"` // Items that spanned multiple lines
	HandwrittenItems int       `json:"handwrittenItems"`
}

// Suggestion represents an AI-generated suggestion
type Suggestion struct {
	Field      string  `json:"field"`
	Type       string  `json:"type"` // correction, completion, validation
	Value      string  `json:"value"`
	Confidence float64 `json:"confidence"`
	Reasoning  string  `json:"reasoning"`
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

	// ExtractAndValidateItems extracts military equipment entities
	ExtractAndValidateItems(ctx context.Context, text string) (*ValidationResult, error)

	// SuggestCompletions gets AI suggestions for incomplete DA 2062 fields
	SuggestCompletions(ctx context.Context, partialForm *ParsedDA2062) (*[]Suggestion, error)
}

// GeneratedDA2062 represents an AI-generated DA 2062 form
type GeneratedDA2062 struct {
	Form        *ParsedDA2062 `json:"form"`
	Suggestions []Suggestion  `json:"suggestions"`
	Confidence  float64       `json:"confidence"`
}

// ValidationResult represents the validation outcome
type ValidationResult struct {
	IsValid     bool               `json:"isValid"`
	Items       []ParsedDA2062Item `json:"items"`
	Issues      []ValidationIssue  `json:"issues"`
	Suggestions []Suggestion       `json:"suggestions"`
}

// ValidationIssue represents a validation problem
type ValidationIssue struct {
	Field      string `json:"field"`
	ItemIndex  int    `json:"itemIndex"`
	Issue      string `json:"issue"`
	Severity   string `json:"severity"` // error, warning, info
	Suggestion string `json:"suggestion"`
}

// Suggestions represents AI-generated suggestions for form and item improvements
type Suggestions struct {
	FormSuggestions []Suggestion         `json:"formSuggestions"`
	ItemSuggestions map[int][]Suggestion `json:"itemSuggestions"`
}

// Config holds AI service configuration including provider settings and API parameters
type Config struct {
	Provider       string        `yaml:"provider"`
	Endpoint       string        `yaml:"endpoint"`
	APIKey         string        `yaml:"api_key"`
	Model          string        `yaml:"model"`
	MaxTokens      int           `yaml:"max_tokens"`
	Temperature    float64       `yaml:"temperature"`
	TimeoutSeconds int           `yaml:"timeout_seconds"`
	RetryAttempts  int           `yaml:"retry_attempts"`
	CacheEnabled   bool          `yaml:"cache_enabled"`
	CacheTTL       time.Duration `yaml:"cache_ttl"`
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
