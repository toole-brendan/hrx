package publog

import (
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/toole-brendan/handreceipt-go/internal/publog/models"
)

// DataLoader handles loading extracted PUB LOG data files
type DataLoader struct {
	service *Service
	logger  *logrus.Logger
}

// NewDataLoader creates a new data loader
func NewDataLoader(service *Service, logger *logrus.Logger) *DataLoader {
	return &DataLoader{
		service: service,
		logger:  logger,
	}
}

// LoadExtractedData loads all extracted data files from a directory
func (dl *DataLoader) LoadExtractedData(dataDir string) error {
	dl.logger.WithField("directory", dataDir).Info("Loading extracted PUB LOG data")

	// Load NSN data
	if err := dl.loadNSNData(filepath.Join(dataDir, "master_nsn_all.txt")); err != nil {
		return fmt.Errorf("failed to load NSN data: %w", err)
	}

	// Load part numbers
	if err := dl.loadPartNumbers(filepath.Join(dataDir, "part_numbers_sample.txt")); err != nil {
		dl.logger.WithError(err).Warn("Failed to load part numbers")
		// Continue even if part numbers fail
	}

	// Load CAGE addresses
	if err := dl.loadCAGEAddresses(filepath.Join(dataDir, "cage_addresses_sample.txt")); err != nil {
		dl.logger.WithError(err).Warn("Failed to load CAGE addresses")
		// Continue even if CAGE addresses fail
	}

	stats := dl.service.GetStats()
	dl.logger.WithFields(logrus.Fields{
		"nsn_items":      stats["nsn_items"],
		"part_numbers":   stats["part_numbers"],
		"cage_addresses": stats["cage_addresses"],
	}).Info("Data loading complete")

	return nil
}

// loadNSNData loads the master NSN file
func (dl *DataLoader) loadNSNData(filepath string) error {
	file, err := os.Open(filepath)
	if err != nil {
		return fmt.Errorf("failed to open NSN file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.Comma = '|' // Pipe delimiter
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	// Read header
	header, err := reader.Read()
	if err != nil {
		return fmt.Errorf("failed to read header: %w", err)
	}

	// Map column indices
	colMap := make(map[string]int)
	for i, col := range header {
		colMap[strings.ToUpper(strings.TrimSpace(col))] = i
	}

	// Validate required columns
	requiredCols := []string{"INC", "ITEM_NAME", "FSC", "NIIN"}
	for _, col := range requiredCols {
		if _, exists := colMap[col]; !exists {
			return fmt.Errorf("missing required column: %s", col)
		}
	}

	var items []models.NSNItem
	lineNum := 1
	batchSize := 10000

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			dl.logger.WithError(err).WithField("line", lineNum).Debug("Skipping malformed line")
			lineNum++
			continue
		}

		item := dl.parseNSNRecord(record, colMap)
		if item != nil {
			items = append(items, *item)
		}

		lineNum++

		// Load in batches
		if len(items) >= batchSize {
			if err := dl.service.store.LoadNSNItems(items); err != nil {
				return fmt.Errorf("failed to load NSN batch at line %d: %w", lineNum, err)
			}
			dl.logger.WithField("count", len(items)).Debug("Loaded NSN batch")
			items = items[:0] // Clear slice
		}
	}

	// Load remaining items
	if len(items) > 0 {
		if err := dl.service.store.LoadNSNItems(items); err != nil {
			return fmt.Errorf("failed to load final NSN batch: %w", err)
		}
	}

	dl.logger.WithField("lines_processed", lineNum).Info("NSN data loaded")
	return nil
}

// parseNSNRecord parses a single NSN record
func (dl *DataLoader) parseNSNRecord(record []string, colMap map[string]int) *models.NSNItem {
	getValue := func(col string) string {
		if idx, exists := colMap[col]; exists && idx < len(record) {
			return strings.TrimSpace(record[idx])
		}
		return ""
	}

	// Skip records without essential data
	itemName := getValue("ITEM_NAME")
	fsc := getValue("FSC")
	niin := getValue("NIIN")

	if itemName == "" || fsc == "" || niin == "" {
		return nil
	}

	// Create full NSN
	nsn := dl.formatNSN(fsc, niin)

	item := &models.NSNItem{
		NSN:             nsn,
		ItemName:        itemName,
		FSG:             fsc[:2], // First 2 digits of FSC
		SupplyClass:     fsc,
		NIIN:            niin,
		ItemDescription: getValue("END_ITEM_NAME"),
		UnitOfIssue:     getValue("UI"),
		LastModified:    time.Now(),
	}

	// Parse unit price if available
	if priceStr := getValue("UNIT_PRICE"); priceStr != "" {
		if price, err := strconv.ParseFloat(priceStr, 64); err == nil {
			item.UnitPrice = price
		}
	}

	// Set additional fields
	item.DemilCode = getValue("DEMIL")
	item.SecurityCode = getValue("SECURITY_CODE")

	return item
}

// formatNSN creates a properly formatted NSN from FSC and NIIN
func (dl *DataLoader) formatNSN(fsc, niin string) string {
	// Ensure FSC is 4 digits
	fsc = strings.TrimSpace(fsc)
	if len(fsc) < 4 {
		fsc = fmt.Sprintf("%04s", fsc)
	}

	// Ensure NIIN is 9 digits
	niin = strings.TrimSpace(niin)
	if len(niin) < 9 {
		niin = fmt.Sprintf("%09s", niin)
	}

	// Format: XXXX-XX-XXX-XXXX
	if len(niin) >= 9 {
		return fmt.Sprintf("%s-%s-%s-%s",
			fsc,
			niin[0:2],
			niin[2:5],
			niin[5:9])
	}

	// Fallback format if NIIN is malformed
	return fmt.Sprintf("%s-%s", fsc, niin)
}

// loadPartNumbers loads part number cross-references
func (dl *DataLoader) loadPartNumbers(filepath string) error {
	file, err := os.Open(filepath)
	if err != nil {
		return fmt.Errorf("failed to open part numbers file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.Comma = '|'
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	// Read header
	header, err := reader.Read()
	if err != nil {
		return fmt.Errorf("failed to read header: %w", err)
	}

	// Map column indices
	colMap := make(map[string]int)
	for i, col := range header {
		colMap[strings.ToUpper(strings.TrimSpace(col))] = i
	}

	var parts []models.PartNumber
	lineNum := 1

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			lineNum++
			continue
		}

		part := dl.parsePartNumber(record, colMap)
		if part != nil {
			parts = append(parts, *part)
		}

		lineNum++
	}

	if len(parts) > 0 {
		if err := dl.service.store.LoadPartNumbers(parts); err != nil {
			return fmt.Errorf("failed to load part numbers: %w", err)
		}
	}

	dl.logger.WithField("count", len(parts)).Info("Part numbers loaded")
	return nil
}

// parsePartNumber parses a single part number record
func (dl *DataLoader) parsePartNumber(record []string, colMap map[string]int) *models.PartNumber {
	getValue := func(col string) string {
		if idx, exists := colMap[col]; exists && idx < len(record) {
			return strings.TrimSpace(record[idx])
		}
		return ""
	}

	niin := getValue("NIIN")
	partNumber := getValue("PART_NUMBER")
	cageCode := getValue("CAGE_CODE")

	if niin == "" || partNumber == "" {
		return nil
	}

	// Get FSC to create full NSN (this would need to be looked up from loaded NSN data)
	// For now, we'll store NIIN and convert later
	return &models.PartNumber{
		NSN:           niin, // Will be converted to full NSN later
		PartNumber:    partNumber,
		CAGECode:      cageCode,
		ReferenceType: getValue("RNCC"),
		Description:   getValue("DESCRIPTION"),
	}
}

// loadCAGEAddresses loads CAGE address data
func (dl *DataLoader) loadCAGEAddresses(filepath string) error {
	file, err := os.Open(filepath)
	if err != nil {
		return fmt.Errorf("failed to open CAGE addresses file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.Comma = '|'
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	// Read header
	header, err := reader.Read()
	if err != nil {
		return fmt.Errorf("failed to read header: %w", err)
	}

	// Map column indices
	colMap := make(map[string]int)
	for i, col := range header {
		colMap[strings.ToUpper(strings.TrimSpace(col))] = i
	}

	var addresses []models.CAGEAddress
	lineNum := 1

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			lineNum++
			continue
		}

		addr := dl.parseCAGEAddress(record, colMap)
		if addr != nil {
			addresses = append(addresses, *addr)
		}

		lineNum++
	}

	if len(addresses) > 0 {
		if err := dl.service.store.LoadCAGEAddresses(addresses); err != nil {
			return fmt.Errorf("failed to load CAGE addresses: %w", err)
		}
	}

	dl.logger.WithField("count", len(addresses)).Info("CAGE addresses loaded")
	return nil
}

// parseCAGEAddress parses a single CAGE address record
func (dl *DataLoader) parseCAGEAddress(record []string, colMap map[string]int) *models.CAGEAddress {
	getValue := func(col string) string {
		if idx, exists := colMap[col]; exists && idx < len(record) {
			return strings.TrimSpace(record[idx])
		}
		return ""
	}

	cageCode := getValue("CAGE_CODE")
	companyName := getValue("COMPANY_NAME")

	if cageCode == "" {
		return nil
	}

	return &models.CAGEAddress{
		CAGECode:     cageCode,
		CompanyName:  companyName,
		AddressLine1: getValue("STREET_ADDRESS_1"),
		AddressLine2: getValue("STREET_ADDRESS_2"),
		City:         getValue("CITY"),
		State:        getValue("STATE"),
		ZipCode:      getValue("ZIP"),
		Country:      getValue("COUNTRY"),
		Phone:        getValue("PHONE"),
	}
}
