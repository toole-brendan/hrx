package models

import (
	"time"
)

// ImportMetadata represents metadata about how an item was imported
type ImportMetadata struct {
	Source               string    `json:"source"`
	ImportDate           time.Time `json:"import_date"`
	FormNumber           string    `json:"form_number,omitempty"`
	UnitName             string    `json:"unit_name,omitempty"`
	ScanConfidence       float64   `json:"scan_confidence"`
	ItemConfidence       float64   `json:"item_confidence"`
	SerialSource         string    `json:"serial_source"` // explicit, generated, manual
	OriginalQuantity     int       `json:"original_quantity,omitempty"`
	QuantityIndex        int       `json:"quantity_index,omitempty"`
	RequiresVerification bool      `json:"requires_verification"`
	VerificationReasons  []string  `json:"verification_reasons,omitempty"`
}

// DA2062ImportItem represents an item being imported from a DA-2062 form
type DA2062ImportItem struct {
	Name           string          `json:"name"`
	Description    string          `json:"description"`
	SerialNumber   string          `json:"serial_number"`
	NSN            string          `json:"nsn"`
	Quantity       int             `json:"quantity"`
	Unit           string          `json:"unit"`
	Category       string          `json:"category"`
	SourceRef      string          `json:"source_ref"` // Reference to source document
	ImportMetadata *ImportMetadata `json:"import_metadata,omitempty"`
}

// BatchCreateRequest represents a batch import request
type BatchCreateRequest struct {
	Items           []DA2062ImportItem `json:"items" binding:"required"`
	Source          string             `json:"source"`
	SourceReference string             `json:"source_reference"`
}

// VerifyItemRequest represents a verification request for an imported item
type VerifyItemRequest struct {
	SerialNumber string `json:"serial_number,omitempty"`
	NSN          string `json:"nsn,omitempty"`
	Notes        string `json:"notes,omitempty"`
}

// ImportSummary provides a summary of the import operation
type ImportSummary struct {
	TotalItems       int            `json:"total_items"`
	Categories       map[string]int `json:"categories"`
	ConfidenceLevels map[string]int `json:"confidence_levels"`
}
