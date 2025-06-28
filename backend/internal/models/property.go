package models

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"

	"gorm.io/gorm"
)

// StringArray represents a JSON array of strings for GORM
type StringArray []string

// Scan implements the sql.Scanner interface for StringArray
func (s *StringArray) Scan(value interface{}) error {
	if value == nil {
		*s = nil
		return nil
	}

	switch v := value.(type) {
	case []byte:
		return json.Unmarshal(v, s)
	case string:
		return json.Unmarshal([]byte(v), s)
	default:
		return errors.New("cannot scan into StringArray")
	}
}

// Value implements the driver.Valuer interface for StringArray
func (s StringArray) Value() (driver.Value, error) {
	if s == nil {
		return nil, nil
	}
	return json.Marshal(s)
}

// Property represents a trackable property/equipment item
type Property struct {
	ID                uint       `json:"id" gorm:"primaryKey"`
	Name              string     `json:"name" gorm:"not null"`
	SerialNumber      string     `json:"serial_number" gorm:"not null;uniqueIndex"`
	Description       string     `json:"description"`
	CurrentStatus     string     `json:"current_status" gorm:"not null"`
	Condition         string     `json:"condition" gorm:"default:serviceable"`
	ConditionNotes    string     `json:"condition_notes"`
	NSN               string     `json:"nsn" gorm:"index"`
	LIN               string     `json:"lin" gorm:"index"`
	Location          string     `json:"location"`
	AcquisitionDate   *time.Time `json:"acquisition_date"`
	UnitPrice         float64    `json:"unit_price" gorm:"type:decimal(12,2);default:0"`
	Quantity          int        `json:"quantity" gorm:"default:1"`
	PhotoURL          string     `json:"photo_url"`
	AssignedToUserID  *uint      `json:"assigned_to_user_id"`
	AssignedToUser    *User      `json:"assigned_to_user,omitempty" gorm:"foreignKey:AssignedToUserID"`
	LastVerifiedAt    *time.Time `json:"last_verified_at"`
	LastMaintenanceAt *time.Time `json:"last_maintenance_at"`
	SyncStatus        string     `json:"sync_status" gorm:"default:synced"`
	LastSyncedAt      *time.Time `json:"last_synced_at"`
	ClientID          string     `json:"client_id"`
	Version           int        `json:"version" gorm:"default:1"`

	// Component association fields
	IsAttachable     bool        `json:"is_attachable" gorm:"default:false"`
	AttachmentPoints StringArray `json:"attachment_points" gorm:"type:jsonb"`
	CompatibleWith   StringArray `json:"compatible_with" gorm:"type:jsonb"`

	// DA 2062 required fields
	UnitOfIssue            string `json:"unit_of_issue" gorm:"default:EA"`
	ConditionCode          string `json:"condition_code" gorm:"default:A"`
	Category               string `json:"category"`
	Manufacturer           string `json:"manufacturer"`
	PartNumber             string `json:"part_number"`
	SecurityClassification string `json:"security_classification" gorm:"default:U"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Component relationships
	AttachedComponents []PropertyComponent `json:"attached_components,omitempty" gorm:"foreignKey:ParentPropertyID"`
	AttachedTo         *PropertyComponent  `json:"attached_to,omitempty" gorm:"foreignKey:ComponentPropertyID"`
}

// PropertyComponent represents an attachment relationship between properties
type PropertyComponent struct {
	ID                  uint      `json:"id" gorm:"primaryKey"`
	ParentPropertyID    uint      `json:"parent_property_id" gorm:"not null"`
	ComponentPropertyID uint      `json:"component_property_id" gorm:"not null;uniqueIndex"`
	AttachedAt          time.Time `json:"attached_at" gorm:"default:CURRENT_TIMESTAMP"`
	AttachedByUserID    uint      `json:"attached_by_user_id" gorm:"not null"`
	Notes               string    `json:"notes"`
	AttachmentType      string    `json:"attachment_type" gorm:"default:field"`
	Position            string    `json:"position"`
	CreatedAt           time.Time `json:"created_at"`
	UpdatedAt           time.Time `json:"updated_at"`

	// Relationships
	ParentProperty    Property `json:"parent_property" gorm:"foreignKey:ParentPropertyID"`
	ComponentProperty Property `json:"component_property" gorm:"foreignKey:ComponentPropertyID"`
	AttachedByUser    User     `json:"attached_by_user" gorm:"foreignKey:AttachedByUserID"`
}

// AttachmentPoint represents an attachment position definition
type AttachmentPoint struct {
	Position    string   `json:"position"`
	Types       []string `json:"types"`
	MaxItems    int      `json:"max_items"`
	CurrentItem *uint    `json:"current_item,omitempty"`
}

// PropertyWithComponents extends Property with component information
type PropertyWithComponents struct {
	Property
	AttachmentPointsData []AttachmentPoint `json:"attachment_points_data,omitempty"`
}

// TableName specifies the table name for Property model
func (Property) TableName() string {
	return "properties"
}

// TableName specifies the table name for PropertyComponent model
func (PropertyComponent) TableName() string {
	return "property_components"
}

// CanHaveComponents checks if a property can have components attached
func (p *Property) CanHaveComponents() bool {
	return p.IsAttachable && len(p.AttachmentPoints) > 0
}

// IsComponent checks if a property is currently attached as a component
func (p *Property) IsComponent() bool {
	return p.AttachedTo != nil
}

// GetAvailablePositions returns positions that are not currently occupied
func (p *Property) GetAvailablePositions() []string {
	if !p.CanHaveComponents() {
		return []string{}
	}

	occupiedPositions := make(map[string]bool)
	for _, component := range p.AttachedComponents {
		if component.Position != "" {
			occupiedPositions[component.Position] = true
		}
	}

	available := []string{}
	for _, position := range p.AttachmentPoints {
		if !occupiedPositions[position] {
			available = append(available, position)
		}
	}

	return available
}

// IsCompatibleWith checks if this property can be attached to a parent
func (p *Property) IsCompatibleWith(parent *Property) bool {
	if len(p.CompatibleWith) == 0 {
		return true // No restrictions
	}

	for _, compatible := range p.CompatibleWith {
		if parent.Name == compatible ||
			parent.SerialNumber == compatible ||
			containsIgnoreCase(parent.Name, compatible) {
			return true
		}
	}

	return false
}

// Helper function for case-insensitive string contains
func containsIgnoreCase(s, substr string) bool {
	return len(s) >= len(substr) &&
		(s == substr ||
			(len(s) > len(substr) &&
				(s[:len(substr)] == substr ||
					s[len(s)-len(substr):] == substr ||
					contains(s, substr))))
}

func contains(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// BeforeCreate hook for Property
func (p *Property) BeforeCreate(tx *gorm.DB) error {
	return nil
}

// BeforeCreate hook for PropertyComponent
func (pc *PropertyComponent) BeforeCreate(tx *gorm.DB) error {
	if pc.AttachedAt.IsZero() {
		pc.AttachedAt = time.Now()
	}
	return nil
}
