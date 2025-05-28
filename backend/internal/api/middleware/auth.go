package middleware

import (
	"fmt"
	"net/http"
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
	// Use cookie store for sessions
	store := cookie.NewStore([]byte(viper.GetString("auth.session_secret")))
	store.Options(sessions.Options{
		Path:     "/",
		MaxAge:   int(24 * time.Hour.Seconds()), // 1 day
		HttpOnly: true,
		Secure:   viper.GetString("server.environment") == "production",
	})
	router.Use(sessions.Sessions("handreceipt_session", store))
}

// SessionAuthMiddleware is a middleware for session-based authentication
// This provides compatibility with the existing frontend
func SessionAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		session := sessions.Default(c)
		userID := session.Get("userID")

		if userID == nil {
			// Check if there's a JWT token as backup
			authHeader := c.GetHeader("Authorization")
			if authHeader != "" {
				parts := strings.Split(authHeader, " ")
				if len(parts) == 2 && parts[0] == "Bearer" {
					claims, err := ValidateToken(parts[1])
					if err == nil {
						// Set user ID from JWT claims
						c.Set("userID", claims.UserID)
						// Also set in session
						session.Set("userID", claims.UserID)
						session.Save()
						c.Next()
						return
					}
				}
			}

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
	secret := viper.GetString("auth.jwt_secret")
	if secret == "" {
		// Fallback to environment variable if not in config
		secret = "your-secret-key" // TODO: Use actual secure secret
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
	secret := viper.GetString("auth.jwt_secret")
	if secret == "" {
		// Fallback to environment variable if not in config
		secret = "your-secret-key" // TODO: Use actual secure secret
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
