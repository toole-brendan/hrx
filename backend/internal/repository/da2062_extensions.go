package repository

import (
	"github.com/toole-brendan/handreceipt-go/internal/domain"
)

// DA2062Repository extends the base Repository with DA2062-specific operations
type DA2062Repository interface {
	Repository

	// GetUnverifiedProperties returns all unverified properties for a user
	GetUnverifiedProperties(userID uint) ([]domain.Property, error)

	// GetPropertiesBySourceRef returns properties matching source reference criteria
	GetPropertiesBySourceRef(userID uint, sourceRef string, formNumber string) ([]domain.Property, error)

	// BatchCreateProperties creates multiple properties in a single transaction
	BatchCreateProperties(properties []domain.Property) ([]domain.Property, error)

	// UpdatePropertyVerification updates verification status of a property
	UpdatePropertyVerification(propertyID uint, verified bool, verifiedBy uint) error
}

// NOTE: Implementation of these methods would be added to the concrete repository
// implementation (e.g., PostgresRepository, MySQLRepository) for optimized queries
// instead of the in-memory filtering currently used in the handler.
//
// Example implementation for GetUnverifiedProperties:
// func (r *PostgresRepository) GetUnverifiedProperties(userID uint) ([]domain.Property, error) {
//     var properties []domain.Property
//     err := r.db.Where("assigned_to_user_id = ? AND verified = ?", userID, false).
//         Preload("PropertyModel").
//         Preload("AssignedToUser").
//         Find(&properties).Error
//     return properties, err
// }
//
// Example implementation for GetPropertiesBySourceRef:
// func (r *PostgresRepository) GetPropertiesBySourceRef(userID uint, sourceRef string, formNumber string) ([]domain.Property, error) {
//     query := r.db.Where("assigned_to_user_id = ?", userID)
//
//     if sourceRef != "" {
//         query = query.Where("source_ref = ?", sourceRef)
//     }
//
//     if formNumber != "" {
//         // Using JSONB query for PostgreSQL
//         query = query.Where("import_metadata->>'form_number' = ?", formNumber)
//     }
//
//     var properties []domain.Property
//     err := query.Preload("PropertyModel").
//         Preload("AssignedToUser").
//         Find(&properties).Error
//     return properties, err
// }
