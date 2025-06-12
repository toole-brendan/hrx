package handlers

import (
	"log"
	"net/http"

	"github.com/gin-contrib/sessions"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/spf13/viper"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/models"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/auth"
	"golang.org/x/crypto/bcrypt"
)

// AuthHandler handles authentication operations
type AuthHandler struct {
	repo       repository.Repository
	jwtService *auth.JWTService
}

// NewAuthHandler creates a new auth handler
func NewAuthHandler(repo repository.Repository) *AuthHandler {
	// Initialize JWT service
	jwtService := auth.NewJWTService(&config.JWTConfig{
		SecretKey:      viper.GetString("jwt.secret_key"),
		AccessExpiry:   viper.GetDuration("jwt.access_expiry"),
		RefreshExpiry:  viper.GetDuration("jwt.refresh_expiry"),
		RefreshEnabled: viper.GetBool("jwt.refresh_enabled"),
		Issuer:         viper.GetString("jwt.issuer"),
		Audience:       viper.GetString("jwt.audience"),
	})

	return &AuthHandler{
		repo:       repo,
		jwtService: jwtService,
	}
}

// Login handles user login
func (h *AuthHandler) Login(c *gin.Context) {
	var credentials models.LoginRequest

	// Validate request body
	if err := c.ShouldBindJSON(&credentials); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Authenticate user by email - repository returns domain.User
	domainUser, err := h.repo.GetUserByEmail(credentials.Email)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Compare passwords
	err = bcrypt.CompareHashAndPassword([]byte(domainUser.PasswordHash), []byte(credentials.Password))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	// Create session
	session := sessions.Default(c)
	sessionID := uuid.New().String()
	session.Set("userID", domainUser.ID)
	session.Set("sessionID", sessionID)

	// Save session with error handling
	if err := session.Save(); err != nil {
		log.Printf("Failed to save session: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create session"})
		return
	}

	// Use new name fields directly
	firstName := domainUser.FirstName
	lastName := domainUser.LastName

	// Convert domain.User to models.User for JWT service
	modelUser := models.User{
		ID:           domainUser.ID,
		UUID:         uuid.New(), // Generate new UUID since domain.User doesn't have it
		Email:        domainUser.Email,
		PasswordHash: domainUser.PasswordHash,
		FirstName:    firstName,
		LastName:     lastName,
		Rank:         domainUser.Rank,
		Unit:         domainUser.Unit,
		Role:         models.UserRole("user"), // Default role
		Status:       models.StatusActive,     // Default status
		CreatedAt:    domainUser.CreatedAt,
		UpdatedAt:    domainUser.UpdatedAt,
	}

	// Generate JWT tokens
	tokenPair, err := h.jwtService.GenerateTokenPair(modelUser, sessionID)
	if err != nil {
		log.Printf("Failed to generate JWT tokens: %v", err)
		// Continue without tokens - session auth will still work
		tokenPair = nil
	}

	// Prepare response
	response := models.LoginResponse{
		User: models.UserDTO{
			ID:        domainUser.ID,
			UUID:      modelUser.UUID,
			Email:     domainUser.Email,
			FirstName: firstName,
			LastName:  lastName,
			Rank:      domainUser.Rank,
			Unit:      domainUser.Unit,
			Role:      modelUser.Role,
			Status:    modelUser.Status,
		},
	}

	// Include tokens in response if available
	if tokenPair != nil {
		response.AccessToken = tokenPair.AccessToken
		response.RefreshToken = tokenPair.RefreshToken
		response.ExpiresAt = tokenPair.ExpiresAt
	}

	c.JSON(http.StatusOK, response)
}

// RefreshToken handles token refresh
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req models.RefreshTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Validate refresh token
	claims, err := h.jwtService.ValidateToken(req.RefreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid refresh token"})
		return
	}

	// Get user from database
	domainUser, err := h.repo.GetUserByID(claims.UserID)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	// Use new name fields directly
	firstName := domainUser.FirstName
	lastName := domainUser.LastName

	// Convert domain.User to models.User
	modelUser := models.User{
		ID:           domainUser.ID,
		UUID:         uuid.New(),
		Email:        domainUser.Email,
		PasswordHash: domainUser.PasswordHash,
		FirstName:    firstName,
		LastName:     lastName,
		Rank:         domainUser.Rank,
		Unit:         domainUser.Unit,
		Role:         models.UserRole("user"),
		Status:       models.StatusActive,
		CreatedAt:    domainUser.CreatedAt,
		UpdatedAt:    domainUser.UpdatedAt,
	}

	// Generate new token pair
	tokenPair, err := h.jwtService.RefreshAccessToken(req.RefreshToken, modelUser)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Failed to refresh token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  tokenPair.AccessToken,
		"refresh_token": tokenPair.RefreshToken,
		"expires_at":    tokenPair.ExpiresAt,
		"token_type":    tokenPair.TokenType,
	})
}

// Register handles user registration
func (h *AuthHandler) Register(c *gin.Context) {
	var createUserInput models.CreateUserRequest

	// Validate request body
	if err := c.ShouldBindJSON(&createUserInput); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid input format"})
		return
	}

	// Check if email already exists
	_, err := h.repo.GetUserByEmail(createUserInput.Email)
	if err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email already exists"})
		return
	}

	// Hash password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(createUserInput.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process request"})
		return
	}

	// Create domain.User for repository (since repository expects domain.User)
	domainUser := &domain.User{
		Email:        createUserInput.Email,
		PasswordHash: string(hashedPassword),
		FirstName:    createUserInput.FirstName,
		LastName:     createUserInput.LastName,
		Rank:         createUserInput.Rank,
		Unit:         createUserInput.Unit,
	}

	if err := h.repo.CreateUser(domainUser); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	// Create session
	session := sessions.Default(c)
	sessionID := uuid.New().String()
	session.Set("userID", domainUser.ID)
	session.Set("sessionID", sessionID)

	if err := session.Save(); err != nil {
		log.Printf("Failed to save session for new user: %v", err)
	}

	// Create models.User for JWT generation
	modelUser := models.User{
		ID:           domainUser.ID,
		UUID:         uuid.New(),
		Email:        createUserInput.Email,
		PasswordHash: domainUser.PasswordHash,
		FirstName:    createUserInput.FirstName,
		LastName:     createUserInput.LastName,
		Rank:         createUserInput.Rank,
		Unit:         createUserInput.Unit,
		Role:         createUserInput.Role,
		Status:       models.StatusActive,
		CreatedAt:    domainUser.CreatedAt,
		UpdatedAt:    domainUser.UpdatedAt,
	}

	// Generate token pair
	tokenPair, err := h.jwtService.GenerateTokenPair(modelUser, sessionID)
	if err != nil {
		log.Printf("Failed to generate tokens for new user: %v", err)
		tokenPair = nil
	}

	// Prepare response
	response := models.LoginResponse{
		User: models.UserDTO{
			ID:        domainUser.ID,
			UUID:      modelUser.UUID,
			Email:     modelUser.Email,
			FirstName: createUserInput.FirstName,
			LastName:  createUserInput.LastName,
			Rank:      createUserInput.Rank,
			Unit:      createUserInput.Unit,
			Role:      models.UserRole("user"),
			Status:    models.StatusActive,
			CreatedAt: domainUser.CreatedAt,
			UpdatedAt: domainUser.UpdatedAt,
		},
	}

	// Include tokens if available
	if tokenPair != nil {
		response.AccessToken = tokenPair.AccessToken
		response.RefreshToken = tokenPair.RefreshToken
		response.ExpiresAt = tokenPair.ExpiresAt
	}

	c.JSON(http.StatusCreated, response)
}

// GetCurrentUser returns the currently authenticated user
func (h *AuthHandler) GetCurrentUser(c *gin.Context) {
	// Get user ID from context (set by auth middleware)
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Retrieve user from database
	domainUser, err := h.repo.GetUserByID(userID.(uint))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve user"})
		return
	}

	// Use new name fields directly
	firstName := domainUser.FirstName
	lastName := domainUser.LastName

	// Return user data - convert domain.User to UserDTO
	c.JSON(http.StatusOK, gin.H{
		"user": models.UserDTO{
			ID:        domainUser.ID,
			UUID:      uuid.New(), // Generate since domain.User doesn't have it
			Email:     domainUser.Email,
			FirstName: firstName,
			LastName:  lastName,
			Rank:      domainUser.Rank,
			Unit:      domainUser.Unit,
			Role:      models.UserRole("user"),
			Status:    models.StatusActive,
			CreatedAt: domainUser.CreatedAt,
			UpdatedAt: domainUser.UpdatedAt,
		},
	})
}

// Logout handles user logout
func (h *AuthHandler) Logout(c *gin.Context) {
	session := sessions.Default(c)
	session.Clear()
	if err := session.Save(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clear session"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}
