package repository

import (
	"github.com/toole-brendan/handreceipt-go/internal/domain"
)

// Repository defines the interface for data access operations.
type Repository interface {
	// User operations
	CreateUser(user *domain.User) error
	GetUserByID(id uint) (*domain.User, error)
	GetUserByUsername(username string) (*domain.User, error)
	GetAllUsers() ([]domain.User, error)
	// Add other user methods as needed (Update, Delete, List)

	// Property operations
	CreateProperty(property *domain.Property) error
	GetPropertyByID(id uint) (*domain.Property, error)
	GetPropertyBySerialNumber(serialNumber string) (*domain.Property, error)
	UpdateProperty(property *domain.Property) error
	ListProperties(assignedUserID *uint) ([]domain.Property, error) // List all or by assigned user
	// Add DeleteProperty if needed

	// PropertyType operations
	GetPropertyTypeByID(id uint) (*domain.PropertyType, error)
	ListPropertyTypes() ([]domain.PropertyType, error)

	// PropertyModel operations
	GetPropertyModelByID(id uint) (*domain.PropertyModel, error)
	GetPropertyModelByNSN(nsn string) (*domain.PropertyModel, error)
	ListPropertyModels(typeID *uint) ([]domain.PropertyModel, error) // List all or by type

	// Transfer operations
	CreateTransfer(transfer *domain.Transfer) error
	GetTransferByID(id uint) (*domain.Transfer, error)
	UpdateTransfer(transfer *domain.Transfer) error
	ListTransfers(userID uint, status *string) ([]domain.Transfer, error) // List transfers involving a user (from/to), optionally filter by status

	// Add other data access methods as required
}
