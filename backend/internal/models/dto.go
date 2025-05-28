package models

import (
	"time"

	"github.com/google/uuid"
)

// Authentication DTOs
type LoginRequest struct {
	Username string `json:"username" validate:"required,min=3,max=50"`
	Password string `json:"password" validate:"required,min=8"`
}

type LoginResponse struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
	User         UserDTO   `json:"user"`
}

type RefreshTokenRequest struct {
	RefreshToken string `json:"refresh_token" validate:"required"`
}

type ChangePasswordRequest struct {
	CurrentPassword string `json:"current_password" validate:"required"`
	NewPassword     string `json:"new_password" validate:"required,min=8"`
	ConfirmPassword string `json:"confirm_password" validate:"required,eqfield=NewPassword"`
}

// User DTOs
type UserDTO struct {
	ID          uint       `json:"id"`
	UUID        uuid.UUID  `json:"uuid"`
	Username    string     `json:"username"`
	Email       string     `json:"email"`
	FirstName   string     `json:"first_name"`
	LastName    string     `json:"last_name"`
	Rank        string     `json:"rank"`
	Unit        string     `json:"unit"`
	Role        UserRole   `json:"role"`
	Status      UserStatus `json:"status"`
	LastLoginAt *time.Time `json:"last_login_at"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

type CreateUserRequest struct {
	Username  string   `json:"username" validate:"required,min=3,max=50,alphanum"`
	Email     string   `json:"email" validate:"required,email"`
	Password  string   `json:"password" validate:"required,min=8"`
	FirstName string   `json:"first_name" validate:"required,min=2,max=50"`
	LastName  string   `json:"last_name" validate:"required,min=2,max=50"`
	Rank      string   `json:"rank" validate:"max=20"`
	Unit      string   `json:"unit" validate:"max=100"`
	Role      UserRole `json:"role" validate:"required,oneof=user admin super_admin property_officer commander"`
}

type UpdateUserRequest struct {
	Email     *string     `json:"email,omitempty" validate:"omitempty,email"`
	FirstName *string     `json:"first_name,omitempty" validate:"omitempty,min=2,max=50"`
	LastName  *string     `json:"last_name,omitempty" validate:"omitempty,min=2,max=50"`
	Rank      *string     `json:"rank,omitempty" validate:"omitempty,max=20"`
	Unit      *string     `json:"unit,omitempty" validate:"omitempty,max=100"`
	Role      *UserRole   `json:"role,omitempty" validate:"omitempty,oneof=user admin super_admin property_officer commander"`
	Status    *UserStatus `json:"status,omitempty" validate:"omitempty,oneof=active inactive suspended pending"`
}

type UserListResponse struct {
	Users []UserDTO `json:"users"`
	Total int64     `json:"total"`
	Page  int       `json:"page"`
	Limit int       `json:"limit"`
}

// Equipment DTOs
type EquipmentDTO struct {
	ID              uint               `json:"id"`
	UUID            uuid.UUID          `json:"uuid"`
	NSN             string             `json:"nsn"`
	LIN             string             `json:"lin"`
	SerialNumber    string             `json:"serial_number"`
	Nomenclature    string             `json:"nomenclature"`
	Description     string             `json:"description"`
	Manufacturer    string             `json:"manufacturer"`
	Model           string             `json:"model"`
	PartNumber      string             `json:"part_number"`
	UnitPrice       float64            `json:"unit_price"`
	Quantity        int                `json:"quantity"`
	Location        string             `json:"location"`
	Status          EquipmentStatus    `json:"status"`
	Condition       EquipmentCondition `json:"condition"`
	AssignedTo      *UserDTO           `json:"assigned_to,omitempty"`
	AcquisitionDate *time.Time         `json:"acquisition_date"`
	WarrantyExpiry  *time.Time         `json:"warranty_expiry"`
	LastInspection  *time.Time         `json:"last_inspection"`
	NextInspection  *time.Time         `json:"next_inspection"`
	CreatedAt       time.Time          `json:"created_at"`
	UpdatedAt       time.Time          `json:"updated_at"`
}

type CreateEquipmentRequest struct {
	NSN             string             `json:"nsn" validate:"omitempty,len=13"`
	LIN             string             `json:"lin" validate:"omitempty,len=6"`
	SerialNumber    string             `json:"serial_number" validate:"required,min=1,max=100"`
	Nomenclature    string             `json:"nomenclature" validate:"max=255"`
	Description     string             `json:"description" validate:"max=1000"`
	Manufacturer    string             `json:"manufacturer" validate:"max=100"`
	Model           string             `json:"model" validate:"max=100"`
	PartNumber      string             `json:"part_number" validate:"max=100"`
	UnitPrice       float64            `json:"unit_price" validate:"min=0"`
	Quantity        int                `json:"quantity" validate:"min=1"`
	Location        string             `json:"location" validate:"max=255"`
	Condition       EquipmentCondition `json:"condition" validate:"required,oneof=serviceable unserviceable needs_repair beyond_repair new"`
	AcquisitionDate *time.Time         `json:"acquisition_date"`
	WarrantyExpiry  *time.Time         `json:"warranty_expiry"`
}

type UpdateEquipmentRequest struct {
	NSN             *string             `json:"nsn,omitempty" validate:"omitempty,len=13"`
	LIN             *string             `json:"lin,omitempty" validate:"omitempty,len=6"`
	SerialNumber    *string             `json:"serial_number,omitempty" validate:"omitempty,min=1,max=100"`
	Nomenclature    *string             `json:"nomenclature,omitempty" validate:"omitempty,max=255"`
	Description     *string             `json:"description,omitempty" validate:"omitempty,max=1000"`
	Manufacturer    *string             `json:"manufacturer,omitempty" validate:"omitempty,max=100"`
	Model           *string             `json:"model,omitempty" validate:"omitempty,max=100"`
	PartNumber      *string             `json:"part_number,omitempty" validate:"omitempty,max=100"`
	UnitPrice       *float64            `json:"unit_price,omitempty" validate:"omitempty,min=0"`
	Quantity        *int                `json:"quantity,omitempty" validate:"omitempty,min=1"`
	Location        *string             `json:"location,omitempty" validate:"omitempty,max=255"`
	Status          *EquipmentStatus    `json:"status,omitempty" validate:"omitempty,oneof=available assigned in_transit maintenance retired lost damaged"`
	Condition       *EquipmentCondition `json:"condition,omitempty" validate:"omitempty,oneof=serviceable unserviceable needs_repair beyond_repair new"`
	AcquisitionDate *time.Time          `json:"acquisition_date,omitempty"`
	WarrantyExpiry  *time.Time          `json:"warranty_expiry,omitempty"`
	LastInspection  *time.Time          `json:"last_inspection,omitempty"`
	NextInspection  *time.Time          `json:"next_inspection,omitempty"`
}

type EquipmentListResponse struct {
	Equipment []EquipmentDTO `json:"equipment"`
	Total     int64          `json:"total"`
	Page      int            `json:"page"`
	Limit     int            `json:"limit"`
}

type EquipmentSearchRequest struct {
	Query      string             `json:"query" validate:"max=255"`
	NSN        string             `json:"nsn" validate:"omitempty,len=13"`
	LIN        string             `json:"lin" validate:"omitempty,len=6"`
	Status     EquipmentStatus    `json:"status" validate:"omitempty,oneof=available assigned in_transit maintenance retired lost damaged"`
	Condition  EquipmentCondition `json:"condition" validate:"omitempty,oneof=serviceable unserviceable needs_repair beyond_repair new"`
	AssignedTo uint               `json:"assigned_to" validate:"omitempty,min=1"`
	Location   string             `json:"location" validate:"max=255"`
	Page       int                `json:"page" validate:"min=1"`
	Limit      int                `json:"limit" validate:"min=1,max=100"`
}

// Hand Receipt DTOs
type HandReceiptDTO struct {
	ID               uint                 `json:"id"`
	UUID             uuid.UUID            `json:"uuid"`
	Equipment        EquipmentDTO         `json:"equipment"`
	FromUser         *UserDTO             `json:"from_user,omitempty"`
	ToUser           UserDTO              `json:"to_user"`
	TransferType     TransferType         `json:"transfer_type"`
	Status           TransferStatus       `json:"status"`
	TransferDate     time.Time            `json:"transfer_date"`
	EffectiveDate    *time.Time           `json:"effective_date"`
	ExpiryDate       *time.Time           `json:"expiry_date"`
	SignatureData    string               `json:"signature_data"`
	DigitalSignature string               `json:"digital_signature"`
	Notes            string               `json:"notes"`
	Reason           string               `json:"reason"`
	Location         string               `json:"location"`
	Witnesses        []TransferWitnessDTO `json:"witnesses,omitempty"`
	CreatedAt        time.Time            `json:"created_at"`
	UpdatedAt        time.Time            `json:"updated_at"`
}

type CreateHandReceiptRequest struct {
	EquipmentID      uint         `json:"equipment_id" validate:"required,min=1"`
	FromUserID       *uint        `json:"from_user_id,omitempty" validate:"omitempty,min=1"`
	ToUserID         uint         `json:"to_user_id" validate:"required,min=1"`
	TransferType     TransferType `json:"transfer_type" validate:"required,oneof=assignment return transfer loan temporary"`
	TransferDate     time.Time    `json:"transfer_date" validate:"required"`
	EffectiveDate    *time.Time   `json:"effective_date,omitempty"`
	ExpiryDate       *time.Time   `json:"expiry_date,omitempty"`
	SignatureData    string       `json:"signature_data" validate:"max=10000"`
	DigitalSignature string       `json:"digital_signature" validate:"max=1000"`
	Notes            string       `json:"notes" validate:"max=1000"`
	Reason           string       `json:"reason" validate:"max=500"`
	Location         string       `json:"location" validate:"max=255"`
	WitnessUserIDs   []uint       `json:"witness_user_ids,omitempty"`
}

type UpdateHandReceiptRequest struct {
	Status           *TransferStatus `json:"status,omitempty" validate:"omitempty,oneof=pending approved completed rejected cancelled"`
	EffectiveDate    *time.Time      `json:"effective_date,omitempty"`
	ExpiryDate       *time.Time      `json:"expiry_date,omitempty"`
	SignatureData    *string         `json:"signature_data,omitempty" validate:"omitempty,max=10000"`
	DigitalSignature *string         `json:"digital_signature,omitempty" validate:"omitempty,max=1000"`
	Notes            *string         `json:"notes,omitempty" validate:"omitempty,max=1000"`
	Reason           *string         `json:"reason,omitempty" validate:"omitempty,max=500"`
	Location         *string         `json:"location,omitempty" validate:"omitempty,max=255"`
}

type TransferWitnessDTO struct {
	ID            uint      `json:"id"`
	User          UserDTO   `json:"user"`
	SignatureData string    `json:"signature_data"`
	SignedAt      time.Time `json:"signed_at"`
	CreatedAt     time.Time `json:"created_at"`
}

type HandReceiptListResponse struct {
	HandReceipts []HandReceiptDTO `json:"hand_receipts"`
	Total        int64            `json:"total"`
	Page         int              `json:"page"`
	Limit        int              `json:"limit"`
}

// Maintenance DTOs
type MaintenanceRecordDTO struct {
	ID            uint              `json:"id"`
	UUID          uuid.UUID         `json:"uuid"`
	Equipment     EquipmentDTO      `json:"equipment"`
	Technician    UserDTO           `json:"technician"`
	Type          MaintenanceType   `json:"type"`
	Status        MaintenanceStatus `json:"status"`
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

type CreateMaintenanceRequest struct {
	EquipmentID   uint            `json:"equipment_id" validate:"required,min=1"`
	TechnicianID  uint            `json:"technician_id" validate:"required,min=1"`
	Type          MaintenanceType `json:"type" validate:"required,oneof=preventive corrective inspection calibration overhaul"`
	ScheduledDate time.Time       `json:"scheduled_date" validate:"required"`
	Description   string          `json:"description" validate:"required,max=1000"`
	NextDueDate   *time.Time      `json:"next_due_date,omitempty"`
}

type UpdateMaintenanceRequest struct {
	Status        *MaintenanceStatus `json:"status,omitempty" validate:"omitempty,oneof=scheduled in_progress completed cancelled overdue"`
	ScheduledDate *time.Time         `json:"scheduled_date,omitempty"`
	CompletedDate *time.Time         `json:"completed_date,omitempty"`
	Description   *string            `json:"description,omitempty" validate:"omitempty,max=1000"`
	WorkPerformed *string            `json:"work_performed,omitempty" validate:"omitempty,max=2000"`
	PartsUsed     *string            `json:"parts_used,omitempty" validate:"omitempty,max=1000"`
	Cost          *float64           `json:"cost,omitempty" validate:"omitempty,min=0"`
	NextDueDate   *time.Time         `json:"next_due_date,omitempty"`
}

// NSN DTOs
type NSNDataDTO struct {
	ID             uint                   `json:"id"`
	NSN            string                 `json:"nsn"`
	LIN            string                 `json:"lin"`
	Nomenclature   string                 `json:"nomenclature"`
	FSC            string                 `json:"fsc"`
	NIIN           string                 `json:"niin"`
	UnitPrice      float64                `json:"unit_price"`
	Manufacturer   string                 `json:"manufacturer"`
	PartNumber     string                 `json:"part_number"`
	Specifications map[string]interface{} `json:"specifications"`
	LastUpdated    time.Time              `json:"last_updated"`
}

type NSNLookupRequest struct {
	NSN string `json:"nsn" validate:"required,len=13"`
}

type BulkNSNLookupRequest struct {
	NSNs []string `json:"nsns" validate:"required,min=1,max=100,dive,len=13"`
}

type NSNLookupResponse struct {
	NSNData *NSNDataDTO `json:"nsn_data"`
	Cached  bool        `json:"cached"`
}

type BulkNSNLookupResponse struct {
	Results map[string]*NSNDataDTO `json:"results"`
	Errors  map[string]string      `json:"errors,omitempty"`
}

// Audit DTOs
type AuditLogDTO struct {
	ID         uint                   `json:"id"`
	UUID       uuid.UUID              `json:"uuid"`
	EntityType string                 `json:"entity_type"`
	EntityID   string                 `json:"entity_id"`
	Action     AuditAction            `json:"action"`
	User       UserDTO                `json:"user"`
	OldValues  map[string]interface{} `json:"old_values,omitempty"`
	NewValues  map[string]interface{} `json:"new_values,omitempty"`
	IPAddress  string                 `json:"ip_address"`
	UserAgent  string                 `json:"user_agent"`
	SessionID  string                 `json:"session_id"`
	CreatedAt  time.Time              `json:"created_at"`
}

type AuditLogListResponse struct {
	AuditLogs []AuditLogDTO `json:"audit_logs"`
	Total     int64         `json:"total"`
	Page      int           `json:"page"`
	Limit     int           `json:"limit"`
}

type AuditSearchRequest struct {
	EntityType string      `json:"entity_type" validate:"max=50"`
	EntityID   string      `json:"entity_id" validate:"max=50"`
	Action     AuditAction `json:"action" validate:"omitempty,oneof=create update delete view login logout transfer assign return"`
	UserID     uint        `json:"user_id" validate:"omitempty,min=1"`
	StartDate  *time.Time  `json:"start_date"`
	EndDate    *time.Time  `json:"end_date"`
	Page       int         `json:"page" validate:"min=1"`
	Limit      int         `json:"limit" validate:"min=1,max=100"`
}

// Sync DTOs for Mobile
type SyncRequest struct {
	LastSyncTimestamp time.Time        `json:"last_sync_timestamp"`
	LocalChanges      []PropertyChange `json:"local_changes"`
	DeviceID          string           `json:"device_id" validate:"required,max=100"`
}

type SyncResponse struct {
	ServerChanges    []PropertyChange     `json:"server_changes"`
	Conflicts        []ConflictResolution `json:"conflicts"`
	NewSyncTimestamp time.Time            `json:"new_sync_timestamp"`
}

type PropertyChange struct {
	ID        string                 `json:"id"`
	Type      string                 `json:"type"`
	EntityID  string                 `json:"entity_id"`
	Action    string                 `json:"action"`
	Data      map[string]interface{} `json:"data"`
	Timestamp time.Time              `json:"timestamp"`
}

type ConflictResolution struct {
	ChangeID     string                 `json:"change_id"`
	ConflictType string                 `json:"conflict_type"`
	ServerData   map[string]interface{} `json:"server_data"`
	ClientData   map[string]interface{} `json:"client_data"`
	Resolution   string                 `json:"resolution"`
	ResolvedData map[string]interface{} `json:"resolved_data"`
}

type OfflineBundle struct {
	Users         []UserDTO        `json:"users"`
	Equipment     []EquipmentDTO   `json:"equipment"`
	HandReceipts  []HandReceiptDTO `json:"hand_receipts"`
	NSNData       []NSNDataDTO     `json:"nsn_data"`
	LastUpdated   time.Time        `json:"last_updated"`
	BundleVersion string           `json:"bundle_version"`
}

// Generic Response DTOs
type ErrorResponse struct {
	Error   string            `json:"error"`
	Message string            `json:"message"`
	Code    int               `json:"code"`
	Details map[string]string `json:"details,omitempty"`
}

type SuccessResponse struct {
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

type PaginationRequest struct {
	Page  int `json:"page" validate:"min=1"`
	Limit int `json:"limit" validate:"min=1,max=100"`
}

type HealthCheckResponse struct {
	Status    string            `json:"status"`
	Timestamp time.Time         `json:"timestamp"`
	Version   string            `json:"version"`
	Services  map[string]string `json:"services"`
}

// File Upload DTOs
type FileUploadResponse struct {
	ID           uint      `json:"id"`
	UUID         uuid.UUID `json:"uuid"`
	FileName     string    `json:"file_name"`
	OriginalName string    `json:"original_name"`
	FileSize     int64     `json:"file_size"`
	MimeType     string    `json:"mime_type"`
	UploadedAt   time.Time `json:"uploaded_at"`
}

type AttachmentDTO struct {
	ID           uint      `json:"id"`
	UUID         uuid.UUID `json:"uuid"`
	FileName     string    `json:"file_name"`
	OriginalName string    `json:"original_name"`
	FileSize     int64     `json:"file_size"`
	MimeType     string    `json:"mime_type"`
	Description  string    `json:"description"`
	UploadedBy   UserDTO   `json:"uploaded_by"`
	CreatedAt    time.Time `json:"created_at"`
}
