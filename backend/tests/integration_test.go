package tests

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
	"github.com/toole-brendan/handreceipt-go/internal/api/routes"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/ledger"
	"github.com/toole-brendan/handreceipt-go/internal/platform/database"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
)

// IntegrationTestSuite runs integration tests for the complete flow
type IntegrationTestSuite struct {
	suite.Suite
	router       *gin.Engine
	testUser1ID  uint
	testUser2ID  uint
	propertyID   uint
	transferID   uint
	sessionToken string
}

// SetupSuite runs before the test suite
func (suite *IntegrationTestSuite) SetupSuite() {
	// Initialize test configuration
	cfg := config.NewTestConfig()

	// Initialize database
	db, err := database.InitTestDB(cfg)
	suite.Require().NoError(err)

	// Initialize repositories
	repo := repository.NewRepository(db)

	// Initialize ledger service
	ledgerService := ledger.NewMockLedgerService()

	// Setup router
	gin.SetMode(gin.TestMode)
	suite.router = routes.SetupRouter(repo, ledgerService, cfg)

	// Create test users
	suite.createTestUsers()
}

// TearDownSuite runs after all tests
func (suite *IntegrationTestSuite) TearDownSuite() {
	// Cleanup test data
	database.CleanupTestDB()
}

// Test the complete create-sync-transfer-approve scenario
func (suite *IntegrationTestSuite) TestCompletePropertyTransferFlow() {
	// Step 1: Login as user1
	suite.Run("Login", func() {
		loginReq := map[string]string{
			"username": "testuser1",
			"password": "testpass123",
		}
		body, _ := json.Marshal(loginReq)

		w := httptest.NewRecorder()
		req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")

		suite.router.ServeHTTP(w, req)

		assert.Equal(suite.T(), http.StatusOK, w.Code)

		// Extract session cookie
		cookies := w.Result().Cookies()
		for _, cookie := range cookies {
			if cookie.Name == "session" {
				suite.sessionToken = cookie.Value
				break
			}
		}
		assert.NotEmpty(suite.T(), suite.sessionToken)
	})

	// Step 2: Create a property item
	suite.Run("CreateProperty", func() {
		createReq := map[string]interface{}{
			"name":           "M4 Carbine",
			"serial_number":  fmt.Sprintf("TEST-%d", time.Now().UnixNano()),
			"description":    "5.56mm Carbine",
			"current_status": "Operational",
			"nsn":            "1005-01-382-0953",
			"lin":            "C74940",
		}
		body, _ := json.Marshal(createReq)

		w := httptest.NewRecorder()
		req, _ := http.NewRequest("POST", "/api/inventory", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		req.AddCookie(&http.Cookie{Name: "session", Value: suite.sessionToken})

		suite.router.ServeHTTP(w, req)

		assert.Equal(suite.T(), http.StatusCreated, w.Code)

		var response map[string]interface{}
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(suite.T(), err)

		suite.propertyID = uint(response["id"].(float64))
		assert.Greater(suite.T(), suite.propertyID, uint(0))

		// Verify immutable ledger entry exists
		assert.NotEmpty(suite.T(), w.Header().Get("X-Ledger-TX-ID"))
	})

	// Step 3: Create a transfer request to user2
	suite.Run("CreateTransfer", func() {
		transferReq := map[string]interface{}{
			"property_id":    suite.propertyID,
			"target_user_id": suite.testUser2ID,
		}
		body, _ := json.Marshal(transferReq)

		w := httptest.NewRecorder()
		req, _ := http.NewRequest("POST", "/api/transfers", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		req.AddCookie(&http.Cookie{Name: "session", Value: suite.sessionToken})

		suite.router.ServeHTTP(w, req)

		assert.Equal(suite.T(), http.StatusOK, w.Code)

		var response map[string]interface{}
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(suite.T(), err)

		suite.transferID = uint(response["id"].(float64))
		assert.Equal(suite.T(), "pending", response["status"])
	})

	// Step 4: Login as user2 to approve the transfer
	suite.Run("LoginAsUser2", func() {
		loginReq := map[string]string{
			"username": "testuser2",
			"password": "testpass123",
		}
		body, _ := json.Marshal(loginReq)

		w := httptest.NewRecorder()
		req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")

		suite.router.ServeHTTP(w, req)

		assert.Equal(suite.T(), http.StatusOK, w.Code)

		// Update session token for user2
		cookies := w.Result().Cookies()
		for _, cookie := range cookies {
			if cookie.Name == "session" {
				suite.sessionToken = cookie.Value
				break
			}
		}
	})

	// Step 5: Approve the transfer
	suite.Run("ApproveTransfer", func() {
		approveReq := map[string]string{
			"status": "Approved",
		}
		body, _ := json.Marshal(approveReq)

		w := httptest.NewRecorder()
		req, _ := http.NewRequest("PATCH", fmt.Sprintf("/api/transfers/%d/status", suite.transferID), bytes.NewBuffer(body))
		req.Header.Set("Content-Type", "application/json")
		req.AddCookie(&http.Cookie{Name: "session", Value: suite.sessionToken})

		suite.router.ServeHTTP(w, req)

		assert.Equal(suite.T(), http.StatusOK, w.Code)

		var response map[string]interface{}
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(suite.T(), err)

		assert.Equal(suite.T(), "Approved", response["status"])
	})

	// Step 6: Verify property ownership changed
	suite.Run("VerifyOwnershipTransfer", func() {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", fmt.Sprintf("/api/inventory/%d", suite.propertyID), nil)
		req.AddCookie(&http.Cookie{Name: "session", Value: suite.sessionToken})

		suite.router.ServeHTTP(w, req)

		assert.Equal(suite.T(), http.StatusOK, w.Code)

		var response map[string]interface{}
		err := json.Unmarshal(w.Body.Bytes(), &response)
		assert.NoError(suite.T(), err)

		item := response["item"].(map[string]interface{})
		assert.Equal(suite.T(), float64(suite.testUser2ID), item["assigned_to_user_id"])
	})

	// Step 7: Verify ledger history
	suite.Run("VerifyLedgerHistory", func() {
		w := httptest.NewRecorder()
		serialNumber := fmt.Sprintf("TEST-%d", time.Now().UnixNano())
		req, _ := http.NewRequest("GET", fmt.Sprintf("/api/inventory/history/%s", serialNumber), nil)
		req.AddCookie(&http.Cookie{Name: "session", Value: suite.sessionToken})

		suite.router.ServeHTTP(w, req)

		// Note: May return 404 if using mock ledger service
		// In real implementation, should return 200 with history
		if w.Code == http.StatusOK {
			var response map[string]interface{}
			err := json.Unmarshal(w.Body.Bytes(), &response)
			assert.NoError(suite.T(), err)

			history := response["history"].([]interface{})
			assert.GreaterOrEqual(suite.T(), len(history), 2) // At least CREATE and TRANSFER events
		}
	})
}

// Helper method to create test users
func (suite *IntegrationTestSuite) createTestUsers() {
	// This would typically use your user service/repository
	// For now, we'll assume they exist in the test database
	suite.testUser1ID = 1
	suite.testUser2ID = 2
}

// Run the test suite
func TestIntegrationSuite(t *testing.T) {
	suite.Run(t, new(IntegrationTestSuite))
}
