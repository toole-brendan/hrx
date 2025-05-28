package repository

import (
	"fmt"
	"regexp"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/stretchr/testify/assert"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"gorm.io/driver/postgres" // Using postgres dialect for realistic query generation
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// Helper function to set up a mock GORM database and repository
func setupMockDB(t *testing.T) (*gorm.DB, sqlmock.Sqlmock, Repository) {
	db, mock, err := sqlmock.New()
	assert.NoError(t, err)

	// Use postgres dialect, but connect it to the sqlmock
	dialector := postgres.New(postgres.Config{
		Conn:             db,
		WithoutReturning: true, // Recommended for tests to avoid RETURNING issues with mock
	})

	// Open GORM connection with logger in silent mode for cleaner test output
	gormDB, err := gorm.Open(dialector, &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	assert.NoError(t, err)

	repo := NewGormRepository(gormDB)

	return gormDB, mock, repo
}

func TestGormRepository_GetUserByID(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	expectedUserID := uint(1)
	expectedUsername := "testuser"
	expectedName := "Test User"
	expectedRank := "E4"
	mockUser := domain.User{
		ID:        expectedUserID,
		Username:  expectedUsername,
		Password:  "hashedpassword", // Field name is Password
		Name:      expectedName,     // Added Name
		Rank:      expectedRank,     // Added Rank
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	// Define the expected SQL query that GORM will generate
	// Updated columns to match the actual User struct and typical DB schema
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "users" WHERE "users"."id" = $1 ORDER BY "users"."id" LIMIT 1`)

	// Set up the expectation on the mock - Updated columns
	rows := sqlmock.NewRows([]string{"id", "username", "password", "name", "rank", "created_at", "updated_at"}).
		AddRow(mockUser.ID, mockUser.Username, mockUser.Password, mockUser.Name, mockUser.Rank, mockUser.CreatedAt, mockUser.UpdatedAt)

	mock.ExpectQuery(expectedSQL).
		WithArgs(expectedUserID). // Check the arguments passed to the query
		WillReturnRows(rows)      // Define the rows to return

	// Call the method under test
	user, err := repo.GetUserByID(expectedUserID)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, expectedUserID, user.ID)
	assert.Equal(t, expectedUsername, user.Username)
	assert.Equal(t, expectedName, user.Name) // Added assertion for Name
	assert.Equal(t, expectedRank, user.Rank) // Added assertion for Rank

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetUserByID")
}

func TestGormRepository_GetUserByID_NotFound(t *testing.T) {
	_, mock, repo := setupMockDB(t)
	targetUserID := uint(99)

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "users" WHERE "users"."id" = $1 ORDER BY "users"."id" LIMIT 1`)

	// Expect the query but return gorm.ErrRecordNotFound
	mock.ExpectQuery(expectedSQL).
		WithArgs(targetUserID).
		WillReturnError(gorm.ErrRecordNotFound) // Simulate not found

	// Call the method under test
	user, err := repo.GetUserByID(targetUserID)

	// Assertions
	assert.Error(t, err) // Expect an error
	// Check if the specific error message matches what the repository returns
	assert.Contains(t, err.Error(), fmt.Sprintf("user with ID %d not found", targetUserID))
	assert.Nil(t, user) // Expect user to be nil

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetUserByID_NotFound")
}

func TestGormRepository_CreateUser(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	newUser := &domain.User{
		Username: "newuser",
		Password: "newpasswordhash",
		Name:     "New User",
		Rank:     "E1",
		// ID, CreatedAt, UpdatedAt are usually handled by the DB/GORM
	}

	// Define the expected SQL INSERT query
	// GORM might include all fields, using placeholders for DB-generated ones.
	// Using AnyArg() for ID, created_at, updated_at assumes DB handles them or we don't care about the exact mock time.
	expectedSQL := regexp.QuoteMeta(`INSERT INTO "users" ("username","password","name","rank","created_at","updated_at","id") VALUES ($1,$2,$3,$4,$5,$6,$7)`)

	// Mock transaction flow for Create
	mock.ExpectBegin()
	mock.ExpectExec(expectedSQL).
		WithArgs(newUser.Username, newUser.Password, newUser.Name, newUser.Rank, sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg()). // Match args
		WillReturnResult(sqlmock.NewResult(1, 1))                                                                                       // Simulate 1 row inserted with ID 1
	mock.ExpectCommit()

	// Call the method under test
	err := repo.CreateUser(newUser)

	// Assertions
	assert.NoError(t, err)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for CreateUser")
}

func TestGormRepository_GetUserByUsername(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	expectedUserID := uint(2)
	expectedUsername := "findme"
	expectedName := "Find Me User"
	expectedRank := "E5"
	mockUser := domain.User{
		ID:        expectedUserID,
		Username:  expectedUsername,
		Password:  "hashedpassword2",
		Name:      expectedName,
		Rank:      expectedRank,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "users" WHERE username = $1 ORDER BY "users"."id" LIMIT 1`)

	// Set up the expectation on the mock
	rows := sqlmock.NewRows([]string{"id", "username", "password", "name", "rank", "created_at", "updated_at"}).
		AddRow(mockUser.ID, mockUser.Username, mockUser.Password, mockUser.Name, mockUser.Rank, mockUser.CreatedAt, mockUser.UpdatedAt)

	mock.ExpectQuery(expectedSQL).
		WithArgs(expectedUsername).
		WillReturnRows(rows)

	// Call the method under test
	user, err := repo.GetUserByUsername(expectedUsername)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, user)
	assert.Equal(t, expectedUserID, user.ID)
	assert.Equal(t, expectedUsername, user.Username)
	assert.Equal(t, expectedName, user.Name)
	assert.Equal(t, expectedRank, user.Rank)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetUserByUsername")
}

func TestGormRepository_GetUserByUsername_NotFound(t *testing.T) {
	_, mock, repo := setupMockDB(t)
	targetUsername := "nosuchuser"

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "users" WHERE username = $1 ORDER BY "users"."id" LIMIT 1`)

	// Expect the query but return gorm.ErrRecordNotFound
	mock.ExpectQuery(expectedSQL).
		WithArgs(targetUsername).
		WillReturnError(gorm.ErrRecordNotFound)

	// Call the method under test
	user, err := repo.GetUserByUsername(targetUsername)

	// Assertions
	assert.Error(t, err)
	assert.Contains(t, err.Error(), fmt.Sprintf("user with username '%s' not found", targetUsername))
	assert.Nil(t, user)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetUserByUsername_NotFound")
}

// --- Property Tests ---

func TestGormRepository_CreateProperty(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	newProperty := &domain.Property{
		Name:          "Test Property",
		SerialNumber:  "SN12345",
		CurrentStatus: "Operational",
		// Assume PropertyModelID and AssignedToUserID might be nil or set
	}

	// Define the expected SQL INSERT query
	expectedSQL := regexp.QuoteMeta(`INSERT INTO "properties" ("property_model_id","name","serial_number","description","current_status","assigned_to_user_id","last_verified_at","last_maintenance_at","created_at","updated_at","id") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`)

	// Mock transaction flow for Create
	mock.ExpectBegin()
	mock.ExpectExec(expectedSQL).
		WithArgs(
			newProperty.PropertyModelID, // Use the actual value (could be nil)
			newProperty.Name,
			newProperty.SerialNumber,
			newProperty.Description, // Use the actual value (could be nil)
			newProperty.CurrentStatus,
			newProperty.AssignedToUserID,  // Use the actual value (could be nil)
			newProperty.LastVerifiedAt,    // Use the actual value (could be nil)
			newProperty.LastMaintenanceAt, // Use the actual value (could be nil)
			sqlmock.AnyArg(),              // created_at
			sqlmock.AnyArg(),              // updated_at
			sqlmock.AnyArg(),              // id
		).
		WillReturnResult(sqlmock.NewResult(1, 1)) // Simulate 1 row inserted
	mock.ExpectCommit()

	// Call the method under test
	err := repo.CreateProperty(newProperty)

	// Assertions
	assert.NoError(t, err)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for CreateProperty")
}

func TestGormRepository_GetPropertyByID(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	expectedPropertyID := uint(10)
	expectedSerialNumber := "SN-PROP-10"
	mockProperty := domain.Property{
		ID:            expectedPropertyID,
		Name:          "Property Ten",
		SerialNumber:  expectedSerialNumber,
		CurrentStatus: "Stored",
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
		// Other fields can be nil or have default values
	}

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "properties" WHERE "properties"."id" = $1 ORDER BY "properties"."id" LIMIT 1`)

	// Set up the expectation on the mock - match columns in Property struct
	rows := sqlmock.NewRows([]string{
		"id", "property_model_id", "name", "serial_number", "description", "current_status",
		"assigned_to_user_id", "last_verified_at", "last_maintenance_at", "created_at", "updated_at",
	}).AddRow(
		mockProperty.ID, mockProperty.PropertyModelID, mockProperty.Name, mockProperty.SerialNumber,
		mockProperty.Description, mockProperty.CurrentStatus, mockProperty.AssignedToUserID,
		mockProperty.LastVerifiedAt, mockProperty.LastMaintenanceAt, mockProperty.CreatedAt, mockProperty.UpdatedAt,
	)

	mock.ExpectQuery(expectedSQL).
		WithArgs(expectedPropertyID).
		WillReturnRows(rows)

	// Call the method under test
	property, err := repo.GetPropertyByID(expectedPropertyID)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, property)
	assert.Equal(t, expectedPropertyID, property.ID)
	assert.Equal(t, expectedSerialNumber, property.SerialNumber)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyByID")
}

func TestGormRepository_GetPropertyByID_NotFound(t *testing.T) {
	_, mock, repo := setupMockDB(t)
	targetPropertyID := uint(999)

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "properties" WHERE "properties"."id" = $1 ORDER BY "properties"."id" LIMIT 1`)

	// Expect the query but return gorm.ErrRecordNotFound
	mock.ExpectQuery(expectedSQL).
		WithArgs(targetPropertyID).
		WillReturnError(gorm.ErrRecordNotFound)

	// Call the method under test
	property, err := repo.GetPropertyByID(targetPropertyID)

	// Assertions
	assert.Error(t, err)
	assert.Contains(t, err.Error(), fmt.Sprintf("property with ID %d not found", targetPropertyID))
	assert.Nil(t, property)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyByID_NotFound")
}

func TestGormRepository_GetPropertyBySerialNumber(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	expectedPropertyID := uint(20)
	expectedSerialNumber := "SN-PROP-20"
	mockProperty := domain.Property{
		ID:            expectedPropertyID,
		Name:          "Property Twenty",
		SerialNumber:  expectedSerialNumber,
		CurrentStatus: "In Use",
		CreatedAt:     time.Now(),
		UpdatedAt:     time.Now(),
	}

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "properties" WHERE serial_number = $1 ORDER BY "properties"."id" LIMIT 1`)

	// Set up the expectation on the mock
	rows := sqlmock.NewRows([]string{
		"id", "property_model_id", "name", "serial_number", "description", "current_status",
		"assigned_to_user_id", "last_verified_at", "last_maintenance_at", "created_at", "updated_at",
	}).AddRow(
		mockProperty.ID, mockProperty.PropertyModelID, mockProperty.Name, mockProperty.SerialNumber,
		mockProperty.Description, mockProperty.CurrentStatus, mockProperty.AssignedToUserID,
		mockProperty.LastVerifiedAt, mockProperty.LastMaintenanceAt, mockProperty.CreatedAt, mockProperty.UpdatedAt,
	)

	mock.ExpectQuery(expectedSQL).
		WithArgs(expectedSerialNumber).
		WillReturnRows(rows)

	// Call the method under test
	property, err := repo.GetPropertyBySerialNumber(expectedSerialNumber)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, property)
	assert.Equal(t, expectedPropertyID, property.ID)
	assert.Equal(t, expectedSerialNumber, property.SerialNumber)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyBySerialNumber")
}

func TestGormRepository_GetPropertyBySerialNumber_NotFound(t *testing.T) {
	_, mock, repo := setupMockDB(t)
	targetSerialNumber := "SN-DOES-NOT-EXIST"

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "properties" WHERE serial_number = $1 ORDER BY "properties"."id" LIMIT 1`)

	// Expect the query but return gorm.ErrRecordNotFound
	mock.ExpectQuery(expectedSQL).
		WithArgs(targetSerialNumber).
		WillReturnError(gorm.ErrRecordNotFound)

	// Call the method under test
	property, err := repo.GetPropertyBySerialNumber(targetSerialNumber)

	// Assertions
	assert.Error(t, err)
	assert.Contains(t, err.Error(), fmt.Sprintf("property with serial number '%s' not found", targetSerialNumber))
	assert.Nil(t, property)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyBySerialNumber_NotFound")
}

func TestGormRepository_UpdateProperty(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	updatedProperty := &domain.Property{
		ID:            30,
		Name:          "Updated Property Name",
		SerialNumber:  "SN-UPDATE-ME",
		CurrentStatus: "Under Maintenance",
		UpdatedAt:     time.Now(), // GORM Save usually updates UpdatedAt
		// Assume other fields might be updated too
		// We need to ensure all fields expected by GORM's Save are present in the SQL
	}

	// GORM's Save typically generates an UPDATE statement setting all fields
	// including potentially unchanged ones, identified by the primary key.
	expectedSQL := regexp.QuoteMeta(`UPDATE "properties" SET "property_model_id"=$1,"name"=$2,"serial_number"=$3,"description"=$4,"current_status"=$5,"assigned_to_user_id"=$6,"last_verified_at"=$7,"last_maintenance_at"=$8,"created_at"=$9,"updated_at"=$10 WHERE "id" = $11`)

	// Mock transaction flow for Update (Save)
	mock.ExpectBegin()
	mock.ExpectExec(expectedSQL).
		WithArgs(
			updatedProperty.PropertyModelID, // Send current values, even if nil/zero
			updatedProperty.Name,
			updatedProperty.SerialNumber,
			updatedProperty.Description,
			updatedProperty.CurrentStatus,
			updatedProperty.AssignedToUserID,
			updatedProperty.LastVerifiedAt,
			updatedProperty.LastMaintenanceAt,
			updatedProperty.CreatedAt, // Save typically includes CreatedAt
			sqlmock.AnyArg(),          // Expect UpdatedAt to be updated
			updatedProperty.ID,        // WHERE clause argument
		).
		WillReturnResult(sqlmock.NewResult(0, 1)) // Simulate 1 row affected
	mock.ExpectCommit()

	// Call the method under test
	err := repo.UpdateProperty(updatedProperty)

	// Assertions
	assert.NoError(t, err)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for UpdateProperty")
}

func TestGormRepository_ListProperties_All(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	mockProperties := []domain.Property{
		{ID: 1, Name: "Prop 1", SerialNumber: "SN1", CurrentStatus: "Op"},
		{ID: 2, Name: "Prop 2", SerialNumber: "SN2", CurrentStatus: "Maint"},
	}

	// Define the expected SQL query for listing all
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "properties"`)

	// Set up the expectation on the mock
	rows := sqlmock.NewRows([]string{"id", "name", "serial_number", "current_status"}).
		AddRow(mockProperties[0].ID, mockProperties[0].Name, mockProperties[0].SerialNumber, mockProperties[0].CurrentStatus).
		AddRow(mockProperties[1].ID, mockProperties[1].Name, mockProperties[1].SerialNumber, mockProperties[1].CurrentStatus)
	// Add more columns as needed by the actual query/struct mapping

	mock.ExpectQuery(expectedSQL).
		WillReturnRows(rows)

	// Call the method under test (passing nil for assignedUserID)
	properties, err := repo.ListProperties(nil)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, properties)
	assert.Len(t, properties, 2)
	assert.Equal(t, mockProperties[0].Name, properties[0].Name)
	assert.Equal(t, mockProperties[1].SerialNumber, properties[1].SerialNumber)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for ListProperties_All")
}

func TestGormRepository_ListProperties_ByAssignedUser(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	targetUserID := uint(5)
	mockProperties := []domain.Property{
		{ID: 3, Name: "Prop 3", SerialNumber: "SN3", CurrentStatus: "Op", AssignedToUserID: &targetUserID},
	}

	// Define the expected SQL query for listing by user ID
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "properties" WHERE assigned_to_user_id = $1`)

	// Set up the expectation on the mock
	rows := sqlmock.NewRows([]string{"id", "name", "serial_number", "current_status", "assigned_to_user_id"}).
		AddRow(mockProperties[0].ID, mockProperties[0].Name, mockProperties[0].SerialNumber, mockProperties[0].CurrentStatus, *mockProperties[0].AssignedToUserID)

	mock.ExpectQuery(expectedSQL).
		WithArgs(targetUserID).
		WillReturnRows(rows)

	// Call the method under test
	properties, err := repo.ListProperties(&targetUserID)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, properties)
	assert.Len(t, properties, 1)
	assert.Equal(t, mockProperties[0].ID, properties[0].ID)
	assert.Equal(t, targetUserID, *properties[0].AssignedToUserID)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for ListProperties_ByAssignedUser")
}

// --- Transfer Tests ---

func TestGormRepository_CreateTransfer(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	newTransfer := &domain.Transfer{
		PropertyID: 100,
		FromUserID: 1,
		ToUserID:   2,
		Status:     "Requested",
		// RequestDate, CreatedAt, UpdatedAt usually handled by DB/GORM
	}

	// Define the expected SQL INSERT query for transfers
	expectedSQL := regexp.QuoteMeta(`INSERT INTO "transfers" ("property_id","from_user_id","to_user_id","status","request_date","resolved_date","notes","created_at","updated_at","id") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`)

	// Mock transaction flow for Create
	mock.ExpectBegin()
	mock.ExpectExec(expectedSQL).
		WithArgs(
			newTransfer.PropertyID,
			newTransfer.FromUserID,
			newTransfer.ToUserID,
			newTransfer.Status,
			sqlmock.AnyArg(),         // request_date
			newTransfer.ResolvedDate, // Use actual value (likely nil initially)
			newTransfer.Notes,        // Use actual value (likely nil initially)
			sqlmock.AnyArg(),         // created_at
			sqlmock.AnyArg(),         // updated_at
			sqlmock.AnyArg(),         // id
		).
		WillReturnResult(sqlmock.NewResult(1, 1)) // Simulate 1 row inserted
	mock.ExpectCommit()

	// Call the method under test
	err := repo.CreateTransfer(newTransfer)

	// Assertions
	assert.NoError(t, err)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for CreateTransfer")
}

func TestGormRepository_GetTransferByID(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	expectedTransferID := uint(50)
	mockTransfer := domain.Transfer{
		ID:          expectedTransferID,
		PropertyID:  101,
		FromUserID:  3,
		ToUserID:    4,
		Status:      "Approved",
		RequestDate: time.Now().Add(-time.Hour),
		CreatedAt:   time.Now().Add(-time.Hour),
		UpdatedAt:   time.Now(),
	}

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "transfers" WHERE "transfers"."id" = $1 ORDER BY "transfers"."id" LIMIT 1`)

	// Set up the expectation on the mock - match columns in Transfer struct
	rows := sqlmock.NewRows([]string{
		"id", "property_id", "from_user_id", "to_user_id", "status",
		"request_date", "resolved_date", "notes", "created_at", "updated_at",
	}).AddRow(
		mockTransfer.ID, mockTransfer.PropertyID, mockTransfer.FromUserID, mockTransfer.ToUserID, mockTransfer.Status,
		mockTransfer.RequestDate, mockTransfer.ResolvedDate, mockTransfer.Notes, mockTransfer.CreatedAt, mockTransfer.UpdatedAt,
	)

	mock.ExpectQuery(expectedSQL).
		WithArgs(expectedTransferID).
		WillReturnRows(rows)

	// Call the method under test
	transfer, err := repo.GetTransferByID(expectedTransferID)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, transfer)
	assert.Equal(t, expectedTransferID, transfer.ID)
	assert.Equal(t, mockTransfer.Status, transfer.Status)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetTransferByID")
}

func TestGormRepository_GetTransferByID_NotFound(t *testing.T) {
	_, mock, repo := setupMockDB(t)
	targetTransferID := uint(9999)

	// Define the expected SQL query
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "transfers" WHERE "transfers"."id" = $1 ORDER BY "transfers"."id" LIMIT 1`)

	// Expect the query but return gorm.ErrRecordNotFound
	mock.ExpectQuery(expectedSQL).
		WithArgs(targetTransferID).
		WillReturnError(gorm.ErrRecordNotFound)

	// Call the method under test
	transfer, err := repo.GetTransferByID(targetTransferID)

	// Assertions
	assert.Error(t, err)
	assert.Contains(t, err.Error(), fmt.Sprintf("transfer with ID %d not found", targetTransferID))
	assert.Nil(t, transfer)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetTransferByID_NotFound")
}

func TestGormRepository_UpdateTransfer(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	updatedTransfer := &domain.Transfer{
		ID:           60,
		PropertyID:   102,
		FromUserID:   5,
		ToUserID:     6,
		Status:       "Completed",
		RequestDate:  time.Now().Add(-2 * time.Hour),                     // Existing request date
		ResolvedDate: func() *time.Time { t := time.Now(); return &t }(), // Set resolved date
		CreatedAt:    time.Now().Add(-2 * time.Hour),                     // Existing created date
		// GORM Save will update UpdatedAt
	}

	// Define the expected SQL UPDATE query from GORM Save
	expectedSQL := regexp.QuoteMeta(`UPDATE "transfers" SET "property_id"=$1,"from_user_id"=$2,"to_user_id"=$3,"status"=$4,"request_date"=$5,"resolved_date"=$6,"notes"=$7,"created_at"=$8,"updated_at"=$9 WHERE "id" = $10`)

	// Mock transaction flow for Update (Save)
	mock.ExpectBegin()
	mock.ExpectExec(expectedSQL).
		WithArgs(
			updatedTransfer.PropertyID,
			updatedTransfer.FromUserID,
			updatedTransfer.ToUserID,
			updatedTransfer.Status,
			updatedTransfer.RequestDate,
			updatedTransfer.ResolvedDate,
			updatedTransfer.Notes,
			updatedTransfer.CreatedAt,
			sqlmock.AnyArg(),   // updated_at
			updatedTransfer.ID, // WHERE clause argument
		).
		WillReturnResult(sqlmock.NewResult(0, 1)) // Simulate 1 row affected
	mock.ExpectCommit()

	// Call the method under test
	err := repo.UpdateTransfer(updatedTransfer)

	// Assertions
	assert.NoError(t, err)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for UpdateTransfer")
}

func TestGormRepository_ListTransfers_ByUser(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	targetUserID := uint(7)
	mockTransfers := []domain.Transfer{
		{ID: 71, PropertyID: 103, FromUserID: targetUserID, ToUserID: 8, Status: "Requested"}, // User is sender
		{ID: 72, PropertyID: 104, FromUserID: 9, ToUserID: targetUserID, Status: "Approved"},  // User is receiver
	}

	// Define the expected SQL query (no status filter)
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "transfers" WHERE (from_user_id = $1 OR to_user_id = $2) ORDER BY request_date desc`)

	// Set up the expectation on the mock
	rows := sqlmock.NewRows([]string{"id", "property_id", "from_user_id", "to_user_id", "status"}).
		AddRow(mockTransfers[0].ID, mockTransfers[0].PropertyID, mockTransfers[0].FromUserID, mockTransfers[0].ToUserID, mockTransfers[0].Status).
		AddRow(mockTransfers[1].ID, mockTransfers[1].PropertyID, mockTransfers[1].FromUserID, mockTransfers[1].ToUserID, mockTransfers[1].Status)

	mock.ExpectQuery(expectedSQL).
		WithArgs(targetUserID, targetUserID). // Should pass the user ID twice for OR clause
		WillReturnRows(rows)

	// Call the method under test (nil status)
	transfers, err := repo.ListTransfers(targetUserID, nil)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, transfers)
	assert.Len(t, transfers, 2)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for ListTransfers_ByUser")
}

func TestGormRepository_ListTransfers_ByUserAndStatus(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	targetUserID := uint(8)
	targetStatus := "Requested"
	mockTransfers := []domain.Transfer{
		{ID: 81, PropertyID: 105, FromUserID: targetUserID, ToUserID: 9, Status: targetStatus}, // User is sender, status matches
	}

	// Define the expected SQL query (with status filter)
	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "transfers" WHERE (from_user_id = $1 OR to_user_id = $2) AND status = $3 ORDER BY request_date desc`)

	// Set up the expectation on the mock
	rows := sqlmock.NewRows([]string{"id", "property_id", "from_user_id", "to_user_id", "status"}).
		AddRow(mockTransfers[0].ID, mockTransfers[0].PropertyID, mockTransfers[0].FromUserID, mockTransfers[0].ToUserID, mockTransfers[0].Status)

	mock.ExpectQuery(expectedSQL).
		WithArgs(targetUserID, targetUserID, targetStatus). // User ID twice + status
		WillReturnRows(rows)

	// Call the method under test (with status)
	transfers, err := repo.ListTransfers(targetUserID, &targetStatus)

	// Assertions
	assert.NoError(t, err)
	assert.NotNil(t, transfers)
	assert.Len(t, transfers, 1)
	assert.Equal(t, mockTransfers[0].ID, transfers[0].ID)
	assert.Equal(t, targetStatus, transfers[0].Status)

	// Verify that all expectations were met
	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for ListTransfers_ByUserAndStatus")
}

// --- PropertyType / PropertyModel Tests ---

func TestGormRepository_GetPropertyTypeByID(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	expectedTypeID := uint(1)
	expectedTypeName := "Weapon"
	mockType := domain.PropertyType{
		ID:   expectedTypeID,
		Name: expectedTypeName,
	}

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_types" WHERE "property_types"."id" = $1 ORDER BY "property_types"."id" LIMIT 1`)

	rows := sqlmock.NewRows([]string{"id", "name", "description", "created_at", "updated_at"}).
		AddRow(mockType.ID, mockType.Name, mockType.Description, mockType.CreatedAt, mockType.UpdatedAt)

	mock.ExpectQuery(expectedSQL).
		WithArgs(expectedTypeID).
		WillReturnRows(rows)

	propType, err := repo.GetPropertyTypeByID(expectedTypeID)

	assert.NoError(t, err)
	assert.NotNil(t, propType)
	assert.Equal(t, expectedTypeID, propType.ID)
	assert.Equal(t, expectedTypeName, propType.Name)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyTypeByID")
}

func TestGormRepository_GetPropertyTypeByID_NotFound(t *testing.T) {
	_, mock, repo := setupMockDB(t)
	targetTypeID := uint(99)

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_types" WHERE "property_types"."id" = $1 ORDER BY "property_types"."id" LIMIT 1`)

	mock.ExpectQuery(expectedSQL).
		WithArgs(targetTypeID).
		WillReturnError(gorm.ErrRecordNotFound)

	propType, err := repo.GetPropertyTypeByID(targetTypeID)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), fmt.Sprintf("property type with ID %d not found", targetTypeID))
	assert.Nil(t, propType)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyTypeByID_NotFound")
}

func TestGormRepository_ListPropertyTypes(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	mockTypes := []domain.PropertyType{
		{ID: 1, Name: "Weapon"},
		{ID: 2, Name: "Comms"},
	}

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_types"`)

	rows := sqlmock.NewRows([]string{"id", "name"}).
		AddRow(mockTypes[0].ID, mockTypes[0].Name).
		AddRow(mockTypes[1].ID, mockTypes[1].Name)

	mock.ExpectQuery(expectedSQL).
		WillReturnRows(rows)

	propTypes, err := repo.ListPropertyTypes()

	assert.NoError(t, err)
	assert.NotNil(t, propTypes)
	assert.Len(t, propTypes, 2)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for ListPropertyTypes")
}

func TestGormRepository_GetPropertyModelByID(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	expectedModelID := uint(10)
	expectedModelName := "M4 Carbine"
	mockModel := domain.PropertyModel{
		ID:        expectedModelID,
		ModelName: expectedModelName,
	}

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_models" WHERE "property_models"."id" = $1 ORDER BY "property_models"."id" LIMIT 1`)

	rows := sqlmock.NewRows([]string{"id", "property_type_id", "model_name", "manufacturer", "nsn", "description", "specifications", "image_url", "created_at", "updated_at"}).
		AddRow(mockModel.ID, mockModel.PropertyTypeID, mockModel.ModelName, mockModel.Manufacturer, mockModel.Nsn, mockModel.Description, mockModel.Specifications, mockModel.ImageURL, mockModel.CreatedAt, mockModel.UpdatedAt)

	mock.ExpectQuery(expectedSQL).
		WithArgs(expectedModelID).
		WillReturnRows(rows)

	model, err := repo.GetPropertyModelByID(expectedModelID)

	assert.NoError(t, err)
	assert.NotNil(t, model)
	assert.Equal(t, expectedModelID, model.ID)
	assert.Equal(t, expectedModelName, model.ModelName)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyModelByID")
}

func TestGormRepository_GetPropertyModelByID_NotFound(t *testing.T) {
	_, mock, repo := setupMockDB(t)
	targetModelID := uint(99)

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_models" WHERE "property_models"."id" = $1 ORDER BY "property_models"."id" LIMIT 1`)

	mock.ExpectQuery(expectedSQL).
		WithArgs(targetModelID).
		WillReturnError(gorm.ErrRecordNotFound)

	model, err := repo.GetPropertyModelByID(targetModelID)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), fmt.Sprintf("property model with ID %d not found", targetModelID))
	assert.Nil(t, model)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyModelByID_NotFound")
}

func TestGormRepository_GetPropertyModelByNSN(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	expectedModelID := uint(11)
	targetNsnStr := "1234-01-234-5678"
	targetNsn := &targetNsnStr // NSN is a pointer in the domain model
	mockModel := domain.PropertyModel{
		ID:  expectedModelID,
		Nsn: targetNsn,
	}

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_models" WHERE nsn = $1 ORDER BY "property_models"."id" LIMIT 1`)

	rows := sqlmock.NewRows([]string{"id", "nsn"}).
		AddRow(mockModel.ID, *mockModel.Nsn)

	mock.ExpectQuery(expectedSQL).
		WithArgs(targetNsnStr).
		WillReturnRows(rows)

	model, err := repo.GetPropertyModelByNSN(targetNsnStr)

	assert.NoError(t, err)
	assert.NotNil(t, model)
	assert.Equal(t, expectedModelID, model.ID)
	assert.Equal(t, targetNsnStr, *model.Nsn)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyModelByNSN")
}

func TestGormRepository_GetPropertyModelByNSN_NotFound(t *testing.T) {
	_, mock, repo := setupMockDB(t)
	targetNsn := "XXXX-XX-XXX-XXXX"

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_models" WHERE nsn = $1 ORDER BY "property_models"."id" LIMIT 1`)

	mock.ExpectQuery(expectedSQL).
		WithArgs(targetNsn).
		WillReturnError(gorm.ErrRecordNotFound)

	model, err := repo.GetPropertyModelByNSN(targetNsn)

	assert.Error(t, err)
	assert.Contains(t, err.Error(), fmt.Sprintf("property model with NSN '%s' not found", targetNsn))
	assert.Nil(t, model)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetPropertyModelByNSN_NotFound")
}

func TestGormRepository_ListPropertyModels_All(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	mockModels := []domain.PropertyModel{
		{ID: 10, ModelName: "M4 Carbine"},
		{ID: 11, ModelName: "AN/PRC-152"},
	}

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_models"`)

	rows := sqlmock.NewRows([]string{"id", "model_name"}).
		AddRow(mockModels[0].ID, mockModels[0].ModelName).
		AddRow(mockModels[1].ID, mockModels[1].ModelName)

	mock.ExpectQuery(expectedSQL).
		WillReturnRows(rows)

	models, err := repo.ListPropertyModels(nil)

	assert.NoError(t, err)
	assert.NotNil(t, models)
	assert.Len(t, models, 2)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for ListPropertyModels_All")
}

func TestGormRepository_ListPropertyModels_ByType(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	targetTypeID := uint(1) // e.g., Weapon type
	mockModels := []domain.PropertyModel{
		{ID: 10, ModelName: "M4 Carbine", PropertyTypeID: targetTypeID},
	}

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "property_models" WHERE property_type_id = $1`)

	rows := sqlmock.NewRows([]string{"id", "model_name", "property_type_id"}).
		AddRow(mockModels[0].ID, mockModels[0].ModelName, mockModels[0].PropertyTypeID)

	mock.ExpectQuery(expectedSQL).
		WithArgs(targetTypeID).
		WillReturnRows(rows)

	models, err := repo.ListPropertyModels(&targetTypeID)

	assert.NoError(t, err)
	assert.NotNil(t, models)
	assert.Len(t, models, 1)
	assert.Equal(t, targetTypeID, models[0].PropertyTypeID)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for ListPropertyModels_ByType")
}

// --- All Users Test ---

func TestGormRepository_GetAllUsers(t *testing.T) {
	_, mock, repo := setupMockDB(t)

	mockUsers := []domain.User{
		{ID: 1, Username: "user1", Name: "User One", Rank: "E1"},
		{ID: 2, Username: "user2", Name: "User Two", Rank: "E4"},
	}

	expectedSQL := regexp.QuoteMeta(`SELECT * FROM "users"`)

	rows := sqlmock.NewRows([]string{"id", "username", "name", "rank"}).
		AddRow(mockUsers[0].ID, mockUsers[0].Username, mockUsers[0].Name, mockUsers[0].Rank).
		AddRow(mockUsers[1].ID, mockUsers[1].Username, mockUsers[1].Name, mockUsers[1].Rank)

	mock.ExpectQuery(expectedSQL).
		WillReturnRows(rows)

	users, err := repo.GetAllUsers()

	assert.NoError(t, err)
	assert.NotNil(t, users)
	assert.Len(t, users, 2)
	assert.Equal(t, mockUsers[0].Username, users[0].Username)
	assert.Equal(t, mockUsers[1].Rank, users[1].Rank)

	err = mock.ExpectationsWereMet()
	assert.NoError(t, err, "SQL mock expectations were not met for GetAllUsers")
}

// TODO: Add tests for error scenarios (e.g., database connection errors - mock.ExpectQuery(...).WillReturnError(errors.New("DB error")))
