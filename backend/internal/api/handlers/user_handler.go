package handlers

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/models"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/notification"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
	"golang.org/x/crypto/bcrypt"
)

// UserHandler handles user-related API requests
type UserHandler struct {
	repo                repository.Repository
	StorageService      storage.StorageService
	NotificationService *notification.Service
}

// NewUserHandler creates a new UserHandler
func NewUserHandler(repo repository.Repository, storageService storage.StorageService, notificationService *notification.Service) *UserHandler {
	return &UserHandler{
		repo:                repo,
		StorageService:      storageService,
		NotificationService: notificationService,
	}
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

	// Send notification to target user
	if h.NotificationService != nil {
		// Get sender's name for the notification
		sender, _ := h.repo.GetUserByID(userID)
		senderName := "A user"
		if sender != nil {
			senderName = fmt.Sprintf("%s %s", sender.FirstName, sender.LastName)
		}
		
		h.NotificationService.NotifyConnectionRequest(
			int(connection.ID),
			int(userID),
			senderName,
			int(req.TargetUserID),
		)
	}

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

	// Send notification when connection is accepted
	if h.NotificationService != nil && req.Status == domain.ConnectionStatusAccepted {
		// Get accepter's name for the notification
		accepter, _ := h.repo.GetUserByID(userID)
		accepterName := "A user"
		if accepter != nil {
			accepterName = fmt.Sprintf("%s %s", accepter.FirstName, accepter.LastName)
		}
		
		h.NotificationService.NotifyConnectionAccepted(
			int(connection.ID),
			int(connection.UserID), // Original requester
			accepterName,
			int(userID), // Person who accepted
		)
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
		user.FirstName = *updateReq.FirstName
	}
	if updateReq.LastName != nil {
		user.LastName = *updateReq.LastName
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

	// Return updated user data using the new fields directly
	firstName := user.FirstName
	lastName := user.LastName

	response := models.UserDTO{
		ID: user.ID,
		// Username:  user.Username, // REMOVED: Username field
		Email:     user.Email,
		FirstName: firstName,
		LastName:  lastName,
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
	err = bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(changePasswordReq.CurrentPassword))
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
	user.PasswordHash = string(hashedPassword)
	if err := h.repo.UpdateUser(user); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update password"})
		return
	}

	// TODO: Invalidate other sessions/tokens for this user for security

	c.JSON(http.StatusOK, gin.H{"message": "Password changed successfully"})
}

// UploadSignature handles user signature upload
func (h *UserHandler) UploadSignature(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	// Get uploaded file
	file, header, err := c.Request.FormFile("signature")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No signature file uploaded"})
		return
	}
	defer file.Close()

	// Validate file type
	contentType := header.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file type. Only images are supported"})
		return
	}

	// Read file data
	fileData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
		return
	}

	// Upload to storage service (assuming Azure Blob or similar)
	ctx := context.Background()
	objectName := fmt.Sprintf("signatures/%d/%d-%s", userID, time.Now().Unix(), header.Filename)

	// Assuming you have a storage service available
	// You'll need to inject this into the handler
	if h.StorageService != nil {
		err = h.StorageService.UploadFile(ctx, objectName, bytes.NewReader(fileData), int64(len(fileData)), contentType)
		if err != nil {
			log.Printf("Failed to upload signature to storage: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store signature"})
			return
		}

		// Get the URL for the uploaded signature
		signatureURL, err := h.StorageService.GetPresignedURL(ctx, objectName, 365*24*time.Hour) // 1 year expiry
		if err != nil {
			// Use direct URL if presigned fails
			signatureURL = fmt.Sprintf("/storage/%s", objectName)
		}

		// Update user with signature URL
		user, err := h.repo.GetUserByID(userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user"})
			return
		}

		user.SignatureURL = &signatureURL
		if err := h.repo.UpdateUser(user); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user signature"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":      "Signature uploaded successfully",
			"signatureUrl": signatureURL,
		})
	} else {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Storage service not configured"})
	}
}

// GetSignature retrieves the user's signature URL
func (h *UserHandler) GetSignature(c *gin.Context) {
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
		return
	}

	user, err := h.repo.GetUserByID(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user"})
		return
	}

	if user.SignatureURL == nil || *user.SignatureURL == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "No signature found for user"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"signatureUrl": *user.SignatureURL,
	})
}

// ExportConnections exports user connections to CSV format
// @Summary Export user connections
// @Description Export all user connections to CSV format
// @Tags Users
// @Produce text/csv
// @Success 200 {string} string "CSV file"
// @Failure 401 {object} map[string]string "Unauthorized"
// @Failure 500 {object} map[string]string "Internal Server Error"
// @Router /users/connections/export [get]
// @Security BearerAuth
func (h *UserHandler) ExportConnections(c *gin.Context) {
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

	// Create CSV content
	var csvBuffer bytes.Buffer
	csvBuffer.WriteString("Name,Email,Rank,Unit,Status,Connected Since\n")

	for _, conn := range connections {
		// Get connected user details
		var connectedUser *domain.User
		if conn.UserID == userID {
			connectedUser, _ = h.repo.GetUserByID(conn.ConnectedUserID)
		} else {
			connectedUser, _ = h.repo.GetUserByID(conn.UserID)
		}

		if connectedUser != nil {
			csvBuffer.WriteString(fmt.Sprintf("%s %s,%s,%s,%s,%s,%s\n",
				connectedUser.FirstName,
				connectedUser.LastName,
				connectedUser.Email,
				connectedUser.Rank,
				connectedUser.Unit,
				conn.ConnectionStatus,
				conn.CreatedAt.Format("2006-01-02"),
			))
		}
	}

	// Set headers for CSV download
	c.Header("Content-Type", "text/csv")
	c.Header("Content-Disposition", "attachment; filename=\"connections.csv\"")
	c.String(http.StatusOK, csvBuffer.String())
}
