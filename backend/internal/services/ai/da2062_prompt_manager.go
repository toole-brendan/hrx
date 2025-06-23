package ai

import (
	"fmt"
)

// DA2062PromptManager manages prompts specific to DA 2062 processing
type DA2062PromptManager struct {
	systemPrompt      string
	parsingRules      string
	generationPrompt  string
	examples          []DA2062Example
}

// DA2062Example represents example items for training
type DA2062Example struct {
	Input    string
	Expected ParsedDA2062Item
}

// NewDA2062PromptManager creates a new prompt manager
func NewDA2062PromptManager() *DA2062PromptManager {
	mgr := &DA2062PromptManager{}
	mgr.initializePrompts()
	mgr.loadExamples()
	return mgr
}

// initializePrompts sets up DA 2062-specific prompts
func (m *DA2062PromptManager) initializePrompts() {
	// System prompt for parsing DA 2062
	m.systemPrompt = `You are an expert military supply specialist with extensive experience processing DA Form 2062 (Hand Receipt/Annex Number) documents. Your expertise includes:

1. Military Equipment Knowledge:
   - National Stock Numbers (NSN) in format ####-##-###-####
   - Line Item Numbers (LIN) for Army equipment
   - Standard military nomenclature (e.g., RIFLE, 5.56MM, M4)
   - Common abbreviations (EA, BX, CS, DZ, PR, SE for units of issue)

2. DA 2062 Structure Understanding:
   - Header information: Unit names, DODAAC/UIC, dates
   - Line items that often span multiple lines
   - Serial numbers that may appear on separate lines
   - Handwritten annotations and corrections

3. Military Context:
   - Condition codes: A (Serviceable), B (Serviceable with qualification), C (Unserviceable)
   - Common equipment serial number patterns
   - Standard issue quantities for military units

You must output valid JSON matching the exact structure provided. Be intelligent about grouping multi-line items and identifying serial numbers that may not be on the same line as the item description.`

	// Parsing rules and instructions
	m.parsingRules = `Extract all information from this DA Form 2062 OCR text following these rules:

1. Item Grouping:
   - If a line starts with an NSN, it begins a new item
   - Serial numbers often appear on the line below the item description
   - Descriptions may span multiple lines - group them intelligently
   - Look for patterns like "S/N:", "SN:", or standalone alphanumeric strings as serial numbers

2. Data Normalization:
   - Convert NSNs to format: ####-##-###-####
   - Standardize condition codes to A, B, or C
   - Default quantity to 1 if not specified
   - Default unit of issue to "EA" if not specified

3. Confidence Scoring:
   - High confidence (>0.9): Complete NSN, description, and serial number
   - Medium confidence (0.7-0.9): Missing serial number or partial information
   - Low confidence (<0.7): Missing critical fields or unclear text

4. Multi-line Item Example:
   Line 1: "1005-01-123-4567 RIFLE, 5.56MM, M4"
   Line 2: "W/ RAIL SYSTEM"
   Line 3: "S/N: M4123456"
   Should be grouped as one item with full description and serial number.

Return structured JSON with all extracted items and metadata.`

	// Generation prompt for creating DA 2062 from description
	m.generationPrompt = `You are creating a DA Form 2062 based on a natural language description. Generate the form data following military standards:

1. Parse the description to extract:
   - Equipment types and quantities
   - Receiving unit/person
   - Transfer type (temporary or permanent)

2. For each item, provide:
   - Correct NSN (use your knowledge of military equipment)
   - Full military nomenclature
   - Appropriate condition code (default to A)
   - Realistic serial number format for that equipment type

3. Common Equipment NSNs:
   - M4 Rifle: 1005-01-231-0973
   - M16A4 Rifle: 1005-01-383-2872
   - M9 Pistol: 1005-01-118-2640
   - PVS-14 NVG: 5855-01-432-0524
   - ACH Helmet: 8470-01-523-8127
   - IOTV Body Armor: 8470-01-520-7373
   - M240B Machine Gun: 1005-01-411-6095
   - M249 SAW: 1005-01-331-4167

4. Serial Number Patterns:
   - Weapons: Alphanumeric, typically 6-8 characters (e.g., FE123456, W1234567)
   - Optics: Start with equipment prefix (e.g., PVS14-12345)
   - Body armor: Date code + sequential number (e.g., 2023-001234)

Generate complete DA 2062 data in the required JSON format.`
}

// loadExamples loads example patterns for better parsing
func (m *DA2062PromptManager) loadExamples() {
	m.examples = []DA2062Example{
		{
			Input: "1005-01-231-0973 RIFLE, 5.56MM, M4\nW/ RAIL ADAPTER SYSTEM\nS/N: FE123456",
			Expected: ParsedDA2062Item{
				NSN:          "1005-01-231-0973",
				Description:  "RIFLE, 5.56MM, M4 W/ RAIL ADAPTER SYSTEM",
				SerialNumber: "FE123456",
				Quantity:     1,
				UnitOfIssue:  "EA",
				Condition:    "A",
				AIGrouped:    true,
			},
		},
		{
			Input: "5855-01-432-0524 NIGHT VISION GOGGLE\nAN/PVS-14\nPVS14-87654",
			Expected: ParsedDA2062Item{
				NSN:          "5855-01-432-0524",
				Description:  "NIGHT VISION GOGGLE AN/PVS-14",
				SerialNumber: "PVS14-87654",
				Quantity:     1,
				UnitOfIssue:  "EA",
				Condition:    "A",
				AIGrouped:    true,
			},
		},
		{
			Input: "8470-01-520-7373 IMPROVED OUTER TACTICAL VEST (IOTV)\nSIZE: MEDIUM\nS/N: 2023-045678\nCONDITION: A",
			Expected: ParsedDA2062Item{
				NSN:          "8470-01-520-7373",
				Description:  "IMPROVED OUTER TACTICAL VEST (IOTV) SIZE: MEDIUM",
				SerialNumber: "2023-045678",
				Quantity:     1,
				UnitOfIssue:  "EA",
				Condition:    "A",
				AIGrouped:    true,
			},
		},
		{
			Input: "1005-01-411-6095 MACHINE GUN, 7.62MM\nM240B\nW/ SPARE BARREL\nS/N: 1234567\nQTY: 2 EA",
			Expected: ParsedDA2062Item{
				NSN:          "1005-01-411-6095",
				Description:  "MACHINE GUN, 7.62MM M240B W/ SPARE BARREL",
				SerialNumber: "1234567",
				Quantity:     2,
				UnitOfIssue:  "EA",
				Condition:    "A",
				AIGrouped:    true,
			},
		},
	}
}

// GetSystemPrompt returns the system prompt for DA 2062 parsing
func (m *DA2062PromptManager) GetSystemPrompt() string {
	return m.systemPrompt
}

// BuildParsingPrompt builds the user prompt for parsing OCR text
func (m *DA2062PromptManager) BuildParsingPrompt(ocrText string) string {
	return fmt.Sprintf(`%s

OCR Text to parse:
%s

Expected JSON structure:
{
  "formNumber": "DA2062-YYYYMMDD-####",
  "unitName": "unit name from form",
  "dodaac": "6 character code",
  "fromUnit": "issuing unit",
  "toUnit": "receiving unit",
  "date": "YYYY-MM-DD",
  "items": [
    {
      "lineNumber": 1,
      "nsn": "####-##-###-####",
      "description": "complete item description",
      "quantity": 1,
      "unitOfIssue": "EA",
      "serialNumber": "serial if found",
      "condition": "A",
      "confidence": 0.95,
      "aiGrouped": true,
      "suggestions": []
    }
  ],
  "confidence": 0.90,
  "metadata": {
    "itemCount": 1,
    "groupedItems": 1,
    "handwrittenItems": 0
  },
  "suggestions": []
}`, m.parsingRules, ocrText)
}

// GetGenerationPrompt returns the prompt for generating DA 2062
func (m *DA2062PromptManager) GetGenerationPrompt() string {
	return m.generationPrompt
}

// AddCustomSerialPatterns adds unit-specific serial number patterns
func (m *DA2062PromptManager) AddCustomSerialPatterns(patterns []string) {
	// This can be extended to add unit-specific patterns
	// For now, patterns are embedded in the prompts
}