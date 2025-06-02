package models

import "time"

// NSNItem represents a National Stock Number item from V_FLIS_NSN.TAB
type NSNItem struct {
	NSN             string    `json:"nsn"`
	ItemName        string    `json:"item_name"`
	SupplyClass     string    `json:"supply_class"`
	FSG             string    `json:"fsg"`  // Federal Supply Group
	NIIN            string    `json:"niin"` // National Item Identification Number
	ItemDescription string    `json:"item_description"`
	UnitOfIssue     string    `json:"unit_of_issue"`
	UnitPrice       float64   `json:"unit_price"`
	DemilCode       string    `json:"demil_code"`
	ShelfLife       string    `json:"shelf_life"`
	SecurityCode    string    `json:"security_code"`
	LastModified    time.Time `json:"last_modified"`
}

// PartNumber represents a part number cross-reference from V_FLIS_PART.TAB
type PartNumber struct {
	NSN           string `json:"nsn"`
	PartNumber    string `json:"part_number"`
	CAGECode      string `json:"cage_code"`
	ReferenceType string `json:"reference_type"`
	Description   string `json:"description"`
}

// MOERule represents Method of Evaluation rules from V_MOE_RULE.TAB
type MOERule struct {
	NSN                string `json:"nsn"`
	SupplyCode         string `json:"supply_code"`
	AcquisitionCode    string `json:"acquisition_code"`
	RecoverabilityCode string `json:"recoverability_code"`
	MaterialControl    string `json:"material_control"`
	EssentialityCode   string `json:"essentiality_code"`
}

// CAGEAddress represents a CAGE code and address from V_CAGE_ADDRESS.TAB
type CAGEAddress struct {
	CAGECode     string `json:"cage_code"`
	CompanyName  string `json:"company_name"`
	AddressLine1 string `json:"address_line1"`
	AddressLine2 string `json:"address_line2"`
	City         string `json:"city"`
	State        string `json:"state"`
	ZipCode      string `json:"zip_code"`
	Country      string `json:"country"`
	Phone        string `json:"phone"`
}

// CAGEStatus represents CAGE status from V_CAGE_STATUS_AND_TYPE.TAB
type CAGEStatus struct {
	CAGECode      string    `json:"cage_code"`
	Status        string    `json:"status"`
	Type          string    `json:"type"`
	EffectiveDate time.Time `json:"effective_date"`
}

// ItemCharacteristics represents item characteristics from V_CHARACTERISTICS.TAB
type ItemCharacteristics struct {
	NSN                string            `json:"nsn"`
	Characteristics    map[string]string `json:"characteristics"`
	PhysicalDimensions PhysicalDims      `json:"physical_dimensions"`
	TechnicalData      map[string]string `json:"technical_data"`
}

// PhysicalDims represents physical dimensions of an item
type PhysicalDims struct {
	Length     float64 `json:"length"`
	Width      float64 `json:"width"`
	Height     float64 `json:"height"`
	Weight     float64 `json:"weight"`
	LengthUnit string  `json:"length_unit"`
	WeightUnit string  `json:"weight_unit"`
}

// ManagementData represents management data from V_FLIS_MANAGEMENT.TAB
type ManagementData struct {
	NSN                   string    `json:"nsn"`
	ManagementControlCode string    `json:"management_control_code"`
	AcquisitionAdviceCode string    `json:"acquisition_advice_code"`
	SourceOfSupply        string    `json:"source_of_supply"`
	LeadTime              int       `json:"lead_time_days"`
	ReorderPoint          int       `json:"reorder_point"`
	ReorderQuantity       int       `json:"reorder_quantity"`
	LastUpdated           time.Time `json:"last_updated"`
}

// PhraseData represents phrase data from V_FLIS_PHRASE.TAB
type PhraseData struct {
	NSN        string `json:"nsn"`
	PhraseType string `json:"phrase_type"`
	PhraseCode string `json:"phrase_code"`
	PhraseText string `json:"phrase_text"`
	Sequence   int    `json:"sequence"`
}

// SearchResult represents a search result combining multiple data sources
type SearchResult struct {
	NSNItem         *NSNItem             `json:"nsn_item"`
	PartNumbers     []PartNumber         `json:"part_numbers,omitempty"`
	MOERule         *MOERule             `json:"moe_rule,omitempty"`
	CAGEInfo        *CAGEInfo            `json:"cage_info,omitempty"`
	Characteristics *ItemCharacteristics `json:"characteristics,omitempty"`
	ManagementData  *ManagementData      `json:"management_data,omitempty"`
	Phrases         []PhraseData         `json:"phrases,omitempty"`
}

// CAGEInfo combines CAGE address and status
type CAGEInfo struct {
	Address *CAGEAddress `json:"address"`
	Status  *CAGEStatus  `json:"status"`
}
