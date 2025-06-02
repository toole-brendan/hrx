package services

import (
	"context"
	"errors"
	"fmt"

	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
)

// ComponentService defines the interface for component association operations
type ComponentService interface {
	AttachComponent(ctx context.Context, parentID, componentID, userID uint, position, notes string) (*domain.PropertyComponent, error)
	DetachComponent(ctx context.Context, parentID, componentID, userID uint) error
	GetPropertyComponents(ctx context.Context, propertyID uint) ([]domain.PropertyComponent, error)
	GetAvailableComponents(ctx context.Context, propertyID, userID uint) ([]domain.Property, error)
	ValidateAttachment(ctx context.Context, parentID, componentID uint, position string) error
	UpdateComponentPosition(ctx context.Context, parentID, componentID uint, position string) error
}

type componentService struct {
	repo repository.Repository
}

// NewComponentService creates a new component service
func NewComponentService(repo repository.Repository) ComponentService {
	return &componentService{
		repo: repo,
	}
}

// AttachComponent attaches a component to a parent property
func (s *componentService) AttachComponent(ctx context.Context, parentID, componentID, userID uint, position, notes string) (*domain.PropertyComponent, error) {
	// Validate that both properties exist and are owned by the user
	parentProperty, err := s.repo.GetPropertyByID(parentID)
	if err != nil {
		return nil, fmt.Errorf("parent property not found: %w", err)
	}

	componentProperty, err := s.repo.GetPropertyByID(componentID)
	if err != nil {
		return nil, fmt.Errorf("component property not found: %w", err)
	}

	// Validate ownership
	if parentProperty.AssignedToUserID == nil || *parentProperty.AssignedToUserID != userID {
		return nil, errors.New("you must own the parent property to attach components")
	}

	if componentProperty.AssignedToUserID == nil || *componentProperty.AssignedToUserID != userID {
		return nil, errors.New("you must own the component to attach it")
	}

	// Validate attachment rules
	if err := s.ValidateAttachment(ctx, parentID, componentID, position); err != nil {
		return nil, err
	}

	// Create the attachment
	attachment, err := s.repo.AttachComponent(parentID, componentID, userID, position, notes)
	if err != nil {
		return nil, fmt.Errorf("failed to attach component: %w", err)
	}

	return attachment, nil
}

// DetachComponent removes an attachment between components
func (s *componentService) DetachComponent(ctx context.Context, parentID, componentID, userID uint) error {
	// Verify that the user owns the parent property
	parentProperty, err := s.repo.GetPropertyByID(parentID)
	if err != nil {
		return fmt.Errorf("parent property not found: %w", err)
	}

	if parentProperty.AssignedToUserID == nil || *parentProperty.AssignedToUserID != userID {
		return errors.New("you must own the parent property to detach components")
	}

	// Remove the attachment
	return s.repo.DetachComponent(parentID, componentID)
}

// GetPropertyComponents retrieves all components attached to a property
func (s *componentService) GetPropertyComponents(ctx context.Context, propertyID uint) ([]domain.PropertyComponent, error) {
	return s.repo.GetPropertyComponents(propertyID)
}

// GetAvailableComponents retrieves components that can be attached to a property
func (s *componentService) GetAvailableComponents(ctx context.Context, propertyID, userID uint) ([]domain.Property, error) {
	// Get the parent property to check if it can have attachments
	parentProperty, err := s.repo.GetPropertyByID(propertyID)
	if err != nil {
		return nil, fmt.Errorf("parent property not found: %w", err)
	}

	if !parentProperty.IsAttachable {
		return []domain.Property{}, nil
	}

	return s.repo.GetAvailableComponents(propertyID, userID)
}

// ValidateAttachment validates that a component can be attached to a parent
func (s *componentService) ValidateAttachment(ctx context.Context, parentID, componentID uint, position string) error {
	// Prevent self-attachment
	if parentID == componentID {
		return errors.New("cannot attach property to itself")
	}

	// Check if component is already attached
	isAttached, err := s.repo.IsComponentAttached(componentID)
	if err != nil {
		return fmt.Errorf("failed to check component status: %w", err)
	}
	if isAttached {
		return errors.New("component is already attached to another item")
	}

	// Get parent property to check attachment rules
	parentProperty, err := s.repo.GetPropertyByID(parentID)
	if err != nil {
		return fmt.Errorf("parent property not found: %w", err)
	}

	// Check if parent can have attachments
	if !parentProperty.IsAttachable {
		return errors.New("parent property cannot have components attached")
	}

	// Check if position is valid for the parent
	if position != "" && parentProperty.AttachmentPoints != nil {
		validPosition := false
		// Parse the JSON attachment points
		// For now, we'll skip detailed validation
		// TODO: Implement proper JSON parsing for attachment points validation
		validPosition = true // Simplified for now

		if !validPosition {
			return fmt.Errorf("invalid attachment position: %s", position)
		}

		// Check if position is already occupied
		isOccupied, err := s.repo.IsPositionOccupied(parentID, position)
		if err != nil {
			return fmt.Errorf("failed to check position availability: %w", err)
		}
		if isOccupied {
			return fmt.Errorf("position %s is already occupied", position)
		}
	}

	// Get component property to check compatibility
	componentProperty, err := s.repo.GetPropertyByID(componentID)
	if err != nil {
		return fmt.Errorf("component property not found: %w", err)
	}

	// Check compatibility
	if !s.isCompatible(parentProperty, componentProperty) {
		return errors.New("component is not compatible with parent property")
	}

	return nil
}

// UpdateComponentPosition updates the position of an attached component
func (s *componentService) UpdateComponentPosition(ctx context.Context, parentID, componentID uint, position string) error {
	// Validate the new position
	if err := s.ValidateAttachment(ctx, parentID, componentID, position); err != nil {
		return err
	}

	return s.repo.UpdateComponentPosition(parentID, componentID, position)
}

// isCompatible checks if a component is compatible with a parent property
func (s *componentService) isCompatible(parent, component *domain.Property) bool {
	// If component has no compatibility restrictions, allow attachment
	if component.CompatibleWith == nil || *component.CompatibleWith == "" {
		return true
	}

	// TODO: Implement proper JSON parsing for compatibility checking
	// For now, we'll return true to allow attachments
	// In a real implementation, you would:
	// 1. Parse the CompatibleWith JSON array
	// 2. Check if parent's name, model, or category matches any entry
	// 3. Return true if compatible, false otherwise

	return true
}

// AttachmentInput represents input for attaching a component
type AttachmentInput struct {
	ComponentID uint   `json:"componentId" binding:"required"`
	Position    string `json:"position"`
	Notes       string `json:"notes"`
}

// UpdatePositionInput represents input for updating component position
type UpdatePositionInput struct {
	Position string `json:"position" binding:"required"`
}
