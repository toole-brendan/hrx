package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
)

// UserHandler handles user-related API requests
type UserHandler struct {
	repo repository.Repository
}

// NewUserHandler creates a new UserHandler
func NewUserHandler(repo repository.Repository) *UserHandler {
	return &UserHandler{repo: repo}
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
