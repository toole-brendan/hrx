package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/models"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"golang.org/x/crypto/bcrypt"
)

// UserHandler handles user-related API requests
type UserHandler struct {
	repo repository.Repository
}

// NewUserHandler creates a new UserHandler
func NewUserHandler(repo repository.Repository) *UserHandler {
	return &UserHandler{repo: repo}
}

// Helper function to get user ID from session (placeholder implementation)
func getUserIDFromSession(c *gin.Context) uint {
	// TODO: Implement proper session/JWT token parsing
	// For now, this is a placeholder - in real implementation, extract from JWT/session
	userID, exists := c.Get("userID")
	if !exists {
		return 0
	}
	if id, ok := userID.(uint); ok {
		return id
	}
	return 0
}

// GetAllUsers godoc
// @Summary Get all users
// @Description Get a list of all registered users
// @Tags Users
// @Produce json
// @Success 200 {array} domain.User
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /users [get]
// @Security BearerAuth
func (h *UserHandler) GetAllUsers(c *gin.Context) {
	users, err := h.repo.GetAllUsers()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch users"})
		return
	}
	c.JSON(http.StatusOK, users)
}

// GetUserByID godoc
// @Summary Get user by ID
// @Description Get details for a specific user by their ID
// @Tags Users
// @Produce json
// @Param id path uint true "User ID"
// @Success 200 {object} domain.User
// @Failure 400 {object} map[string]string "Invalid User ID"
// @Failure 404 {object} map[string]string "User not found"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /users/{id} [get]
// @Security BearerAuth
func (h *UserHandler) GetUserByID(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	user, err := h.repo.GetUserByID(uint(id))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user"})
		return
	}
	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, user)
}

// GetConnections godoc
// @Summary Get user's connections
// @Description Get a list of all connections (friends) for the authenticated user
// @Tags Users
// @Produce json
// @Success 200 {object} map[string]interface{} "connections"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /users/connections [get]
// @Security BearerAuth
func (h *UserHandler) GetConnections(c *gin.Context) {
	userID := getUserIDFromSession(c)
	if userID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	connections, err := h.repo.GetUserConnections(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch connections"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"connections": connections})
}

// SearchUsers godoc
// @Summary Search users to connect
// @Description Search for users by name, phone, or DODID to send connection requests
// @Tags Users
// @Produce json
// @Param q query string true "Search query (name, phone, or DODID)"
// @Success 200 {object} map[string]interface{} "users"
// @Failure 400 {object} map[string]string "Missing search query"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /users/search [get]
// @Security BearerAuth
func (h *UserHandler) SearchUsers(c *gin.Context) {
	query := strings.TrimSpace(c.Query("q"))
	userID := getUserIDFromSession(c)

	if userID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Search query is required"})
		return
	}

	// Search by name, phone, or DODID
	users, err := h.repo.SearchUsers(query, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Search failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}

// SendConnectionRequest godoc
// @Summary Send connection request
// @Description Send a friendship/connection request to another user
// @Tags Users
// @Accept json
// @Produce json
// @Param request body domain.CreateConnectionRequest true "Connection request"
// @Success 201 {object} domain.UserConnection
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 500 {object} map[string]string "Failed to create connection"
// @Router /users/connections [post]
// @Security BearerAuth
func (h *UserHandler) SendConnectionRequest(c *gin.Context) {
	userID := getUserIDFromSession(c)
	if userID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	var req domain.CreateConnectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Prevent self-connection
	if req.TargetUserID == userID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot connect to yourself"})
		return
	}

	connection := domain.UserConnection{
		UserID:           userID,
		ConnectedUserID:  req.TargetUserID,
		ConnectionStatus: domain.ConnectionStatusPending,
	}

	if err := h.repo.CreateConnection(&connection); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create connection"})
		return
	}

	// TODO: Send notification to target user
	// h.notificationService.SendConnectionRequest(userID, req.TargetUserID)

	c.JSON(http.StatusCreated, connection)
}

// UpdateConnectionStatus godoc
// @Summary Accept or reject connection request
// @Description Update the status of a connection request (accept or block)
// @Tags Users
// @Accept json
// @Produce json
// @Param connectionId path string true "Connection ID"
// @Param request body domain.UpdateConnectionRequest true "Status update"
// @Success 200 {object} domain.UserConnection
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 403 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "Connection not found"
// @Failure 500 {object} map[string]string "Failed to update connection"
// @Router /users/connections/{connectionId} [patch]
// @Security BearerAuth
func (h *UserHandler) UpdateConnectionStatus(c *gin.Context) {
	connectionIDParam := c.Param("connectionId")
	userID := getUserIDFromSession(c)

	if userID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	connectionID, err := strconv.ParseUint(connectionIDParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid connection ID"})
		return
	}

	var req domain.UpdateConnectionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Verify user is the recipient of the connection request
	connection, err := h.repo.GetConnectionByID(uint(connectionID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch connection"})
		return
	}

	if connection == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Connection not found"})
		return
	}

	if connection.ConnectedUserID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized to modify this connection"})
		return
	}

	connection.ConnectionStatus = req.Status
	if err := h.repo.UpdateConnection(connection); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update connection"})
		return
	}

	c.JSON(http.StatusOK, connection)
}

// UpdateUserProfile godoc
// @Summary Update user profile
// @Description Update the authenticated user's profile information
// @Tags Users
// @Accept json
// @Produce json
// @Param id path uint true "User ID"
// @Param request body models.UpdateUserRequest true "Profile update data"
// @Success 200 {object} models.UserDTO "Updated user profile"
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 403 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "User not found"
// @Failure 500 {object} map[string]string "Failed to update profile"
// @Router /users/{id} [patch]
// @Security BearerAuth
func (h *UserHandler) UpdateUserProfile(c *gin.Context) {
	userIDParam := c.Param("id")
	currentUserID := getUserIDFromSession(c)

	if currentUserID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	targetUserID, err := strconv.ParseUint(userIDParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Users can only update their own profile (unless admin - TODO: implement admin check)
	if currentUserID != uint(targetUserID) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Can only update your own profile"})
		return
	}

	var updateReq models.UpdateUserRequest
	if err := c.ShouldBindJSON(&updateReq); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
		return
	}

	// Get the current user from database
	user, err := h.repo.GetUserByID(currentUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user"})
		return
	}
	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Update allowed fields
	if updateReq.Email != nil {
		user.Email = *updateReq.Email
	}
	if updateReq.FirstName != nil {
		// Domain User has "Name" field, we'll update it with first name
		if updateReq.LastName != nil {
			user.Name = *updateReq.FirstName + " " + *updateReq.LastName
		} else {
			user.Name = *updateReq.FirstName
		}
	}
	if updateReq.Rank != nil {
		user.Rank = *updateReq.Rank
	}
	if updateReq.Unit != nil {
		user.Unit = *updateReq.Unit
	}

	// Save changes to database
	if err := h.repo.UpdateUser(user); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
		return
	}

	// Return updated user data
	response := models.UserDTO{
		ID:        user.ID,
		Username:  user.Username,
		Email:     user.Email,
		FirstName: user.Name, // Since domain.User only has Name
		LastName:  "",
		Rank:      user.Rank,
		Unit:      user.Unit,
		CreatedAt: user.CreatedAt,
		UpdatedAt: user.UpdatedAt,
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Profile updated successfully",
		"user":    response,
	})
}

// ChangePassword godoc
// @Summary Change user password
// @Description Change the authenticated user's password
// @Tags Users
// @Accept json
// @Produce json
// @Param id path uint true "User ID"
// @Param request body models.ChangePasswordRequest true "Password change data"
// @Success 200 {object} map[string]string "Password updated successfully"
// @Failure 400 {object} map[string]string "Invalid request"
// @Failure 401 {object} map[string]string "Current password incorrect"
// @Failure 403 {object} map[string]string "Unauthorized"
// @Failure 404 {object} map[string]string "User not found"
// @Failure 500 {object} map[string]string "Failed to update password"
// @Router /users/{id}/password [post]
// @Security BearerAuth
func (h *UserHandler) ChangePassword(c *gin.Context) {
	userIDParam := c.Param("id")
	currentUserID := getUserIDFromSession(c)

	if currentUserID == 0 {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	targetUserID, err := strconv.ParseUint(userIDParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Users can only change their own password (unless admin - TODO: implement admin check)
	if currentUserID != uint(targetUserID) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Can only change your own password"})
		return
	}

	var changePasswordReq models.ChangePasswordRequest
	if err := c.ShouldBindJSON(&changePasswordReq); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request data"})
		return
	}

	// Get the current user from database
	user, err := h.repo.GetUserByID(currentUserID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user"})
		return
	}
	if user == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Verify current password
	err = bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(changePasswordReq.CurrentPassword))
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Current password is incorrect"})
		return
	}

	// Hash the new password
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(changePasswordReq.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to secure new password"})
		return
	}

	// Update password in database
	user.Password = string(hashedPassword)
	if err := h.repo.UpdateUser(user); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update password"})
		return
	}

	// TODO: Invalidate other sessions/tokens for this user for security

	c.JSON(http.StatusOK, gin.H{"message": "Password changed successfully"})
}
