package middleware

import (
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-contrib/sessions"
	"github.com/gin-contrib/sessions/cookie"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v4"
	"github.com/spf13/viper"
)

// SetupSession configures session middleware
func SetupSession(router *gin.Engine) {
	// Get session secret from config or environment
	sessionSecret := viper.GetString("auth.session_secret")
	if sessionSecret == "" {
		sessionSecret = os.Getenv("HANDRECEIPT_AUTH_SESSION_SECRET")
	}
	if sessionSecret == "" {
		// Fallback to a default (NOT RECOMMENDED for production)
		sessionSecret = "default-session-secret-change-this"
		fmt.Println("WARNING: Using default session secret. Set auth.session_secret in config or HANDRECEIPT_AUTH_SESSION_SECRET env var")
	}

	// Use cookie store for sessions
	store := cookie.NewStore([]byte(sessionSecret))

	// Configure cookie options based on environment
	isProduction := viper.GetString("server.environment") == "production"

	// For iOS Capacitor apps, we need special handling
	options := sessions.Options{
		Path:     "/",
		MaxAge:   int(24 * time.Hour.Seconds()), // 1 day
		HttpOnly: true,
		Domain:   "", // Leave empty to use the request domain
	}

	// Handle SameSite and Secure settings carefully
	if isProduction {
		options.Secure = true
		// For production with iOS apps, use SameSite=None
		options.SameSite = http.SameSiteNoneMode
	} else {
		// For development, use Lax to avoid cookie issues
		options.Secure = false
		options.SameSite = http.SameSiteLaxMode
	}

	store.Options(options)
	router.Use(sessions.Sessions("handreceipt_session", store))
}

// SessionAuthMiddleware is a middleware that prioritizes JWT authentication
// Falls back to session-based authentication for backward compatibility
func SessionAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Check JWT token FIRST
		authHeader := c.GetHeader("Authorization")
		fmt.Printf("[Auth Middleware] Authorization header: '%s'\n", authHeader)
		if authHeader != "" {
			parts := strings.Split(authHeader, " ")
			if len(parts) == 2 && parts[0] == "Bearer" {
				fmt.Printf("[Auth Middleware] Attempting JWT validation for token: %s...\n", parts[1][:20])
				claims, err := ValidateToken(parts[1])
				if err == nil {
					// Set user ID from JWT claims
					fmt.Printf("[Auth Middleware] JWT validation successful, userID: %d\n", claims.UserID)
					c.Set("userID", claims.UserID)
					c.Next()
					return
				} else {
					fmt.Printf("[Auth Middleware] JWT validation failed: %v\n", err)
				}
			}
		}

		// Fall back to session for backward compatibility
		session := sessions.Default(c)
		userID := session.Get("userID")
		if userID == nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			c.Abort()
			return
		}

		// Set user ID in context
		c.Set("userID", userID)
		c.Next()
	}
}

// JWTAuthMiddleware is a middleware for JWT authentication
func JWTAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization header is required"})
			c.Abort()
			return
		}

		// Check the format of the Authorization header
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "authorization header format must be Bearer {token}"})
			c.Abort()
			return
		}

		tokenString := parts[1]
		claims, err := ValidateToken(tokenString)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": err.Error()})
			c.Abort()
			return
		}

		// Set user ID from claims in the context for later use
		c.Set("userID", claims.UserID)
		c.Next()
	}
}

// Claims represents the JWT claims
type Claims struct {
	UserID uint `json:"user_id"`
	jwt.RegisteredClaims
}

// GenerateToken generates a new JWT token for a user
func GenerateToken(userID uint) (string, error) {
	// Get token expiry configuration
	expiryStr := viper.GetString("auth.access_token_expiry")
	expiry, err := time.ParseDuration(expiryStr)
	if err != nil {
		expiry = 24 * time.Hour // Default to 24 hours if not specified or invalid
	}

	// Get JWT secret configuration
	secret := viper.GetString("jwt.secret_key")
	if secret == "" {
		// Try environment variable with HANDRECEIPT prefix
		secret = os.Getenv("HANDRECEIPT_JWT_SECRET_KEY")
	}
	if secret == "" {
		// Fallback to default for local development only
		secret = "9xr/uSKNDqOfSPkVOpujQUW3nzll5ykcT8nzu9W9Cvc="
		fmt.Println("WARNING: Using default JWT secret. Set jwt.secret_key in config or HANDRECEIPT_JWT_SECRET_KEY env var")
	}

	// Create the claims
	claims := &Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiry)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			Issuer:    "handreceipt",
			Subject:   fmt.Sprintf("%d", userID),
		},
	}

	// Create token with claims
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)

	// Generate encoded token using the secret signing key
	tokenString, err := token.SignedString([]byte(secret))
	if err != nil {
		return "", fmt.Errorf("failed to generate token: %w", err)
	}

	return tokenString, nil
}

// ValidateToken validates a JWT token and returns the claims
func ValidateToken(tokenString string) (*Claims, error) {
	// Get JWT secret configuration
	secret := viper.GetString("jwt.secret_key")
	if secret == "" {
		// Try environment variable with HANDRECEIPT prefix
		secret = os.Getenv("HANDRECEIPT_JWT_SECRET_KEY")
	}
	if secret == "" {
		// Fallback to default for local development only
		secret = "9xr/uSKNDqOfSPkVOpujQUW3nzll5ykcT8nzu9W9Cvc="
		fmt.Println("WARNING: Using default JWT secret. Set jwt.secret_key in config or HANDRECEIPT_JWT_SECRET_KEY env var")
	}

	// Parse the token
	token, err := jwt.ParseWithClaims(
		tokenString,
		&Claims{},
		func(token *jwt.Token) (interface{}, error) {
			// Validate the signing method
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(secret), nil
		},
	)

	if err != nil {
		return nil, fmt.Errorf("invalid token: %w", err)
	}

	// Extract and validate claims
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, fmt.Errorf("invalid token claims")
	}

	return claims, nil
}
