package tests

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
	"github.com/toole-brendan/handreceipt-go/internal/api/handlers"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/platform/database"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"github.com/toole-brendan/handreceipt-go/internal/services/storage"
)

// PropertyCreationTestSuite tests property creation workflows
type PropertyCreationTestSuite struct {
	suite.Suite
	router         *gin.Engine
	repo           repository.Repository
	ledger         *MockLedgerService
	storageService *storage.MinIOService
	testUserID     uint
	sessionToken   string
}

func (suite *PropertyCreationTestSuite) SetupSuite() {
	// Setup test environment using the same pattern as other tests
	db := setupTestDB(suite.T())
	suite.repo = setupTestRepository(db)
	suite.ledger = &MockLedgerService{}

	// Mock storage service for testing
	suite.storageService = &storage.MinIOService{} // This should be a mock for testing

	// Create handlers
	inventoryHandler := handlers.NewInventoryHandler(suite.ledger, suite.repo)

	// Setup router
	gin.SetMode(gin.TestMode)
	suite.router = gin.New()

	// Setup routes
	api := suite.router.Group("/api")
	{
		protected := api.Group("")
		protected.Use(mockAuthMiddleware())
		{
			inventory := protected.Group("/inventory")
			{
				inventory.POST("", inventoryHandler.CreateInventoryItem)
				inventory.GET("/serial/:serialNumber", inventoryHandler.GetPropertyBySerialNumber)
			}
		}
	}

	// Create test user
	suite.testUserID = 1
}

// TearDownSuite cleans up after tests
func (suite *PropertyCreationTestSuite) TearDownSuite() {
	database.CleanupTestDB()
}

// TestCreatePropertyWithUniqueSerialNumber tests successful property creation
func (suite *PropertyCreationTestSuite) TestCreatePropertyWithUniqueSerialNumber() {
	testCases := []struct {
		name     string
		input    domain.CreatePropertyInput
		expected string
	}{
		{
			name: "Create M4 Carbine",
			input: domain.CreatePropertyInput{
				Name:             "M4 Carbine",
				SerialNumber:     fmt.Sprintf("M4-%d", time.Now().UnixNano()),
				Description:      stringPtr("5.56mm Carbine with ACOG"),
				CurrentStatus:    "Operational",
				PropertyModelID:  uintPtr(1),
				AssignedToUserID: &suite.testUserID,
			},
			expected: "M4 Carbine",
		},
		{
			name: "Create Radio with minimal fields",
			input: domain.CreatePropertyInput{
				Name:          "PRC-152 Radio",
				SerialNumber:  fmt.Sprintf("PRC-%d", time.Now().UnixNano()),
				CurrentStatus: "Operational",
			},
			expected: "PRC-152 Radio",
		},
		{
			name: "Create NVG with description",
			input: domain.CreatePropertyInput{
				Name:          "PVS-14 NVG",
				SerialNumber:  fmt.Sprintf("NVG-%d", time.Now().UnixNano()),
				Description:   stringPtr("Night Vision Goggles - Monocular"),
				CurrentStatus: "Requires Maintenance",
			},
			expected: "PVS-14 NVG",
		},
	}

	for _, tc := range testCases {
		suite.Run(tc.name, func() {
			body, _ := json.Marshal(tc.input)

			w := httptest.NewRecorder()
			req, _ := http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
			req.Header.Set("Content-Type", "application/json")
			setTestUserContext(req, suite.testUserID)

			suite.router.ServeHTTP(w, req)

			assert.Equal(suite.T(), http.StatusCreated, w.Code)

			var response domain.Property
			err := json.Unmarshal(w.Body.Bytes(), &response)
			assert.NoError(suite.T(), err)

			// Verify response
			assert.Equal(suite.T(), tc.expected, response.Name)
			assert.Equal(suite.T(), tc.input.SerialNumber, response.SerialNumber)
			assert.NotZero(suite.T(), response.ID)
			assert.NotZero(suite.T(), response.CreatedAt)

			// Verify ledger was called
			assert.True(suite.T(), suite.ledger.HasEvent("ITEM_CREATE", response.ID))
		})
	}
}

// TestCreatePropertyWithDuplicateSerialNumber tests serial number uniqueness enforcement
func (suite *PropertyCreationTestSuite) TestCreatePropertyWithDuplicateSerialNumber() {
	serialNumber := fmt.Sprintf("DUP-%d", time.Now().UnixNano())

	// Create first property
	firstProperty := domain.CreatePropertyInput{
		Name:          "First Item",
		SerialNumber:  serialNumber,
		CurrentStatus: "Operational",
	}

	body, _ := json.Marshal(firstProperty)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	setTestUserContext(req, suite.testUserID)

	suite.router.ServeHTTP(w, req)
	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	// Attempt to create duplicate
	duplicateProperty := domain.CreatePropertyInput{
		Name:          "Duplicate Item",
		SerialNumber:  serialNumber, // Same serial number
		CurrentStatus: "Operational",
	}

	body, _ = json.Marshal(duplicateProperty)
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	setTestUserContext(req, suite.testUserID)

	suite.router.ServeHTTP(w, req)
	assert.Equal(suite.T(), http.StatusBadRequest, w.Code)

	var errorResponse map[string]string
	json.Unmarshal(w.Body.Bytes(), &errorResponse)
	assert.Contains(suite.T(), errorResponse["error"], "already exists")
}

// TestPropertyCreationValidation tests input validation
func (suite *PropertyCreationTestSuite) TestPropertyCreationValidation() {
	testCases := []struct {
		name        string
		input       map[string]interface{}
		expectedErr string
	}{
		{
			name: "Missing serial number",
			input: map[string]interface{}{
				"name":           "Invalid Item",
				"current_status": "Operational",
			},
			expectedErr: "serialNumber",
		},
		{
			name: "Empty serial number",
			input: map[string]interface{}{
				"name":           "Invalid Item",
				"serialNumber":   "",
				"current_status": "Operational",
			},
			expectedErr: "serialNumber",
		},
		{
			name: "Missing name",
			input: map[string]interface{}{
				"serialNumber":   "TEST-123",
				"current_status": "Operational",
			},
			expectedErr: "name",
		},
		{
			name: "Invalid status",
			input: map[string]interface{}{
				"name":           "Test Item",
				"serialNumber":   "TEST-123",
				"current_status": "",
			},
			expectedErr: "currentStatus",
		},
	}

	for _, tc := range testCases {
		suite.Run(tc.name, func() {
			body, _ := json.Marshal(tc.input)

			w := httptest.NewRecorder()
			req, _ := http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
			req.Header.Set("Content-Type", "application/json")
			setTestUserContext(req, suite.testUserID)

			suite.router.ServeHTTP(w, req)

			assert.Equal(suite.T(), http.StatusBadRequest, w.Code)

			var errorResponse map[string]string
			json.Unmarshal(w.Body.Bytes(), &errorResponse)
			assert.Contains(suite.T(), errorResponse["error"], tc.expectedErr)
		})
	}
}

// TestPropertyCreationWithAssignment tests creating property for another user
func (suite *PropertyCreationTestSuite) TestPropertyCreationWithAssignment() {
	targetUserID := uint(2)

	property := domain.CreatePropertyInput{
		Name:             "Assigned Equipment",
		SerialNumber:     fmt.Sprintf("ASSIGN-%d", time.Now().UnixNano()),
		CurrentStatus:    "Operational",
		AssignedToUserID: &targetUserID,
	}

	body, _ := json.Marshal(property)
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	setTestUserContext(req, suite.testUserID)

	suite.router.ServeHTTP(w, req)
	assert.Equal(suite.T(), http.StatusCreated, w.Code)

	var response domain.Property
	json.Unmarshal(w.Body.Bytes(), &response)

	// Verify assignment
	assert.NotNil(suite.T(), response.AssignedToUserID)
	assert.Equal(suite.T(), targetUserID, *response.AssignedToUserID)

	// Verify ledger entry
	assert.True(suite.T(), suite.ledger.HasEvent("ITEM_CREATE", response.ID))
}

// TestOfflinePropertyCreationSync tests offline queue synchronization
func (suite *PropertyCreationTestSuite) TestOfflinePropertyCreationSync() {
	// This test simulates the offline sync service behavior
	// In a real implementation, this would test:
	// 1. Queue management when offline
	// 2. Batch sync when connection restored
	// 3. Conflict resolution for duplicate serial numbers
	// 4. Retry logic for failed syncs

	offlineQueue := []domain.CreatePropertyInput{
		{
			Name:          "Offline Item 1",
			SerialNumber:  fmt.Sprintf("OFFLINE-1-%d", time.Now().UnixNano()),
			CurrentStatus: "Operational",
		},
		{
			Name:          "Offline Item 2",
			SerialNumber:  fmt.Sprintf("OFFLINE-2-%d", time.Now().UnixNano()),
			CurrentStatus: "Non-Operational",
		},
	}

	// Simulate batch sync
	for _, item := range offlineQueue {
		body, _ := json.Marshal(item)
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("X-Offline-Sync", "true") // Indicate offline sync
		setTestUserContext(req, suite.testUserID)

		suite.router.ServeHTTP(w, req)
		assert.Equal(suite.T(), http.StatusCreated, w.Code)
	}

	// Verify all items created successfully
	assert.Equal(suite.T(), 2, len(suite.ledger.events["ITEM_CREATE"]))
}

// TestPropertyCreationCompleteWorkflow tests the end-to-end digital twin creation
func (suite *PropertyCreationTestSuite) TestPropertyCreationCompleteWorkflow() {
	suite.Run("Complete Digital Twin Creation Workflow", func() {
		// Step 1: Create property with full metadata
		timestamp := time.Now().UnixNano()
		property := domain.CreatePropertyInput{
			Name:             "M4A1 Carbine (Complete)",
			SerialNumber:     fmt.Sprintf("COMPLETE-%d", timestamp),
			Description:      stringPtr("5.56mm Carbine with ACOG scope and PEQ-15"),
			CurrentStatus:    "Operational",
			PropertyModelID:  uintPtr(1),
			AssignedToUserID: &suite.testUserID,
		}

		body, _ := json.Marshal(property)
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		setTestUserContext(req, suite.testUserID)

		suite.router.ServeHTTP(w, req)
		assert.Equal(suite.T(), http.StatusCreated, w.Code)

		var createdProperty domain.Property
		json.Unmarshal(w.Body.Bytes(), &createdProperty)

		// Step 2: Verify property can be retrieved by serial number
		w = httptest.NewRecorder()
		req, _ = http.NewRequest("GET", fmt.Sprintf("/api/inventory/serial/%s", property.SerialNumber), nil)
		setTestUserContext(req, suite.testUserID)

		suite.router.ServeHTTP(w, req)
		assert.Equal(suite.T(), http.StatusOK, w.Code)

		var retrievedProperty domain.Property
		json.Unmarshal(w.Body.Bytes(), &retrievedProperty)
		assert.Equal(suite.T(), createdProperty.ID, retrievedProperty.ID)
		assert.Equal(suite.T(), property.SerialNumber, retrievedProperty.SerialNumber)

		// Step 3: Verify immutable ledger entry
		assert.True(suite.T(), suite.ledger.HasEvent("ITEM_CREATE", createdProperty.ID))

		// Step 4: Verify no duplicate can be created
		duplicateAttempt := domain.CreatePropertyInput{
			Name:          "Duplicate Attempt",
			SerialNumber:  property.SerialNumber, // Same serial
			CurrentStatus: "Operational",
		}

		body, _ = json.Marshal(duplicateAttempt)
		w = httptest.NewRecorder()
		req, _ = http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		setTestUserContext(req, suite.testUserID)

		suite.router.ServeHTTP(w, req)
		assert.Equal(suite.T(), http.StatusBadRequest, w.Code)

		// Verify error message mentions duplicate/existing serial number
		var errorResponse map[string]string
		json.Unmarshal(w.Body.Bytes(), &errorResponse)
		assert.Contains(suite.T(), errorResponse["error"], "already exists")
	})
}

// Helper functions
func createMultipartFormData(fieldName, fileName string, content []byte) (*bytes.Buffer, string) {
	body := new(bytes.Buffer)
	writer := multipart.NewWriter(body)

	part, _ := writer.CreateFormFile(fieldName, fileName)
	io.Copy(part, bytes.NewReader(content))
	writer.Close()

	return body, writer.FormDataContentType()
}

func setTestUserContext(req *http.Request, userID uint) {
	req.Header.Set("X-User-ID", fmt.Sprintf("%d", userID))
}

func mockAuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		userIDStr := c.GetHeader("X-User-ID")
		if userIDStr != "" {
			var userID uint
			fmt.Sscanf(userIDStr, "%d", &userID)
			c.Set("userID", userID)
		}
		c.Next()
	}
}

func uintPtr(u uint) *uint {
	return &u
}

func stringPtr(s string) *string {
	return &s
}

func TestPropertyCreationSuite(t *testing.T) {
	suite.Run(t, new(PropertyCreationTestSuite))
}
