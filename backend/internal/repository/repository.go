package repository

import (
	"github.com/toole-brendan/handreceipt-go/internal/domain"
)

// Repository defines the interface for data access operations.
type Repository interface {
	// Database access
	DB() interface{} // Returns the underlying database connection
	
	// User operations
	CreateUser(user *domain.User) error
	GetUserByID(id uint) (*domain.User, error)
	GetUserByEmail(email string) (*domain.User, error)
	GetAllUsers() ([]domain.User, error)
	UpdateUser(user *domain.User) error
	SearchUsers(query string, excludeUserID uint) ([]domain.User, error)
	SearchUsersWithFilters(filters domain.UserSearchFilters, excludeUserID uint) ([]domain.User, error)
	// Add other user methods as needed (Update, Delete, List)

	// User Connection operations
	CreateConnection(connection *domain.UserConnection) error
	GetConnectionByID(id uint) (*domain.UserConnection, error)
	GetUserConnections(userID uint) ([]domain.UserConnection, error)
	UpdateConnection(connection *domain.UserConnection) error
	AreUsersConnected(userID1, userID2 uint) (bool, error)

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

	// Reference data operations
	ListUnitOfIssueCodes() ([]domain.UnitOfIssueCode, error)
	ListPropertyCategories() ([]domain.PropertyCategory, error)

	// Transfer operations
	CreateTransfer(transfer *domain.Transfer) error
	GetTransferByID(id uint) (*domain.Transfer, error)
	UpdateTransfer(transfer *domain.Transfer) error
	ListTransfers(userID uint, status *string) ([]domain.Transfer, error) // List transfers involving a user (from/to), optionally filter by status

	// Property queries
	GetPropertyBySerial(serialNumber string) (*domain.Property, error)

	// Transfer offer operations
	CreateTransferOffer(offer *domain.TransferOffer, recipientIDs []uint) error
	GetTransferOfferByID(id uint) (*domain.TransferOffer, error)
	ListActiveOffersForUser(userID uint) ([]domain.TransferOffer, error)
	UpdateTransferOffer(offer *domain.TransferOffer) error
	MarkOfferViewed(offerID, userID uint) error

	// Component association operations
	AttachComponent(parentID, componentID, userID uint, position, notes string) (*domain.PropertyComponent, error)
	DetachComponent(parentID, componentID uint) error
	GetPropertyComponents(propertyID uint) ([]domain.PropertyComponent, error)
	GetAvailableComponents(propertyID, userID uint) ([]domain.Property, error)
	IsComponentAttached(componentID uint) (bool, error)
	IsPositionOccupied(parentID uint, position string) (bool, error)
	UpdateComponentPosition(parentID, componentID uint, position string) error

	// Document operations
	CreateDocument(document *domain.Document) error
	GetDocumentByID(id uint) (*domain.Document, error)
	GetDocumentsByRecipient(userID uint, status, docType *string) ([]domain.Document, error)
	GetDocumentsBySender(userID uint, status, docType *string) ([]domain.Document, error)
	GetDocumentsForUser(userID uint, status, docType *string) ([]domain.Document, error)
	UpdateDocument(document *domain.Document) error
	DeleteDocument(id uint) error
	GetUnreadDocumentCount(userID uint) (int64, error)
	SearchDocuments(userID uint, query string) ([]domain.Document, error)
	CheckUserConnection(userID1, userID2 uint) (bool, error)

	// Add other data access methods as required
}
