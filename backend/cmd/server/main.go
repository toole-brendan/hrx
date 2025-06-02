package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"github.com/toole-brendan/handreceipt-go/internal/api/routes"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/platform/database"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
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

	// Initialize MinIO Storage Service
	minioEndpoint := viper.GetString("minio.endpoint")
	if minioEndpoint == "" {
		minioEndpoint = "localhost:9000" // Default for development
	}
	minioAccessKey := viper.GetString("minio.access_key")
	if minioAccessKey == "" {
		minioAccessKey = os.Getenv("MINIO_ACCESS_KEY")
	}
	minioSecretKey := viper.GetString("minio.secret_key")
	if minioSecretKey == "" {
		minioSecretKey = os.Getenv("MINIO_SECRET_KEY")
	}
	minioBucket := viper.GetString("minio.bucket")
	if minioBucket == "" {
		minioBucket = "handreceipt-photos"
	}
	minioUseSSL := viper.GetBool("minio.use_ssl")

	storageService, err := storage.NewMinIOService(minioEndpoint, minioAccessKey, minioSecretKey, minioBucket, minioUseSSL)
	if err != nil {
		log.Printf("WARNING: Failed to initialize MinIO storage service: %v", err)
		// Storage is not critical for basic operations, so we'll continue
		// but photo uploads won't work
		storageService = nil
	} else {
		log.Printf("MinIO storage service initialized successfully")
	}

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
			log.Println("No ledger service configured - ledger functionality disabled")
			// Ledger service will be nil - routes should handle this gracefully
		}
	}

	if ledgerService != nil {
		if err := ledgerService.Initialize(); err != nil {
			log.Fatalf("Failed to initialize Ledger service: %v", err)
		}
		// Ensure Close is called on shutdown (using defer in main is tricky, consider signal handling)
		// defer ledgerService.Close()
	}

	// Initialize NSN Service
	logger := logrus.New()
	logger.SetLevel(logrus.InfoLevel)

	nsnConfig := &config.NSNConfig{
		CacheEnabled:   viper.GetBool("nsn.cache_enabled"),
		CacheTTL:       viper.GetDuration("nsn.cache_ttl"),
		APIEndpoint:    viper.GetString("nsn.api_endpoint"),
		APIKey:         viper.GetString("nsn.api_key"),
		TimeoutSeconds: viper.GetInt("nsn.timeout_seconds"),
		RateLimitRPS:   viper.GetInt("nsn.rate_limit_rps"),
		BulkBatchSize:  viper.GetInt("nsn.bulk_batch_size"),
		PubLogDataDir:  viper.GetString("nsn.publog_data_dir"),
	}

	// Set defaults if not configured
	if nsnConfig.TimeoutSeconds == 0 {
		nsnConfig.TimeoutSeconds = 30
	}
	if nsnConfig.RateLimitRPS == 0 {
		nsnConfig.RateLimitRPS = 10
	}
	if nsnConfig.BulkBatchSize == 0 {
		nsnConfig.BulkBatchSize = 1000
	}

	nsnService := nsn.NewNSNService(nsnConfig, db, logger)
	if err := nsnService.Initialize(); err != nil {
		log.Printf("WARNING: Failed to initialize NSN service: %v", err)
		// NSN service is not critical, so we continue
	} else {
		log.Println("NSN service initialized successfully")
	}

	// Create Gin router
	router := gin.Default()

	// CORS middleware
	router.Use(corsMiddleware())

	// Setup routes, passing the LedgerService interface, Repository, Storage Service, and NSN Service
	routes.SetupRoutes(router, ledgerService, repo, storageService, nsnService)

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
	// Get allowed origins from config
	var allowedOrigins []string

	// First try to get from config file
	configOrigins := viper.GetStringSlice("security.cors_allowed_origins")
	if len(configOrigins) > 0 {
		allowedOrigins = configOrigins
		log.Printf("Using CORS origins from config: %v", allowedOrigins)
	}

	// Override with environment variable if set
	if envOrigins := os.Getenv("CORS_ORIGINS"); envOrigins != "" {
		allowedOrigins = strings.Split(envOrigins, ",")
		for i := range allowedOrigins {
			allowedOrigins[i] = strings.TrimSpace(allowedOrigins[i])
		}
		log.Printf("Using CORS origins from environment: %v", allowedOrigins)
	}

	// If still empty, use defaults
	if len(allowedOrigins) == 0 {
		allowedOrigins = []string{
			"capacitor://localhost", // For iOS app
			"http://localhost:3000", // For local development
			"http://localhost:5173", // For Vite development server
		}
		log.Printf("Using default CORS origins: %v", allowedOrigins)
	}

	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")

		// Check if the origin is allowed
		isAllowed := false
		for _, allowed := range allowedOrigins {
			if allowed == "*" || origin == allowed {
				isAllowed = true
				break
			}
		}

		// Set CORS headers
		if isAllowed {
			c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
		} else if viper.GetString("server.environment") != "production" && origin != "" {
			// In development, be more permissive
			c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
			log.Printf("WARNING: Allowing origin %s in development mode", origin)
		}

		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Expose-Headers", "Content-Length, X-Session-Token")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Max-Age", "43200") // 12 hours

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
