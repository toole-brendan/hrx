package publog

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/sirupsen/logrus"
	"github.com/toole-brendan/handreceipt-go/internal/publog/models"
	"github.com/toole-brendan/handreceipt-go/internal/publog/parser"
	"github.com/toole-brendan/handreceipt-go/internal/publog/store"
)

// Service provides PUB LOG data access and search functionality
type Service struct {
	store  *store.Store
	parser *parser.Parser
	logger *logrus.Logger
}

// NewService creates a new PUB LOG service
func NewService() *Service {
	return &Service{
		store:  store.NewStore(),
		parser: parser.NewParser(),
		logger: logrus.New(),
	}
}

// NewServiceWithLogger creates a new PUB LOG service with a logger
func NewServiceWithLogger(logger *logrus.Logger) *Service {
	return &Service{
		store:  store.NewStore(),
		parser: parser.NewParser(),
		logger: logger,
	}
}

// LoadExtractedData loads pre-extracted pipe-delimited data files
func (s *Service) LoadExtractedData(dataDir string) error {
	loader := NewDataLoader(s, s.logger)
	return loader.LoadExtractedData(dataDir)
}

// LoadDataFromDirectory loads all PUB LOG TAB files from a directory
func (s *Service) LoadDataFromDirectory(dir string) error {
	// Check if this is an extracted data directory (contains master_nsn_all.txt)
	masterFile := filepath.Join(dir, "master_nsn_all.txt")
	if _, err := os.Stat(masterFile); err == nil {
		s.logger.Info("Detected extracted data format, using data loader")
		return s.LoadExtractedData(dir)
	}

	// Otherwise, use the original TAB file parser
	s.logger.Info("Loading TAB format files")

	// Load NSN data
	nsnFile := filepath.Join(dir, "V_FLIS_NSN.TAB")
	if items, err := s.parser.ParseNSNFile(nsnFile); err == nil {
		if err := s.store.LoadNSNItems(items); err != nil {
			return fmt.Errorf("failed to load NSN items: %w", err)
		}
	}

	// Load part numbers
	partFile := filepath.Join(dir, "V_FLIS_PART.TAB")
	if parts, err := s.parser.ParsePartNumberFile(partFile); err == nil {
		if err := s.store.LoadPartNumbers(parts); err != nil {
			return fmt.Errorf("failed to load part numbers: %w", err)
		}
	}

	// Load CAGE addresses
	cageAddrFile := filepath.Join(dir, "V_CAGE_ADDRESS.TAB")
	if addresses, err := s.parser.ParseCAGEAddressFile(cageAddrFile); err == nil {
		if err := s.store.LoadCAGEAddresses(addresses); err != nil {
			return fmt.Errorf("failed to load CAGE addresses: %w", err)
		}
	}

	// Load MOE rules
	moeFile := filepath.Join(dir, "V_MOE_RULE.TAB")
	if rules, err := s.parser.ParseMOERuleFile(moeFile); err == nil {
		if err := s.store.LoadMOERules(rules); err != nil {
			return fmt.Errorf("failed to load MOE rules: %w", err)
		}
	}

	// Load management data
	mgmtFile := filepath.Join(dir, "V_FLIS_MANAGEMENT.TAB")
	if data, err := s.parser.ParseManagementFile(mgmtFile); err == nil {
		if err := s.store.LoadManagementData(data); err != nil {
			return fmt.Errorf("failed to load management data: %w", err)
		}
	}

	return nil
}

// Search performs a universal search across NSN, part numbers, and item names
func (s *Service) Search(query string) ([]*models.SearchResult, error) {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, fmt.Errorf("empty search query")
	}

	// Check if it looks like an NSN (format: ####-##-###-####)
	if isNSNFormat(query) {
		if result, err := s.store.SearchByNSN(query); err == nil {
			return []*models.SearchResult{result}, nil
		}
	}

	// Check if it could be a part number (alphanumeric, possibly with dashes)
	if isPartNumberFormat(query) {
		if results, err := s.store.SearchByPartNumber(query); err == nil && len(results) > 0 {
			return results, nil
		}
	}

	// Fall back to name search
	return s.store.SearchByName(query)
}

// SearchNSN searches for an item by exact NSN
func (s *Service) SearchNSN(nsn string) (*models.SearchResult, error) {
	return s.store.SearchByNSN(nsn)
}

// SearchPartNumber searches for items by part number
func (s *Service) SearchPartNumber(partNumber string) ([]*models.SearchResult, error) {
	return s.store.SearchByPartNumber(partNumber)
}

// SearchByName searches for items by name keywords
func (s *Service) SearchByName(query string) ([]*models.SearchResult, error) {
	return s.store.SearchByName(query)
}

// SearchCAGE searches for CAGE information by code or company name
func (s *Service) SearchCAGE(query string) ([]*models.CAGEInfo, error) {
	query = strings.TrimSpace(query)

	// If it looks like a CAGE code (5 characters, alphanumeric)
	if len(query) == 5 && isAlphanumeric(query) {
		if info, err := s.store.SearchCAGEByCode(query); err == nil {
			return []*models.CAGEInfo{info}, nil
		}
	}

	// Otherwise search by company name
	return s.store.SearchCAGEByName(query)
}

// GetStats returns statistics about loaded data
func (s *Service) GetStats() map[string]int {
	return s.store.GetStats()
}

// Helper functions

func isNSNFormat(s string) bool {
	// NSN format: ####-##-###-####
	parts := strings.Split(s, "-")
	if len(parts) != 4 {
		return false
	}

	if len(parts[0]) != 4 || len(parts[1]) != 2 || len(parts[2]) != 3 || len(parts[3]) != 4 {
		return false
	}

	for _, part := range parts {
		for _, ch := range part {
			if ch < '0' || ch > '9' {
				return false
			}
		}
	}

	return true
}

func isPartNumberFormat(s string) bool {
	// Part numbers are typically alphanumeric, may contain dashes
	// At least 3 characters, not too long
	if len(s) < 3 || len(s) > 50 {
		return false
	}

	hasAlpha := false
	hasDigit := false

	for _, ch := range s {
		if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
			hasAlpha = true
		} else if ch >= '0' && ch <= '9' {
			hasDigit = true
		} else if ch != '-' && ch != ' ' && ch != '_' {
			return false
		}
	}

	// Most part numbers have both letters and numbers
	return hasAlpha || hasDigit
}

func isAlphanumeric(s string) bool {
	for _, ch := range s {
		if !((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9')) {
			return false
		}
	}
	return true
}
