package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/spf13/viper"
	"github.com/toole-brendan/handreceipt-go/internal/api/routes"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/platform/database"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
)

func main() {
	// Setup configuration
	if err := setupConfig(); err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	// Debug configuration values
	dbName := viper.GetString("database.name")
	dbUser := viper.GetString("database.user")
	dbHost := viper.GetString("database.host")
	log.Printf("Database config: name=%s, user=%s, host=%s", dbName, dbUser, dbHost)

	// Setup environment
	environment := viper.GetString("server.environment")
	if environment == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Connect to database
	db, err := database.Connect()
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Run migrations
	if err := database.Migrate(db); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	// Create default user if needed
	if err := database.CreateDefaultUser(db); err != nil {
		log.Fatalf("Failed to create default user: %v", err)
	}

	// Initialize Repository
	repo := repository.NewPostgresRepository(db)

	// Initialize Ledger Service based on configuration
	var ledgerService ledger.LedgerService

	if environment == "production" || viper.GetBool("immudb.enabled") {
		// Use ImmuDB for ledger service
		immuHost := viper.GetString("immudb.host")
		immuPort := viper.GetInt("immudb.port")
		immuUsername := viper.GetString("immudb.username")
		immuPassword := viper.GetString("immudb.password")
		immuDatabase := viper.GetString("immudb.database")

		var err error
		ledgerService, err = ledger.NewImmuDBLedgerService(immuHost, immuPort, immuUsername, immuPassword, immuDatabase)
		if err != nil {
			log.Fatalf("Failed to initialize ImmuDB Ledger service: %v", err)
		}
		log.Println("Using ImmuDB Ledger")
	} else {
		// Fallback to Azure SQL for development/testing if needed
		connectionString := os.Getenv("AZURE_SQL_LEDGER_CONNECTION_STRING")
		if connectionString != "" {
			var err error
			ledgerService, err = ledger.NewAzureSqlLedgerService(connectionString)
			if err != nil {
				log.Fatalf("Failed to initialize Azure SQL Ledger service: %v", err)
			}
			log.Println("Using Azure SQL Ledger (fallback)")
		} else {
			log.Println("No ledger service configured - using mock/disabled mode")
			// You might want to create a mock ledger service here
		}
	}

	if err := ledgerService.Initialize(); err != nil {
		log.Fatalf("Failed to initialize Ledger service: %v", err)
	}
	// Ensure Close is called on shutdown (using defer in main is tricky, consider signal handling)
	// defer ledgerService.Close()

	// Create Gin router
	router := gin.Default()

	// CORS middleware
	router.Use(corsMiddleware())

	// Setup routes, passing the LedgerService interface and Repository
	routes.SetupRoutes(router, ledgerService, repo)

	// Get server port, prioritizing environment variable, then config, then default
	var port int
	envPortStr := os.Getenv("HANDRECEIPT_SERVER_PORT")
	if envPortStr != "" {
		fmt.Sscan(envPortStr, &port) // Simple conversion, assumes valid integer
		log.Printf("Using server port from HANDRECEIPT_SERVER_PORT environment variable: %d", port)
	}

	if port == 0 {
		port = viper.GetInt("server.port")
		if port != 0 {
			log.Printf("Using server port from config file: %d", port)
		}
	}

	if port == 0 {
		port = 8080 // Default port if not set by env var or config
		log.Printf("Using default server port: %d", port)
	}

	// Start server
	serverAddr := fmt.Sprintf(":%d", port)
	log.Printf("Starting server on %s (environment: %s)", serverAddr, environment)
	if err := router.Run(serverAddr); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

// setupConfig loads application configuration from config.yaml
func setupConfig() error {
	// Set configuration name
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")

	// Get executable path
	execPath, err := os.Executable()
	if err != nil {
		log.Printf("Warning: Could not get executable path: %v", err)
		execPath = "."
	}

	// Config can be in multiple locations, check them in order
	viper.AddConfigPath(".")                                   // Current directory
	viper.AddConfigPath("./configs")                           // Configuration directory in current directory
	viper.AddConfigPath(filepath.Join(execPath, ".."))         // Parent directory of executable
	viper.AddConfigPath(filepath.Join(execPath, "../configs")) // Configuration directory in parent of executable
	viper.AddConfigPath("/etc/handreceipt")                    // System directory

	// Set environment variable prefix
	viper.SetEnvPrefix("HANDRECEIPT")
	viper.AutomaticEnv() // Automatically use all environment variables

	// Read configuration
	if err := viper.ReadInConfig(); err != nil {
		// It's only an error if no configuration is found
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			log.Println("Warning: No configuration file found. Using default values and environment variables.")
			return nil
		}
		return fmt.Errorf("error reading config file: %w", err)
	}

	log.Printf("Using config file: %s", viper.ConfigFileUsed())
	return nil
}

// corsMiddleware adds CORS headers to responses
func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", c.Request.Header.Get("Origin"))
		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization")
		c.Writer.Header().Set("Access-Control-Expose-Headers", "Content-Length")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
