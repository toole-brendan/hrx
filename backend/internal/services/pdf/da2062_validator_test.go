package pdf

import (
	"testing"
)

func TestDA2062ValidatorCreation(t *testing.T) {
	validator, err := NewDA2062Validator()
	if err != nil {
		t.Skipf("Skipping validator test - template file not available: %v", err)
		return
	}

	if validator == nil {
		t.Fatal("Expected validator to be created, got nil")
	}

	template := validator.GetTemplate()
	if template == nil {
		t.Fatal("Expected template to be loaded, got nil")
	}

	// Test basic template properties
	if template.FormName != "DA FORM 2062" {
		t.Errorf("Expected form name 'DA FORM 2062', got '%s'", template.FormName)
	}

	if template.Version != "JAN 1982" {
		t.Errorf("Expected version 'JAN 1982', got '%s'", template.Version)
	}
}

func TestValidateLayout(t *testing.T) {
	validator, err := NewDA2062Validator()
	if err != nil {
		t.Skipf("Skipping validator test - template file not available: %v", err)
		return
	}

	options := GenerateOptions{
		GroupByCategory:   false,
		IncludeSignatures: true,
		IncludeQRCodes:    false,
	}

	validationErrors := validator.ValidateLayout(options)

	// Should have some validation results (template structure validation)
	if len(validationErrors) == 0 {
		t.Log("No validation errors found - layout appears compliant")
	} else {
		t.Logf("Found %d validation issues:", len(validationErrors))
		for _, err := range validationErrors {
			t.Logf("  - %s (%s): %s", err.Element, err.Severity, err.Description)
		}
	}
}

func TestValidateCompliance(t *testing.T) {
	validator, err := NewDA2062Validator()
	if err != nil {
		t.Skipf("Skipping validator test - template file not available: %v", err)
		return
	}

	options := GenerateOptions{
		GroupByCategory:   false,
		IncludeSignatures: true,
		IncludeQRCodes:    false,
	}

	report := validator.ValidateCompliance(options)

	// Test report structure
	if report.TemplateVersion == "" {
		t.Error("Expected template version to be set in report")
	}

	if report.Timestamp == "" {
		t.Error("Expected timestamp to be set in report")
	}

	// Log compliance status
	if report.IsCompliant {
		t.Log("PDF layout is compliant with official template")
	} else {
		t.Logf("PDF layout has %d compliance errors", len(report.Errors))
		for _, err := range report.Errors {
			t.Logf("  Error: %s - %s", err.Element, err.Description)
		}
	}

	if len(report.Warnings) > 0 {
		t.Logf("PDF layout has %d warnings", len(report.Warnings))
		for _, warning := range report.Warnings {
			t.Logf("  Warning: %s - %s", warning.Element, warning.Description)
		}
	}
}

func TestTemplateStructureValidation(t *testing.T) {
	validator, err := NewDA2062Validator()
	if err != nil {
		t.Skipf("Skipping validator test - template file not available: %v", err)
		return
	}

	template := validator.GetTemplate()

	// Test that all required sections are present
	if template.Sections.Header.Title.Text == "" {
		t.Error("Expected header title to be defined")
	}

	if template.Sections.Table.StartY == 0 {
		t.Error("Expected table start Y coordinate to be defined")
	}

	if template.Sections.Table.RowHeight == 0 {
		t.Error("Expected table row height to be defined")
	}

	if len(template.Sections.Table.Columns) == 0 {
		t.Error("Expected table columns to be defined")
	}

	// Test specific column requirements
	requiredColumns := []string{"stock_number", "item_description", "sec", "ui", "qty_auth"}
	for _, colName := range requiredColumns {
		if _, exists := template.Sections.Table.Columns[colName]; !exists {
			t.Errorf("Expected column '%s' to be defined", colName)
		}
	}

	// Test quantity columns A-F
	quantityColumns := []string{"quantity_a", "quantity_b", "quantity_c", "quantity_d", "quantity_e", "quantity_f"}
	for _, colName := range quantityColumns {
		if col, exists := template.Sections.Table.Columns[colName]; !exists {
			t.Errorf("Expected quantity column '%s' to be defined", colName)
		} else if col.Width <= 0 {
			t.Errorf("Expected quantity column '%s' to have positive width", colName)
		}
	}
}

func TestValidationErrorTypes(t *testing.T) {
	validator, err := NewDA2062Validator()
	if err != nil {
		t.Skipf("Skipping validator test - template file not available: %v", err)
		return
	}

	options := GenerateOptions{
		GroupByCategory:   false,
		IncludeSignatures: true,
		IncludeQRCodes:    false,
	}

	validationErrors := validator.ValidateLayout(options)

	// Test that validation errors have proper structure
	for _, validationErr := range validationErrors {
		if validationErr.Type == "" {
			t.Error("Expected validation error to have a type")
		}

		if validationErr.Element == "" {
			t.Error("Expected validation error to have an element")
		}

		if validationErr.Severity == "" {
			t.Error("Expected validation error to have a severity")
		}

		if validationErr.Description == "" {
			t.Error("Expected validation error to have a description")
		}

		// Test severity values
		validSeverities := map[string]bool{"error": true, "warning": true, "info": true}
		if !validSeverities[validationErr.Severity] {
			t.Errorf("Expected severity to be 'error', 'warning', or 'info', got '%s'", validationErr.Severity)
		}
	}
}
