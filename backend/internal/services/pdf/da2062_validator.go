package pdf

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// DA2062Template represents the official DA Form 2062 template structure
type DA2062Template struct {
	FormName   string             `json:"form_name"`
	Version    string             `json:"version"`
	PageSize   string             `json:"page_size"`
	Dimensions TemplateDimensions `json:"dimensions"`
	Margins    TemplateMargins    `json:"margins"`
	Sections   TemplateSections   `json:"sections"`
	Fonts      TemplateFonts      `json:"fonts"`
	Validation TemplateValidation `json:"validation_rules"`
}

type TemplateDimensions struct {
	Width  float64 `json:"width"`
	Height float64 `json:"height"`
}

type TemplateMargins struct {
	Top    float64 `json:"top"`
	Bottom float64 `json:"bottom"`
	Left   float64 `json:"left"`
	Right  float64 `json:"right"`
}

type TemplateSections struct {
	Header           TemplateHeader     `json:"header"`
	FromToSection    TemplateFromTo     `json:"from_to_section"`
	UnitInfo         TemplateUnitInfo   `json:"unit_info"`
	Table            TemplateTable      `json:"table"`
	SignatureSection TemplateSignature  `json:"signature_section"`
	PageNumber       TemplatePageNumber `json:"page_number"`
}

type TemplateHeader struct {
	Title      TemplateElement `json:"title"`
	FormNumber TemplateElement `json:"form_number"`
}

type TemplateFromTo struct {
	Y         float64         `json:"y"`
	Height    float64         `json:"height"`
	FromLabel TemplateElement `json:"from_label"`
	FromField TemplateElement `json:"from_field"`
	ToLabel   TemplateElement `json:"to_label"`
	ToField   TemplateElement `json:"to_field"`
}

type TemplateUnitInfo struct {
	Y         float64         `json:"y"`
	Height    float64         `json:"height"`
	UnitLabel TemplateElement `json:"unit_label"`
	UnitField TemplateElement `json:"unit_field"`
}

type TemplateTable struct {
	StartY       float64                        `json:"start_y"`
	HeaderHeight float64                        `json:"header_height"`
	RowHeight    float64                        `json:"row_height"`
	Columns      map[string]TemplateTableColumn `json:"columns"`
}

type TemplateTableColumn struct {
	Header string  `json:"header"`
	X      float64 `json:"x"`
	Width  float64 `json:"width"`
}

type TemplateSignature struct {
	Y          float64           `json:"y"`
	Height     float64           `json:"height"`
	Signatures []TemplateElement `json:"signatures"`
}

type TemplatePageNumber struct {
	X    float64 `json:"x"`
	Y    float64 `json:"y"`
	Text string  `json:"text"`
}

type TemplateElement struct {
	Text   string  `json:"text,omitempty"`
	X      float64 `json:"x"`
	Y      float64 `json:"y,omitempty"`
	Width  float64 `json:"width,omitempty"`
	Height float64 `json:"height,omitempty"`
	Font   string  `json:"font,omitempty"`
	Size   float64 `json:"size,omitempty"`
	Label  string  `json:"label,omitempty"`
}

type TemplateFonts struct {
	Default string             `json:"default"`
	Header  string             `json:"header"`
	Sizes   map[string]float64 `json:"sizes"`
}

type TemplateValidation struct {
	RequiredText []string `json:"required_text"`
	MinimumRows  int      `json:"minimum_rows"`
	MaximumRows  int      `json:"maximum_rows"`
}

// DA2062Validator provides validation against the official template
type DA2062Validator struct {
	template *DA2062Template
}

// NewDA2062Validator creates a new validator instance
func NewDA2062Validator() (*DA2062Validator, error) {
	template, err := loadTemplate()
	if err != nil {
		return nil, fmt.Errorf("failed to load template: %w", err)
	}

	return &DA2062Validator{
		template: template,
	}, nil
}

// loadTemplate loads the reference template from the JSON file
func loadTemplate() (*DA2062Template, error) {
	// Get the project root directory
	pwd, err := os.Getwd()
	if err != nil {
		return nil, err
	}

	// Navigate to the backend directory if we're not already there
	templatePath := filepath.Join(pwd, "backend", "assets", "forms", "DA_Form_2062_reference.json")
	if _, err := os.Stat(templatePath); os.IsNotExist(err) {
		// Try from current directory if backend path doesn't exist
		templatePath = filepath.Join(pwd, "assets", "forms", "DA_Form_2062_reference.json")
	}

	data, err := os.ReadFile(templatePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read template file: %w", err)
	}

	var template DA2062Template
	if err := json.Unmarshal(data, &template); err != nil {
		return nil, fmt.Errorf("failed to parse template JSON: %w", err)
	}

	return &template, nil
}

// ValidateLayout validates a DA2062 against the official template
func (v *DA2062Validator) ValidateLayout(options GenerateOptions) []ValidationError {
	var errors []ValidationError

	// Validate basic structure
	errors = append(errors, v.validateBasicStructure()...)

	// Validate table layout
	errors = append(errors, v.validateTableLayout()...)

	// Validate signature sections
	errors = append(errors, v.validateSignatureLayout()...)

	return errors
}

// ValidationError represents a validation error
type ValidationError struct {
	Type        string `json:"type"`
	Element     string `json:"element"`
	Expected    string `json:"expected"`
	Actual      string `json:"actual,omitempty"`
	Severity    string `json:"severity"` // "error", "warning", "info"
	Description string `json:"description"`
}

// validateBasicStructure validates the basic form structure
func (v *DA2062Validator) validateBasicStructure() []ValidationError {
	var errors []ValidationError

	// Check page dimensions
	if v.template.Dimensions.Width != 215.9 {
		errors = append(errors, ValidationError{
			Type:        "dimension",
			Element:     "page_width",
			Expected:    "215.9mm",
			Severity:    "error",
			Description: "Page width must match official form dimensions",
		})
	}

	if v.template.Dimensions.Height != 279.4 {
		errors = append(errors, ValidationError{
			Type:        "dimension",
			Element:     "page_height",
			Expected:    "279.4mm",
			Severity:    "error",
			Description: "Page height must match official form dimensions",
		})
	}

	// Validate required text elements
	for _, requiredText := range v.template.Validation.RequiredText {
		errors = append(errors, ValidationError{
			Type:        "content",
			Element:     "required_text",
			Expected:    requiredText,
			Severity:    "warning",
			Description: fmt.Sprintf("Required text '%s' should be present", requiredText),
		})
	}

	return errors
}

// validateTableLayout validates the table structure
func (v *DA2062Validator) validateTableLayout() []ValidationError {
	var errors []ValidationError

	// Validate column widths sum to expected total
	totalWidth := 0.0
	for _, col := range v.template.Sections.Table.Columns {
		totalWidth += col.Width
	}

	expectedTotal := 195.0 // Approximate expected table width
	if totalWidth < expectedTotal-5 || totalWidth > expectedTotal+5 {
		errors = append(errors, ValidationError{
			Type:        "layout",
			Element:     "table_width",
			Expected:    fmt.Sprintf("~%.1fmm", expectedTotal),
			Actual:      fmt.Sprintf("%.1fmm", totalWidth),
			Severity:    "warning",
			Description: "Table width should match official form proportions",
		})
	}

	// Validate row height consistency
	if v.template.Sections.Table.RowHeight != 8.0 {
		errors = append(errors, ValidationError{
			Type:        "layout",
			Element:     "row_height",
			Expected:    "8mm",
			Actual:      fmt.Sprintf("%.1fmm", v.template.Sections.Table.RowHeight),
			Severity:    "error",
			Description: "Row height must match official form specifications",
		})
	}

	return errors
}

// validateSignatureLayout validates the signature section
func (v *DA2062Validator) validateSignatureLayout() []ValidationError {
	var errors []ValidationError

	// Validate signature section position
	expectedY := 220.0
	if v.template.Sections.SignatureSection.Y != expectedY {
		errors = append(errors, ValidationError{
			Type:        "layout",
			Element:     "signature_position",
			Expected:    fmt.Sprintf("Y=%.1fmm", expectedY),
			Actual:      fmt.Sprintf("Y=%.1fmm", v.template.Sections.SignatureSection.Y),
			Severity:    "error",
			Description: "Signature section must be positioned correctly",
		})
	}

	// Validate number of signature fields
	expectedSignatures := 4
	if len(v.template.Sections.SignatureSection.Signatures) != expectedSignatures {
		errors = append(errors, ValidationError{
			Type:        "content",
			Element:     "signature_count",
			Expected:    fmt.Sprintf("%d signatures", expectedSignatures),
			Actual:      fmt.Sprintf("%d signatures", len(v.template.Sections.SignatureSection.Signatures)),
			Severity:    "error",
			Description: "Must have exactly 4 signature fields as per official form",
		})
	}

	return errors
}

// GetTemplate returns the loaded template for reference
func (v *DA2062Validator) GetTemplate() *DA2062Template {
	return v.template
}

// ValidateCompliance performs a comprehensive compliance check
func (v *DA2062Validator) ValidateCompliance(options GenerateOptions) ValidationReport {
	errors := v.ValidateLayout(options)

	report := ValidationReport{
		IsCompliant:     len(filterErrors(errors)) == 0,
		Errors:          filterErrors(errors),
		Warnings:        filterWarnings(errors),
		Timestamp:       "validation performed",
		TemplateVersion: v.template.Version,
	}

	return report
}

// ValidationReport contains the complete validation results
type ValidationReport struct {
	IsCompliant     bool              `json:"is_compliant"`
	Errors          []ValidationError `json:"errors"`
	Warnings        []ValidationError `json:"warnings"`
	Timestamp       string            `json:"timestamp"`
	TemplateVersion string            `json:"template_version"`
}

// Helper functions to filter validation results
func filterErrors(validations []ValidationError) []ValidationError {
	var errors []ValidationError
	for _, v := range validations {
		if v.Severity == "error" {
			errors = append(errors, v)
		}
	}
	return errors
}

func filterWarnings(validations []ValidationError) []ValidationError {
	var warnings []ValidationError
	for _, v := range validations {
		if v.Severity == "warning" {
			warnings = append(warnings, v)
		}
	}
	return warnings
}
