package repository

import (
	"errors"
	"time"

	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"gorm.io/gorm"
)

// PostgresRepository implements the Repository interface using GORM and PostgreSQL.
type PostgresRepository struct {
	db *gorm.DB
}

// NewPostgresRepository creates a new instance of PostgresRepository.
func NewPostgresRepository(db *gorm.DB) Repository {
	return &PostgresRepository{db: db}
}

// DB returns the underlying database connection
func (r *PostgresRepository) DB() interface{} {
	return r.db
}

// User operations
func (r *PostgresRepository) CreateUser(user *domain.User) error {
	return r.db.Create(user).Error
}

func (r *PostgresRepository) GetUserByID(id uint) (*domain.User, error) {
	var user domain.User
	if err := r.db.First(&user, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil // Or return a specific "not found" error
		}
		return nil, err
	}
	return &user, nil
}

func (r *PostgresRepository) GetUserByEmail(email string) (*domain.User, error) {
	var user domain.User
	if err := r.db.Where("email = ?", email).First(&user).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			// Return the actual error so the handler knows the user wasn't found
			return nil, err
		}
		return nil, err
	}
	return &user, nil
}

func (r *PostgresRepository) GetAllUsers() ([]domain.User, error) {
	var users []domain.User
	if err := r.db.Find(&users).Error; err != nil {
		return nil, err
	}
	return users, nil
}

func (r *PostgresRepository) UpdateUser(user *domain.User) error {
	// Use Save to update all fields
	return r.db.Save(user).Error
}

// Property operations
func (r *PostgresRepository) CreateProperty(property *domain.Property) error {
	return r.db.Create(property).Error
}

func (r *PostgresRepository) GetPropertyByID(id uint) (*domain.Property, error) {
	var property domain.Property
	if err := r.db.First(&property, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &property, nil
}

func (r *PostgresRepository) GetPropertyBySerialNumber(serialNumber string) (*domain.Property, error) {
	var property domain.Property
	if err := r.db.Where("serial_number = ?", serialNumber).First(&property).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &property, nil
}

func (r *PostgresRepository) UpdateProperty(property *domain.Property) error {
	// Use Select("*") to update all fields, including zero values.
	// Or specify fields to update if needed.
	return r.db.Save(property).Error
}

func (r *PostgresRepository) ListProperties(assignedUserID *uint) ([]domain.Property, error) {
	var properties []domain.Property
	query := r.db
	if assignedUserID != nil {
		query = query.Where("assigned_to_user_id = ?", *assignedUserID)
	}
	if err := query.Find(&properties).Error; err != nil {
		return nil, err
	}
	return properties, nil
}

// PropertyType operations
func (r *PostgresRepository) GetPropertyTypeByID(id uint) (*domain.PropertyType, error) {
	var propType domain.PropertyType
	if err := r.db.First(&propType, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &propType, nil
}

func (r *PostgresRepository) ListPropertyTypes() ([]domain.PropertyType, error) {
	var types []domain.PropertyType
	if err := r.db.Find(&types).Error; err != nil {
		return nil, err
	}
	return types, nil
}

// PropertyModel operations
func (r *PostgresRepository) GetPropertyModelByID(id uint) (*domain.PropertyModel, error) {
	var model domain.PropertyModel
	if err := r.db.First(&model, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &model, nil
}

func (r *PostgresRepository) GetPropertyModelByNSN(nsn string) (*domain.PropertyModel, error) {
	var model domain.PropertyModel
	if err := r.db.Where("nsn = ?", nsn).First(&model).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &model, nil
}

func (r *PostgresRepository) ListPropertyModels(typeID *uint) ([]domain.PropertyModel, error) {
	var models []domain.PropertyModel
	query := r.db
	if typeID != nil {
		query = query.Where("property_type_id = ?", *typeID)
	}
	if err := query.Find(&models).Error; err != nil {
		return nil, err
	}
	return models, nil
}

// Transfer operations
func (r *PostgresRepository) CreateTransfer(transfer *domain.Transfer) error {
	return r.db.Create(transfer).Error
}

func (r *PostgresRepository) GetTransferByID(id uint) (*domain.Transfer, error) {
	var transfer domain.Transfer
	// TODO: Consider preloading related data (Property, FromUser, ToUser) if needed
	if err := r.db.First(&transfer, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &transfer, nil
}

func (r *PostgresRepository) UpdateTransfer(transfer *domain.Transfer) error {
	return r.db.Save(transfer).Error
}

func (r *PostgresRepository) ListTransfers(userID uint, status *string) ([]domain.Transfer, error) {
	var transfers []domain.Transfer
	query := r.db.Where("from_user_id = ? OR to_user_id = ?", userID, userID)
	if status != nil {
		query = query.Where("status = ?", *status)
	}
	// TODO: Consider preloading related data
	if err := query.Order("request_date DESC").Find(&transfers).Error; err != nil {
		return nil, err
	}
	return transfers, nil
}

// User Connection operations
func (r *PostgresRepository) CreateConnection(connection *domain.UserConnection) error {
	return r.db.Create(connection).Error
}

func (r *PostgresRepository) GetConnectionByID(id uint) (*domain.UserConnection, error) {
	var connection domain.UserConnection
	if err := r.db.Preload("User").Preload("ConnectedUser").First(&connection, id).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &connection, nil
}

func (r *PostgresRepository) GetUserConnections(userID uint) ([]domain.UserConnection, error) {
	var connections []domain.UserConnection
	err := r.db.Where("user_id = ? OR connected_user_id = ?", userID, userID).
		Preload("User").
		Preload("ConnectedUser").
		Find(&connections).Error
	return connections, err
}

func (r *PostgresRepository) UpdateConnection(connection *domain.UserConnection) error {
	return r.db.Save(connection).Error
}

func (r *PostgresRepository) AreUsersConnected(userID1, userID2 uint) (bool, error) {
	var count int64
	err := r.db.Model(&domain.UserConnection{}).
		Where("((user_id = ? AND connected_user_id = ?) OR (user_id = ? AND connected_user_id = ?)) AND connection_status = ?",
			userID1, userID2, userID2, userID1, domain.ConnectionStatusAccepted).
		Count(&count).Error
	return count > 0, err
}

func (r *PostgresRepository) SearchUsers(query string, excludeUserID uint) ([]domain.User, error) {
	var users []domain.User
	searchPattern := "%" + query + "%"

	err := r.db.Where(
		"id != ? AND (LOWER(CONCAT(first_name, ' ', last_name)) LIKE LOWER(?) OR phone LIKE ? OR dodid LIKE ?)",
		excludeUserID, searchPattern, searchPattern, searchPattern,
	).Limit(20).Find(&users).Error

	return users, err
}

// Additional Property Operations
func (r *PostgresRepository) GetPropertyBySerial(serialNumber string) (*domain.Property, error) {
	var property domain.Property
	err := r.db.Where("serial_number = ? AND current_status = ?", serialNumber, "active").
		Preload("AssignedToUser").
		First(&property).Error

	if err == gorm.ErrRecordNotFound {
		return nil, err
	}
	return &property, err
}

// Transfer Offer Operations
func (r *PostgresRepository) CreateTransferOffer(offer *domain.TransferOffer, recipientIDs []uint) error {
	return r.db.Transaction(func(tx *gorm.DB) error {
		// Create the offer
		if err := tx.Create(offer).Error; err != nil {
			return err
		}

		// Create recipient records
		for _, recipientID := range recipientIDs {
			recipient := domain.TransferOfferRecipient{
				TransferOfferID: offer.ID,
				RecipientUserID: recipientID,
			}
			if err := tx.Create(&recipient).Error; err != nil {
				return err
			}
		}

		return nil
	})
}

func (r *PostgresRepository) GetTransferOfferByID(id uint) (*domain.TransferOffer, error) {
	var offer domain.TransferOffer
	err := r.db.Preload("Property").
		Preload("OfferingUser").
		Preload("Recipients.RecipientUser").
		First(&offer, id).Error

	if err == gorm.ErrRecordNotFound {
		return nil, err
	}
	return &offer, err
}

func (r *PostgresRepository) ListActiveOffersForUser(userID uint) ([]domain.TransferOffer, error) {
	var offers []domain.TransferOffer

	err := r.db.
		Joins("JOIN transfer_offer_recipients tor ON tor.transfer_offer_id = transfer_offers.id").
		Where("tor.recipient_user_id = ? AND transfer_offers.offer_status = ?", userID, domain.OfferStatusActive).
		Where("transfer_offers.expires_at IS NULL OR transfer_offers.expires_at > ?", time.Now()).
		Preload("Property").
		Preload("OfferingUser").
		Find(&offers).Error

	return offers, err
}

func (r *PostgresRepository) UpdateTransferOffer(offer *domain.TransferOffer) error {
	return r.db.Save(offer).Error
}

func (r *PostgresRepository) MarkOfferViewed(offerID, userID uint) error {
	now := time.Now()
	return r.db.Model(&domain.TransferOfferRecipient{}).
		Where("transfer_offer_id = ? AND recipient_user_id = ?", offerID, userID).
		Update("viewed_at", now).Error
}

// Component operations
func (r *PostgresRepository) AttachComponent(parentID, componentID, userID uint, position, notes string) (*domain.PropertyComponent, error) {
	attachment := &domain.PropertyComponent{
		ParentPropertyID:    parentID,
		ComponentPropertyID: componentID,
		AttachedByUserID:    userID,
		Position:            &position,
		Notes:               &notes,
		AttachmentType:      "field",
	}

	if err := r.db.Create(attachment).Error; err != nil {
		return nil, err
	}

	// Load the relationship data
	if err := r.db.Preload("ParentProperty").Preload("ComponentProperty").Preload("AttachedByUser").First(attachment, attachment.ID).Error; err != nil {
		return nil, err
	}

	return attachment, nil
}

func (r *PostgresRepository) DetachComponent(parentID, componentID uint) error {
	return r.db.Where("parent_property_id = ? AND component_property_id = ?", parentID, componentID).
		Delete(&domain.PropertyComponent{}).Error
}

func (r *PostgresRepository) GetPropertyComponents(propertyID uint) ([]domain.PropertyComponent, error) {
	var components []domain.PropertyComponent
	err := r.db.Where("parent_property_id = ?", propertyID).
		Preload("ComponentProperty").
		Preload("AttachedByUser").
		Find(&components).Error
	return components, err
}

func (r *PostgresRepository) GetAvailableComponents(propertyID, userID uint) ([]domain.Property, error) {
	var components []domain.Property

	// Find properties that:
	// 1. Are owned by the user
	// 2. Are not already attached to anything
	// 3. Are not the parent property itself
	err := r.db.Where("assigned_to_user_id = ? AND id != ?", userID, propertyID).
		Where("id NOT IN (SELECT component_property_id FROM property_components)").
		Find(&components).Error

	return components, err
}

func (r *PostgresRepository) IsComponentAttached(componentID uint) (bool, error) {
	var count int64
	err := r.db.Model(&domain.PropertyComponent{}).
		Where("component_property_id = ?", componentID).
		Count(&count).Error
	return count > 0, err
}

func (r *PostgresRepository) IsPositionOccupied(parentID uint, position string) (bool, error) {
	if position == "" {
		return false, nil
	}

	var count int64
	err := r.db.Model(&domain.PropertyComponent{}).
		Where("parent_property_id = ? AND position = ?", parentID, position).
		Count(&count).Error
	return count > 0, err
}

func (r *PostgresRepository) UpdateComponentPosition(parentID, componentID uint, position string) error {
	return r.db.Model(&domain.PropertyComponent{}).
		Where("parent_property_id = ? AND component_property_id = ?", parentID, componentID).
		Update("position", position).Error
}

// CheckUserConnection checks if two users are connected (same as AreUsersConnected)
func (r *PostgresRepository) CheckUserConnection(userID1, userID2 uint) (bool, error) {
	var count int64
	err := r.db.Model(&domain.UserConnection{}).
		Where("((user_id = ? AND connected_user_id = ?) OR (user_id = ? AND connected_user_id = ?)) AND connection_status = ?",
			userID1, userID2, userID2, userID1, domain.ConnectionStatusAccepted).
		Count(&count).Error
	return count > 0, err
}

// Document operations
func (r *PostgresRepository) CreateDocument(document *domain.Document) error {
	return r.db.Create(document).Error
}

func (r *PostgresRepository) GetDocumentByID(id uint) (*domain.Document, error) {
	var document domain.Document
	err := r.db.Preload("Sender").
		Preload("Recipient").
		Preload("Property").
		First(&document, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, nil
		}
		return nil, err
	}
	return &document, nil
}

func (r *PostgresRepository) GetDocumentsByRecipient(userID uint, status, docType *string) ([]domain.Document, error) {
	var documents []domain.Document
	query := r.db.Where("recipient_user_id = ?", userID)

	if status != nil {
		query = query.Where("status = ?", *status)
	}
	if docType != nil {
		query = query.Where("type = ?", *docType)
	}

	err := query.Preload("Sender").
		Preload("Property").
		Order("sent_at DESC").
		Find(&documents).Error
	return documents, err
}

func (r *PostgresRepository) GetDocumentsBySender(userID uint, status, docType *string) ([]domain.Document, error) {
	var documents []domain.Document
	query := r.db.Where("sender_user_id = ?", userID)

	if status != nil {
		query = query.Where("status = ?", *status)
	}
	if docType != nil {
		query = query.Where("type = ?", *docType)
	}

	err := query.Preload("Recipient").
		Preload("Property").
		Order("sent_at DESC").
		Find(&documents).Error
	return documents, err
}

func (r *PostgresRepository) GetDocumentsForUser(userID uint, status, docType *string) ([]domain.Document, error) {
	var documents []domain.Document
	query := r.db.Where("sender_user_id = ? OR recipient_user_id = ?", userID, userID)

	if status != nil {
		query = query.Where("status = ?", *status)
	}
	if docType != nil {
		query = query.Where("type = ?", *docType)
	}

	err := query.Preload("Sender").
		Preload("Recipient").
		Preload("Property").
		Order("sent_at DESC").
		Find(&documents).Error
	return documents, err
}

func (r *PostgresRepository) UpdateDocument(document *domain.Document) error {
	return r.db.Save(document).Error
}

func (r *PostgresRepository) GetUnreadDocumentCount(userID uint) (int64, error) {
	var count int64
	err := r.db.Model(&domain.Document{}).
		Where("recipient_user_id = ? AND status = ?", userID, domain.DocumentStatusUnread).
		Count(&count).Error
	return count, err
}
