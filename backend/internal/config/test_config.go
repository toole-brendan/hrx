package config

import (
	"os"
	"testing"
	"time"
)

// NewTestConfig creates a configuration suitable for testing
func NewTestConfig() *Config {
	// Set test environment variables
	os.Setenv("HR_SERVER_ENVIRONMENT", "test")
	os.Setenv("HR_DATABASE_HOST", "localhost")
	os.Setenv("HR_DATABASE_PORT", "5432")
	os.Setenv("HR_DATABASE_USER", "test")
	os.Setenv("HR_DATABASE_PASSWORD", "test")
	os.Setenv("HR_DATABASE_DB_NAME", "handreceipt_test")
	os.Setenv("HR_JWT_SECRET_KEY", "test-secret-key-for-testing-only")
	os.Setenv("HR_IMMUDB_HOST", "localhost")
	os.Setenv("HR_IMMUDB_PORT", "3322")
	os.Setenv("HR_IMMUDB_USERNAME", "immudb")
	os.Setenv("HR_IMMUDB_PASSWORD", "immudb")
	os.Setenv("HR_MINIO_ENDPOINT", "localhost:9000")
	os.Setenv("HR_MINIO_ACCESS_KEY_ID", "minioadmin")
	os.Setenv("HR_MINIO_SECRET_ACCESS_KEY", "minioadmin")

	// Create config with test values
	cfg := &Config{
		Server: ServerConfig{
			Port:         "8080",
			Host:         "localhost",
			ReadTimeout:  15 * time.Second,
			WriteTimeout: 15 * time.Second,
			Environment:  "test",
		},
		Database: DatabaseConfig{
			Host:            "localhost",
			Port:            5432,
			User:            "test",
			Password:        "test",
			DBName:          "handreceipt_test",
			SSLMode:         "disable",
			MaxIdleConns:    5,
			MaxOpenConns:    10,
			ConnMaxLifetime: 30 * time.Minute,
		},
		JWT: JWTConfig{
			SecretKey:     "test-secret-key-for-testing-only",
			AccessExpiry:  15 * time.Minute,
			RefreshExpiry: 60 * time.Minute,
			Issuer:        "handreceipt-test",
			Audience:      "handreceipt-test-users",
		},
		ImmuDB: ImmuDBConfig{
			Host:     "localhost",
			Port:     3322,
			Username: "immudb",
			Password: "immudb",
			Database: "handreceipt_test",
			Enabled:  true,
		},
		MinIO: MinIOConfig{
			Endpoint:        "localhost:9000",
			AccessKeyID:     "minioadmin",
			SecretAccessKey: "minioadmin",
			UseSSL:          false,
			BucketName:      "handreceipt-test",
			Enabled:         true,
		},
		Security: SecurityConfig{
			SessionTimeout:     3600 * time.Second, // 1 hour for tests
			CORSAllowedOrigins: []string{"*"},      // Allow all origins in test
		},
	}

	return cfg
}

// NewTestConfigWithCleanup creates a test config and returns a cleanup function
func NewTestConfigWithCleanup(t *testing.T) (*Config, func()) {
	cfg := NewTestConfig()

	cleanup := func() {
		// Clean up any test-specific resources
		// This could include dropping test databases, clearing caches, etc.
	}

	return cfg, cleanup
}
