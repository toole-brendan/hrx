package middleware

import (
	"log"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/spf13/viper"
)

// CORSMiddleware returns a configured CORS middleware handler
func CORSMiddleware() gin.HandlerFunc {
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

// SimpleCORSMiddleware provides a simple CORS implementation without external dependencies
func SimpleCORSMiddleware() gin.HandlerFunc {
	// Get allowed origins from environment or use defaults
	allowedOrigins := []string{
		"https://your-web-domain.com", // Replace with your actual web domain
		"capacitor://localhost",       // For iOS app
		"http://localhost:3000",       // For local development
		"http://localhost:5173",       // For Vite development server
	}

	// Check if CORS_ORIGINS is set in environment
	if envOrigins := os.Getenv("CORS_ORIGINS"); envOrigins != "" {
		allowedOrigins = strings.Split(envOrigins, ",")
		for i := range allowedOrigins {
			allowedOrigins[i] = strings.TrimSpace(allowedOrigins[i])
		}
	}

	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")

		// Check if the origin is allowed
		isAllowed := false
		for _, allowed := range allowedOrigins {
			if origin == allowed {
				isAllowed = true
				break
			}
		}

		// If origin is allowed, set it; otherwise check if we're in development
		if isAllowed {
			c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
		} else if origin != "" {
			// For development, allow any origin
			if viper.GetString("server.environment") != "production" {
				c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
			}
		}

		c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Origin, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization")
		c.Writer.Header().Set("Access-Control-Expose-Headers", "Content-Length")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Max-Age", "43200") // 12 hours

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
