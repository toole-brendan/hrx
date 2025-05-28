package repository

import (
	"errors"

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

func (r *PostgresRepository) GetUserByUsername(username string) (*domain.User, error) {
	var user domain.User
	if err := r.db.Where("username = ?", username).First(&user).Error; err != nil {
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
