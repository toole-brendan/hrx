package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/services"
)

// ComponentHandler handles component association operations
type ComponentHandler struct {
	componentService services.ComponentService
	ledgerService    ledger.LedgerService
}

// NewComponentHandler creates a new component handler
func NewComponentHandler(componentService services.ComponentService, ledgerService ledger.LedgerService) *ComponentHandler {
	return &ComponentHandler{
		componentService: componentService,
		ledgerService:    ledgerService,
	}
}

// GetPropertyComponents godoc
// @Summary Get all components attached to a property
// @Description Retrieves all components currently attached to a specific property
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Success 200 {array} domain.PropertyComponent
// @Failure 404 {object} map[string]string
// @Router /api/properties/{id}/components [get]
// @Security BearerAuth
func (h *ComponentHandler) GetPropertyComponents(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	components, err := h.componentService.GetPropertyComponents(c.Request.Context(), uint(propertyID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve components"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"components": components})
}

// AttachComponent godoc
// @Summary Attach a component to a property
// @Description Attaches a component to a property at a specific position
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Param request body services.AttachmentInput true "Attach component request"
// @Success 201 {object} domain.PropertyComponent
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Failure 409 {object} map[string]string
// @Router /api/properties/{id}/components [post]
// @Security BearerAuth
func (h *ComponentHandler) AttachComponent(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	var req services.AttachmentInput
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user ID from context (set by auth middleware)
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Attach the component
	attachment, err := h.componentService.AttachComponent(
		c.Request.Context(),
		uint(propertyID),
		req.ComponentID,
		userID,
		req.Position,
		req.Notes,
	)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Log to immutable ledger
	if err := h.ledgerService.LogComponentAttached(
		uint(propertyID),
		req.ComponentID,
		userID,
		req.Position,
		req.Notes,
	); err != nil {
		// Log error but don't fail the request
		// The attachment was successful, but logging failed
		// In production, you might want to implement retry logic or alerts
		// For now, we'll just log the error and continue
		c.Header("X-Ledger-Warning", "Failed to log to immutable ledger")
	}

	c.JSON(http.StatusCreated, gin.H{"attachment": attachment})
}

// DetachComponent godoc
// @Summary Detach a component from a property
// @Description Removes the attachment between a component and a property
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Param componentId path int true "Component ID"
// @Success 204
// @Failure 404 {object} map[string]string
// @Failure 403 {object} map[string]string
// @Router /api/properties/{id}/components/{componentId} [delete]
// @Security BearerAuth
func (h *ComponentHandler) DetachComponent(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	componentID, err := strconv.ParseUint(c.Param("componentId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid component ID"})
		return
	}

	// Get user ID from context
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Detach the component
	if err := h.componentService.DetachComponent(
		c.Request.Context(),
		uint(propertyID),
		uint(componentID),
		userID,
	); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Log to immutable ledger
	if err := h.ledgerService.LogComponentDetached(
		uint(propertyID),
		uint(componentID),
		userID,
	); err != nil {
		// Log error but don't fail the request
		c.Header("X-Ledger-Warning", "Failed to log to immutable ledger")
	}

	c.Status(http.StatusNoContent)
}

// GetAvailableComponents godoc
// @Summary Get available components for attachment
// @Description Retrieves all components that can be attached to a specific property
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Success 200 {array} domain.Property
// @Failure 404 {object} map[string]string
// @Router /api/properties/{id}/available-components [get]
// @Security BearerAuth
func (h *ComponentHandler) GetAvailableComponents(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	// Get user ID from context
	userIDVal, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userID, ok := userIDVal.(uint)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format in context"})
		return
	}

	// Get available components for the user
	components, err := h.componentService.GetAvailableComponents(
		c.Request.Context(),
		uint(propertyID),
		userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve available components"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"availableComponents": components})
}

// UpdateComponentPosition godoc
// @Summary Update component attachment position
// @Description Updates the position where a component is attached to a property
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Param componentId path int true "Component ID"
// @Param request body services.UpdatePositionInput true "Update position request"
// @Success 200 {object} domain.PropertyComponent
// @Failure 400 {object} map[string]string
// @Failure 404 {object} map[string]string
// @Router /api/properties/{id}/components/{componentId}/position [put]
// @Security BearerAuth
func (h *ComponentHandler) UpdateComponentPosition(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	componentID, err := strconv.ParseUint(c.Param("componentId"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid component ID"})
		return
	}

	var req services.UpdatePositionInput
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Update the position
	if err := h.componentService.UpdateComponentPosition(
		c.Request.Context(),
		uint(propertyID),
		uint(componentID),
		req.Position,
	); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Component position updated successfully"})
}
