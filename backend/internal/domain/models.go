package domain

import (
	"time"
)

// User represents a user in the system
type User struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	Username  string    `json:"username" gorm:"uniqueIndex;not null"`
	Password  string    `json:"-" gorm:"not null"` // Password is omitted from JSON responses
	Name      string    `json:"name" gorm:"not null"`
	Rank      string    `json:"rank" gorm:"not null"`
	CreatedAt time.Time `json:"createdAt" gorm:"not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updatedAt" gorm:"not null;default:CURRENT_TIMESTAMP"` // Added UpdatedAt for consistency
}

// Property represents an individual piece of property in the inventory
type Property struct {
	ID                uint       `json:"id" gorm:"primaryKey"`
	PropertyModelID   *uint      `json:"propertyModelId" gorm:"column:property_model_id"` // Foreign key to PropertyModel
	Name              string     `json:"name" gorm:"not null"`                            // Retained Name for easier display, though model has name too
	SerialNumber      string     `json:"serialNumber" gorm:"column:serial_number;uniqueIndex;not null"`
	Description       *string    `json:"description" gorm:"default:null"`
	CurrentStatus     string     `json:"currentStatus" gorm:"column:current_status;not null"`
	AssignedToUserID  *uint      `json:"assignedToUserId" gorm:"column:assigned_to_user_id"` // Tracks current assigned user
	LastVerifiedAt    *time.Time `json:"lastVerifiedAt" gorm:"column:last_verified_at"`
	LastMaintenanceAt *time.Time `json:"lastMaintenanceAt" gorm:"column:last_maintenance_at"`
	CreatedAt         time.Time  `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt         time.Time  `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"`

	// Optional: Eager/Lazy load related data with GORM tags
	// PropertyModel     *PropertyModel `json:"propertyModel,omitempty" gorm:"foreignKey:PropertyModelID"`
	// AssignedToUser    *User          `json:"assignedToUser,omitempty" gorm:"foreignKey:AssignedToUserID"`
}

// PropertyType represents a broad category of property (e.g., Weapon, Communication)
type PropertyType struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	Name        string    `json:"name" gorm:"uniqueIndex;not null"`
	Description *string   `json:"description"`
	CreatedAt   time.Time `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt   time.Time `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"`
}

// PropertyModel represents a specific model of property (e.g., M4 Carbine)
type PropertyModel struct {
	ID             uint      `json:"id" gorm:"primaryKey"`
	PropertyTypeID uint      `json:"propertyTypeId" gorm:"column:property_type_id;not null"`
	ModelName      string    `json:"modelName" gorm:"column:model_name;not null"`
	Manufacturer   *string   `json:"manufacturer"`
	Nsn            *string   `json:"nsn" gorm:"column:nsn;uniqueIndex"`
	Description    *string   `json:"description"`
	Specifications *string   `json:"specifications" gorm:"type:jsonb"` // Assuming JSONB in DB
	ImageURL       *string   `json:"imageUrl" gorm:"column:image_url"`
	CreatedAt      time.Time `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt      time.Time `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"`

	// PropertyType *PropertyType `json:"propertyType,omitempty" gorm:"foreignKey:PropertyTypeID"`
}

// Transfer represents a transfer of property between users
type Transfer struct {
	ID           uint       `json:"id" gorm:"primaryKey"`
	PropertyID   uint       `json:"propertyId" gorm:"column:property_id;not null"` // Renamed from ItemID
	FromUserID   uint       `json:"fromUserId" gorm:"column:from_user_id;not null"`
	ToUserID     uint       `json:"toUserId" gorm:"column:to_user_id;not null"`
	Status       string     `json:"status" gorm:"not null"` // e.g., Requested, Approved, Completed, Rejected
	RequestDate  time.Time  `json:"requestDate" gorm:"column:request_date;not null;default:CURRENT_TIMESTAMP"`
	ResolvedDate *time.Time `json:"resolvedDate" gorm:"column:resolved_date"`
	Notes        *string    `json:"notes"`
	CreatedAt    time.Time  `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"` // Added CreatedAt
	UpdatedAt    time.Time  `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"` // Added UpdatedAt

	// Property      *Property `json:"property,omitempty" gorm:"foreignKey:PropertyID"`
	// FromUser      *User     `json:"fromUser,omitempty" gorm:"foreignKey:FromUserID"`
	// ToUser        *User     `json:"toUser,omitempty" gorm:"foreignKey:ToUserID"`
}

// Activity represents a system activity or event (consider replacing with specific ledger events)
type Activity struct {
	ID                uint      `json:"id" gorm:"primaryKey"`
	Type              string    `json:"type" gorm:"not null"`
	Description       string    `json:"description" gorm:"not null"`
	UserID            *uint     `json:"userId" gorm:"column:user_id"`
	RelatedPropertyID *uint     `json:"relatedPropertyId" gorm:"column:related_property_id"` // Renamed from RelatedItemID
	RelatedTransferID *uint     `json:"relatedTransferId" gorm:"column:related_transfer_id"`
	Timestamp         time.Time `json:"timestamp" gorm:"not null;default:CURRENT_TIMESTAMP"`
	// Consider adding CreatedAt/UpdatedAt if this table remains
}

// CreateUserInput represents input for creating a user
type CreateUserInput struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
	Name     string `json:"name" binding:"required"`
	Rank     string `json:"rank" binding:"required"`
}

// CreatePropertyInput represents input for creating a property item
type CreatePropertyInput struct {
	PropertyModelID  *uint   `json:"propertyModelId"` // Optional: Link to model on creation
	Name             string  `json:"name" binding:"required"`
	SerialNumber     string  `json:"serialNumber" binding:"required"`
	Description      *string `json:"description"`
	CurrentStatus    string  `json:"currentStatus" binding:"required"`
	AssignedToUserID *uint   `json:"assignedToUserId"`
}

// CreateTransferInput represents input for creating a transfer request
type CreateTransferInput struct {
	PropertyID uint    `json:"propertyId" binding:"required"` // Renamed from ItemID
	ToUserID   uint    `json:"toUserId" binding:"required"`
	Notes      *string `json:"notes"`
	// FromUserID and Status will likely be set by the backend logic
}

// UpdateTransferInput represents input for updating a transfer status
type UpdateTransferInput struct {
	Status string  `json:"status" binding:"required"` // e.g., Approved, Rejected, Completed
	Notes  *string `json:"notes"`
}

// CreateActivityInput represents input for creating an activity (consider deprecating)
type CreateActivityInput struct {
	Type              string `json:"type" binding:"required"`
	Description       string `json:"description" binding:"required"`
	UserID            *uint  `json:"userId"`
	RelatedPropertyID *uint  `json:"relatedPropertyId"` // Renamed from RelatedItemID
	RelatedTransferID *uint  `json:"relatedTransferId"`
}

// LoginInput represents input for user login
type LoginInput struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// CorrectionEvent represents a record from the CorrectionEvents ledger table.
type CorrectionEvent struct {
	EventID             string    `json:"eventId"`             // EventID (UNIQUEIDENTIFIER as string)
	OriginalEventID     string    `json:"originalEventId"`     // OriginalEventID (UNIQUEIDENTIFIER as string)
	OriginalEventType   string    `json:"originalEventType"`   // Type hint for the original event
	Reason              string    `json:"reason"`              // Reason for correction
	CorrectingUserID    uint64    `json:"correctingUserId"`    // User ID (BIGINT)
	CorrectionTimestamp time.Time `json:"correctionTimestamp"` // Timestamp from DB
	// Optional Ledger metadata (might be useful for UI)
	LedgerTransactionID  *int64 `json:"ledgerTransactionId,omitempty"`
	LedgerSequenceNumber *int64 `json:"ledgerSequenceNumber,omitempty"`
}

// GeneralLedgerEvent represents a consolidated event from any ledger table,
// structured for frontend display.
// NOTE: This struct corresponds to the output of the LedgerService.GetGeneralHistory method.
// The `Details` field uses `any` for flexibility, but consider more specific types if feasible.
type GeneralLedgerEvent struct {
	EventID              string    `json:"eventId"`          // Event ID (UNIQUEIDENTIFIER as string)
	EventType            string    `json:"eventType"`        // e.g., 'TRANSFER_REQUEST', 'ITEM_VERIFY'
	Timestamp            time.Time `json:"timestamp"`        // Event timestamp
	UserID               *uint64   `json:"userId,omitempty"` // User associated (BIGINT)
	ItemID               *uint64   `json:"itemId,omitempty"` // Item associated (BIGINT)
	Details              any       `json:"details"`          // JSON object with event-specific details
	LedgerTransactionID  *int64    `json:"ledgerTransactionId,omitempty"`
	LedgerSequenceNumber *int64    `json:"ledgerSequenceNumber,omitempty"`
}
