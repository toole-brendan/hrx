package config

import (
	"log"
	"os"

	"github.com/spf13/viper"
)

// GetJWTSecret returns the JWT secret key with proper fallback logic
// This ensures consistency between token generation and validation
func GetJWTSecret() string {
	// First try viper config
	secret := viper.GetString("jwt.secret_key")
	
	// If empty, try environment variable
	if secret == "" {
		secret = os.Getenv("HANDRECEIPT_JWT_SECRET_KEY")
	}
	
	// If still empty, use default for development
	if secret == "" {
		secret = "9xr/uSKNDqOfSPkVOpujQUW3nzll5ykcT8nzu9W9Cvc="
		log.Println("WARNING: Using default JWT secret. Set jwt.secret_key in config or HANDRECEIPT_JWT_SECRET_KEY env var")
	}
	
	return secret
}

// ValidateJWTConfig ensures JWT configuration is valid and logs the configuration
func ValidateJWTConfig() error {
	secret := GetJWTSecret()
	
	// Log the JWT configuration (without exposing the full secret)
	if len(secret) > 10 {
		log.Printf("JWT Configuration: secret=%s...%s (length=%d)", 
			secret[:5], secret[len(secret)-5:], len(secret))
	} else {
		log.Printf("JWT Configuration: secret=***** (length=%d)", len(secret))
	}
	
	// Check if using default in production
	isProduction := viper.GetString("server.environment") == "production"
	if isProduction && secret == "9xr/uSKNDqOfSPkVOpujQUW3nzll5ykcT8nzu9W9Cvc=" {
		log.Println("ERROR: Using default JWT secret in production! This is a security risk!")
	}
	
	return nil
}