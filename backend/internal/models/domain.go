package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// User represents a system user (military personnel)
type User struct {
	ID           uint           `json:"id" gorm:"primaryKey"`
	UUID         uuid.UUID      `json:"uuid" gorm:"type:uuid;default:gen_random_uuid();uniqueIndex"`
	Username     string         `json:"username" gorm:"uniqueIndex;not null"`
	Email        string         `json:"email" gorm:"uniqueIndex;not null"`
	PasswordHash string         `json:"-" gorm:"not null"`
	FirstName    string         `json:"first_name" gorm:"not null"`
	LastName     string         `json:"last_name" gorm:"not null"`
	Rank         string         `json:"rank"`
	Unit         string         `json:"unit"`
	Role         UserRole       `json:"role" gorm:"type:varchar(50);default:'user'"`
	Status       UserStatus     `json:"status" gorm:"type:varchar(20);default:'active'"`
	LastLoginAt  *time.Time     `json:"last_login_at"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `json:"-" gorm:"index"`

	// Relationships
	AssignedEquipment []Equipment   `json:"assigned_equipment,omitempty" gorm:"foreignKey:AssignedToID"`
	HandReceipts      []HandReceipt `json:"hand_receipts,omitempty" gorm:"foreignKey:ToUserID"`
	IssuedReceipts    []HandReceipt `json:"issued_receipts,omitempty" gorm:"foreignKey:FromUserID"`
	AuditLogs         []AuditLog    `json:"audit_logs,omitempty" gorm:"foreignKey:UserID"`
}

type UserRole string

const (
	RoleUser            UserRole = "user"
	RoleAdmin           UserRole = "admin"
	RoleSuperAdmin      UserRole = "super_admin"
	RolePropertyOfficer UserRole = "property_officer"
	RoleCommander       UserRole = "commander"
)

type UserStatus string

const (
	StatusActive    UserStatus = "active"
	StatusInactive  UserStatus = "inactive"
	StatusSuspended UserStatus = "suspended"
	StatusPending   UserStatus = "pending"
)

// Equipment represents military equipment/property
type Equipment struct {
	ID              uint               `json:"id" gorm:"primaryKey"`
	UUID            uuid.UUID          `json:"uuid" gorm:"type:uuid;default:gen_random_uuid();uniqueIndex"`
	NSN             string             `json:"nsn" gorm:"index"`
	LIN             string             `json:"lin" gorm:"index"`
	SerialNumber    string             `json:"serial_number" gorm:"not null;index"`
	Nomenclature    string             `json:"nomenclature"`
	Description     string             `json:"description"`
	Manufacturer    string             `json:"manufacturer"`
	Model           string             `json:"model"`
	PartNumber      string             `json:"part_number"`
	UnitPrice       float64            `json:"unit_price"`
	Quantity        int                `json:"quantity" gorm:"default:1"`
	Location        string             `json:"location"`
	Status          EquipmentStatus    `json:"status" gorm:"type:varchar(50);default:'available'"`
	Condition       EquipmentCondition `json:"condition" gorm:"type:varchar(50);default:'serviceable'"`
	AssignedToID    *uint              `json:"assigned_to_id"`
	AssignedTo      *User              `json:"assigned_to,omitempty" gorm:"foreignKey:AssignedToID"`
	AcquisitionDate *time.Time         `json:"acquisition_date"`
	WarrantyExpiry  *time.Time         `json:"warranty_expiry"`
	LastInspection  *time.Time         `json:"last_inspection"`
	NextInspection  *time.Time         `json:"next_inspection"`
	CreatedAt       time.Time          `json:"created_at"`
	UpdatedAt       time.Time          `json:"updated_at"`
	DeletedAt       gorm.DeletedAt     `json:"-" gorm:"index"`

	// Relationships
	HandReceipts       []HandReceipt       `json:"hand_receipts,omitempty" gorm:"foreignKey:EquipmentID"`
	MaintenanceRecords []MaintenanceRecord `json:"maintenance_records,omitempty" gorm:"foreignKey:EquipmentID"`
	Attachments        []Attachment        `json:"attachments,omitempty" gorm:"foreignKey:EquipmentID"`
	AuditLogs          []AuditLog          `json:"audit_logs,omitempty" gorm:"foreignKey:EntityID;where:entity_type = 'equipment'"`
}

type EquipmentStatus string

const (
	StatusAvailable   EquipmentStatus = "available"
	StatusAssigned    EquipmentStatus = "assigned"
	StatusInTransit   EquipmentStatus = "in_transit"
	StatusMaintenance EquipmentStatus = "maintenance"
	StatusRetired     EquipmentStatus = "retired"
	StatusLost        EquipmentStatus = "lost"
	StatusDamaged     EquipmentStatus = "damaged"
)

type EquipmentCondition string

const (
	ConditionServiceable   EquipmentCondition = "serviceable"
	ConditionUnserviceable EquipmentCondition = "unserviceable"
	ConditionNeedsRepair   EquipmentCondition = "needs_repair"
	ConditionBeyondRepair  EquipmentCondition = "beyond_repair"
	ConditionNew           EquipmentCondition = "new"
)

// HandReceipt represents a property transfer record
type HandReceipt struct {
	ID               uint              `json:"id" gorm:"primaryKey"`
	UUID             uuid.UUID         `json:"uuid" gorm:"type:uuid;default:gen_random_uuid();uniqueIndex"`
	EquipmentID      uint              `json:"equipment_id" gorm:"not null"`
	Equipment        Equipment         `json:"equipment" gorm:"foreignKey:EquipmentID"`
	FromUserID       *uint             `json:"from_user_id"`
	FromUser         *User             `json:"from_user,omitempty" gorm:"foreignKey:FromUserID"`
	ToUserID         uint              `json:"to_user_id" gorm:"not null"`
	ToUser           User              `json:"to_user" gorm:"foreignKey:ToUserID"`
	TransferType     TransferType      `json:"transfer_type" gorm:"type:varchar(50);not null"`
	Status           TransferStatus    `json:"status" gorm:"type:varchar(50);default:'pending'"`
	TransferDate     time.Time         `json:"transfer_date"`
	EffectiveDate    *time.Time        `json:"effective_date"`
	ExpiryDate       *time.Time        `json:"expiry_date"`
	SignatureData    string            `json:"signature_data"`
	DigitalSignature string            `json:"digital_signature"`
	Notes            string            `json:"notes"`
	Reason           string            `json:"reason"`
	Location         string            `json:"location"`
	Witnesses        []TransferWitness `json:"witnesses,omitempty" gorm:"foreignKey:HandReceiptID"`
	CreatedAt        time.Time         `json:"created_at"`
	UpdatedAt        time.Time         `json:"updated_at"`
	DeletedAt        gorm.DeletedAt    `json:"-" gorm:"index"`
}

type TransferType string

const (
	TransferTypeAssignment TransferType = "assignment"
	TransferTypeReturn     TransferType = "return"
	TransferTypeTransfer   TransferType = "transfer"
	TransferTypeLoan       TransferType = "loan"
	TransferTypeTemporary  TransferType = "temporary"
)

type TransferStatus string

const (
	TransferStatusPending   TransferStatus = "pending"
	TransferStatusApproved  TransferStatus = "approved"
	TransferStatusCompleted TransferStatus = "completed"
	TransferStatusRejected  TransferStatus = "rejected"
	TransferStatusCancelled TransferStatus = "cancelled"
)

// TransferWitness represents witnesses to a property transfer
type TransferWitness struct {
	ID            uint      `json:"id" gorm:"primaryKey"`
	HandReceiptID uint      `json:"hand_receipt_id" gorm:"not null"`
	UserID        uint      `json:"user_id" gorm:"not null"`
	User          User      `json:"user" gorm:"foreignKey:UserID"`
	SignatureData string    `json:"signature_data"`
	SignedAt      time.Time `json:"signed_at"`
	CreatedAt     time.Time `json:"created_at"`
}

// MaintenanceRecord represents equipment maintenance history
type MaintenanceRecord struct {
	ID            uint              `json:"id" gorm:"primaryKey"`
	UUID          uuid.UUID         `json:"uuid" gorm:"type:uuid;default:gen_random_uuid();uniqueIndex"`
	EquipmentID   uint              `json:"equipment_id" gorm:"not null"`
	Equipment     Equipment         `json:"equipment" gorm:"foreignKey:EquipmentID"`
	TechnicianID  uint              `json:"technician_id" gorm:"not null"`
	Technician    User              `json:"technician" gorm:"foreignKey:TechnicianID"`
	Type          MaintenanceType   `json:"type" gorm:"type:varchar(50);not null"`
	Status        MaintenanceStatus `json:"status" gorm:"type:varchar(50);default:'scheduled'"`
	ScheduledDate time.Time         `json:"scheduled_date"`
	CompletedDate *time.Time        `json:"completed_date"`
	Description   string            `json:"description"`
	WorkPerformed string            `json:"work_performed"`
	PartsUsed     string            `json:"parts_used"`
	Cost          float64           `json:"cost"`
	NextDueDate   *time.Time        `json:"next_due_date"`
	CreatedAt     time.Time         `json:"created_at"`
	UpdatedAt     time.Time         `json:"updated_at"`
}

type MaintenanceType string

const (
	MaintenanceTypePreventive  MaintenanceType = "preventive"
	MaintenanceTypeCorrective  MaintenanceType = "corrective"
	MaintenanceTypeInspection  MaintenanceType = "inspection"
	MaintenanceTypeCalibration MaintenanceType = "calibration"
	MaintenanceTypeOverhaul    MaintenanceType = "overhaul"
)

type MaintenanceStatus string

const (
	MaintenanceStatusScheduled  MaintenanceStatus = "scheduled"
	MaintenanceStatusInProgress MaintenanceStatus = "in_progress"
	MaintenanceStatusCompleted  MaintenanceStatus = "completed"
	MaintenanceStatusCancelled  MaintenanceStatus = "cancelled"
	MaintenanceStatusOverdue    MaintenanceStatus = "overdue"
)

// Attachment represents file attachments for equipment
type Attachment struct {
	ID           uint           `json:"id" gorm:"primaryKey"`
	UUID         uuid.UUID      `json:"uuid" gorm:"type:uuid;default:gen_random_uuid();uniqueIndex"`
	EquipmentID  uint           `json:"equipment_id" gorm:"not null"`
	Equipment    Equipment      `json:"equipment" gorm:"foreignKey:EquipmentID"`
	FileName     string         `json:"file_name" gorm:"not null"`
	OriginalName string         `json:"original_name" gorm:"not null"`
	FileSize     int64          `json:"file_size"`
	MimeType     string         `json:"mime_type"`
	FilePath     string         `json:"file_path" gorm:"not null"`
	FileHash     string         `json:"file_hash"`
	UploadedByID uint           `json:"uploaded_by_id" gorm:"not null"`
	UploadedBy   User           `json:"uploaded_by" gorm:"foreignKey:UploadedByID"`
	Description  string         `json:"description"`
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `json:"-" gorm:"index"`
}

// AuditLog represents audit trail entries
type AuditLog struct {
	ID         uint                   `json:"id" gorm:"primaryKey"`
	UUID       uuid.UUID              `json:"uuid" gorm:"type:uuid;default:gen_random_uuid();uniqueIndex"`
	EntityType string                 `json:"entity_type" gorm:"not null;index"`
	EntityID   string                 `json:"entity_id" gorm:"not null;index"`
	Action     AuditAction            `json:"action" gorm:"type:varchar(50);not null"`
	UserID     uint                   `json:"user_id" gorm:"not null"`
	User       User                   `json:"user" gorm:"foreignKey:UserID"`
	OldValues  map[string]interface{} `json:"old_values" gorm:"type:jsonb"`
	NewValues  map[string]interface{} `json:"new_values" gorm:"type:jsonb"`
	IPAddress  string                 `json:"ip_address"`
	UserAgent  string                 `json:"user_agent"`
	SessionID  string                 `json:"session_id"`
	CreatedAt  time.Time              `json:"created_at" gorm:"index"`
}

type AuditAction string

const (
	ActionCreate   AuditAction = "create"
	ActionUpdate   AuditAction = "update"
	ActionDelete   AuditAction = "delete"
	ActionView     AuditAction = "view"
	ActionLogin    AuditAction = "login"
	ActionLogout   AuditAction = "logout"
	ActionTransfer AuditAction = "transfer"
	ActionAssign   AuditAction = "assign"
	ActionReturn   AuditAction = "return"
)

// NSNData represents cached NSN lookup data
type NSNData struct {
	ID             uint                   `json:"id" gorm:"primaryKey"`
	NSN            string                 `json:"nsn" gorm:"uniqueIndex;not null"`
	LIN            string                 `json:"lin" gorm:"index"`
	Nomenclature   string                 `json:"nomenclature"`
	FSC            string                 `json:"fsc"`
	NIIN           string                 `json:"niin"`
	UnitPrice      float64                `json:"unit_price"`
	Manufacturer   string                 `json:"manufacturer"`
	PartNumber     string                 `json:"part_number"`
	Specifications map[string]interface{} `json:"specifications" gorm:"type:jsonb"`
	LastUpdated    time.Time              `json:"last_updated"`
	CreatedAt      time.Time              `json:"created_at"`
	UpdatedAt      time.Time              `json:"updated_at"`
}

// Session represents user sessions for tracking
type Session struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UUID      uuid.UUID `json:"uuid" gorm:"type:uuid;default:gen_random_uuid();uniqueIndex"`
	UserID    uint      `json:"user_id" gorm:"not null"`
	User      User      `json:"user" gorm:"foreignKey:UserID"`
	Token     string    `json:"token" gorm:"uniqueIndex;not null"`
	IPAddress string    `json:"ip_address"`
	UserAgent string    `json:"user_agent"`
	ExpiresAt time.Time `json:"expires_at"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// RefreshToken represents JWT refresh tokens
type RefreshToken struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UUID      uuid.UUID `json:"uuid" gorm:"type:uuid;default:gen_random_uuid();uniqueIndex"`
	UserID    uint      `json:"user_id" gorm:"not null"`
	User      User      `json:"user" gorm:"foreignKey:UserID"`
	Token     string    `json:"token" gorm:"uniqueIndex;not null"`
	ExpiresAt time.Time `json:"expires_at"`
	IsRevoked bool      `json:"is_revoked" gorm:"default:false"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// BeforeCreate hooks for UUID generation
func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.UUID == uuid.Nil {
		u.UUID = uuid.New()
	}
	return nil
}

func (e *Equipment) BeforeCreate(tx *gorm.DB) error {
	if e.UUID == uuid.Nil {
		e.UUID = uuid.New()
	}
	return nil
}

func (hr *HandReceipt) BeforeCreate(tx *gorm.DB) error {
	if hr.UUID == uuid.Nil {
		hr.UUID = uuid.New()
	}
	return nil
}

func (mr *MaintenanceRecord) BeforeCreate(tx *gorm.DB) error {
	if mr.UUID == uuid.Nil {
		mr.UUID = uuid.New()
	}
	return nil
}

func (a *Attachment) BeforeCreate(tx *gorm.DB) error {
	if a.UUID == uuid.Nil {
		a.UUID = uuid.New()
	}
	return nil
}

func (al *AuditLog) BeforeCreate(tx *gorm.DB) error {
	if al.UUID == uuid.Nil {
		al.UUID = uuid.New()
	}
	return nil
}

func (s *Session) BeforeCreate(tx *gorm.DB) error {
	if s.UUID == uuid.Nil {
		s.UUID = uuid.New()
	}
	return nil
}

func (rt *RefreshToken) BeforeCreate(tx *gorm.DB) error {
	if rt.UUID == uuid.Nil {
		rt.UUID = uuid.New()
	}
	return nil
}
