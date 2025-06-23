package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"github.com/spf13/viper"
	"github.com/toole-brendan/handreceipt-go/internal/api/handlers"
	"github.com/toole-brendan/handreceipt-go/internal/api/routes"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/platform/database"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/notification"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
	"github.com/toole-brendan/handreceipt-go/internal/services/ai"
	"github.com/toole-brendan/handreceipt-go/internal/services/ocr"
	"github.com/toole-brendan/handreceipt-go/internal/services"
)

// min returns the smaller of two integers (helper function for older Go versions)
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

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

	// Initialize Storage Service (MinIO or Azure Blob)
	var storageService storage.StorageService

	// Check storage type configuration
	storageType := viper.GetString("storage.type")
	if storageType == "" {
		storageType = os.Getenv("HANDRECEIPT_STORAGE_TYPE")
	}

	// Default to MinIO if not specified
	if storageType == "" {
		storageType = "minio"
	}

	switch storageType {
	case "azure_blob":
		// Initialize Azure Blob Storage
		connectionString := viper.GetString("storage.connection_string")
		if connectionString == "" {
			connectionString = os.Getenv("HANDRECEIPT_STORAGE_CONNECTION_STRING")
		}
		containerName := viper.GetString("storage.container_name")
		if containerName == "" {
			containerName = os.Getenv("HANDRECEIPT_STORAGE_CONTAINER_NAME")
		}
		if containerName == "" {
			containerName = "documents" // Default container name
		}

		if connectionString != "" {
			azureService, err := storage.NewAzureBlobService(connectionString, containerName)
			if err != nil {
				log.Printf("WARNING: Failed to initialize Azure Blob storage service: %v", err)
			} else {
				storageService = azureService
				log.Printf("Azure Blob Storage service initialized successfully")
			}
		} else {
			log.Printf("WARNING: Azure Blob Storage connection string not provided")
		}

	default: // "minio" or any other value defaults to MinIO
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

		minioService, err := storage.NewMinIOService(minioEndpoint, minioAccessKey, minioSecretKey, minioBucket, minioUseSSL)
		if err != nil {
			log.Printf("WARNING: Failed to initialize MinIO storage service: %v", err)
		} else {
			storageService = minioService
			log.Printf("MinIO storage service initialized successfully")
		}
	}

	if storageService == nil {
		log.Printf("WARNING: No storage service initialized - photo uploads will not work")
	}

	// Initialize Ledger Service based on configuration
	var ledgerService ledger.LedgerService

	// Debug logging for ledger configuration
	log.Printf("Initializing ledger service for environment: %s", environment)

	// In production or when explicitly enabled, use a real ledger service
	if environment == "production" || viper.GetBool("ledger.enabled") {
		// Try PostgreSQL Ledger Service first (uses same DB connection)
		log.Println("Attempting to initialize PostgreSQL Ledger service...")
		postgresLedger, err := ledger.NewPostgresLedgerService(db)
		if err != nil {
			log.Printf("Failed to initialize PostgreSQL Ledger service: %v", err)
			log.Printf("WARNING: No ledger service available - audit trail functionality will be disabled")
			ledgerService = nil
		} else {
			ledgerService = postgresLedger
			log.Println("Successfully initialized PostgreSQL Ledger service")
		}
	} else {
		// In development, ledger is optional
		log.Println("Development environment - ledger service is optional")

		// Still try to use PostgreSQL ledger if available
		postgresLedger, err := ledger.NewPostgresLedgerService(db)
		if err != nil {
			log.Printf("INFO: Ledger service not initialized in development: %v", err)
			ledgerService = nil
		} else {
			ledgerService = postgresLedger
			log.Println("PostgreSQL Ledger service initialized for development")
		}
	}

	if ledgerService != nil {
		if err := ledgerService.Initialize(); err != nil {
			log.Printf("WARNING: Failed to initialize Ledger service: %v", err)
			log.Printf("Application will continue without ledger functionality.")
			ledgerService = nil
		}
		// Note: Consider adding proper shutdown handling to call ledgerService.Close()
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

	// Create notification hub and start it
	notificationHub := notification.NewHub()
	go notificationHub.Run()
	log.Println("WebSocket notification hub started")

	// Initialize Azure OCR service
	azureOCREndpoint := os.Getenv("AZURE_OCR_ENDPOINT")
	azureOCRKey := os.Getenv("AZURE_OCR_KEY")
	var ocrService *ocr.AzureOCRService
	if azureOCREndpoint != "" && azureOCRKey != "" {
		ocrService = ocr.NewAzureOCRService(azureOCREndpoint, azureOCRKey)
		log.Println("Azure OCR service initialized")
	}

	// Initialize DA2062 AI handler
	var da2062AIHandler *handlers.DA2062AIHandler
	if ocrService != nil {
		// Initialize AI service for DA2062
		azureOpenAIEndpoint := viper.GetString("azure.openai.endpoint")
		azureOpenAIKey := viper.GetString("azure.openai.api_key")
		
		if azureOpenAIEndpoint != "" && azureOpenAIKey != "" {
			// Create AI config
			aiConfig := ai.Config{
				Provider:       "azure_openai",
				Endpoint:       azureOpenAIEndpoint,
				APIKey:         azureOpenAIKey,
				Model:          viper.GetString("azure.openai.model"),
				MaxTokens:      viper.GetInt("azure.openai.max_tokens"),
				Temperature:    viper.GetFloat64("azure.openai.temperature"),
				TimeoutSeconds: viper.GetInt("azure.openai.timeout_seconds"),
				RetryAttempts:  viper.GetInt("azure.openai.retry_attempts"),
				CacheEnabled:   viper.GetBool("azure.openai.cache_enabled"),
				CacheTTL:       viper.GetDuration("azure.openai.cache_ttl"),
			}
			
			// Set defaults if not configured
			if aiConfig.Model == "" {
				aiConfig.Model = "gpt-4-turbo"
			}
			if aiConfig.MaxTokens == 0 {
				aiConfig.MaxTokens = 2000
			}
			if aiConfig.Temperature == 0 {
				aiConfig.Temperature = 0.2
			}
			if aiConfig.TimeoutSeconds == 0 {
				aiConfig.TimeoutSeconds = 60
			}
			if aiConfig.RetryAttempts == 0 {
				aiConfig.RetryAttempts = 3
			}
			if aiConfig.CacheTTL == 0 {
				aiConfig.CacheTTL = 5 * time.Minute
			}
			
			// Create Azure OpenAI service
			azureAIService, err := ai.NewAzureOpenAIDA2062Service(aiConfig)
			if err != nil {
				log.Printf("WARNING: Failed to initialize Azure OpenAI service: %v", err)
			} else {
				// Create enhanced DA2062 service
				enhancedDA2062Service := ocr.NewEnhancedDA2062Service(ocrService, azureAIService)
				
				// Create DA2062 AI handler
				da2062AIHandler = handlers.NewDA2062AIHandler(
					enhancedDA2062Service,
					azureAIService,
					ledgerService,
					repo,
					nsnService,
				)
				log.Println("DA2062 AI handler initialized successfully with Azure OpenAI")
			}
		} else {
			log.Println("Azure OpenAI not configured - DA2062 AI features will be disabled")
		}
	}

	// Initialize Demo Refresh Service (only in production)
	if environment == "production" {
		// Get the underlying *sql.DB from GORM
		sqlDB, err := db.DB()
		if err != nil {
			log.Fatalf("Failed to get underlying SQL database: %v", err)
		}
		
		demoRefreshService := services.NewDemoRefreshService(sqlDB)
		// Refresh demo data every 4 hours
		demoRefreshService.Start(4 * time.Hour)
		defer demoRefreshService.Stop()
		log.Println("Demo refresh service started (4-hour interval)")
	}

	// Create Gin router
	router := gin.Default()

	// CORS middleware
	router.Use(corsMiddleware())

	// Setup routes, passing the LedgerService interface, Repository, Storage Service, NSN Service, and Notification Hub
	routes.SetupRoutes(router, ledgerService, repo, storageService, nsnService, notificationHub, da2062AIHandler)

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
	// Check for custom config name from environment
	configName := os.Getenv("HANDRECEIPT_CONFIG_NAME")
	if configName == "" {
		configName = "config"
	}

	// Set configuration name
	viper.SetConfigName(configName)
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

	// Set key replacer to handle dot-to-underscore conversion for environment variables
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	viper.AutomaticEnv() // Automatically use all environment variables

	// Explicitly bind ImmuDB environment variables to config keys
	viper.BindEnv("immudb.host", "HANDRECEIPT_IMMUDB_HOST")
	viper.BindEnv("immudb.port", "HANDRECEIPT_IMMUDB_PORT")
	viper.BindEnv("immudb.username", "HANDRECEIPT_IMMUDB_USERNAME")
	viper.BindEnv("immudb.password", "HANDRECEIPT_IMMUDB_PASSWORD")
	viper.BindEnv("immudb.database", "HANDRECEIPT_IMMUDB_DATABASE")
	viper.BindEnv("immudb.enabled", "HANDRECEIPT_IMMUDB_ENABLED")

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
