package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"gorm.io/gorm"
)

// ReferenceDBHandler handles operations related to the reference database (property types, models).
type ReferenceDBHandler struct {
	Repo repository.Repository
}

// NewReferenceDBHandler creates a new reference database handler.
func NewReferenceDBHandler(repo repository.Repository) *ReferenceDBHandler {
	return &ReferenceDBHandler{Repo: repo}
}

// ListPropertyTypes handles GET requests for listing all property types.
func (h *ReferenceDBHandler) ListPropertyTypes(c *gin.Context) {
	types, err := h.Repo.ListPropertyTypes()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property types: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"types": types})
}

// ListPropertyModels handles GET requests for listing property models, with an optional filter by type ID.
func (h *ReferenceDBHandler) ListPropertyModels(c *gin.Context) {
	var typeID *uint
	typeIDStr := c.Query("typeId")
	if typeIDStr != "" {
		uID, err := strconv.ParseUint(typeIDStr, 10, 32)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid typeId format"})
			return
		}
		tempID := uint(uID)
		typeID = &tempID
	}

	models, err := h.Repo.ListPropertyModels(typeID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property models: " + err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"models": models})
}

// GetPropertyModelByNSN handles GET requests for fetching a specific property model by its NSN.
func (h *ReferenceDBHandler) GetPropertyModelByNSN(c *gin.Context) {
	nsn := c.Param("nsn")
	if nsn == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "NSN parameter is required"})
		return
	}

	model, err := h.Repo.GetPropertyModelByNSN(nsn)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{"error": "Property model not found for NSN: " + nsn})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch property model by NSN: " + err.Error()})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"model": model})
}
