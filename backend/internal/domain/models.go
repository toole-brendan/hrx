package domain

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
	"time"
)

// JSONStringArray is a custom type for handling []string in JSONB columns
type JSONStringArray []string

// Value implements the driver.Valuer interface for GORM
func (jsa JSONStringArray) Value() (driver.Value, error) {
	if jsa == nil {
		return "[]", nil
	}
	data, err := json.Marshal([]string(jsa))
	if err != nil {
		return nil, err
	}
	return string(data), nil
}

// Scan implements the sql.Scanner interface for GORM
func (jsa *JSONStringArray) Scan(value interface{}) error {
	if value == nil {
		*jsa = JSONStringArray{}
		return nil
	}

	var data []byte
	switch v := value.(type) {
	case []byte:
		data = v
	case string:
		data = []byte(v)
	default:
		return fmt.Errorf("cannot scan %T into JSONStringArray", value)
	}

	var arr []string
	if err := json.Unmarshal(data, &arr); err != nil {
		return err
	}
	*jsa = JSONStringArray(arr)
	return nil
}

// User represents a user in the system with military-specific fields
type User struct {
	ID uint `json:"id" gorm:"primaryKey"`
	// Username     string    `json:"username" gorm:"uniqueIndex;not null"` // REMOVED: Username field
	Email        string    `json:"email" gorm:"not null"`
	PasswordHash string    `json:"-" gorm:"not null"` // Updated field name for consistency
	FirstName    string    `json:"first_name" gorm:"not null"`
	LastName     string    `json:"last_name" gorm:"not null"`
	Rank         string    `json:"rank" gorm:"not null"`
	Unit         string    `json:"unit"`
	Phone        string    `json:"phone"`                                    // NEW: Added for contact info
	DoDID        *string   `json:"dodid" gorm:"column:dodid;unique"`         // NEW: Department of Defense ID
	SignatureURL *string   `json:"signatureUrl" gorm:"column:signature_url"` // NEW: URL to stored signature image
	CreatedAt    time.Time `json:"createdAt" gorm:"not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt    time.Time `json:"updatedAt" gorm:"not null;default:CURRENT_TIMESTAMP"`
}

// UserConnection represents a friendship/connection between users (like Venmo)
type UserConnection struct {
	ID               uint      `json:"id" gorm:"primaryKey"`
	UserID           uint      `json:"userId" gorm:"column:user_id;not null"`
	ConnectedUserID  uint      `json:"connectedUserId" gorm:"column:connected_user_id;not null"`
	ConnectionStatus string    `json:"connectionStatus" gorm:"column:connection_status;default:'pending';not null"`
	CreatedAt        time.Time `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt        time.Time `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"`

	// Relationships
	User          *User `json:"user,omitempty" gorm:"foreignKey:UserID"`
	ConnectedUser *User `json:"connectedUser,omitempty" gorm:"foreignKey:ConnectedUserID"`
}

// Property represents an individual piece of property in the inventory
type Property struct {
	ID                uint       `json:"id" gorm:"primaryKey"`
	PropertyModelID   *uint      `json:"propertyModelId" gorm:"column:property_model_id"`
	Name              string     `json:"name" gorm:"not null"`
	SerialNumber      string     `json:"serialNumber" gorm:"column:serial_number;uniqueIndex;not null"`
	Description       *string    `json:"description" gorm:"default:null"`
	CurrentStatus     string     `json:"currentStatus" gorm:"column:current_status;not null"`
	Condition         string     `json:"condition" gorm:"default:'serviceable'"`         // NEW
	ConditionNotes    *string    `json:"conditionNotes" gorm:"column:condition_notes"`   // NEW
	NSN               *string    `json:"nsn" gorm:"column:nsn"`                          // NEW: National Stock Number
	LIN               *string    `json:"lin" gorm:"column:lin"`                          // NEW: Line Item Number
	Location          *string    `json:"location"`                                       // NEW
	AcquisitionDate   *time.Time `json:"acquisitionDate" gorm:"column:acquisition_date"` // NEW
	UnitPrice         float64    `json:"unitPrice" gorm:"column:unit_price;default:0"`   // NEW
	Quantity          int        `json:"quantity" gorm:"default:1"`                      // NEW
	PhotoURL          *string    `json:"photoUrl" gorm:"column:photo_url"`               // NEW: MinIO URL
	AssignedToUserID  *uint      `json:"assignedToUserId" gorm:"column:assigned_to_user_id"`
	LastVerifiedAt    *time.Time `json:"lastVerifiedAt" gorm:"column:last_verified_at"`
	LastMaintenanceAt *time.Time `json:"lastMaintenanceAt" gorm:"column:last_maintenance_at"`
	SyncStatus        string     `json:"syncStatus" gorm:"column:sync_status;default:'synced'"`   // NEW
	LastSyncedAt      *time.Time `json:"lastSyncedAt" gorm:"column:last_synced_at"`               // NEW
	ClientID          *string    `json:"clientId" gorm:"column:client_id"`                        // NEW
	Version           int        `json:"version" gorm:"default:1"`                                // NEW: For conflict resolution
	SourceType        *string    `json:"sourceType" gorm:"column:source_type"`                    // NEW: manual, da2062_scan, etc
	SourceRef         *string    `json:"sourceRef" gorm:"column:source_ref"`                      // NEW: Reference to source document
	SourceDocumentURL *string    `json:"sourceDocumentUrl" gorm:"column:source_document_url"`     // NEW: URL to original scanned form
	ImportMetadata    *string    `json:"importMetadata" gorm:"column:import_metadata;type:jsonb"` // NEW: Import metadata as JSONB
	Verified          bool       `json:"verified" gorm:"default:false"`                           // NEW: Whether item has been verified
	VerifiedAt        *time.Time `json:"verifiedAt" gorm:"column:verified_at"`                    // NEW: When item was verified
	VerifiedBy        *uint      `json:"verifiedBy" gorm:"column:verified_by"`                    // NEW: Who verified the item

	// Component association fields
	IsAttachable     bool    `json:"isAttachable" gorm:"column:is_attachable;default:false"`
	AttachmentPoints *string `json:"attachmentPoints" gorm:"column:attachment_points;type:jsonb"` // ["rail_top", "rail_side", "barrel"]
	CompatibleWith   *string `json:"compatibleWith" gorm:"column:compatible_with;type:jsonb"`     // ["M4", "M16", "AR15"]

	CreatedAt time.Time `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"`

	// Relationships
	PropertyModel      *PropertyModel      `json:"propertyModel,omitempty" gorm:"foreignKey:PropertyModelID"`
	AssignedToUser     *User               `json:"assignedToUser,omitempty" gorm:"foreignKey:AssignedToUserID"`
	VerifiedByUser     *User               `json:"verifiedByUser,omitempty" gorm:"foreignKey:VerifiedBy"` // NEW
	AttachedComponents []PropertyComponent `json:"attachedComponents,omitempty" gorm:"foreignKey:ParentPropertyID"`
	AttachedTo         *PropertyComponent  `json:"attachedTo,omitempty" gorm:"foreignKey:ComponentPropertyID"`
}

// PropertyComponent represents an attachment relationship between properties
type PropertyComponent struct {
	ID                  uint      `json:"id" gorm:"primaryKey"`
	ParentPropertyID    uint      `json:"parentPropertyId" gorm:"column:parent_property_id;not null"`
	ComponentPropertyID uint      `json:"componentPropertyId" gorm:"column:component_property_id;not null;uniqueIndex"`
	AttachedAt          time.Time `json:"attachedAt" gorm:"column:attached_at;not null;default:CURRENT_TIMESTAMP"`
	AttachedByUserID    uint      `json:"attachedByUserId" gorm:"column:attached_by_user_id;not null"`
	Notes               *string   `json:"notes"`
	AttachmentType      string    `json:"attachmentType" gorm:"column:attachment_type;default:'field'"`
	Position            *string   `json:"position"`
	CreatedAt           time.Time `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt           time.Time `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"`

	// Relationships
	ParentProperty    *Property `json:"parentProperty,omitempty" gorm:"foreignKey:ParentPropertyID"`
	ComponentProperty *Property `json:"componentProperty,omitempty" gorm:"foreignKey:ComponentPropertyID"`
	AttachedByUser    *User     `json:"attachedByUser,omitempty" gorm:"foreignKey:AttachedByUserID"`
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
	ID                    uint       `json:"id" gorm:"primaryKey"`
	PropertyID            uint       `json:"propertyId" gorm:"column:property_id;not null"` // Renamed from ItemID
	FromUserID            uint       `json:"fromUserId" gorm:"column:from_user_id;not null"`
	ToUserID              uint       `json:"toUserId" gorm:"column:to_user_id;not null"`
	Status                string     `json:"status" gorm:"not null"`                                            // e.g., Requested, Approved, Completed, Rejected
	TransferType          string     `json:"transferType" gorm:"column:transfer_type;default:'offer';not null"` // NEW: 'request' or 'offer'
	InitiatorID           *uint      `json:"initiatorId" gorm:"column:initiator_id"`                            // NEW: Who started the transfer
	RequestedSerialNumber *string    `json:"requestedSerialNumber" gorm:"column:requested_serial_number"`       // NEW: For serial number-based requests
	IncludeComponents     bool       `json:"includeComponents" gorm:"column:include_components;default:false"`  // NEW: Whether to transfer attached components
	RequestDate           time.Time  `json:"requestDate" gorm:"column:request_date;not null;default:CURRENT_TIMESTAMP"`
	ResolvedDate          *time.Time `json:"resolvedDate" gorm:"column:resolved_date"`
	Notes                 *string    `json:"notes"`
	CreatedAt             time.Time  `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"` // Added CreatedAt
	UpdatedAt             time.Time  `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"` // Added UpdatedAt

	// Relationships
	Property  *Property `json:"property,omitempty" gorm:"foreignKey:PropertyID"`
	FromUser  *User     `json:"fromUser,omitempty" gorm:"foreignKey:FromUserID"`
	ToUser    *User     `json:"toUser,omitempty" gorm:"foreignKey:ToUserID"`
	Initiator *User     `json:"initiator,omitempty" gorm:"foreignKey:InitiatorID"`
}

// TransferOffer represents an offer to transfer property to one or more users
type TransferOffer struct {
	ID               uint       `json:"id" gorm:"primaryKey"`
	PropertyID       uint       `json:"propertyId" gorm:"column:property_id;not null"`
	OfferingUserID   uint       `json:"offeringUserId" gorm:"column:offering_user_id;not null"`
	OfferStatus      string     `json:"offerStatus" gorm:"column:offer_status;default:'active';not null"`
	Notes            *string    `json:"notes"`
	ExpiresAt        *time.Time `json:"expiresAt" gorm:"column:expires_at"`
	CreatedAt        time.Time  `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	AcceptedByUserID *uint      `json:"acceptedByUserId" gorm:"column:accepted_by_user_id"`
	AcceptedAt       *time.Time `json:"acceptedAt" gorm:"column:accepted_at"`

	// Relationships
	Property       *Property                `json:"property,omitempty" gorm:"foreignKey:PropertyID"`
	OfferingUser   *User                    `json:"offeringUser,omitempty" gorm:"foreignKey:OfferingUserID"`
	AcceptedByUser *User                    `json:"acceptedByUser,omitempty" gorm:"foreignKey:AcceptedByUserID"`
	Recipients     []TransferOfferRecipient `json:"recipients,omitempty" gorm:"foreignKey:TransferOfferID"`
}

// TransferOfferRecipient represents a recipient of a transfer offer
type TransferOfferRecipient struct {
	ID              uint       `json:"id" gorm:"primaryKey"`
	TransferOfferID uint       `json:"transferOfferId" gorm:"column:transfer_offer_id;not null"`
	RecipientUserID uint       `json:"recipientUserId" gorm:"column:recipient_user_id;not null"`
	NotifiedAt      *time.Time `json:"notifiedAt" gorm:"column:notified_at"`
	ViewedAt        *time.Time `json:"viewedAt" gorm:"column:viewed_at"`

	// Relationships
	TransferOffer *TransferOffer `json:"transferOffer,omitempty" gorm:"foreignKey:TransferOfferID"`
	RecipientUser *User          `json:"recipientUser,omitempty" gorm:"foreignKey:RecipientUserID"`
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

// DEPRECATED: QRCode represents a generated QR code for a property item - REMOVED
// type QRCode struct {
// 	ID                uint       `json:"id" gorm:"primaryKey"`
// 	PropertyID        uint       `json:"propertyId" gorm:"column:property_id;not null"`
// 	QRCodeData        string     `json:"qrCodeData" gorm:"column:qr_code_data;type:text;not null"`
// 	QRCodeHash        string     `json:"qrCodeHash" gorm:"column:qr_code_hash;uniqueIndex;not null"`
// 	GeneratedByUserID uint       `json:"generatedByUserId" gorm:"column:generated_by_user_id;not null"`
// 	IsActive          bool       `json:"isActive" gorm:"column:is_active;default:true;not null"`
// 	CreatedAt         time.Time  `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
// 	DeactivatedAt     *time.Time `json:"deactivatedAt" gorm:"column:deactivated_at"`
//
// 	// Relationships
// 	Property        *Property `json:"property,omitempty" gorm:"foreignKey:PropertyID"`
// 	GeneratedByUser *User     `json:"generatedByUser,omitempty" gorm:"foreignKey:GeneratedByUserID"`
// }

// Attachment represents a photo or document attached to a property (NEW)
type Attachment struct {
	ID               uint      `json:"id" gorm:"primaryKey"`
	PropertyID       uint      `json:"propertyId" gorm:"column:property_id;not null"`
	FileName         string    `json:"fileName" gorm:"column:file_name;not null"`
	FileURL          string    `json:"fileUrl" gorm:"column:file_url;not null"` // MinIO URL
	FileSize         *int64    `json:"fileSize" gorm:"column:file_size"`
	MimeType         *string   `json:"mimeType" gorm:"column:mime_type"`
	UploadedByUserID uint      `json:"uploadedByUserId" gorm:"column:uploaded_by_user_id;not null"`
	Description      *string   `json:"description"`
	CreatedAt        time.Time `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`

	// Relationships
	Property       *Property `json:"property,omitempty" gorm:"foreignKey:PropertyID"`
	UploadedByUser *User     `json:"uploadedByUser,omitempty" gorm:"foreignKey:UploadedByUserID"`
}

// TransferItem represents individual items in a bulk transfer (NEW)
type TransferItem struct {
	ID         uint      `json:"id" gorm:"primaryKey"`
	TransferID uint      `json:"transferId" gorm:"column:transfer_id;not null"`
	PropertyID uint      `json:"propertyId" gorm:"column:property_id;not null"`
	Quantity   int       `json:"quantity" gorm:"default:1"`
	Notes      *string   `json:"notes"`
	CreatedAt  time.Time `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`

	// Relationships
	Transfer *Transfer `json:"transfer,omitempty" gorm:"foreignKey:TransferID"`
	Property *Property `json:"property,omitempty" gorm:"foreignKey:PropertyID"`
}

// OfflineSyncQueue represents pending sync operations from offline iOS devices (NEW)
type OfflineSyncQueue struct {
	ID            uint       `json:"id" gorm:"primaryKey"`
	ClientID      string     `json:"clientId" gorm:"column:client_id;not null"`
	OperationType string     `json:"operationType" gorm:"column:operation_type;not null"` // create, update, delete
	EntityType    string     `json:"entityType" gorm:"column:entity_type;not null"`       // property, transfer, etc.
	EntityID      *uint      `json:"entityId" gorm:"column:entity_id"`
	Payload       string     `json:"payload" gorm:"type:jsonb;not null"`
	SyncStatus    string     `json:"syncStatus" gorm:"column:sync_status;default:'pending'"`
	RetryCount    int        `json:"retryCount" gorm:"column:retry_count;default:0"`
	CreatedAt     time.Time  `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	SyncedAt      *time.Time `json:"syncedAt" gorm:"column:synced_at"`
}

// ImmuDBReference represents a reference to an immutable audit entry (NEW)
type ImmuDBReference struct {
	ID          uint      `json:"id" gorm:"primaryKey"`
	EntityType  string    `json:"entityType" gorm:"column:entity_type;not null"`
	EntityID    uint      `json:"entityId" gorm:"column:entity_id;not null"`
	ImmuDBKey   string    `json:"immudbKey" gorm:"column:immudb_key;not null"`
	ImmuDBIndex uint64    `json:"immudbIndex" gorm:"column:immudb_index;not null"`
	CreatedAt   time.Time `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
}

// Constants for property conditions
const (
	ConditionServiceable   = "serviceable"
	ConditionUnserviceable = "unserviceable"
	ConditionNeedsRepair   = "needs_repair"
	ConditionBeyondRepair  = "beyond_repair"
	ConditionNew           = "new"
)

// Constants for sync status
const (
	SyncStatusSynced   = "synced"
	SyncStatusPending  = "pending"
	SyncStatusConflict = "conflict"
	SyncStatusFailed   = "failed"
)

// Constants for connection status
const (
	ConnectionStatusPending  = "pending"
	ConnectionStatusAccepted = "accepted"
	ConnectionStatusBlocked  = "blocked"
)

// Constants for transfer types
const (
	TransferTypeRequest = "request"
	TransferTypeOffer   = "offer"
)

// Constants for offer status
const (
	OfferStatusActive    = "active"
	OfferStatusAccepted  = "accepted"
	OfferStatusExpired   = "expired"
	OfferStatusCancelled = "cancelled"
)

// CreateUserInput represents input for creating a user
type CreateUserInput struct {
	// Username string `json:"username" binding:"required"` // REMOVED: Username field
	Email     string `json:"email" binding:"required,email"`
	Password  string `json:"password" binding:"required"`
	FirstName string `json:"first_name" binding:"required"`
	LastName  string `json:"last_name" binding:"required"`
	Rank      string `json:"rank" binding:"required"`
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
	PropertyID        uint    `json:"propertyId" binding:"required"` // Renamed from ItemID
	ToUserID          uint    `json:"toUserId" binding:"required"`
	IncludeComponents bool    `json:"includeComponents"` // Whether to transfer attached components
	Notes             *string `json:"notes"`
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

// DEPRECATED: QRTransferRequest represents input for initiating a transfer via QR code scan - REMOVED
// type QRTransferRequest struct {
// 	QRData    map[string]interface{} `json:"qrData" binding:"required"`
// 	ScannedAt string                 `json:"scannedAt" binding:"required"`
// }

// CreateConnectionRequest represents input for creating a user connection
type CreateConnectionRequest struct {
	TargetUserID uint `json:"targetUserId" binding:"required"`
}

// UpdateConnectionRequest represents input for updating a connection status
type UpdateConnectionRequest struct {
	Status string `json:"status" binding:"required,oneof=accepted blocked"`
}

// Input DTOs
type RequestBySerialInput struct {
	SerialNumber      string  `json:"serialNumber" binding:"required"`
	IncludeComponents bool    `json:"includeComponents"` // Whether to request attached components too
	Notes             *string `json:"notes"`
}

type CreateOfferInput struct {
	PropertyID        uint    `json:"propertyId" binding:"required"`
	RecipientIDs      []uint  `json:"recipientIds" binding:"required,min=1"`
	IncludeComponents bool    `json:"includeComponents"` // Whether to offer attached components too
	Notes             *string `json:"notes"`
	ExpiresInDays     *int    `json:"expiresInDays"` // Optional expiration
}

type AcceptOfferInput struct {
	OfferID uint `json:"offerId" binding:"required"`
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

// Document represents a document (like maintenance forms) sent between users
type Document struct {
	ID              uint            `json:"id" gorm:"primaryKey"`
	Type            string          `json:"type" gorm:"not null"`          // 'maintenance_form', 'transfer_form', etc.
	Subtype         *string         `json:"subtype" gorm:"column:subtype"` // 'DA2404', 'DA5988E', etc.
	Title           string          `json:"title" gorm:"not null"`
	SenderUserID    uint            `json:"senderUserId" gorm:"column:sender_user_id;not null"`
	RecipientUserID uint            `json:"recipientUserId" gorm:"column:recipient_user_id;not null"`
	PropertyID      *uint           `json:"propertyId" gorm:"column:property_id"`
	FormData        string          `json:"formData" gorm:"column:form_data;type:jsonb;not null"` // Complete form data
	Description     *string         `json:"description"`
	Attachments     JSONStringArray `json:"attachments" gorm:"type:jsonb"` // Array of photo URLs
	Status          string          `json:"status" gorm:"default:'unread';not null"`
	SentAt          time.Time       `json:"sentAt" gorm:"column:sent_at;not null;default:CURRENT_TIMESTAMP"`
	ReadAt          *time.Time      `json:"readAt" gorm:"column:read_at"`
	CreatedAt       time.Time       `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt       time.Time       `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"`

	// Relationships
	Sender    *User     `json:"sender,omitempty" gorm:"foreignKey:SenderUserID"`
	Recipient *User     `json:"recipient,omitempty" gorm:"foreignKey:RecipientUserID"`
	Property  *Property `json:"property,omitempty" gorm:"foreignKey:PropertyID"`
}

// MaintenanceFormData represents the data for maintenance forms
type MaintenanceFormData struct {
	FormType         string                 `json:"form_type"` // DA2404, DA5988E
	EquipmentName    string                 `json:"equipment_name"`
	SerialNumber     string                 `json:"serial_number"`
	NSN              string                 `json:"nsn"`
	Location         string                 `json:"location"`
	Description      string                 `json:"description"`
	FaultDescription string                 `json:"fault_description"`
	RequestDate      time.Time              `json:"request_date"`
	FormFields       map[string]interface{} `json:"form_fields"` // Form-specific fields
}

// Constants for document types
const (
	DocumentTypeMaintenanceForm = "maintenance_form"
	DocumentTypeTransferForm    = "transfer_form"
)

// Constants for document status
const (
	DocumentStatusUnread   = "unread"
	DocumentStatusRead     = "read"
	DocumentStatusArchived = "archived"
)

// CreateDocumentInput represents input for creating a document
type CreateDocumentInput struct {
	Type            string           `json:"type" binding:"required"`
	Subtype         *string          `json:"subtype"`
	Title           string           `json:"title" binding:"required"`
	RecipientUserID uint             `json:"recipientUserId" binding:"required"`
	PropertyID      *uint            `json:"propertyId"`
	FormData        string           `json:"formData" binding:"required"`
	Description     *string          `json:"description"`
	Attachments     *JSONStringArray `json:"attachments"`
}

// CreateMaintenanceFormInput represents input for creating/sending maintenance forms
type CreateMaintenanceFormInput struct {
	PropertyID       uint            `json:"propertyId" binding:"required"`
	RecipientUserID  uint            `json:"recipientUserId" binding:"required"`
	FormType         string          `json:"formType" binding:"required"` // DA2404, DA5988E
	Description      string          `json:"description" binding:"required"`
	FaultDescription *string         `json:"faultDescription"`
	Attachments      JSONStringArray `json:"attachments"` // Photo URLs
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


// BulkDocumentOperationRequest represents a request to perform bulk operations on documents
type BulkDocumentOperationRequest struct {
	DocumentIDs []uint `json:"documentIds" binding:"required"`
	Operation   string `json:"operation" binding:"required,oneof=read archive delete"`
}

// Notification represents a persistent notification
type Notification struct {
	ID        uint            `json:"id" gorm:"primaryKey"`
	UserID    uint            `json:"userId" gorm:"column:user_id;not null"`
	Type      string          `json:"type" gorm:"column:type;not null"`
	Title     string          `json:"title" gorm:"column:title;not null"`
	Message   string          `json:"message" gorm:"column:message;not null"`
	Data      json.RawMessage `json:"data,omitempty" gorm:"column:data;type:jsonb"`
	Read      bool            `json:"read" gorm:"column:read;default:false;not null"`
	ReadAt    *time.Time      `json:"readAt,omitempty" gorm:"column:read_at"`
	Priority  string          `json:"priority" gorm:"column:priority;default:'normal';not null"`
	ExpiresAt *time.Time      `json:"expiresAt,omitempty" gorm:"column:expires_at"`
	CreatedAt time.Time       `json:"createdAt" gorm:"column:created_at;not null;default:CURRENT_TIMESTAMP"`
	UpdatedAt time.Time       `json:"updatedAt" gorm:"column:updated_at;not null;default:CURRENT_TIMESTAMP"`
}

// Constants for notification types
const (
	NotificationTypeTransferUpdate     = "transfer_update"
	NotificationTypeTransferCreated    = "transfer_created"
	NotificationTypePropertyUpdate     = "property_update"
	NotificationTypeConnectionRequest  = "connection_request"
	NotificationTypeConnectionAccepted = "connection_accepted"
	NotificationTypeDocumentReceived   = "document_received"
	NotificationTypeGeneral            = "general"
)

// Constants for notification priority
const (
	NotificationPriorityLow    = "low"
	NotificationPriorityNormal = "normal"
	NotificationPriorityHigh   = "high"
	NotificationPriorityUrgent = "urgent"
)

// NotificationService defines the interface for notification operations
type NotificationService interface {
	// Existing real-time methods
	NotifyTransferUpdate(transfer *Transfer) error
	NotifyTransferCreated(transfer *Transfer) error
	NotifyPropertyUpdate(property *Property) error
	NotifyConnectionRequest(requesterID, targetUserID int) error
	NotifyConnectionAccepted(acceptorID, requesterID int) error
	NotifyDocumentReceived(document *Document) error
	SendGeneralNotification(userID int, title, message string) error
	IsUserOnline(userID int) bool
	GetOnlineUsers() []int

	// New persistent notification methods
	CreateNotification(notification *Notification) error
	GetUserNotifications(userID int, limit, offset int, unreadOnly bool) ([]*Notification, error)
	GetUnreadCount(userID int) (int64, error)
	MarkAsRead(userID, notificationID int) error
	MarkAllAsRead(userID int) error
	DeleteNotification(userID, notificationID int) error
	ClearOldNotifications(userID int, days int) (int64, error)
}

// UserSearchFilters represents filters for searching users
type UserSearchFilters struct {
	Query        string `json:"query"`
	Organization string `json:"organization"`
	Rank         string `json:"rank"`
	Location     string `json:"location"`
}
