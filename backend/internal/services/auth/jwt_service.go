package auth

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/models"
)

var (
	ErrInvalidToken     = errors.New("invalid token")
	ErrExpiredToken     = errors.New("token has expired")
	ErrTokenNotFound    = errors.New("token not found")
	ErrInvalidSignature = errors.New("invalid token signature")
	ErrInvalidClaims    = errors.New("invalid token claims")
)

type JWTService struct {
	config *config.JWTConfig
}

type Claims struct {
	UserID    uint              `json:"user_id"`
	Username  string            `json:"username"`
	Email     string            `json:"email"`
	Role      models.UserRole   `json:"role"`
	Status    models.UserStatus `json:"status"`
	SessionID string            `json:"session_id"`
	TokenType string            `json:"token_type"` // "access" or "refresh"
	jwt.RegisteredClaims
}

type TokenPair struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
	ExpiresAt    time.Time `json:"expires_at"`
	TokenType    string    `json:"token_type"`
}

func NewJWTService(cfg *config.JWTConfig) *JWTService {
	return &JWTService{
		config: cfg,
	}
}

// GenerateTokenPair creates both access and refresh tokens for a user
func (s *JWTService) GenerateTokenPair(user models.User, sessionID string) (*TokenPair, error) {
	// Generate access token
	accessToken, accessExpiresAt, err := s.generateToken(user, sessionID, "access", s.config.AccessExpiry)
	if err != nil {
		return nil, fmt.Errorf("failed to generate access token: %w", err)
	}

	// Generate refresh token if enabled
	var refreshToken string
	if s.config.RefreshEnabled {
		refreshToken, _, err = s.generateToken(user, sessionID, "refresh", s.config.RefreshExpiry)
		if err != nil {
			return nil, fmt.Errorf("failed to generate refresh token: %w", err)
		}
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresAt:    accessExpiresAt,
		TokenType:    "Bearer",
	}, nil
}

// generateToken creates a JWT token with the specified parameters
func (s *JWTService) generateToken(user models.User, sessionID, tokenType string, expiry time.Duration) (string, time.Time, error) {
	now := time.Now()
	expiresAt := now.Add(expiry)

	claims := &Claims{
		UserID:    user.ID,
		Username:  user.Username,
		Email:     user.Email,
		Role:      user.Role,
		Status:    user.Status,
		SessionID: sessionID,
		TokenType: tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.New().String(),
			Subject:   fmt.Sprintf("%d", user.ID),
			Audience:  jwt.ClaimStrings{s.config.Audience},
			Issuer:    s.config.Issuer,
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(s.config.SecretKey))
	if err != nil {
		return "", time.Time{}, fmt.Errorf("failed to sign token: %w", err)
	}

	return tokenString, expiresAt, nil
}

// ValidateToken validates a JWT token and returns the claims
func (s *JWTService) ValidateToken(tokenString string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		// Verify the signing method
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.config.SecretKey), nil
	})

	if err != nil {
		if errors.Is(err, jwt.ErrTokenExpired) {
			return nil, ErrExpiredToken
		}
		if errors.Is(err, jwt.ErrSignatureInvalid) {
			return nil, ErrInvalidSignature
		}
		return nil, fmt.Errorf("%w: %v", ErrInvalidToken, err)
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, ErrInvalidClaims
	}

	// Validate issuer and audience
	if claims.Issuer != s.config.Issuer {
		return nil, fmt.Errorf("invalid issuer: expected %s, got %s", s.config.Issuer, claims.Issuer)
	}

	// Check if the audience contains our expected audience
	audienceValid := false
	for _, aud := range claims.Audience {
		if aud == s.config.Audience {
			audienceValid = true
			break
		}
	}
	if !audienceValid {
		return nil, fmt.Errorf("invalid audience")
	}

	return claims, nil
}

// RefreshAccessToken generates a new access token using a valid refresh token
func (s *JWTService) RefreshAccessToken(refreshTokenString string, user models.User) (*TokenPair, error) {
	if !s.config.RefreshEnabled {
		return nil, errors.New("refresh tokens are disabled")
	}

	// Validate the refresh token
	claims, err := s.ValidateToken(refreshTokenString)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token: %w", err)
	}

	// Ensure it's a refresh token
	if claims.TokenType != "refresh" {
		return nil, errors.New("token is not a refresh token")
	}

	// Ensure the token belongs to the user
	if claims.UserID != user.ID {
		return nil, errors.New("refresh token does not belong to user")
	}

	// Generate new token pair
	return s.GenerateTokenPair(user, claims.SessionID)
}

// ExtractTokenFromHeader extracts the JWT token from the Authorization header
func (s *JWTService) ExtractTokenFromHeader(authHeader string) (string, error) {
	if authHeader == "" {
		return "", errors.New("authorization header is required")
	}

	const bearerPrefix = "Bearer "
	if len(authHeader) < len(bearerPrefix) || authHeader[:len(bearerPrefix)] != bearerPrefix {
		return "", errors.New("authorization header must start with 'Bearer '")
	}

	token := authHeader[len(bearerPrefix):]
	if token == "" {
		return "", errors.New("token is required")
	}

	return token, nil
}

// GetTokenClaims extracts and validates claims from a token string
func (s *JWTService) GetTokenClaims(tokenString string) (*Claims, error) {
	return s.ValidateToken(tokenString)
}

// IsTokenExpired checks if a token is expired without full validation
func (s *JWTService) IsTokenExpired(tokenString string) bool {
	token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
		return []byte(s.config.SecretKey), nil
	})

	if err != nil {
		return true
	}

	claims, ok := token.Claims.(*Claims)
	if !ok {
		return true
	}

	return claims.ExpiresAt.Before(time.Now())
}

// GetTokenExpiry returns the expiry time of a token
func (s *JWTService) GetTokenExpiry(tokenString string) (time.Time, error) {
	claims, err := s.ValidateToken(tokenString)
	if err != nil {
		return time.Time{}, err
	}

	return claims.ExpiresAt.Time, nil
}

// GeneratePasswordResetToken generates a special token for password reset
func (s *JWTService) GeneratePasswordResetToken(user models.User) (string, time.Time, error) {
	now := time.Now()
	expiresAt := now.Add(1 * time.Hour) // Password reset tokens expire in 1 hour

	claims := &Claims{
		UserID:    user.ID,
		Username:  user.Username,
		Email:     user.Email,
		TokenType: "password_reset",
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.New().String(),
			Subject:   fmt.Sprintf("%d", user.ID),
			Audience:  jwt.ClaimStrings{s.config.Audience},
			Issuer:    s.config.Issuer,
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(s.config.SecretKey))
	if err != nil {
		return "", time.Time{}, fmt.Errorf("failed to sign password reset token: %w", err)
	}

	return tokenString, expiresAt, nil
}

// ValidatePasswordResetToken validates a password reset token
func (s *JWTService) ValidatePasswordResetToken(tokenString string) (*Claims, error) {
	claims, err := s.ValidateToken(tokenString)
	if err != nil {
		return nil, err
	}

	if claims.TokenType != "password_reset" {
		return nil, errors.New("token is not a password reset token")
	}

	return claims, nil
}

// GenerateEmailVerificationToken generates a token for email verification
func (s *JWTService) GenerateEmailVerificationToken(user models.User) (string, time.Time, error) {
	now := time.Now()
	expiresAt := now.Add(24 * time.Hour) // Email verification tokens expire in 24 hours

	claims := &Claims{
		UserID:    user.ID,
		Username:  user.Username,
		Email:     user.Email,
		TokenType: "email_verification",
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.New().String(),
			Subject:   fmt.Sprintf("%d", user.ID),
			Audience:  jwt.ClaimStrings{s.config.Audience},
			Issuer:    s.config.Issuer,
			IssuedAt:  jwt.NewNumericDate(now),
			NotBefore: jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(s.config.SecretKey))
	if err != nil {
		return "", time.Time{}, fmt.Errorf("failed to sign email verification token: %w", err)
	}

	return tokenString, expiresAt, nil
}

// ValidateEmailVerificationToken validates an email verification token
func (s *JWTService) ValidateEmailVerificationToken(tokenString string) (*Claims, error) {
	claims, err := s.ValidateToken(tokenString)
	if err != nil {
		return nil, err
	}

	if claims.TokenType != "email_verification" {
		return nil, errors.New("token is not an email verification token")
	}

	return claims, nil
}

// GetUserFromToken extracts user information from a valid token
func (s *JWTService) GetUserFromToken(tokenString string) (*models.UserDTO, error) {
	claims, err := s.ValidateToken(tokenString)
	if err != nil {
		return nil, err
	}

	return &models.UserDTO{
		ID:       claims.UserID,
		Username: claims.Username,
		Email:    claims.Email,
		Role:     claims.Role,
		Status:   claims.Status,
	}, nil
}

// BlacklistToken adds a token to the blacklist (implementation depends on storage)
func (s *JWTService) BlacklistToken(tokenString string) error {
	// This would typically involve storing the token ID in a blacklist
	// Implementation depends on your chosen storage (Redis, database, etc.)
	// For now, we'll return nil as this is a placeholder
	return nil
}

// IsTokenBlacklisted checks if a token is blacklisted
func (s *JWTService) IsTokenBlacklisted(tokenString string) (bool, error) {
	// This would typically involve checking the token ID against a blacklist
	// Implementation depends on your chosen storage (Redis, database, etc.)
	// For now, we'll return false as this is a placeholder
	return false, nil
}
