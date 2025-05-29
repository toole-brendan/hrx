package repository

import (
	"gorm.io/gorm"
)

// NewRepository creates a new repository instance for testing
// This is a simple wrapper that returns a basic repository struct
func NewRepository(db *gorm.DB) interface{} {
	// Return a struct that contains the DB connection
	// In a real implementation, this would return your actual repository interface
	return &testRepository{
		db: db,
	}
}

// testRepository is a minimal repository implementation for testing
type testRepository struct {
	db *gorm.DB
}

// GetDB returns the database connection
func (r *testRepository) GetDB() *gorm.DB {
	return r.db
}
