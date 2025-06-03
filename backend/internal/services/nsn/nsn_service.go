package nsn

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/patrickmn/go-cache"
	"github.com/sirupsen/logrus"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/models"
	"github.com/toole-brendan/handreceipt-go/internal/publog"
	publogModels "github.com/toole-brendan/handreceipt-go/internal/publog/models"
	"gorm.io/gorm"
)

// NSNService provides NSN/LIN lookup functionality
type NSNService struct {
	config        *config.NSNConfig
	cache         *cache.Cache
	db            *gorm.DB
	logger        *logrus.Logger
	client        *http.Client
	rateLimiter   chan struct{}
	publogService *publog.Service // Add publog service
}

// NSNRecord represents a National Stock Number record
type NSNRecord struct {
	ID           uint      `json:"id" gorm:"primaryKey"`
	NSN          string    `json:"nsn" gorm:"uniqueIndex;not null"`
	LIN          string    `json:"lin" gorm:"index"`
	ItemName     string    `json:"itemName" gorm:"not null"`
	Description  string    `json:"description"`
	Category     string    `json:"category"`
	Manufacturer string    `json:"manufacturer"`
	PartNumber   string    `json:"partNumber"`
	ImageURL     string    `json:"imageUrl"`
	CreatedAt    time.Time `json:"createdAt"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

type NSNDetails struct {
	NSN          string            `json:"nsn"`
	LIN          string            `json:"lin"`
	Nomenclature string            `json:"nomenclature"`
	FSC          string            `json:"fsc"`
	NIIN         string            `json:"niin"`
	UnitPrice    float64           `json:"unit_price"`
	Manufacturer string            `json:"manufacturer"`
	PartNumber   string            `json:"part_number"`
	Specs        map[string]string `json:"specifications"`
	LastUpdated  time.Time         `json:"last_updated"`
}

type NSNAPIResponse struct {
	Success bool       `json:"success"`
	Data    NSNDetails `json:"data"`
	Error   string     `json:"error,omitempty"`
}

type BulkNSNAPIResponse struct {
	Success bool                  `json:"success"`
	Data    map[string]NSNDetails `json:"data"`
	Errors  map[string]string     `json:"errors,omitempty"`
}

type NSNRepository interface {
	GetByNSN(ctx context.Context, nsn string) (*models.NSNData, error)
	GetByLIN(ctx context.Context, lin string) (*models.NSNData, error)
	Save(ctx context.Context, nsnData *models.NSNData) error
	BulkSave(ctx context.Context, nsnDataList []*models.NSNData) error
	Search(ctx context.Context, query string, limit int) ([]*models.NSNData, error)
	GetAll(ctx context.Context, limit, offset int) ([]*models.NSNData, int64, error)
	DeleteOld(ctx context.Context, olderThan time.Time) error
}

type nsnRepository struct {
	db *gorm.DB
}

func NewNSNRepository(db *gorm.DB) NSNRepository {
	return &nsnRepository{db: db}
}

func (r *nsnRepository) GetByNSN(ctx context.Context, nsn string) (*models.NSNData, error) {
	var nsnData models.NSNData
	err := r.db.WithContext(ctx).Where("nsn = ?", nsn).First(&nsnData).Error
	if err != nil {
		return nil, err
	}
	return &nsnData, nil
}

func (r *nsnRepository) GetByLIN(ctx context.Context, lin string) (*models.NSNData, error) {
	var nsnData models.NSNData
	err := r.db.WithContext(ctx).Where("lin = ?", lin).First(&nsnData).Error
	if err != nil {
		return nil, err
	}
	return &nsnData, nil
}

func (r *nsnRepository) Save(ctx context.Context, nsnData *models.NSNData) error {
	return r.db.WithContext(ctx).Save(nsnData).Error
}

func (r *nsnRepository) BulkSave(ctx context.Context, nsnDataList []*models.NSNData) error {
	return r.db.WithContext(ctx).CreateInBatches(nsnDataList, 100).Error
}

func (r *nsnRepository) Search(ctx context.Context, query string, limit int) ([]*models.NSNData, error) {
	var results []*models.NSNData

	// Log the search parameters
	logrus.WithFields(logrus.Fields{
		"query": query,
		"limit": limit,
	}).Debug("Repository search started")

	err := r.db.WithContext(ctx).
		Where("nsn ILIKE ? OR lin ILIKE ? OR nomenclature ILIKE ? OR manufacturer ILIKE ?",
			"%"+query+"%", "%"+query+"%", "%"+query+"%", "%"+query+"%").
		Limit(limit).
		Find(&results).Error

	if err != nil {
		logrus.WithError(err).WithField("query", query).Error("Database query failed in repository")
		return nil, err
	}

	logrus.WithFields(logrus.Fields{
		"query":         query,
		"results_count": len(results),
	}).Debug("Repository search completed")

	return results, err
}

func (r *nsnRepository) GetAll(ctx context.Context, limit, offset int) ([]*models.NSNData, int64, error) {
	var results []*models.NSNData
	var total int64

	err := r.db.WithContext(ctx).Model(&models.NSNData{}).Count(&total).Error
	if err != nil {
		return nil, 0, err
	}

	err = r.db.WithContext(ctx).Limit(limit).Offset(offset).Find(&results).Error
	return results, total, err
}

func (r *nsnRepository) DeleteOld(ctx context.Context, olderThan time.Time) error {
	return r.db.WithContext(ctx).Where("last_updated < ?", olderThan).Delete(&models.NSNData{}).Error
}

// NewNSNService creates a new NSN service instance
func NewNSNService(config *config.NSNConfig, db *gorm.DB, logger *logrus.Logger) *NSNService {
	// Initialize cache
	var cacheInstance *cache.Cache
	if config.CacheEnabled {
		cacheInstance = cache.New(config.CacheTTL, config.CacheTTL*2)
	}

	// Initialize HTTP client with timeout
	client := &http.Client{
		Timeout: time.Duration(config.TimeoutSeconds) * time.Second,
	}

	// Initialize rate limiter
	rateLimiter := make(chan struct{}, config.RateLimitRPS)
	for i := 0; i < config.RateLimitRPS; i++ {
		rateLimiter <- struct{}{}
	}

	// Start rate limiter refill goroutine
	go func() {
		ticker := time.NewTicker(time.Second / time.Duration(config.RateLimitRPS))
		defer ticker.Stop()
		for range ticker.C {
			select {
			case rateLimiter <- struct{}{}:
			default:
			}
		}
	}()

	// Initialize publog service with logger
	publogService := publog.NewServiceWithLogger(logger)

	return &NSNService{
		config:        config,
		cache:         cacheInstance,
		db:            db,
		logger:        logger,
		client:        client,
		rateLimiter:   rateLimiter,
		publogService: publogService,
	}
}

// Initialize sets up the NSN service and ensures database tables exist
func (s *NSNService) Initialize() error {
	// Auto-migrate the NSN records table
	if err := s.db.AutoMigrate(&NSNRecord{}); err != nil {
		return fmt.Errorf("failed to migrate NSN records table: %w", err)
	}

	// Load publog data if directory is configured
	if publogDir := s.config.PubLogDataDir; publogDir != "" {
		// If the path is not absolute, make it relative to the current working directory
		if !filepath.IsAbs(publogDir) {
			// Try to find the directory relative to common locations
			possiblePaths := []string{
				publogDir,                           // As configured
				filepath.Join("backend", publogDir), // From repo root
				filepath.Join("..", publogDir),      // From backend directory
				filepath.Join(".", publogDir),       // Current directory
			}

			foundPath := ""
			for _, path := range possiblePaths {
				if _, err := os.Stat(path); err == nil {
					foundPath = path
					break
				}
			}

			if foundPath != "" {
				publogDir = foundPath
			}
		}

		s.logger.WithField("directory", publogDir).Info("Loading PUB LOG data")
		if err := s.publogService.LoadDataFromDirectory(publogDir); err != nil {
			s.logger.WithError(err).WithField("directory", publogDir).Warn("Failed to load PUB LOG data - NSN searches will use database only")
			// Don't fail initialization, continue without publog data
			// Set publogService to nil to indicate it's not available
			s.publogService = nil
		} else {
			stats := s.publogService.GetStats()
			s.logger.WithFields(logrus.Fields{
				"nsn_items":      stats["nsn_items"],
				"part_numbers":   stats["part_numbers"],
				"cage_addresses": stats["cage_addresses"],
			}).Info("PUB LOG data loaded successfully")
		}
	} else {
		s.logger.Info("No PUB LOG data directory configured")
		s.publogService = nil
	}

	s.logger.Info("NSN service initialized successfully")
	return nil
}

// LookupByNSN retrieves an item by its NSN
func (s *NSNService) LookupByNSN(ctx context.Context, nsn string) (*NSNRecord, error) {
	// Clean and format NSN
	cleanNSN := s.cleanNSN(nsn)

	var record NSNRecord
	err := s.db.WithContext(ctx).Where("nsn = ?", cleanNSN).First(&record).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			// Try to fetch from external API if configured
			if s.config.APIEndpoint != "" {
				return s.fetchFromExternalAPI(ctx, cleanNSN)
			}
			return nil, fmt.Errorf("NSN not found: %s", cleanNSN)
		}
		return nil, fmt.Errorf("database error: %w", err)
	}

	return &record, nil
}

// LookupByLIN retrieves an item by its LIN
func (s *NSNService) LookupByLIN(ctx context.Context, lin string) (*NSNRecord, error) {
	var record NSNRecord
	err := s.db.WithContext(ctx).Where("lin = ?", strings.ToUpper(lin)).First(&record).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, fmt.Errorf("LIN not found: %s", lin)
		}
		return nil, fmt.Errorf("database error: %w", err)
	}

	return &record, nil
}

// SearchItems searches for items by name or description
func (s *NSNService) SearchItems(ctx context.Context, query string, limit int) ([]NSNRecord, error) {
	if limit <= 0 || limit > 100 {
		limit = 20 // Default limit
	}

	var records []NSNRecord
	searchPattern := "%" + strings.ToLower(query) + "%"

	err := s.db.WithContext(ctx).
		Where("LOWER(item_name) LIKE ? OR LOWER(description) LIKE ?", searchPattern, searchPattern).
		Limit(limit).
		Find(&records).Error

	if err != nil {
		return nil, fmt.Errorf("search error: %w", err)
	}

	return records, nil
}

// ImportFromCSV imports NSN data from a CSV file
func (s *NSNService) ImportFromCSV(ctx context.Context, reader io.Reader) error {
	csvReader := csv.NewReader(reader)

	// Read header
	header, err := csvReader.Read()
	if err != nil {
		return fmt.Errorf("failed to read CSV header: %w", err)
	}

	// Map header columns
	columnMap := s.mapCSVColumns(header)

	var records []NSNRecord
	lineNumber := 1

	for {
		row, err := csvReader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			s.logger.WithError(err).WithField("line", lineNumber).Warn("Failed to read CSV row")
			continue
		}

		record := s.parseCSVRow(row, columnMap)
		if record != nil {
			records = append(records, *record)
		}

		lineNumber++

		// Batch insert every 1000 records
		if len(records) >= 1000 {
			if err := s.batchInsertRecords(ctx, records); err != nil {
				return fmt.Errorf("failed to insert batch at line %d: %w", lineNumber, err)
			}
			records = records[:0] // Clear slice
		}
	}

	// Insert remaining records
	if len(records) > 0 {
		if err := s.batchInsertRecords(ctx, records); err != nil {
			return fmt.Errorf("failed to insert final batch: %w", err)
		}
	}

	s.logger.WithField("lines_processed", lineNumber).Info("CSV import completed")
	return nil
}

// RefreshCachedNSNData refreshes NSN data from external sources
func (s *NSNService) RefreshCachedNSNData(ctx context.Context) error {
	if s.config.APIEndpoint == "" {
		s.logger.Info("No external API configured for NSN data refresh")
		return nil
	}

	s.logger.Info("Starting NSN data refresh from external API")

	// This is a placeholder for the actual implementation
	// In practice, you would:
	// 1. Fetch data from government APIs or data sources
	// 2. Parse the response
	// 3. Update the local database

	s.logger.Info("NSN data refresh completed")
	return nil
}

// GetStatistics returns statistics about the NSN database
func (s *NSNService) GetStatistics(ctx context.Context) (map[string]interface{}, error) {
	var totalRecords int64
	var categoryCounts []struct {
		Category string
		Count    int64
	}

	// Get total count
	if err := s.db.WithContext(ctx).Model(&NSNRecord{}).Count(&totalRecords).Error; err != nil {
		return nil, fmt.Errorf("failed to get total count: %w", err)
	}

	// Get category breakdown
	if err := s.db.WithContext(ctx).
		Model(&NSNRecord{}).
		Select("category, COUNT(*) as count").
		Group("category").
		Scan(&categoryCounts).Error; err != nil {
		return nil, fmt.Errorf("failed to get category counts: %w", err)
	}

	stats := map[string]interface{}{
		"total_records":   totalRecords,
		"category_counts": categoryCounts,
		"last_updated":    time.Now(),
	}

	return stats, nil
}

// Helper methods

func (s *NSNService) cleanNSN(nsn string) string {
	// Remove spaces, hyphens, and convert to uppercase
	cleaned := strings.ReplaceAll(nsn, " ", "")
	cleaned = strings.ReplaceAll(cleaned, "-", "")
	return strings.ToUpper(cleaned)
}

func (s *NSNService) fetchFromExternalAPI(ctx context.Context, nsn string) (*NSNRecord, error) {
	if s.config.APIEndpoint == "" {
		return nil, fmt.Errorf("no external API configured")
	}

	// This is a placeholder for external API integration
	// Implementation would depend on the specific API being used
	s.logger.WithField("nsn", nsn).Info("Fetching NSN from external API")

	return nil, fmt.Errorf("external API integration not implemented")
}

func (s *NSNService) mapCSVColumns(header []string) map[string]int {
	columnMap := make(map[string]int)

	for i, col := range header {
		switch strings.ToLower(strings.TrimSpace(col)) {
		case "nsn", "national_stock_number":
			columnMap["nsn"] = i
		case "lin", "line_item_number":
			columnMap["lin"] = i
		case "item_name", "name", "nomenclature":
			columnMap["item_name"] = i
		case "description", "desc":
			columnMap["description"] = i
		case "category", "type":
			columnMap["category"] = i
		case "manufacturer", "mfg":
			columnMap["manufacturer"] = i
		case "part_number", "part_no":
			columnMap["part_number"] = i
		}
	}

	return columnMap
}

func (s *NSNService) parseCSVRow(row []string, columnMap map[string]int) *NSNRecord {
	record := &NSNRecord{}

	if idx, ok := columnMap["nsn"]; ok && idx < len(row) {
		record.NSN = s.cleanNSN(row[idx])
	}
	if idx, ok := columnMap["lin"]; ok && idx < len(row) {
		record.LIN = strings.ToUpper(strings.TrimSpace(row[idx]))
	}
	if idx, ok := columnMap["item_name"]; ok && idx < len(row) {
		record.ItemName = strings.TrimSpace(row[idx])
	}
	if idx, ok := columnMap["description"]; ok && idx < len(row) {
		record.Description = strings.TrimSpace(row[idx])
	}
	if idx, ok := columnMap["category"]; ok && idx < len(row) {
		record.Category = strings.TrimSpace(row[idx])
	}
	if idx, ok := columnMap["manufacturer"]; ok && idx < len(row) {
		record.Manufacturer = strings.TrimSpace(row[idx])
	}
	if idx, ok := columnMap["part_number"]; ok && idx < len(row) {
		record.PartNumber = strings.TrimSpace(row[idx])
	}

	// Validate required fields
	if record.NSN == "" || record.ItemName == "" {
		return nil
	}

	return record
}

func (s *NSNService) batchInsertRecords(ctx context.Context, records []NSNRecord) error {
	return s.db.WithContext(ctx).CreateInBatches(records, s.config.BulkBatchSize).Error
}

// LookupNSN performs NSN lookup with caching and fallback to external API
func (s *NSNService) LookupNSN(ctx context.Context, nsn string) (*NSNDetails, error) {
	// Validate NSN format
	if len(nsn) != 13 {
		return nil, fmt.Errorf("invalid NSN format: must be 13 characters")
	}

	// Check cache first
	if s.cache != nil {
		if cached, found := s.cache.Get(nsn); found {
			s.logger.WithField("nsn", nsn).Debug("NSN found in cache")
			details := cached.(NSNDetails)
			return &details, nil
		}
	}

	// Check publog data first
	if s.publogService != nil {
		if publogResult, err := s.publogService.SearchNSN(nsn); err == nil {
			details := s.convertFromPublog(publogResult)

			// Update cache
			if s.config.CacheEnabled && s.cache != nil {
				s.cache.Set(nsn, details, cache.DefaultExpiration)
			}

			s.logger.WithField("nsn", nsn).Debug("NSN found in PUB LOG data")
			return details, nil
		}
	}

	// Check local database
	repo := NewNSNRepository(s.db)
	if dbData, err := repo.GetByNSN(ctx, nsn); err == nil {
		details := s.convertFromModel(dbData)

		// Update cache
		if s.config.CacheEnabled && s.cache != nil {
			s.cache.Set(nsn, details, cache.DefaultExpiration)
		}

		s.logger.WithField("nsn", nsn).Debug("NSN found in database")
		return details, nil
	}

	// Fetch from external API if configured
	if s.config.APIEndpoint != "" {
		details, err := s.fetchFromAPI(ctx, nsn)
		if err != nil {
			s.logger.WithError(err).WithField("nsn", nsn).Warn("Failed to fetch NSN from API")
			return nil, fmt.Errorf("failed to fetch NSN %s: %w", nsn, err)
		}

		// Store in database
		modelData := s.convertToModel(details)
		if err := repo.Save(ctx, modelData); err != nil {
			s.logger.WithError(err).WithField("nsn", nsn).Warn("Failed to save NSN to database")
		}

		// Update cache
		if s.config.CacheEnabled && s.cache != nil {
			s.cache.Set(nsn, details, cache.DefaultExpiration)
		}

		s.logger.WithField("nsn", nsn).Info("NSN fetched from external API")
		return details, nil
	}

	return nil, fmt.Errorf("NSN %s not found", nsn)
}

// LookupLIN performs LIN lookup
func (s *NSNService) LookupLIN(ctx context.Context, lin string) (*NSNDetails, error) {
	// Validate LIN format
	if len(lin) != 6 {
		return nil, fmt.Errorf("invalid LIN format: must be 6 characters")
	}

	// Check cache first
	cacheKey := "lin:" + lin
	if s.config.CacheEnabled && s.cache != nil {
		if cached, found := s.cache.Get(cacheKey); found {
			s.logger.WithField("lin", lin).Debug("LIN found in cache")
			details := cached.(NSNDetails)
			return &details, nil
		}
	}

	// Check local database
	repo := NewNSNRepository(s.db)
	if dbData, err := repo.GetByLIN(ctx, lin); err == nil {
		details := s.convertFromModel(dbData)

		// Update cache
		if s.config.CacheEnabled && s.cache != nil {
			s.cache.Set(cacheKey, details, cache.DefaultExpiration)
		}

		s.logger.WithField("lin", lin).Debug("LIN found in database")
		return details, nil
	}

	return nil, fmt.Errorf("LIN %s not found", lin)
}

// BulkLookup performs bulk NSN lookup
func (s *NSNService) BulkLookup(ctx context.Context, nsns []string) (map[string]*NSNDetails, error) {
	if len(nsns) > s.config.BulkBatchSize {
		return nil, fmt.Errorf("bulk lookup size exceeds limit of %d", s.config.BulkBatchSize)
	}

	results := make(map[string]*NSNDetails)
	notFound := make([]string, 0)
	mu := sync.Mutex{}

	// Check cache and database first
	for _, nsn := range nsns {
		// Check cache
		if s.cache != nil {
			if cached, found := s.cache.Get(nsn); found {
				mu.Lock()
				results[nsn] = cached.(*NSNDetails)
				mu.Unlock()
				continue
			}
		}

		// Check database
		repo := NewNSNRepository(s.db)
		if dbData, err := repo.GetByNSN(ctx, nsn); err == nil {
			details := s.convertFromModel(dbData)
			mu.Lock()
			results[nsn] = details
			mu.Unlock()

			// Update cache
			if s.config.CacheEnabled && s.cache != nil {
				s.cache.Set(nsn, details, cache.DefaultExpiration)
			}
		} else {
			notFound = append(notFound, nsn)
		}
	}

	// Fetch missing NSNs from API if configured
	if len(notFound) > 0 && s.config.APIEndpoint != "" {
		apiResults, err := s.bulkFetchFromAPI(ctx, notFound)
		if err != nil {
			s.logger.WithError(err).Warn("Bulk API fetch failed")
		} else {
			// Store results
			var modelsToSave []*models.NSNData
			for nsn, details := range apiResults {
				mu.Lock()
				results[nsn] = details
				mu.Unlock()

				// Prepare for bulk save
				modelsToSave = append(modelsToSave, s.convertToModel(details))

				// Update cache
				if s.config.CacheEnabled && s.cache != nil {
					s.cache.Set(nsn, details, cache.DefaultExpiration)
				}
			}

			// Bulk save to database
			if len(modelsToSave) > 0 {
				repo := NewNSNRepository(s.db)
				if err := repo.BulkSave(ctx, modelsToSave); err != nil {
					s.logger.WithError(err).Warn("Failed to bulk save NSN data")
				}
			}
		}
	}

	return results, nil
}

// SearchNSN searches for NSN data by query
func (s *NSNService) SearchNSN(ctx context.Context, query string, limit int) ([]*NSNDetails, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	s.logger.WithFields(logrus.Fields{
		"query": query,
		"limit": limit,
	}).Debug("Performing NSN search")

	repo := NewNSNRepository(s.db)
	dbResults, err := repo.Search(ctx, query, limit)
	if err != nil {
		s.logger.WithError(err).WithField("query", query).Error("Database search failed")
		return nil, fmt.Errorf("database search failed: %w", err)
	}

	s.logger.WithFields(logrus.Fields{
		"query":         query,
		"results_count": len(dbResults),
	}).Debug("Database search completed")

	results := make([]*NSNDetails, len(dbResults))
	for i, dbData := range dbResults {
		results[i] = s.convertFromModel(dbData)
	}

	return results, nil
}

// fetchFromAPI fetches NSN data from external API
func (s *NSNService) fetchFromAPI(ctx context.Context, nsn string) (*NSNDetails, error) {
	// Rate limiting
	select {
	case <-s.rateLimiter:
	case <-ctx.Done():
		return nil, ctx.Err()
	}

	url := fmt.Sprintf("%s/nsn/%s", s.config.APIEndpoint, nsn)
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, err
	}

	if s.config.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.config.APIKey)
	}

	var response NSNAPIResponse
	for attempt := 0; attempt < s.config.RetryAttempts; attempt++ {
		resp, err := s.client.Do(req)
		if err != nil {
			if attempt == s.config.RetryAttempts-1 {
				return nil, err
			}
			time.Sleep(time.Duration(attempt+1) * time.Second)
			continue
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			if attempt == s.config.RetryAttempts-1 {
				return nil, fmt.Errorf("API request failed with status %d", resp.StatusCode)
			}
			time.Sleep(time.Duration(attempt+1) * time.Second)
			continue
		}

		if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
			return nil, err
		}

		if !response.Success {
			return nil, fmt.Errorf("API error: %s", response.Error)
		}

		response.Data.LastUpdated = time.Now()
		return &response.Data, nil
	}

	return nil, fmt.Errorf("max retry attempts exceeded")
}

// bulkFetchFromAPI fetches multiple NSNs from external API
func (s *NSNService) bulkFetchFromAPI(ctx context.Context, nsns []string) (map[string]*NSNDetails, error) {
	// Rate limiting
	select {
	case <-s.rateLimiter:
	case <-ctx.Done():
		return nil, ctx.Err()
	}

	url := fmt.Sprintf("%s/nsn/bulk", s.config.APIEndpoint)
	payload := map[string][]string{"nsns": nsns}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, "POST", url, strings.NewReader(string(jsonData)))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	if s.config.APIKey != "" {
		req.Header.Set("Authorization", "Bearer "+s.config.APIKey)
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("bulk API request failed with status %d", resp.StatusCode)
	}

	var response BulkNSNAPIResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return nil, err
	}

	if !response.Success {
		return nil, fmt.Errorf("bulk API error")
	}

	// Update timestamps
	results := make(map[string]*NSNDetails)
	for nsn, details := range response.Data {
		details.LastUpdated = time.Now()
		results[nsn] = &details
	}

	return results, nil
}

// convertFromModel converts database model to service model
func (s *NSNService) convertFromModel(data *models.NSNData) *NSNDetails {
	specs := make(map[string]string)
	if data.Specifications != nil {
		for k, v := range data.Specifications {
			if str, ok := v.(string); ok {
				specs[k] = str
			}
		}
	}

	return &NSNDetails{
		NSN:          data.NSN,
		LIN:          data.LIN,
		Nomenclature: data.Nomenclature,
		FSC:          data.FSC,
		NIIN:         data.NIIN,
		UnitPrice:    data.UnitPrice,
		Manufacturer: data.Manufacturer,
		PartNumber:   data.PartNumber,
		Specs:        specs,
		LastUpdated:  data.LastUpdated,
	}
}

// convertToModel converts service model to database model
func (s *NSNService) convertToModel(details *NSNDetails) *models.NSNData {
	specs := make(map[string]interface{})
	for k, v := range details.Specs {
		specs[k] = v
	}

	return &models.NSNData{
		NSN:            details.NSN,
		LIN:            details.LIN,
		Nomenclature:   details.Nomenclature,
		FSC:            details.FSC,
		NIIN:           details.NIIN,
		UnitPrice:      details.UnitPrice,
		Manufacturer:   details.Manufacturer,
		PartNumber:     details.PartNumber,
		Specifications: specs,
		LastUpdated:    details.LastUpdated,
	}
}

// ClearCache clears the NSN cache
func (s *NSNService) ClearCache() {
	if s.config.CacheEnabled && s.cache != nil {
		s.cache.Flush()
		s.logger.Info("NSN cache cleared")
	}
}

// GetCacheStats returns cache statistics
func (s *NSNService) GetCacheStats() map[string]interface{} {
	if !s.config.CacheEnabled || s.cache == nil {
		return map[string]interface{}{"enabled": false}
	}

	return map[string]interface{}{
		"enabled":      true,
		"item_count":   s.cache.ItemCount(),
		"cache_hits":   "not_tracked", // go-cache doesn't track hits by default
		"cache_misses": "not_tracked",
	}
}

// GetDatabaseStatus returns database connectivity and NSN data statistics
func (s *NSNService) GetDatabaseStatus(ctx context.Context) (map[string]interface{}, error) {
	status := make(map[string]interface{})

	// Test basic database connectivity
	sqlDB, err := s.db.DB()
	if err != nil {
		return nil, fmt.Errorf("failed to get database instance: %w", err)
	}

	if err := sqlDB.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("database ping failed: %w", err)
	}

	status["database_connected"] = true

	// Count NSN records in database
	var nsnCount int64
	if err := s.db.WithContext(ctx).Model(&models.NSNData{}).Count(&nsnCount).Error; err != nil {
		s.logger.WithError(err).Warn("Failed to count NSN records")
		status["nsn_count_error"] = err.Error()
	} else {
		status["nsn_count"] = nsnCount
	}

	// Check publog service status
	if s.publogService != nil {
		publogStats := s.publogService.GetStats()
		status["publog_enabled"] = true
		status["publog_stats"] = publogStats
	} else {
		status["publog_enabled"] = false
	}

	// Check if NSN records table exists
	hasTable := s.db.Migrator().HasTable(&models.NSNData{})
	status["nsn_table_exists"] = hasTable

	return status, nil
}

// convertFromPublog converts publog search result to NSNDetails
func (s *NSNService) convertFromPublog(result *publogModels.SearchResult) *NSNDetails {
	if result == nil || result.NSNItem == nil {
		return nil
	}

	details := &NSNDetails{
		NSN:          result.NSNItem.NSN,
		Nomenclature: result.NSNItem.ItemName,
		FSC:          result.NSNItem.FSG,
		NIIN:         result.NSNItem.NIIN,
		UnitPrice:    result.NSNItem.UnitPrice,
		LastUpdated:  result.NSNItem.LastModified,
		Specs:        make(map[string]string),
	}

	// Add management data if available
	if result.ManagementData != nil {
		details.Specs["Lead Time"] = fmt.Sprintf("%d days", result.ManagementData.LeadTime)
		details.Specs["Reorder Point"] = fmt.Sprintf("%d", result.ManagementData.ReorderPoint)
		details.Specs["Source of Supply"] = result.ManagementData.SourceOfSupply
	}

	// Add MOE rule data if available
	if result.MOERule != nil {
		details.Specs["Supply Code"] = result.MOERule.SupplyCode
		details.Specs["Acquisition Code"] = result.MOERule.AcquisitionCode
		details.Specs["Essentiality Code"] = result.MOERule.EssentialityCode
	}

	// Get manufacturer from first part number if available
	if len(result.PartNumbers) > 0 {
		details.PartNumber = result.PartNumbers[0].PartNumber
		if result.CAGEInfo != nil && result.CAGEInfo.Address != nil {
			details.Manufacturer = result.CAGEInfo.Address.CompanyName
		}
	}

	// Add physical dimensions if available
	if result.Characteristics != nil && result.Characteristics.PhysicalDimensions.Weight > 0 {
		dims := result.Characteristics.PhysicalDimensions
		details.Specs["Weight"] = fmt.Sprintf("%.2f %s", dims.Weight, dims.WeightUnit)
		if dims.Length > 0 {
			details.Specs["Dimensions"] = fmt.Sprintf("%.2fx%.2fx%.2f %s",
				dims.Length, dims.Width, dims.Height, dims.LengthUnit)
		}
	}

	return details
}

// UniversalSearch performs a universal search across NSN, part numbers, and item names
// using publog data when available
func (s *NSNService) UniversalSearch(ctx context.Context, query string, limit int) ([]*NSNDetails, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	// Log the search query
	s.logger.WithField("query", query).WithField("limit", limit).Debug("Performing universal search")

	// Try publog universal search first if available
	if s.publogService != nil {
		s.logger.Debug("Attempting publog search")
		publogResults, err := s.publogService.Search(query)
		if err != nil {
			// Log the error but don't fail - fall back to database search
			s.logger.WithError(err).WithField("query", query).Warn("Publog search failed, falling back to database")
		} else if len(publogResults) > 0 {
			// Convert publog results to NSNDetails
			results := make([]*NSNDetails, 0, len(publogResults))
			for i, publogResult := range publogResults {
				if i >= limit {
					break
				}
				if details := s.convertFromPublog(publogResult); details != nil {
					results = append(results, details)
				}
			}
			if len(results) > 0 {
				s.logger.WithField("query", query).WithField("results", len(results)).Debug("Found results in publog data")
				return results, nil
			}
		}
	} else {
		s.logger.Debug("Publog service not available, using database search")
	}

	// Fall back to database search
	s.logger.WithField("query", query).Debug("Using database search")
	return s.SearchNSN(ctx, query, limit)
}
