package repository

import (
	"errors"
	"fmt"
	"time"

	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"gorm.io/gorm"
)

// gormRepository implements the Repository interface using GORM.
type gormRepository struct {
	db *gorm.DB
}

// NewGormRepository creates a new GORM-based repository.
func NewGormRepository(db *gorm.DB) Repository {
	return &gormRepository{db: db}
}

// --- User Operations ---

func (r *gormRepository) CreateUser(user *domain.User) error {
	return r.db.Create(user).Error
}

func (r *gormRepository) GetUserByID(id uint) (*domain.User, error) {
	var user domain.User
	err := r.db.First(&user, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("user with ID %d not found", id)
		}
		return nil, err
	}
	return &user, nil
}

func (r *gormRepository) GetUserByUsername(username string) (*domain.User, error) {
	var user domain.User
	err := r.db.Where("username = ?", username).First(&user).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("user with username '%s' not found", username)
		}
		return nil, err
	}
	return &user, nil
}

// GetAllUsers retrieves all users from the database.
// TODO: Implement pagination, filtering, sorting as needed.
func (r *gormRepository) GetAllUsers() ([]domain.User, error) {
	var users []domain.User
	err := r.db.Find(&users).Error
	return users, err
}

// --- Property Operations ---

func (r *gormRepository) CreateProperty(property *domain.Property) error {
	return r.db.Create(property).Error
}

func (r *gormRepository) GetPropertyByID(id uint) (*domain.Property, error) {
	var property domain.Property
	// TODO: Consider preloading PropertyModel and AssignedToUser if needed frequently
	err := r.db.First(&property, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("property with ID %d not found", id)
		}
		return nil, err
	}
	return &property, nil
}

func (r *gormRepository) GetPropertyBySerialNumber(serialNumber string) (*domain.Property, error) {
	var property domain.Property
	err := r.db.Where("serial_number = ?", serialNumber).First(&property).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("property with serial number '%s' not found", serialNumber)
		}
		return nil, err
	}
	return &property, nil
}

func (r *gormRepository) UpdateProperty(property *domain.Property) error {
	// Use Save to update all fields, including zero values
	// Use Updates for partial updates if needed
	return r.db.Save(property).Error
}

func (r *gormRepository) ListProperties(assignedUserID *uint) ([]domain.Property, error) {
	var properties []domain.Property
	query := r.db
	if assignedUserID != nil {
		query = query.Where("assigned_to_user_id = ?", *assignedUserID)
	}
	// TODO: Add pagination, sorting, filtering as needed
	err := query.Find(&properties).Error
	return properties, err
}

// --- PropertyType Operations ---

func (r *gormRepository) GetPropertyTypeByID(id uint) (*domain.PropertyType, error) {
	var propType domain.PropertyType
	err := r.db.First(&propType, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("property type with ID %d not found", id)
		}
		return nil, err
	}
	return &propType, nil
}

func (r *gormRepository) ListPropertyTypes() ([]domain.PropertyType, error) {
	var propTypes []domain.PropertyType
	err := r.db.Find(&propTypes).Error
	return propTypes, err
}

// --- PropertyModel Operations ---

func (r *gormRepository) GetPropertyModelByID(id uint) (*domain.PropertyModel, error) {
	var model domain.PropertyModel
	// TODO: Consider preloading PropertyType if needed
	err := r.db.First(&model, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("property model with ID %d not found", id)
		}
		return nil, err
	}
	return &model, nil
}

func (r *gormRepository) GetPropertyModelByNSN(nsn string) (*domain.PropertyModel, error) {
	var model domain.PropertyModel
	err := r.db.Where("nsn = ?", nsn).First(&model).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("property model with NSN '%s' not found", nsn)
		}
		return nil, err
	}
	return &model, nil
}

func (r *gormRepository) ListPropertyModels(typeID *uint) ([]domain.PropertyModel, error) {
	var models []domain.PropertyModel
	query := r.db
	if typeID != nil {
		query = query.Where("property_type_id = ?", *typeID)
	}
	err := query.Find(&models).Error
	return models, err
}

// --- Transfer Operations ---

func (r *gormRepository) CreateTransfer(transfer *domain.Transfer) error {
	return r.db.Create(transfer).Error
}

func (r *gormRepository) GetTransferByID(id uint) (*domain.Transfer, error) {
	var transfer domain.Transfer
	// TODO: Consider preloading Property, FromUser, ToUser if needed
	err := r.db.First(&transfer, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("transfer with ID %d not found", id)
		}
		return nil, err
	}
	return &transfer, nil
}

func (r *gormRepository) UpdateTransfer(transfer *domain.Transfer) error {
	return r.db.Save(transfer).Error
}

func (r *gormRepository) ListTransfers(userID uint, status *string) ([]domain.Transfer, error) {
	var transfers []domain.Transfer
	query := r.db.Where("from_user_id = ? OR to_user_id = ?", userID, userID)
	if status != nil {
		query = query.Where("status = ?", *status)
	}
	// Order by request date descending
	err := query.Order("request_date desc").Find(&transfers).Error
	return transfers, err
}

// --- User Connection Operations ---

func (r *gormRepository) CreateConnection(connection *domain.UserConnection) error {
	return r.db.Create(connection).Error
}

func (r *gormRepository) GetConnectionByID(id uint) (*domain.UserConnection, error) {
	var connection domain.UserConnection
	err := r.db.Preload("User").Preload("ConnectedUser").First(&connection, id).Error
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, fmt.Errorf("connection with ID %d not found", id)
		}
		return nil, err
	}
	return &connection, nil
}

func (r *gormRepository) GetUserConnections(userID uint) ([]domain.UserConnection, error) {
	var connections []domain.UserConnection
	err := r.db.Where("user_id = ? OR connected_user_id = ?", userID, userID).
		Preload("User").
		Preload("ConnectedUser").
		Find(&connections).Error
	return connections, err
}

func (r *gormRepository) UpdateConnection(connection *domain.UserConnection) error {
	return r.db.Save(connection).Error
}

func (r *gormRepository) AreUsersConnected(userID1, userID2 uint) (bool, error) {
	var count int64
	err := r.db.Model(&domain.UserConnection{}).
		Where("((user_id = ? AND connected_user_id = ?) OR (user_id = ? AND connected_user_id = ?)) AND connection_status = ?",
			userID1, userID2, userID2, userID1, domain.ConnectionStatusAccepted).
		Count(&count).Error
	return count > 0, err
}

func (r *gormRepository) SearchUsers(query string, excludeUserID uint) ([]domain.User, error) {
	var users []domain.User
	searchPattern := "%" + query + "%"

	err := r.db.Where(
		"id != ? AND (LOWER(name) LIKE LOWER(?) OR phone LIKE ? OR dodid LIKE ?)",
		excludeUserID, searchPattern, searchPattern, searchPattern,
	).Limit(20).Find(&users).Error

	return users, err
}

// --- Additional Property Operations ---

// GetPropertyBySerial retrieves a property by its serial number
func (r *gormRepository) GetPropertyBySerial(serialNumber string) (*domain.Property, error) {
	var property domain.Property
	err := r.db.Where("serial_number = ? AND current_status = ?", serialNumber, "active").
		Preload("AssignedToUser").
		First(&property).Error

	if err == gorm.ErrRecordNotFound {
		return nil, err
	}
	return &property, err
}

// --- Transfer Offer Operations ---

// CreateTransferOffer creates a new transfer offer with recipients
func (r *gormRepository) CreateTransferOffer(offer *domain.TransferOffer, recipientIDs []uint) error {
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

// GetTransferOfferByID retrieves an offer with all relationships
func (r *gormRepository) GetTransferOfferByID(id uint) (*domain.TransferOffer, error) {
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

// ListActiveOffersForUser lists all active offers where user is a recipient
func (r *gormRepository) ListActiveOffersForUser(userID uint) ([]domain.TransferOffer, error) {
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

// UpdateTransferOffer updates an existing transfer offer
func (r *gormRepository) UpdateTransferOffer(offer *domain.TransferOffer) error {
	return r.db.Save(offer).Error
}

// MarkOfferViewed marks when a recipient views an offer
func (r *gormRepository) MarkOfferViewed(offerID, userID uint) error {
	now := time.Now()
	return r.db.Model(&domain.TransferOfferRecipient{}).
		Where("transfer_offer_id = ? AND recipient_user_id = ?", offerID, userID).
		Update("viewed_at", now).Error
}
