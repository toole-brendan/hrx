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
	
	// No default fallback - fail fast if not configured
	if secret == "" {
		log.Fatal("JWT secret not configured. Set jwt.secret_key in config or HANDRECEIPT_JWT_SECRET_KEY env var")
	}
	
	return secret
}

// ValidateJWTConfig ensures JWT configuration is valid and logs the configuration
func ValidateJWTConfig() error {
	secret := GetJWTSecret()
	
	// Log the JWT secret length for debugging
	log.Printf("JWT secret loaded; len=%d", len(secret))
	
	// Additional check for production
	isProduction := viper.GetString("server.environment") == "production"
	if isProduction && len(secret) < 32 {
		log.Println("WARNING: JWT secret length is less than 32 characters in production")
	}
	
	return nil
}