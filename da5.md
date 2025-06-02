# Using the Official DA Form 2062 PDF Template

## Overview
The official DA Form 2062 (JAN 1982) PDF template should be integrated into the codebase to ensure exact compliance with military standards. Here are several approaches to utilize it:

## Option 1: PDF as Reference Template (Recommended)

### Directory Structure
```
backend/
├── assets/
│   └── forms/
│       ├── DA_Form_2062_blank.pdf
│       └── DA_Form_2062_reference.json
```

### Reference JSON Schema
Create a JSON file that maps the exact coordinates and dimensions from the official form:

```json
{
  "form_name": "DA FORM 2062",
  "version": "JAN 1982",
  "page_size": "letter",
  "margins": {
    "top": 10,
    "bottom": 10,
    "left": 10,
    "right": 10
  },
  "sections": {
    "header": {
      "title": {
        "text": "HAND RECEIPT/ANNEX NUMBER",
        "x": 10,
        "y": 10,
        "font": "Arial-Bold",
        "size": 10
      },
      "form_number": {
        "x": 170,
        "y": 10,
        "width": 30,
        "height": 10
      }
    },
    "from_to_section": {
      "y": 30,
      "height": 15,
      "from_label_x": 10,
      "from_field_x": 30,
      "to_label_x": 100,
      "to_field_x": 115
    },
    "table": {
      "start_y": 60,
      "columns": {
        "stock_number": {"x": 0, "width": 50},
        "item_description": {"x": 50, "width": 70},
        "sec": {"x": 120, "width": 10},
        "ui": {"x": 130, "width": 10},
        "qty_auth": {"x": 140, "width": 15},
        "quantity_a": {"x": 155, "width": 6.67},
        "quantity_b": {"x": 161.67, "width": 6.67},
        "quantity_c": {"x": 168.34, "width": 6.67},
        "quantity_d": {"x": 175.01, "width": 6.67},
        "quantity_e": {"x": 181.68, "width": 6.67},
        "quantity_f": {"x": 188.35, "width": 6.67}
      },
      "row_height": 8
    }
  }
}
```

## Option 2: PDF Form Filling

Use a PDF form filling library to populate the blank form directly:

```go
// backend/internal/services/pdf/da2062_form_filler.go
package pdf

import (
    "github.com/pdfcpu/pdfcpu/pkg/api"
    "github.com/pdfcpu/pdfcpu/pkg/pdfcpu"
)

type DA2062FormFiller struct {
    templatePath string
}

func NewDA2062FormFiller() *DA2062FormFiller {
    return &DA2062FormFiller{
        templatePath: "assets/forms/DA_Form_2062_blank.pdf",
    }
}

func (f *DA2062FormFiller) FillForm(data DA2062Data) ([]byte, error) {
    // Load template
    ctx, err := api.ReadContextFile(f.templatePath)
    if err != nil {
        return nil, err
    }
    
    // Fill form fields
    err = api.FillForm(ctx, data.ToFormValues(), true, false)
    if err != nil {
        return nil, err
    }
    
    // Return filled PDF
    return api.WriteContextToBytes(ctx)
}
```

## Option 3: Exact Layout Replication

Update the existing generator to match exact coordinates:

```go
// Updated layout constants based on official form
const (
    // Page dimensions (Letter size in mm)
    PageWidth  = 215.9
    PageHeight = 279.4
    
    // Header positions
    TitleX = 10
    TitleY = 10
    FormNumberX = 170
    FormNumberY = 10
    
    // Table dimensions (exact from form)
    TableStartY = 60
    RowHeight = 8
    
    // Column widths (in mm)
    ColStockNumber = 50
    ColDescription = 70
    ColSEC = 10
    ColUI = 10
    ColQtyAuth = 15
    ColQuantity = 6.67 // Each A-F column
)
```

## Implementation Steps

### 1. Store the Template
```bash
# Add to version control
mkdir -p backend/assets/forms
cp DA_Form_2062.pdf backend/assets/forms/

# Add to .gitignore if needed (if containing sensitive data)
# Otherwise, commit it for reference
```

### 2. Create Validation Tests
```go
// backend/internal/services/pdf/da2062_generator_test.go
func TestDA2062LayoutCompliance(t *testing.T) {
    generator := NewDA2062Generator(mockRepo)
    pdf, err := generator.GenerateDA2062(testProperties, testUsers, testUnit, options)
    
    // Validate dimensions
    assert.Equal(t, 215.9, pdf.GetPageWidth())
    assert.Equal(t, 279.4, pdf.GetPageHeight())
    
    // Validate text positions
    // Compare with reference coordinates
}
```

### 3. Visual Regression Testing
Create a visual diff tool to compare generated PDFs with the template:

```go
// backend/internal/services/pdf/visual_test.go
func CompareWithTemplate(generatedPDF, templatePDF []byte) error {
    // Convert to images
    genImg := pdfToImage(generatedPDF)
    tmpImg := pdfToImage(templatePDF)
    
    // Compare layouts
    diff := imageDiff(genImg, tmpImg)
    
    if diff > threshold {
        return fmt.Errorf("layout differs by %f%%", diff)
    }
    
    return nil
}
```

## Benefits of Using the Official Template

1. **Compliance**: Ensures 100% compliance with military standards
2. **Validation**: Can validate generated forms against the official template
3. **Updates**: Easy to update when new form versions are released
4. **Testing**: Enables visual regression testing
5. **Reference**: Developers can view the exact layout requirements

## Recommended Approach

1. Store the PDF template in the repository for reference
2. Extract exact measurements and create a JSON schema
3. Update the PDF generator to use these exact measurements
4. Implement visual regression tests to ensure compliance
5. Consider PDF form filling for complex layouts

This ensures that the generated DA 2062 forms are identical to the official military form while maintaining the flexibility to populate them programmatically.