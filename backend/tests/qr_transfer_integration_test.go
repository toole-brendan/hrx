package tests

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/toole-brendan/handreceipt-go/internal/api/handlers"
	"github.com/toole-brendan/handreceipt-go/internal/api/middleware"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
	"gorm.io/gorm"
)

// Test setup functions (simplified for demo)
func setupTestDB(t *testing.T) *gorm.DB {
	// In a real implementation, this would set up an in-memory database
	// For now, return nil as placeholder
	return nil
}

func cleanupTestDB(db *gorm.DB) {
	// Cleanup test database
}

func setupTestRepository(db *gorm.DB) repository.Repository {
	// In a real implementation, this would return a test repository
	// For now, return a mock repository
	return &MockRepository{}
}

func TestCompleteQRTransferFlow(t *testing.T) {
	// Setup test environment
	db := setupTestDB(t)
	defer cleanupTestDB(db)

	repo := setupTestRepository(db)
	ledger := &MockLedgerService{}

	// Create handlers
	inventoryHandler := handlers.NewInventoryHandler(ledger, repo)
	transferHandler := handlers.NewTransferHandler(ledger, repo)
	qrCodeHandler := handlers.NewQRCodeHandler(ledger, repo)

	// Setup router
	router := gin.New()
	router.Use(middleware.SessionAuthMiddleware())

	// Register routes
	inventory := router.Group("/api/inventory")
	{
		inventory.POST("/qrcode/:propertyId", inventoryHandler.GeneratePropertyQRCode)
		inventory.POST("", inventoryHandler.CreateInventoryItem)
		inventory.GET("/:propertyId/qrcodes", qrCodeHandler.GetPropertyQRCodes)
	}

	transfers := router.Group("/api/transfers")
	{
		transfers.POST("/qr-initiate", transferHandler.InitiateTransferByQR)
		transfers.PATCH("/:id/status", transferHandler.UpdateTransferStatus)
		transfers.GET("", transferHandler.GetAllTransfers)
	}

	qrcodes := router.Group("/api/qrcodes")
	{
		qrcodes.GET("", qrCodeHandler.GetAllQRCodes)
		qrcodes.POST("/:id/report-damaged", qrCodeHandler.ReportQRCodeDamaged)
	}

	// Test data
	owner := createTestUser(t, repo, "owner", "Alice", "CPT")
	recipient := createTestUser(t, repo, "recipient", "Bob", "SGT")

	t.Run("Complete QR Transfer Flow", func(t *testing.T) {
		// Step 1: Create property item
		propertyInput := domain.CreatePropertyInput{
			Name:             "M4 Carbine",
			SerialNumber:     "M4-TEST-001",
			Description:      stringPtr("Test weapon"),
			CurrentStatus:    "Operational",
			AssignedToUserID: &owner.ID,
		}

		w := httptest.NewRecorder()
		body, _ := json.Marshal(propertyInput)
		req := httptest.NewRequest("POST", "/api/inventory", bytes.NewReader(body))
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusCreated, w.Code)

		var property domain.Property
		json.Unmarshal(w.Body.Bytes(), &property)
		assert.Equal(t, "M4 Carbine", property.Name)
		assert.Equal(t, "M4-TEST-001", property.SerialNumber)

		// Step 2: Generate QR code
		w = httptest.NewRecorder()
		req = httptest.NewRequest("POST", fmt.Sprintf("/api/inventory/qrcode/%d", property.ID), nil)
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		var qrResponse struct {
			QRCodeData string `json:"qrCodeData"`
			QRCodeUrl  string `json:"qrCodeUrl"`
		}
		json.Unmarshal(w.Body.Bytes(), &qrResponse)
		assert.NotEmpty(t, qrResponse.QRCodeData)

		// Verify QR code data structure
		var qrData map[string]interface{}
		err := json.Unmarshal([]byte(qrResponse.QRCodeData), &qrData)
		assert.NoError(t, err)
		assert.Equal(t, "handreceipt_property", qrData["type"])
		assert.Equal(t, property.SerialNumber, qrData["serialNumber"])
		assert.Equal(t, fmt.Sprintf("%d", owner.ID), qrData["currentHolderId"])
		assert.NotEmpty(t, qrData["qrHash"])

		// Step 3: Recipient scans QR code to initiate transfer
		scanRequest := domain.QRTransferRequest{
			QRData:    qrData,
			ScannedAt: time.Now().Format(time.RFC3339),
		}

		w = httptest.NewRecorder()
		body, _ = json.Marshal(scanRequest)
		req = httptest.NewRequest("POST", "/api/transfers/qr-initiate", bytes.NewReader(body))
		setUserContext(req, recipient.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		var transferResponse struct {
			TransferID string `json:"transferId"`
			Status     string `json:"status"`
		}
		json.Unmarshal(w.Body.Bytes(), &transferResponse)
		assert.Equal(t, "Requested", transferResponse.Status)
		assert.NotEmpty(t, transferResponse.TransferID)

		// Step 4: Verify transfer appears in owner's incoming requests
		w = httptest.NewRecorder()
		req = httptest.NewRequest("GET", "/api/transfers", nil)
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		var transfers []domain.Transfer
		json.Unmarshal(w.Body.Bytes(), &transfers)
		assert.Len(t, transfers, 1)
		assert.Equal(t, "Requested", transfers[0].Status)
		assert.Equal(t, owner.ID, transfers[0].FromUserID)
		assert.Equal(t, recipient.ID, transfers[0].ToUserID)

		// Step 5: Owner approves transfer
		approveRequest := domain.UpdateTransferInput{
			Status: "Approved",
		}

		w = httptest.NewRecorder()
		body, _ = json.Marshal(approveRequest)
		req = httptest.NewRequest("PATCH", fmt.Sprintf("/api/transfers/%s/status", transferResponse.TransferID), bytes.NewReader(body))
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		// Step 6: Verify property ownership changed
		updatedProperty, err := repo.GetPropertyByID(property.ID)
		assert.NoError(t, err)
		assert.Equal(t, recipient.ID, *updatedProperty.AssignedToUserID)

		// Step 7: Verify transfer status updated
		w = httptest.NewRecorder()
		req = httptest.NewRequest("GET", "/api/transfers", nil)
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		json.Unmarshal(w.Body.Bytes(), &transfers)
		assert.Equal(t, "Approved", transfers[0].Status)
		assert.Equal(t, "Approved", transfers[0].Status)

		// Verify ledger entries
		assert.True(t, ledger.HasEvent("ITEM_CREATE", property.ID))
		assert.True(t, ledger.HasEvent("QR_CODE_GENERATED", property.ID))
		assert.True(t, ledger.HasEvent("TRANSFER_REQUEST", property.ID))
		assert.True(t, ledger.HasEvent("TRANSFER_APPROVED", property.ID))
	})

	t.Run("Reject Invalid QR Code Hash", func(t *testing.T) {
		// Create tampered QR data with invalid hash
		qrData := map[string]interface{}{
			"type":            "handreceipt_property",
			"itemId":          "999",
			"serialNumber":    "FAKE-001",
			"itemName":        "Fake Item",
			"category":        "weapons",
			"currentHolderId": "999",
			"timestamp":       time.Now().Format(time.RFC3339),
			"qrHash":          "invalid_hash_that_wont_match",
		}

		scanRequest := domain.QRTransferRequest{
			QRData:    qrData,
			ScannedAt: time.Now().Format(time.RFC3339),
		}

		w := httptest.NewRecorder()
		body, _ := json.Marshal(scanRequest)
		req := httptest.NewRequest("POST", "/api/transfers/qr-initiate", bytes.NewReader(body))
		setUserContext(req, recipient.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusBadRequest, w.Code)
		assert.Contains(t, w.Body.String(), "Invalid QR code")
	})

	t.Run("Reject Self Transfer", func(t *testing.T) {
		// Create a new property for this test
		newProperty := createTestProperty(t, repo, "M16 Rifle", "M16-SELF-001", owner.ID)

		// Generate valid QR data
		qrData := generateValidQRData(newProperty.ID, newProperty.SerialNumber, "M16 Rifle", owner.ID)

		scanRequest := domain.QRTransferRequest{
			QRData:    qrData,
			ScannedAt: time.Now().Format(time.RFC3339),
		}

		w := httptest.NewRecorder()
		body, _ := json.Marshal(scanRequest)
		req := httptest.NewRequest("POST", "/api/transfers/qr-initiate", bytes.NewReader(body))
		setUserContext(req, owner.ID) // Same as property owner

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusBadRequest, w.Code)
		assert.Contains(t, w.Body.String(), "Cannot transfer to yourself")
	})

	t.Run("Reject Outdated QR Code", func(t *testing.T) {
		// Create new property and transfer it
		newProperty := createTestProperty(t, repo, "SAW", "SAW-001", owner.ID)

		// Generate QR with original owner
		qrData := generateValidQRData(newProperty.ID, newProperty.SerialNumber, "SAW", owner.ID)

		// Manually transfer property to recipient (simulating previous transfer)
		newProperty.AssignedToUserID = &recipient.ID
		err := repo.UpdateProperty(newProperty)
		assert.NoError(t, err)

		// Create third user to attempt scan with outdated QR
		thirdUser := createTestUser(t, repo, "third", "Charlie", "SPC")

		// Try to use old QR code (still references old owner)
		scanRequest := domain.QRTransferRequest{
			QRData:    qrData,
			ScannedAt: time.Now().Format(time.RFC3339),
		}

		w := httptest.NewRecorder()
		body, _ := json.Marshal(scanRequest)
		req := httptest.NewRequest("POST", "/api/transfers/qr-initiate", bytes.NewReader(body))
		setUserContext(req, thirdUser.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusBadRequest, w.Code)
		assert.Contains(t, w.Body.String(), "QR code is outdated")
	})

	t.Run("Reject Transfer for Non-Existent Property", func(t *testing.T) {
		// Generate QR data for non-existent property
		qrData := generateValidQRData(99999, "NONEXISTENT-001", "Fake Item", owner.ID)

		scanRequest := domain.QRTransferRequest{
			QRData:    qrData,
			ScannedAt: time.Now().Format(time.RFC3339),
		}

		w := httptest.NewRecorder()
		body, _ := json.Marshal(scanRequest)
		req := httptest.NewRequest("POST", "/api/transfers/qr-initiate", bytes.NewReader(body))
		setUserContext(req, recipient.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusNotFound, w.Code)
		assert.Contains(t, w.Body.String(), "Property not found")
	})

	t.Run("QR Code Management", func(t *testing.T) {
		// Create property for QR management tests
		qrProperty := createTestProperty(t, repo, "Radio", "RADIO-001", owner.ID)

		// Generate QR code
		w := httptest.NewRecorder()
		req := httptest.NewRequest("POST", fmt.Sprintf("/api/inventory/qrcode/%d", qrProperty.ID), nil)
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		// Get all QR codes
		w = httptest.NewRecorder()
		req = httptest.NewRequest("GET", "/api/qrcodes", nil)
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		var qrCodesResponse struct {
			QRCodes []map[string]interface{} `json:"qrcodes"`
		}
		json.Unmarshal(w.Body.Bytes(), &qrCodesResponse)
		assert.Greater(t, len(qrCodesResponse.QRCodes), 0)

		// Find the QR code we just created
		var qrCodeID string
		for _, qr := range qrCodesResponse.QRCodes {
			if qr["inventoryItemId"] == fmt.Sprintf("%d", qrProperty.ID) {
				qrCodeID = qr["id"].(string)
				break
			}
		}
		assert.NotEmpty(t, qrCodeID)

		// Report QR code as damaged
		damageRequest := map[string]string{
			"reason": "QR code is scratched and unreadable",
		}

		w = httptest.NewRecorder()
		body, _ := json.Marshal(damageRequest)
		req = httptest.NewRequest("POST", fmt.Sprintf("/api/qrcodes/%s/report-damaged", qrCodeID), bytes.NewReader(body))
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		// Verify QR code is marked as damaged
		w = httptest.NewRecorder()
		req = httptest.NewRequest("GET", "/api/qrcodes", nil)
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		json.Unmarshal(w.Body.Bytes(), &qrCodesResponse)
		found := false
		for _, qr := range qrCodesResponse.QRCodes {
			if qr["id"] == qrCodeID {
				assert.False(t, qr["isActive"].(bool))
				found = true
				break
			}
		}
		assert.True(t, found, "Damaged QR code should be found in response")
	})

	t.Run("Transfer Rejection Flow", func(t *testing.T) {
		// Create property for rejection test
		rejectProperty := createTestProperty(t, repo, "Pistol", "PISTOL-001", owner.ID)

		// Generate QR and initiate transfer
		qrData := generateValidQRData(rejectProperty.ID, rejectProperty.SerialNumber, "Pistol", owner.ID)

		scanRequest := domain.QRTransferRequest{
			QRData:    qrData,
			ScannedAt: time.Now().Format(time.RFC3339),
		}

		w := httptest.NewRecorder()
		body, _ := json.Marshal(scanRequest)
		req := httptest.NewRequest("POST", "/api/transfers/qr-initiate", bytes.NewReader(body))
		setUserContext(req, recipient.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		var transferResponse struct {
			TransferID string `json:"transferId"`
			Status     string `json:"status"`
		}
		json.Unmarshal(w.Body.Bytes(), &transferResponse)

		// Owner rejects transfer
		rejectRequest := domain.UpdateTransferInput{
			Status: "Rejected",
			Notes:  stringPtr("Item is currently needed for training exercise"),
		}

		w = httptest.NewRecorder()
		body, _ = json.Marshal(rejectRequest)
		req = httptest.NewRequest("PATCH", fmt.Sprintf("/api/transfers/%s/status", transferResponse.TransferID), bytes.NewReader(body))
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		// Verify property ownership unchanged
		unchangedProperty, err := repo.GetPropertyByID(rejectProperty.ID)
		assert.NoError(t, err)
		assert.Equal(t, owner.ID, *unchangedProperty.AssignedToUserID)

		// Verify transfer status
		w = httptest.NewRecorder()
		req = httptest.NewRequest("GET", "/api/transfers", nil)
		setUserContext(req, owner.ID)

		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)

		var transfers []domain.Transfer
		json.Unmarshal(w.Body.Bytes(), &transfers)

		found := false
		for _, transfer := range transfers {
			if fmt.Sprintf("%d", transfer.ID) == transferResponse.TransferID {
				assert.Equal(t, "Rejected", transfer.Status)
				assert.Equal(t, "Item is currently needed for training exercise", *transfer.Notes)
				found = true
				break
			}
		}
		assert.True(t, found, "Rejected transfer should be found")
	})
}

// Helper functions
func generateValidQRData(itemID uint, serialNumber, itemName string, holderID uint) map[string]interface{} {
	qrData := map[string]interface{}{
		"type":            "handreceipt_property",
		"itemId":          fmt.Sprintf("%d", itemID),
		"serialNumber":    serialNumber,
		"itemName":        itemName,
		"category":        "weapons",
		"currentHolderId": fmt.Sprintf("%d", holderID),
		"timestamp":       time.Now().Format(time.RFC3339),
	}

	// Generate valid hash (same as in QR service)
	qrDataWithoutHash := make(map[string]interface{})
	for k, v := range qrData {
		if k != "qrHash" {
			qrDataWithoutHash[k] = v
		}
	}

	qrJSON, _ := json.Marshal(qrDataWithoutHash)
	hash := sha256.Sum256(qrJSON)
	qrData["qrHash"] = hex.EncodeToString(hash[:])

	return qrData
}

func setUserContext(req *http.Request, userID uint) {
	// Simulate authenticated user context
	req.Header.Set("X-User-ID", fmt.Sprintf("%d", userID))
}

func createTestUser(t *testing.T, repo repository.Repository, username, name, rank string) *domain.User {
	user := &domain.User{
		Username: username,
		Password: "hashed_password",
		Name:     name,
		Rank:     rank,
	}
	err := repo.CreateUser(user)
	assert.NoError(t, err)
	return user
}

func createTestProperty(t *testing.T, repo repository.Repository, name, serial string, ownerID uint) *domain.Property {
	property := &domain.Property{
		Name:             name,
		SerialNumber:     serial,
		Description:      stringPtr("Test property"),
		CurrentStatus:    "Operational",
		AssignedToUserID: &ownerID,
	}
	err := repo.CreateProperty(property)
	assert.NoError(t, err)
	return property
}

func stringPtr(s string) *string {
	return &s
}

// Mock ledger service for testing
type MockLedgerService struct {
	events map[string][]uint
}

func (m *MockLedgerService) LogItemCreation(itemID uint, serialNumber string, userID uint) error {
	if m.events == nil {
		m.events = make(map[string][]uint)
	}
	m.events["ITEM_CREATE"] = append(m.events["ITEM_CREATE"], itemID)
	return nil
}

func (m *MockLedgerService) LogTransferRequest(propertyID uint, fromUserID, toUserID uint, transferID uint) error {
	if m.events == nil {
		m.events = make(map[string][]uint)
	}
	m.events["TRANSFER_REQUEST"] = append(m.events["TRANSFER_REQUEST"], propertyID)
	return nil
}

func (m *MockLedgerService) LogTransferApproval(propertyID uint, fromUserID, toUserID uint, transferID uint) error {
	if m.events == nil {
		m.events = make(map[string][]uint)
	}
	m.events["TRANSFER_APPROVED"] = append(m.events["TRANSFER_APPROVED"], propertyID)
	return nil
}

func (m *MockLedgerService) LogQRCodeGeneration(propertyID uint, serialNumber string, userID uint) error {
	if m.events == nil {
		m.events = make(map[string][]uint)
	}
	m.events["QR_CODE_GENERATED"] = append(m.events["QR_CODE_GENERATED"], propertyID)
	return nil
}

func (m *MockLedgerService) LogVerificationEvent(propertyID uint, serialNumber string, userID uint, eventType string) error {
	if m.events == nil {
		m.events = make(map[string][]uint)
	}
	m.events[eventType] = append(m.events[eventType], propertyID)
	return nil
}

func (m *MockLedgerService) HasEvent(eventType string, itemID uint) bool {
	if m.events == nil {
		return false
	}
	events, exists := m.events[eventType]
	if !exists {
		return false
	}
	for _, id := range events {
		if id == itemID {
			return true
		}
	}
	return false
}

// Required LedgerService methods
func (m *MockLedgerService) GetLedgerHistory(limit int, offset int) ([]interface{}, error) {
	return []interface{}{}, nil
}

func (m *MockLedgerService) GetAllCorrectionEvents() ([]domain.CorrectionEvent, error) {
	return []domain.CorrectionEvent{}, nil
}

func (m *MockLedgerService) Close() error {
	return nil
}

// Mock repository for testing
type MockRepository struct{}

func (m *MockRepository) CreateUser(user *domain.User) error {
	user.ID = 1 // Mock ID
	return nil
}

func (m *MockRepository) GetUserByID(id uint) (*domain.User, error) {
	return &domain.User{ID: id, Username: "testuser", Name: "Test User"}, nil
}

func (m *MockRepository) GetUserByUsername(username string) (*domain.User, error) {
	return &domain.User{ID: 1, Username: username, Name: "Test User"}, nil
}

func (m *MockRepository) GetAllUsers() ([]domain.User, error) {
	return []domain.User{}, nil
}

func (m *MockRepository) CreateProperty(property *domain.Property) error {
	property.ID = 1 // Mock ID
	return nil
}

func (m *MockRepository) GetPropertyByID(id uint) (*domain.Property, error) {
	ownerID := uint(1)
	return &domain.Property{
		ID:               id,
		Name:             "Test Property",
		SerialNumber:     "TEST-001",
		CurrentStatus:    "Operational",
		AssignedToUserID: &ownerID,
	}, nil
}

func (m *MockRepository) GetPropertyBySerialNumber(serialNumber string) (*domain.Property, error) {
	ownerID := uint(1)
	return &domain.Property{
		ID:               1,
		SerialNumber:     serialNumber,
		CurrentStatus:    "Operational",
		AssignedToUserID: &ownerID,
	}, nil
}

func (m *MockRepository) UpdateProperty(property *domain.Property) error {
	return nil
}

func (m *MockRepository) ListProperties(assignedUserID *uint) ([]domain.Property, error) {
	return []domain.Property{}, nil
}

func (m *MockRepository) GetPropertyTypeByID(id uint) (*domain.PropertyType, error) {
	return &domain.PropertyType{ID: id}, nil
}

func (m *MockRepository) ListPropertyTypes() ([]domain.PropertyType, error) {
	return []domain.PropertyType{}, nil
}

func (m *MockRepository) GetPropertyModelByID(id uint) (*domain.PropertyModel, error) {
	return &domain.PropertyModel{ID: id}, nil
}

func (m *MockRepository) GetPropertyModelByNSN(nsn string) (*domain.PropertyModel, error) {
	return &domain.PropertyModel{ID: 1, Nsn: nsn}, nil
}

func (m *MockRepository) ListPropertyModels(typeID *uint) ([]domain.PropertyModel, error) {
	return []domain.PropertyModel{}, nil
}

func (m *MockRepository) CreateTransfer(transfer *domain.Transfer) error {
	transfer.ID = 1 // Mock ID
	return nil
}

func (m *MockRepository) GetTransferByID(id uint) (*domain.Transfer, error) {
	return &domain.Transfer{
		ID:         id,
		Status:     "Requested",
		FromUserID: 1,
		ToUserID:   2,
		PropertyID: 1,
	}, nil
}

func (m *MockRepository) UpdateTransfer(transfer *domain.Transfer) error {
	return nil
}

func (m *MockRepository) ListTransfers(userID uint, status *string) ([]domain.Transfer, error) {
	return []domain.Transfer{}, nil
}

// QR Code methods
func (m *MockRepository) CreateQRCode(qrCode *domain.QRCode) error {
	qrCode.ID = 1 // Mock ID
	return nil
}

func (m *MockRepository) GetQRCodeByHash(hash string) (*domain.QRCode, error) {
	return &domain.QRCode{ID: 1, QRCodeHash: hash, IsActive: true}, nil
}

func (m *MockRepository) GetQRCodeByID(id uint) (*domain.QRCode, error) {
	return &domain.QRCode{ID: id, IsActive: true}, nil
}

func (m *MockRepository) UpdateQRCode(qrCode *domain.QRCode) error {
	return nil
}

func (m *MockRepository) ListAllQRCodes() ([]domain.QRCode, error) {
	return []domain.QRCode{}, nil
}

func (m *MockRepository) ListQRCodesForProperty(propertyID uint) ([]domain.QRCode, error) {
	return []domain.QRCode{}, nil
}

func (m *MockRepository) DeactivateQRCodesForProperty(propertyID uint) error {
	return nil
}

func (m *MockRepository) GetActiveQRCodeForProperty(propertyID uint) (*domain.QRCode, error) {
	return &domain.QRCode{ID: 1, InventoryItemID: propertyID, IsActive: true}, nil
}
