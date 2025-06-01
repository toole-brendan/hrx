package database

import (
	"fmt"
	"log"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"

	"github.com/toole-brendan/handreceipt-go/internal/domain" // Import domain models
)

// ConnectDB initializes and returns a GORM DB instance for PostgreSQL.
func ConnectDB() (*gorm.DB, error) {
	// Construct DSN from environment variables for flexibility
	// Example using individual vars (adjust as needed):
	/*
		host := os.Getenv("POSTGRES_HOST")
		port := os.Getenv("POSTGRES_PORT")
		user := os.Getenv("POSTGRES_USER")
		password := os.Getenv("POSTGRES_PASSWORD")
		dbname := os.Getenv("POSTGRES_DB")
		sslmode := os.Getenv("POSTGRES_SSLMODE") // e.g., "disable", "require", "verify-full"

		dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s TimeZone=UTC",
			host, user, password, dbname, port, sslmode)
	*/

	// Or use a single DSN environment variable
	dsn := os.Getenv("POSTGRES_DSN")
	if dsn == "" {
		return nil, fmt.Errorf("POSTGRES_DSN environment variable not set")
	}

	log.Println("Connecting to PostgreSQL database...")

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info), // Adjust log level (Silent, Error, Warn, Info)
	})

	if err != nil {
		log.Printf("Failed to connect to database: %v\n", err)
		return nil, fmt.Errorf("failed to connect database: %w", err)
	}

	log.Println("Database connection established.")

	// Auto-migrate the schema
	// This will ONLY create tables, missing columns, and missing indexes.
	// It WILL NOT change existing column types or delete unused columns.
	log.Println("Running auto-migration...")
	err = db.AutoMigrate(
		&domain.User{},
		&domain.PropertyType{},
		&domain.PropertyModel{},
		&domain.Property{},
		&domain.Transfer{},
		&domain.Activity{},
		// &domain.QRCode{},           // Removed - deprecated
		&domain.Attachment{},       // Added
		&domain.TransferItem{},     // Added
		&domain.OfflineSyncQueue{}, // Added
		&domain.ImmuDBReference{},  // Added
	)
	if err != nil {
		log.Printf("Auto-migration failed: %v\n", err)
		return nil, fmt.Errorf("auto-migration failed: %w", err)
	}

	log.Println("Auto-migration completed.")

	return db, nil
}

// CloseDB closes the database connection.
func CloseDB(db *gorm.DB) error {
	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("failed to get database instance: %w", err)
	}

	return sqlDB.Close()
}
