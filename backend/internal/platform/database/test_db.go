package database

import (
	"fmt"

	"github.com/toole-brendan/handreceipt-go/internal/config"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var testDB *gorm.DB

// InitTestDB initializes a test database connection
func InitTestDB(cfg *config.Config) (*gorm.DB, error) {
	if testDB != nil {
		return testDB, nil
	}

	dsn := cfg.Database.GetDSN()

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent), // Silence logs during tests
	})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to test database: %w", err)
	}

	// Run migrations
	if err := runTestMigrations(db); err != nil {
		return nil, fmt.Errorf("failed to run test migrations: %w", err)
	}

	testDB = db
	return db, nil
}

// CleanupTestDB cleans up test data
func CleanupTestDB() {
	if testDB == nil {
		return
	}

	// Drop all tables
	testDB.Exec("DROP SCHEMA public CASCADE")
	testDB.Exec("CREATE SCHEMA public")

	// Close connection
	sqlDB, _ := testDB.DB()
	if sqlDB != nil {
		sqlDB.Close()
	}

	testDB = nil
}

// runTestMigrations runs database migrations for tests
func runTestMigrations(db *gorm.DB) error {
	// Define test models here
	// For now, we'll use basic models that match your schema

	type User struct {
		ID       uint   `gorm:"primaryKey"`
		Username string `gorm:"unique;not null"`
		Email    string `gorm:"unique;not null"`
		Password string `gorm:"not null"`
	}

	type Property struct {
		ID               uint   `gorm:"primaryKey"`
		Name             string `gorm:"not null"`
		SerialNumber     string `gorm:"unique;not null"`
		Description      string
		CurrentStatus    string
		NSN              string
		LIN              string
		AssignedToUserID *uint
		AssignedToUser   *User `gorm:"foreignKey:AssignedToUserID"`
	}

	type Transfer struct {
		ID          uint     `gorm:"primaryKey"`
		PropertyID  uint     `gorm:"not null"`
		Property    Property `gorm:"foreignKey:PropertyID"`
		FromUserID  uint     `gorm:"not null"`
		FromUser    User     `gorm:"foreignKey:FromUserID"`
		ToUserID    uint     `gorm:"not null"`
		ToUser      User     `gorm:"foreignKey:ToUserID"`
		Status      string   `gorm:"not null;default:'pending'"`
		CreatedAt   int64    `gorm:"not null"`
		CompletedAt *int64
	}

	// Auto-migrate the test models
	return db.AutoMigrate(&User{}, &Property{}, &Transfer{})
}

// SeedTestData adds test users for integration tests
func SeedTestData(db *gorm.DB) error {
	// Create test users
	users := []map[string]interface{}{
		{
			"username": "testuser1",
			"email":    "test1@example.com",
			"password": "$2a$10$YourHashedPasswordHere", // You'll need to hash "testpass123"
		},
		{
			"username": "testuser2",
			"email":    "test2@example.com",
			"password": "$2a$10$YourHashedPasswordHere", // You'll need to hash "testpass123"
		},
	}

	for _, user := range users {
		if err := db.Table("users").Create(&user).Error; err != nil {
			return fmt.Errorf("failed to seed test user: %w", err)
		}
	}

	return nil
}
