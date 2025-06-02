// backend/internal/api/handlers/component_handler.go
package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/handreceipt/backend/internal/models"
	"github.com/handreceipt/backend/internal/services"
)

type ComponentHandler struct {
	componentService services.ComponentService
	propertyService  services.PropertyService
	ledgerService    services.LedgerService
}

func NewComponentHandler(
	componentService services.ComponentService,
	propertyService services.PropertyService,
	ledgerService services.LedgerService,
) *ComponentHandler {
	return &ComponentHandler{
		componentService: componentService,
		propertyService:  propertyService,
		ledgerService:    ledgerService,
	}
}

// AttachComponentRequest represents the request to attach a component
type AttachComponentRequest struct {
	ComponentID uint   `json:"component_id" binding:"required"`
	Position    string `json:"position"`
	Notes       string `json:"notes"`
}

// UpdatePositionRequest represents the request to update component position
type UpdatePositionRequest struct {
	Position string `json:"position" binding:"required"`
}

// GetPropertyComponents godoc
// @Summary Get all components attached to a property
// @Description Retrieves all components currently attached to a specific property
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Success 200 {array} models.PropertyComponent
// @Failure 404 {object} ErrorResponse
// @Router /api/properties/{id}/components [get]
func (h *ComponentHandler) GetPropertyComponents(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	userID := c.GetUint("userID")

	// Verify user owns the property or has permission to view
	property, err := h.propertyService.GetProperty(c.Request.Context(), uint(propertyID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}

	if property.OwnerID != userID && !h.hasViewPermission(c, userID, property) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Permission denied"})
		return
	}

	components, err := h.componentService.GetPropertyComponents(c.Request.Context(), uint(propertyID))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve components"})
		return
	}

	c.JSON(http.StatusOK, components)
}

// AttachComponent godoc
// @Summary Attach a component to a property
// @Description Attaches a component to a property at a specific position
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Param request body AttachComponentRequest true "Attach component request"
// @Success 201 {object} models.PropertyComponent
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 409 {object} ErrorResponse
// @Router /api/properties/{id}/components [post]
func (h *ComponentHandler) AttachComponent(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	var req AttachComponentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID := c.GetUint("userID")

	// Verify user owns both the parent property and the component
	parentProperty, err := h.propertyService.GetProperty(c.Request.Context(), uint(propertyID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Parent property not found"})
		return
	}

	if parentProperty.OwnerID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You must own the parent property to attach components"})
		return
	}

	componentProperty, err := h.propertyService.GetProperty(c.Request.Context(), req.ComponentID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Component property not found"})
		return
	}

	if componentProperty.OwnerID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "You must own the component to attach it"})
		return
	}

	// Validate attachment compatibility
	if err := h.componentService.ValidateAttachment(
		c.Request.Context(),
		uint(propertyID),
		req.ComponentID,
		req.Position,
	); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Create the attachment
	attachment, err := h.componentService.AttachComponent(
		c.Request.Context(),
		uint(propertyID),
		req.ComponentID,
		userID,
		req.Position,
		req.Notes,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to attach component"})
		return
	}

	// Log to immutable ledger
	h.ledgerService.LogEvent(c.Request.Context(), models.LedgerEvent{
		EventType: "COMPONENT_ATTACHED",
		UserID:    userID,
		EntityID:  strconv.Itoa(int(propertyID)),
		EntityType: "property",
		Details: map[string]interface{}{
			"parent_property_id": propertyID,
			"component_id":       req.ComponentID,
			"position":          req.Position,
		},
	})

	c.JSON(http.StatusCreated, attachment)
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
// @Failure 404 {object} ErrorResponse
// @Failure 403 {object} ErrorResponse
// @Router /api/properties/{id}/components/{componentId} [delete]
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

	userID := c.GetUint("userID")

	// Verify user owns the parent property
	property, err := h.propertyService.GetProperty(c.Request.Context(), uint(propertyID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}

	if property.OwnerID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Permission denied"})
		return
	}

	// Detach the component
	if err := h.componentService.DetachComponent(
		c.Request.Context(),
		uint(propertyID),
		uint(componentID),
		userID,
	); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to detach component"})
		return
	}

	// Log to immutable ledger
	h.ledgerService.LogEvent(c.Request.Context(), models.LedgerEvent{
		EventType:  "COMPONENT_DETACHED",
		UserID:     userID,
		EntityID:   strconv.Itoa(int(propertyID)),
		EntityType: "property",
		Details: map[string]interface{}{
			"parent_property_id": propertyID,
			"component_id":       componentID,
		},
	})

	c.Status(http.StatusNoContent)
}

// GetAvailableComponents godoc
// @Summary Get available components for attachment
// @Description Retrieves all components that can be attached to a specific property
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Success 200 {array} models.Property
// @Failure 404 {object} ErrorResponse
// @Router /api/properties/{id}/available-components [get]
func (h *ComponentHandler) GetAvailableComponents(c *gin.Context) {
	propertyID, err := strconv.ParseUint(c.Param("id"), 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid property ID"})
		return
	}

	userID := c.GetUint("userID")

	// Get available components owned by the user
	components, err := h.componentService.GetAvailableComponents(
		c.Request.Context(),
		uint(propertyID),
		userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve available components"})
		return
	}

	c.JSON(http.StatusOK, components)
}

// UpdateComponentPosition godoc
// @Summary Update component attachment position
// @Description Updates the position where a component is attached to a property
// @Tags components
// @Accept json
// @Produce json
// @Param id path int true "Property ID"
// @Param componentId path int true "Component ID"
// @Param request body UpdatePositionRequest true "Update position request"
// @Success 200 {object} models.PropertyComponent
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Router /api/properties/{id}/components/{componentId}/position [put]
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

	var req UpdatePositionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	userID := c.GetUint("userID")

	// Verify ownership
	property, err := h.propertyService.GetProperty(c.Request.Context(), uint(propertyID))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
		return
	}

	if property.OwnerID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Permission denied"})
		return
	}

	// Update position
	updated, err := h.componentService.UpdateComponentPosition(
		c.Request.Context(),
		uint(propertyID),
		uint(componentID),
		req.Position,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update position"})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (h *ComponentHandler) hasViewPermission(c *gin.Context, userID uint, property *models.Property) bool {
	// Check if user has special roles or permissions
	// This could be extended based on your permission system
	userRole := c.GetString("userRole")
	return userRole == "admin" || userRole == "property_officer"
}

// backend/internal/services/component_service.go
package services

import (
	"context"
	"errors"
	"fmt"

	"github.com/handreceipt/backend/internal/models"
	"github.com/handreceipt/backend/internal/repository"
	"gorm.io/gorm"
)

type ComponentService interface {
	AttachComponent(ctx context.Context, parentID, componentID uint, userID uint, position, notes string) (*models.PropertyComponent, error)
	DetachComponent(ctx context.Context, parentID, componentID uint, userID uint) error
	GetPropertyComponents(ctx context.Context, propertyID uint) ([]models.PropertyComponent, error)
	GetAvailableComponents(ctx context.Context, propertyID uint, userID uint) ([]models.Property, error)
	ValidateAttachment(ctx context.Context, parentID, componentID uint, position string) error
	UpdateComponentPosition(ctx context.Context, parentID, componentID uint, position string) (*models.PropertyComponent, error)
}

type componentService struct {
	db              *gorm.DB
	propertyRepo    repository.PropertyRepository
	componentRepo   repository.ComponentRepository
}

func NewComponentService(
	db *gorm.DB,
	propertyRepo repository.PropertyRepository,
	componentRepo repository.ComponentRepository,
) ComponentService {
	return &componentService{
		db:            db,
		propertyRepo:  propertyRepo,
		componentRepo: componentRepo,
	}
}

func (s *componentService) AttachComponent(ctx context.Context, parentID, componentID uint, userID uint, position, notes string) (*models.PropertyComponent, error) {
	// Start transaction
	tx := s.db.WithContext(ctx).Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Create the attachment
	attachment := &models.PropertyComponent{
		ParentPropertyID:    parentID,
		ComponentPropertyID: componentID,
		AttachedByUserID:   userID,
		Position:           position,
		Notes:              notes,
		AttachmentType:     "field", // Default type
	}

	if err := s.componentRepo.CreateAttachment(ctx, tx, attachment); err != nil {
		tx.Rollback()
		return nil, err
	}

	// Update component property status
	if err := s.propertyRepo.UpdatePropertyStatus(ctx, tx, componentID, "attached"); err != nil {
		tx.Rollback()
		return nil, err
	}

	// Commit transaction
	if err := tx.Commit().Error; err != nil {
		return nil, err
	}

	// Load full attachment with relationships
	return s.componentRepo.GetAttachment(ctx, attachment.ID)
}

func (s *componentService) DetachComponent(ctx context.Context, parentID, componentID uint, userID uint) error {
	tx := s.db.WithContext(ctx).Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Find and delete the attachment
	if err := s.componentRepo.DeleteAttachment(ctx, tx, parentID, componentID); err != nil {
		tx.Rollback()
		return err
	}

	// Update component property status back to available
	if err := s.propertyRepo.UpdatePropertyStatus(ctx, tx, componentID, "available"); err != nil {
		tx.Rollback()
		return err
	}

	return tx.Commit().Error
}

func (s *componentService) GetPropertyComponents(ctx context.Context, propertyID uint) ([]models.PropertyComponent, error) {
	return s.componentRepo.GetPropertyComponents(ctx, propertyID)
}

func (s *componentService) GetAvailableComponents(ctx context.Context, propertyID uint, userID uint) ([]models.Property, error) {
	// Get parent property to check compatibility
	parentProperty, err := s.propertyRepo.GetProperty(ctx, propertyID)
	if err != nil {
		return nil, err
	}

	// Get all user's properties that are attachable and not currently attached
	properties, err := s.propertyRepo.GetUserProperties(ctx, userID)
	if err != nil {
		return nil, err
	}

	availableComponents := []models.Property{}
	for _, prop := range properties {
		// Skip if not attachable or is the parent property itself
		if !prop.IsAttachable || prop.ID == propertyID {
			continue
		}

		// Skip if already attached to something
		isAttached, err := s.componentRepo.IsComponentAttached(ctx, prop.ID)
		if err != nil {
			return nil, err
		}
		if isAttached {
			continue
		}

		// Check compatibility
		if s.isCompatible(parentProperty, &prop) {
			availableComponents = append(availableComponents, prop)
		}
	}

	return availableComponents, nil
}

func (s *componentService) ValidateAttachment(ctx context.Context, parentID, componentID uint, position string) error {
	// Check if component is already attached
	isAttached, err := s.componentRepo.IsComponentAttached(ctx, componentID)
	if err != nil {
		return err
	}
	if isAttached {
		return errors.New("component is already attached to another item")
	}

	// Check if position is already occupied
	if position != "" {
		occupied, err := s.componentRepo.IsPositionOccupied(ctx, parentID, position)
		if err != nil {
			return err
		}
		if occupied {
			return fmt.Errorf("position %s is already occupied", position)
		}
	}

	// Validate position is valid for the parent property
	parentProperty, err := s.propertyRepo.GetProperty(ctx, parentID)
	if err != nil {
		return err
	}

	if position != "" && len(parentProperty.AttachmentPoints) > 0 {
		validPosition := false
		for _, point := range parentProperty.AttachmentPoints {
			if point == position {
				validPosition = true
				break
			}
		}
		if !validPosition {
			return fmt.Errorf("invalid attachment position: %s", position)
		}
	}

	return nil
}

func (s *componentService) UpdateComponentPosition(ctx context.Context, parentID, componentID uint, position string) (*models.PropertyComponent, error) {
	// Validate new position
	if err := s.ValidateAttachment(ctx, parentID, componentID, position); err != nil {
		return nil, err
	}

	// Update position
	if err := s.componentRepo.UpdateAttachmentPosition(ctx, parentID, componentID, position); err != nil {
		return nil, err
	}

	// Get updated attachment
	return s.componentRepo.GetAttachmentByIDs(ctx, parentID, componentID)
}

func (s *componentService) isCompatible(parent, component *models.Property) bool {
	// If no compatibility restrictions, allow attachment
	if len(component.CompatibleWith) == 0 {
		return true
	}

	// Check if parent's name or model matches compatibility list
	for _, compatible := range component.CompatibleWith {
		if parent.Name == compatible || parent.Model == compatible {
			return true
		}
	}

	return false
}

// backend/internal/repository/component_repository.go
package repository

import (
	"context"

	"github.com/handreceipt/backend/internal/models"
	"gorm.io/gorm"
)

type ComponentRepository interface {
	CreateAttachment(ctx context.Context, tx *gorm.DB, attachment *models.PropertyComponent) error
	DeleteAttachment(ctx context.Context, tx *gorm.DB, parentID, componentID uint) error
	GetAttachment(ctx context.Context, id uint) (*models.PropertyComponent, error)
	GetAttachmentByIDs(ctx context.Context, parentID, componentID uint) (*models.PropertyComponent, error)
	GetPropertyComponents(ctx context.Context, propertyID uint) ([]models.PropertyComponent, error)
	IsComponentAttached(ctx context.Context, componentID uint) (bool, error)
	IsPositionOccupied(ctx context.Context, parentID uint, position string) (bool, error)
	UpdateAttachmentPosition(ctx context.Context, parentID, componentID uint, position string) error
}

type componentRepository struct {
	db *gorm.DB
}

func NewComponentRepository(db *gorm.DB) ComponentRepository {
	return &componentRepository{db: db}
}

func (r *componentRepository) CreateAttachment(ctx context.Context, tx *gorm.DB, attachment *models.PropertyComponent) error {
	return tx.WithContext(ctx).Create(attachment).Error
}

func (r *componentRepository) DeleteAttachment(ctx context.Context, tx *gorm.DB, parentID, componentID uint) error {
	return tx.WithContext(ctx).
		Where("parent_property_id = ? AND component_property_id = ?", parentID, componentID).
		Delete(&models.PropertyComponent{}).Error
}

func (r *componentRepository) GetAttachment(ctx context.Context, id uint) (*models.PropertyComponent, error) {
	var attachment models.PropertyComponent
	err := r.db.WithContext(ctx).
		Preload("ComponentProperty").
		Preload("AttachedByUser").
		First(&attachment, id).Error
	return &attachment, err
}

func (r *componentRepository) GetAttachmentByIDs(ctx context.Context, parentID, componentID uint) (*models.PropertyComponent, error) {
	var attachment models.PropertyComponent
	err := r.db.WithContext(ctx).
		Preload("ComponentProperty").
		Preload("AttachedByUser").
		Where("parent_property_id = ? AND component_property_id = ?", parentID, componentID).
		First(&attachment).Error
	return &attachment, err
}

func (r *componentRepository) GetPropertyComponents(ctx context.Context, propertyID uint) ([]models.PropertyComponent, error) {
	var components []models.PropertyComponent
	err := r.db.WithContext(ctx).
		Preload("ComponentProperty").
		Preload("AttachedByUser").
		Where("parent_property_id = ?", propertyID).
		Find(&components).Error
	return components, err
}

func (r *componentRepository) IsComponentAttached(ctx context.Context, componentID uint) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).
		Model(&models.PropertyComponent{}).
		Where("component_property_id = ?", componentID).
		Count(&count).Error
	return count > 0, err
}

func (r *componentRepository) IsPositionOccupied(ctx context.Context, parentID uint, position string) (bool, error) {
	var count int64
	err := r.db.WithContext(ctx).
		Model(&models.PropertyComponent{}).
		Where("parent_property_id = ? AND position = ?", parentID, position).
		Count(&count).Error
	return count > 0, err
}

func (r *componentRepository) UpdateAttachmentPosition(ctx context.Context, parentID, componentID uint, position string) error {
	return r.db.WithContext(ctx).
		Model(&models.PropertyComponent{}).
		Where("parent_property_id = ? AND component_property_id = ?", parentID, componentID).
		Update("position", position).Error
}