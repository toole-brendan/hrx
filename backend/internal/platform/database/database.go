package database

import (
	"fmt"
	"log"
	"os"

	"github.com/spf13/viper"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DB is the database instance
var DB *gorm.DB

// GetConnectionString returns the database connection string (deprecated or for debugging)
func GetConnectionString() string {
	// Check for the full connection string environment variable first
	envDSN := os.Getenv("HANDRECEIPT_DATABASE_URL")
	if envDSN != "" {
		log.Printf("Using DSN from HANDRECEIPT_DATABASE_URL environment variable")
		return envDSN
	}

	// Fallback to config file if environment variable is not set
	host := viper.GetString("database.host")
	port := viper.GetInt("database.port")
	user := viper.GetString("database.user")
	password := viper.GetString("database.password")
	dbname := viper.GetString("database.name")
	sslMode := viper.GetString("database.ssl_mode")

	log.Printf("Database connection details (from config): host=%s, port=%d, user=%s, dbname=%s, sslmode=%s",
		host, port, user, dbname, sslMode)

	connStr := fmt.Sprintf("postgresql://%s:%s@%s:%d/%s?sslmode=%s",
		user, password, host, port, dbname, sslMode)
	log.Printf("Connection string (from config): %s", connStr)

	return connStr
}

// Connect connects to the database
func Connect() (*gorm.DB, error) {
	// Prioritize the HANDRECEIPT_DATABASE_URL environment variable
	dsn := os.Getenv("HANDRECEIPT_DATABASE_URL")
	if dsn != "" {
		log.Printf("Attempting to connect using DSN from HANDRECEIPT_DATABASE_URL")
	} else {
		// Fallback to constructing DSN from config file if environment variable is not set
		log.Printf("HANDRECEIPT_DATABASE_URL not set, falling back to config file values.")
		host := viper.GetString("database.host")
		port := viper.GetInt("database.port")
		user := viper.GetString("database.user")
		password := viper.GetString("database.password")
		dbname := viper.GetString("database.name")
		sslMode := viper.GetString("database.ssl_mode")

		dsn = fmt.Sprintf("postgresql://%s:%s@%s:%d/%s?sslmode=%s",
			user, password, host, port, dbname, sslMode)
		log.Printf("Attempting to connect using DSN constructed from config: %s", dsn) // Avoid logging password if possible
	}

	// Create a custom logger config
	logConfig := logger.Config{
		SlowThreshold: 200,
		LogLevel:      logger.Info,
		Colorful:      true,
	}

	// Connect to the database
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.New(
			log.New(log.Writer(), "\r\n", log.LstdFlags),
			logConfig,
		),
	})

	if err != nil {
		log.Printf("Failed to connect to database using DSN: %s. Error: %v", dsn, err) // Log the DSN used and the error
		return nil, fmt.Errorf("failed to connect to database: %w", err)               // Wrap the original error
	}
	log.Println("Successfully connected to the database")

	// Set global DB
	DB = db

	return db, nil
}

// Migrate runs auto migration for database models
func Migrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&domain.User{},
		&domain.Property{},
		&domain.Transfer{},
		&domain.Activity{},
	)
}

// CreateDefaultUser creates a default admin user if it doesn't exist
func CreateDefaultUser(db *gorm.DB) error {
	var count int64
	if err := db.Model(&domain.User{}).Count(&count).Error; err != nil {
		return err
	}

	// If there are no users, create a default admin user
	if count == 0 {
		defaultUser := domain.User{
			Username: "admin",
			// Note: This is NOT secure and is just for initial setup
			// In real code, you would hash this password
			Password: "$2b$10$xfTImAQbmP6d7S8JGSLDXeu0yDqLRQbYdJ4Jt.1J0C8vMnGJzPXOS", // "password"
			Name:     "Admin User",
			Rank:     "System Administrator",
		}

		result := db.Create(&defaultUser)
		if result.Error != nil {
			return result.Error
		}

		log.Println("Created default admin user")
	}

	return nil
}
