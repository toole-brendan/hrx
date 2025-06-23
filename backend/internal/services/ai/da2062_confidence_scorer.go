package ai

import (
	"regexp"
	"strings"
)

// DA2062ConfidenceScorer calculates confidence scores for DA2062 items
type DA2062ConfidenceScorer struct {
	nsnPatterns  map[string]float64
	fieldWeights DA2062FieldWeights
}

// DA2062FieldWeights defines importance of each field
type DA2062FieldWeights struct {
	NSN          float64
	SerialNumber float64
	Description  float64
	Quantity     float64
	Condition    float64
}

// ItemConfidence represents confidence scores for each field
type ItemConfidence struct {
	NSN          float64 `json:"nsn"`
	SerialNumber float64 `json:"serialNumber"`
	Description  float64 `json:"description"`
	Quantity     float64 `json:"quantity"`
	Overall      float64 `json:"overall"`
}

// NewDA2062ConfidenceScorer creates a new confidence scorer
func NewDA2062ConfidenceScorer() *DA2062ConfidenceScorer {
	return &DA2062ConfidenceScorer{
		nsnPatterns: map[string]float64{
			"1005": 0.95, // Weapons - high confidence
			"5855": 0.90, // Night vision - high confidence
			"8470": 0.85, // Helmets/armor
			"8465": 0.80, // Clothing
		},
		fieldWeights: DA2062FieldWeights{
			NSN:          0.35,
			SerialNumber: 0.30,
			Description:  0.20,
			Quantity:     0.10,
			Condition:    0.05,
		},
	}
}

// ScoreItem calculates confidence for a DA2062 item
func (s *DA2062ConfidenceScorer) ScoreItem(item ParsedDA2062Item) ItemConfidence {
	scores := ItemConfidence{
		NSN:          s.scoreNSN(item.NSN),
		SerialNumber: s.scoreSerialNumber(item.SerialNumber, item.NSN),
		Description:  s.scoreDescription(item.Description),
		Quantity:     s.scoreQuantity(item.Quantity),
		Overall:      0.0,
	}

	// Calculate weighted overall score
	scores.Overall = scores.NSN*s.fieldWeights.NSN +
		scores.SerialNumber*s.fieldWeights.SerialNumber +
		scores.Description*s.fieldWeights.Description +
		scores.Quantity*s.fieldWeights.Quantity

	// Boost confidence if AI grouped multiple lines
	if item.AIGrouped {
		scores.Overall = min(scores.Overall*1.1, 1.0)
	}

	return scores
}

// scoreNSN validates and scores NSN format
func (s *DA2062ConfidenceScorer) scoreNSN(nsn string) float64 {
	if nsn == "" {
		return 0.0
	}

	// Check format (####-##-###-####)
	if !isValidNSNFormat(nsn) {
		return 0.3
	}

	// Check if NSN prefix matches known patterns
	prefix := nsn[0:4]
	if confidence, ok := s.nsnPatterns[prefix]; ok {
		return confidence
	}

	// Valid format but unknown prefix
	return 0.7
}

// scoreSerialNumber validates serial number based on equipment type
func (s *DA2062ConfidenceScorer) scoreSerialNumber(serial string, nsn string) float64 {
	if serial == "" {
		// Some items don't require serial numbers
		if !requiresSerialNumber(nsn) {
			return 1.0
		}
		return 0.0
	}

	// Validate format based on equipment type
	equipType := identifyMilitaryEquipmentType(nsn, "")
	switch equipType {
	case "weapon":
		// Weapons typically have 6-10 character serials
		if len(serial) >= 6 && len(serial) <= 10 {
			return 0.95
		}
		return 0.5
	case "optics":
		// Optics often have prefix-based serials
		if strings.Contains(serial, "-") {
			return 0.9
		}
		return 0.7
	default:
		// Any alphanumeric serial is likely valid
		if len(serial) >= 4 {
			return 0.8
		}
		return 0.4
	}
}

// scoreDescription evaluates description completeness
func (s *DA2062ConfidenceScorer) scoreDescription(desc string) float64 {
	if desc == "" {
		return 0.0
	}

	// Check for military nomenclature patterns
	upperDesc := strings.ToUpper(desc)

	// Full nomenclature (e.g., "RIFLE, 5.56MM, M4")
	if strings.Contains(upperDesc, ",") {
		return 0.95
	}

	// Contains key military terms
	militaryTerms := []string{"RIFLE", "PISTOL", "NIGHT VISION", "HELMET", "VEST", "RADIO"}
	for _, term := range militaryTerms {
		if strings.Contains(upperDesc, term) {
			return 0.85
		}
	}

	// Has some description
	if len(desc) > 10 {
		return 0.7
	}

	return 0.5
}

// scoreQuantity validates quantity reasonableness
func (s *DA2062ConfidenceScorer) scoreQuantity(qty int) float64 {
	if qty == 0 {
		return 0.0
	}

	// Most military items are issued in reasonable quantities
	if qty >= 1 && qty <= 100 {
		return 1.0
	}

	// Large quantities might be valid but less common
	if qty > 100 && qty <= 1000 {
		return 0.7
	}

	// Very large quantities are suspicious
	return 0.3
}

// Helper functions

// Compile regex once at package level for efficiency
var nsnFormatRegex = regexp.MustCompile(`^\d{4}-\d{2}-\d{3}-\d{4}$`)

func isValidNSNFormat(nsn string) bool {
	// Check ####-##-###-#### format
	if len(nsn) != 16 {
		return false
	}

	// Check dash positions
	if nsn[4] != '-' || nsn[7] != '-' || nsn[11] != '-' {
		return false
	}

	// Check that all other characters are digits
	return nsnFormatRegex.MatchString(nsn)
}

func requiresSerialNumber(nsn string) bool {
	if len(nsn) < 4 {
		return false
	}

	// Weapons and sensitive items require serial numbers
	prefix := nsn[0:4]
	sensitiveItems := []string{"1005", "5855", "5965"} // Weapons, NVGs, Radios

	for _, item := range sensitiveItems {
		if prefix == item {
			return true
		}
	}
	return false
}

func min(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

// ScoreDA2062Form calculates overall confidence for entire form
func (s *DA2062ConfidenceScorer) ScoreDA2062Form(form *ParsedDA2062) float64 {
	if len(form.Items) == 0 {
		return 0.0
	}

	totalConfidence := 0.0
	for _, item := range form.Items {
		itemScore := s.ScoreItem(item)
		totalConfidence += itemScore.Overall
	}

	// Average confidence across all items
	avgConfidence := totalConfidence / float64(len(form.Items))

	// Apply form-level factors
	if form.DODAAC != "" && len(form.DODAAC) == 6 {
		avgConfidence *= 1.05
	}
	if form.UnitName != "" {
		avgConfidence *= 1.05
	}

	// Cap at 1.0
	return min(avgConfidence, 1.0)
}

// ItemValidationResult represents validation for a single item including confidence scores and issues
type ItemValidationResult struct {
	LineNumber int            `json:"lineNumber"`
	IsValid    bool           `json:"isValid"`
	Confidence ItemConfidence `json:"confidence"`
	Issues     []string       `json:"issues"`
}
