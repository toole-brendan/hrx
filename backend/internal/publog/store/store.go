package store

import (
	"fmt"
	"strings"
	"sync"

	"github.com/toole-brendan/handreceipt-go/internal/publog/models"
)

// Store manages PUB LOG data in memory with indexing for fast searches
type Store struct {
	mu sync.RWMutex

	// Primary data stores
	nsnItems       map[string]*models.NSNItem
	partNumbers    map[string][]models.PartNumber // NSN -> Part Numbers
	cageAddresses  map[string]*models.CAGEAddress
	cageStatuses   map[string]*models.CAGEStatus
	moeRules       map[string]*models.MOERule
	managementData map[string]*models.ManagementData

	// Indexes for searching
	partToNSN     map[string][]string // Part Number -> NSNs
	nameIndex     map[string][]string // Lowercase word -> NSNs
	cageNameIndex map[string][]string // Lowercase company name word -> CAGE codes
}

// NewStore creates a new in-memory store
func NewStore() *Store {
	return &Store{
		nsnItems:       make(map[string]*models.NSNItem),
		partNumbers:    make(map[string][]models.PartNumber),
		cageAddresses:  make(map[string]*models.CAGEAddress),
		cageStatuses:   make(map[string]*models.CAGEStatus),
		moeRules:       make(map[string]*models.MOERule),
		managementData: make(map[string]*models.ManagementData),
		partToNSN:      make(map[string][]string),
		nameIndex:      make(map[string][]string),
		cageNameIndex:  make(map[string][]string),
	}
}

// LoadNSNItems loads NSN items into the store
func (s *Store) LoadNSNItems(items []models.NSNItem) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, item := range items {
		// Store the item
		s.nsnItems[item.NSN] = &item

		// Index by name words
		words := extractWords(item.ItemName + " " + item.ItemDescription)
		for _, word := range words {
			s.nameIndex[word] = append(s.nameIndex[word], item.NSN)
		}
	}

	return nil
}

// LoadPartNumbers loads part number cross-references
func (s *Store) LoadPartNumbers(parts []models.PartNumber) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, part := range parts {
		// Store by NSN
		s.partNumbers[part.NSN] = append(s.partNumbers[part.NSN], part)

		// Index part number to NSN
		s.partToNSN[part.PartNumber] = append(s.partToNSN[part.PartNumber], part.NSN)
	}

	return nil
}

// LoadCAGEAddresses loads CAGE addresses
func (s *Store) LoadCAGEAddresses(addresses []models.CAGEAddress) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, addr := range addresses {
		s.cageAddresses[addr.CAGECode] = &addr

		// Index by company name words
		words := extractWords(addr.CompanyName)
		for _, word := range words {
			s.cageNameIndex[word] = append(s.cageNameIndex[word], addr.CAGECode)
		}
	}

	return nil
}

// LoadCAGEStatuses loads CAGE statuses
func (s *Store) LoadCAGEStatuses(statuses []models.CAGEStatus) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, status := range statuses {
		s.cageStatuses[status.CAGECode] = &status
	}

	return nil
}

// LoadMOERules loads MOE rules
func (s *Store) LoadMOERules(rules []models.MOERule) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, rule := range rules {
		s.moeRules[rule.NSN] = &rule
	}

	return nil
}

// LoadManagementData loads management data
func (s *Store) LoadManagementData(data []models.ManagementData) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	for _, mgmt := range data {
		s.managementData[mgmt.NSN] = &mgmt
	}

	return nil
}

// SearchByNSN searches for an item by exact NSN
func (s *Store) SearchByNSN(nsn string) (*models.SearchResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	item, exists := s.nsnItems[nsn]
	if !exists {
		return nil, fmt.Errorf("NSN not found: %s", nsn)
	}

	return s.buildSearchResult(nsn, item), nil
}

// SearchByPartNumber searches for items by part number
func (s *Store) SearchByPartNumber(partNumber string) ([]*models.SearchResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	nsns, exists := s.partToNSN[partNumber]
	if !exists || len(nsns) == 0 {
		return nil, fmt.Errorf("no items found for part number: %s", partNumber)
	}

	var results []*models.SearchResult
	for _, nsn := range nsns {
		if item, exists := s.nsnItems[nsn]; exists {
			results = append(results, s.buildSearchResult(nsn, item))
		}
	}

	return results, nil
}

// SearchByName searches for items by name keywords
func (s *Store) SearchByName(query string) ([]*models.SearchResult, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	words := extractWords(query)
	if len(words) == 0 {
		return nil, fmt.Errorf("invalid search query")
	}

	// Find NSNs that match all search words
	nsnCounts := make(map[string]int)
	for _, word := range words {
		for _, nsn := range s.nameIndex[word] {
			nsnCounts[nsn]++
		}
	}

	// Collect NSNs that match all words
	var results []*models.SearchResult
	for nsn, count := range nsnCounts {
		if count == len(words) {
			if item, exists := s.nsnItems[nsn]; exists {
				results = append(results, s.buildSearchResult(nsn, item))
			}
		}
	}

	return results, nil
}

// SearchCAGEByCode searches for a CAGE by exact code
func (s *Store) SearchCAGEByCode(cageCode string) (*models.CAGEInfo, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	addr, addrExists := s.cageAddresses[cageCode]
	status, statusExists := s.cageStatuses[cageCode]

	if !addrExists && !statusExists {
		return nil, fmt.Errorf("CAGE code not found: %s", cageCode)
	}

	return &models.CAGEInfo{
		Address: addr,
		Status:  status,
	}, nil
}

// SearchCAGEByName searches for CAGE codes by company name
func (s *Store) SearchCAGEByName(query string) ([]*models.CAGEInfo, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	words := extractWords(query)
	if len(words) == 0 {
		return nil, fmt.Errorf("invalid search query")
	}

	// Find CAGE codes that match search words
	cageCounts := make(map[string]int)
	for _, word := range words {
		for _, cage := range s.cageNameIndex[word] {
			cageCounts[cage]++
		}
	}

	// Collect matching CAGE codes
	var results []*models.CAGEInfo
	for cage, count := range cageCounts {
		// Require at least one word match
		if count > 0 {
			info := &models.CAGEInfo{}
			if addr, exists := s.cageAddresses[cage]; exists {
				info.Address = addr
			}
			if status, exists := s.cageStatuses[cage]; exists {
				info.Status = status
			}
			results = append(results, info)
		}
	}

	return results, nil
}

// GetStats returns statistics about the loaded data
func (s *Store) GetStats() map[string]int {
	s.mu.RLock()
	defer s.mu.RUnlock()

	return map[string]int{
		"nsn_items":       len(s.nsnItems),
		"part_numbers":    len(s.partToNSN),
		"cage_addresses":  len(s.cageAddresses),
		"cage_statuses":   len(s.cageStatuses),
		"moe_rules":       len(s.moeRules),
		"management_data": len(s.managementData),
	}
}

// buildSearchResult builds a complete search result for an NSN
func (s *Store) buildSearchResult(nsn string, item *models.NSNItem) *models.SearchResult {
	result := &models.SearchResult{
		NSNItem: item,
	}

	// Add part numbers
	if parts, exists := s.partNumbers[nsn]; exists {
		result.PartNumbers = parts
	}

	// Add MOE rule
	if rule, exists := s.moeRules[nsn]; exists {
		result.MOERule = rule
	}

	// Add management data
	if mgmt, exists := s.managementData[nsn]; exists {
		result.ManagementData = mgmt
	}

	// Add CAGE info for part numbers
	cageInfoMap := make(map[string]*models.CAGEInfo)
	for _, part := range result.PartNumbers {
		if _, processed := cageInfoMap[part.CAGECode]; !processed {
			info := &models.CAGEInfo{}
			if addr, exists := s.cageAddresses[part.CAGECode]; exists {
				info.Address = addr
			}
			if status, exists := s.cageStatuses[part.CAGECode]; exists {
				info.Status = status
			}
			cageInfoMap[part.CAGECode] = info
		}
	}

	// Return the first CAGE info (can be extended to return all)
	for _, info := range cageInfoMap {
		result.CAGEInfo = info
		break
	}

	return result
}

// extractWords extracts lowercase words from text for indexing
func extractWords(text string) []string {
	text = strings.ToLower(text)
	// Remove special characters
	replacer := strings.NewReplacer(
		",", " ",
		".", " ",
		";", " ",
		":", " ",
		"-", " ",
		"(", " ",
		")", " ",
		"[", " ",
		"]", " ",
		"/", " ",
		"\\", " ",
	)
	text = replacer.Replace(text)

	// Split into words
	fields := strings.Fields(text)

	// Filter out very short words
	var words []string
	for _, word := range fields {
		if len(word) > 2 {
			words = append(words, word)
		}
	}

	return words
}
