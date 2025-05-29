package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
)

// NSNHandler handles NSN-related API endpoints
type NSNHandler struct {
	service *nsn.NSNService
	logger  *logrus.Logger
}

// NewNSNHandler creates a new NSN handler
func NewNSNHandler(service *nsn.NSNService, logger *logrus.Logger) *NSNHandler {
	return &NSNHandler{
		service: service,
		logger:  logger,
	}
}

// LookupNSN handles GET /api/nsn/:nsn
func (h *NSNHandler) LookupNSN(c *gin.Context) {
	nsnCode := c.Param("nsn")
	if nsnCode == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "NSN is required",
		})
		return
	}

	// Use the existing service method
	details, err := h.service.LookupNSN(c.Request.Context(), nsnCode)
	if err != nil {
		h.logger.WithError(err).WithField("nsn", nsnCode).Error("Failed to lookup NSN")
		c.JSON(http.StatusNotFound, gin.H{
			"error": "NSN not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    details,
	})
}

// LookupLIN handles GET /api/lin/:lin
func (h *NSNHandler) LookupLIN(c *gin.Context) {
	linCode := c.Param("lin")
	if linCode == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "LIN is required",
		})
		return
	}

	details, err := h.service.LookupLIN(c.Request.Context(), linCode)
	if err != nil {
		h.logger.WithError(err).WithField("lin", linCode).Error("Failed to lookup LIN")
		c.JSON(http.StatusNotFound, gin.H{
			"error": "LIN not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    details,
	})
}

// SearchNSN handles GET /api/nsn/search?q=query&limit=20
func (h *NSNHandler) SearchNSN(c *gin.Context) {
	query := c.Query("q")
	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Search query is required",
		})
		return
	}

	// Parse limit with default value
	limit := 20
	if limitStr := c.Query("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			if parsedLimit > 100 {
				limit = 100 // Cap at 100
			} else {
				limit = parsedLimit
			}
		}
	}

	results, err := h.service.SearchNSN(c.Request.Context(), query, limit)
	if err != nil {
		h.logger.WithError(err).WithField("query", query).Error("Failed to search NSN")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Search failed",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    results,
		"count":   len(results),
	})
}

// BulkLookup handles POST /api/nsn/bulk
func (h *NSNHandler) BulkLookup(c *gin.Context) {
	var request struct {
		NSNs []string `json:"nsns" binding:"required"`
	}

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request body",
		})
		return
	}

	if len(request.NSNs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "At least one NSN is required",
		})
		return
	}

	if len(request.NSNs) > 50 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Maximum 50 NSNs allowed per request",
		})
		return
	}

	results, err := h.service.BulkLookup(c.Request.Context(), request.NSNs)
	if err != nil {
		h.logger.WithError(err).Error("Failed to perform bulk NSN lookup")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Bulk lookup failed",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    results,
		"found":   len(results),
		"total":   len(request.NSNs),
	})
}

// GetStatistics handles GET /api/nsn/stats
func (h *NSNHandler) GetStatistics(c *gin.Context) {
	stats, err := h.service.GetStatistics(c.Request.Context())
	if err != nil {
		h.logger.WithError(err).Error("Failed to get NSN statistics")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve statistics",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    stats,
	})
}

// ImportCSV handles POST /api/nsn/import
func (h *NSNHandler) ImportCSV(c *gin.Context) {
	// Check if user has admin privileges
	// This is a placeholder - implement your actual authorization logic
	userRole := c.GetString("user_role")
	if userRole != "admin" && userRole != "super_admin" {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Insufficient permissions",
		})
		return
	}

	// Handle file upload
	file, header, err := c.Request.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "File upload failed",
		})
		return
	}
	defer file.Close()

	// Validate file type
	if header.Header.Get("Content-Type") != "text/csv" &&
		!strings.HasSuffix(header.Filename, ".csv") {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Only CSV files are allowed",
		})
		return
	}

	// Import the CSV data
	err = h.service.ImportFromCSV(c.Request.Context(), file)
	if err != nil {
		h.logger.WithError(err).Error("Failed to import CSV")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Import failed: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "CSV imported successfully",
	})
}

// RefreshCache handles POST /api/nsn/refresh
func (h *NSNHandler) RefreshCache(c *gin.Context) {
	// Check if user has admin privileges
	userRole := c.GetString("user_role")
	if userRole != "admin" && userRole != "super_admin" {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "Insufficient permissions",
		})
		return
	}

	err := h.service.RefreshCachedNSNData(c.Request.Context())
	if err != nil {
		h.logger.WithError(err).Error("Failed to refresh NSN cache")
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Cache refresh failed",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Cache refreshed successfully",
	})
}

// GetCacheStats handles GET /api/nsn/cache/stats
func (h *NSNHandler) GetCacheStats(c *gin.Context) {
	stats := h.service.GetCacheStats()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    stats,
	})
}
