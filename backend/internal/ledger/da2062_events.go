package ledger

import (
	"time"
)

// DA2062Event represents a DA2062-specific ledger event
type DA2062Event struct {
	FormNumber    string    `json:"formNumber"`
	UserID        string    `json:"userId"`
	UnitName      string    `json:"unitName"`
	DODAAC        string    `json:"dodaac"`
	ItemCount     int       `json:"itemCount"`
	ImportMethod  string    `json:"importMethod"` // manual, ocr, ai_enhanced
	Confidence    float64   `json:"confidence"`
	Corrections   int       `json:"corrections"`
	ProcessingMs  int64     `json:"processingMs"`
	Timestamp     time.Time `json:"timestamp"`
}

// PropertyEvent represents a property creation/update event
type PropertyEvent struct {
	ItemID       string                 `json:"itemId"`
	NSN          string                 `json:"nsn"`
	SerialNumber string                 `json:"serialNumber"`
	UserID       string                 `json:"userId"`
	Action       string                 `json:"action"`
	Metadata     map[string]interface{} `json:"metadata"`
	Timestamp    time.Time              `json:"timestamp"`
}

// Note: These are extension methods that will need to be implemented
// by each concrete ledger service implementation (Azure SQL, Postgres, etc.)
// For now, we define the types and interfaces here.

// DA2062AIMetrics captures AI processing metrics
type DA2062AIMetrics struct {
	FormNumber        string    `json:"formNumber"`
	UserID            string    `json:"userId"`
	OCRConfidence     float64   `json:"ocrConfidence"`
	AIConfidence      float64   `json:"aiConfidence"`
	ItemsDetected     int       `json:"itemsDetected"`
	ItemsGrouped      int       `json:"itemsGrouped"`
	ProcessingTimeMs  int64     `json:"processingTimeMs"`
	TokensUsed        int       `json:"tokensUsed"`
	CostEstimateUSD   float64   `json:"costEstimateUsd"`
	Timestamp         time.Time `json:"timestamp"`
}