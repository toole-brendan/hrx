package parser

import (
	"bufio"
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/toole-brendan/handreceipt-go/internal/publog/models"
)

// Parser handles parsing of PUB LOG TAB files with support for various encodings and delimiters
type Parser struct {
	delimiter rune
	encoding  string
}

// NewParser creates a new parser instance
func NewParser() *Parser {
	return &Parser{
		delimiter: '\t', // TAB delimiter
		encoding:  "utf-8",
	}
}

// ParseNSNFile parses V_FLIS_NSN.TAB file
func (p *Parser) ParseNSNFile(filepath string) ([]models.NSNItem, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return nil, fmt.Errorf("failed to open NSN file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.Comma = p.delimiter
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	var items []models.NSNItem
	lineNum := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			// Skip malformed lines
			continue
		}

		lineNum++
		// Skip header if present
		if lineNum == 1 && strings.Contains(strings.ToLower(record[0]), "nsn") {
			continue
		}

		// Parse NSN record (adjust field indices based on actual file format)
		if len(record) >= 10 {
			item := models.NSNItem{
				NSN:             cleanField(record[0]),
				ItemName:        cleanField(record[1]),
				SupplyClass:     cleanField(record[2]),
				FSG:             cleanField(record[3]),
				NIIN:            cleanField(record[4]),
				ItemDescription: cleanField(record[5]),
				UnitOfIssue:     cleanField(record[6]),
				LastModified:    time.Now(), // Default, update if date field exists
			}

			// Parse unit price if present
			if len(record) > 7 {
				if price, err := strconv.ParseFloat(cleanField(record[7]), 64); err == nil {
					item.UnitPrice = price
				}
			}

			// Parse additional fields if present
			if len(record) > 8 {
				item.DemilCode = cleanField(record[8])
			}
			if len(record) > 9 {
				item.SecurityCode = cleanField(record[9])
			}

			items = append(items, item)
		}
	}

	return items, nil
}

// ParsePartNumberFile parses V_FLIS_PART.TAB file
func (p *Parser) ParsePartNumberFile(filepath string) ([]models.PartNumber, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return nil, fmt.Errorf("failed to open part number file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.Comma = p.delimiter
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	var parts []models.PartNumber
	lineNum := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		lineNum++
		if lineNum == 1 && strings.Contains(strings.ToLower(record[0]), "nsn") {
			continue
		}

		if len(record) >= 4 {
			part := models.PartNumber{
				NSN:           cleanField(record[0]),
				PartNumber:    cleanField(record[1]),
				CAGECode:      cleanField(record[2]),
				ReferenceType: cleanField(record[3]),
			}
			if len(record) > 4 {
				part.Description = cleanField(record[4])
			}
			parts = append(parts, part)
		}
	}

	return parts, nil
}

// ParseCAGEAddressFile parses V_CAGE_ADDRESS.TAB file
func (p *Parser) ParseCAGEAddressFile(filepath string) ([]models.CAGEAddress, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return nil, fmt.Errorf("failed to open CAGE address file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.Comma = p.delimiter
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	var addresses []models.CAGEAddress
	lineNum := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		lineNum++
		if lineNum == 1 && strings.Contains(strings.ToLower(record[0]), "cage") {
			continue
		}

		if len(record) >= 8 {
			addr := models.CAGEAddress{
				CAGECode:     cleanField(record[0]),
				CompanyName:  cleanField(record[1]),
				AddressLine1: cleanField(record[2]),
				AddressLine2: cleanField(record[3]),
				City:         cleanField(record[4]),
				State:        cleanField(record[5]),
				ZipCode:      cleanField(record[6]),
				Country:      cleanField(record[7]),
			}
			if len(record) > 8 {
				addr.Phone = cleanField(record[8])
			}
			addresses = append(addresses, addr)
		}
	}

	return addresses, nil
}

// ParseMOERuleFile parses V_MOE_RULE.TAB file
func (p *Parser) ParseMOERuleFile(filepath string) ([]models.MOERule, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return nil, fmt.Errorf("failed to open MOE rule file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.Comma = p.delimiter
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	var rules []models.MOERule
	lineNum := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		lineNum++
		if lineNum == 1 && strings.Contains(strings.ToLower(record[0]), "nsn") {
			continue
		}

		if len(record) >= 6 {
			rule := models.MOERule{
				NSN:                cleanField(record[0]),
				SupplyCode:         cleanField(record[1]),
				AcquisitionCode:    cleanField(record[2]),
				RecoverabilityCode: cleanField(record[3]),
				MaterialControl:    cleanField(record[4]),
				EssentialityCode:   cleanField(record[5]),
			}
			rules = append(rules, rule)
		}
	}

	return rules, nil
}

// ParseManagementFile parses V_FLIS_MANAGEMENT.TAB file
func (p *Parser) ParseManagementFile(filepath string) ([]models.ManagementData, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return nil, fmt.Errorf("failed to open management file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)
	reader.Comma = p.delimiter
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	var data []models.ManagementData
	lineNum := 0

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			continue
		}

		lineNum++
		if lineNum == 1 && strings.Contains(strings.ToLower(record[0]), "nsn") {
			continue
		}

		if len(record) >= 7 {
			mgmt := models.ManagementData{
				NSN:                   cleanField(record[0]),
				ManagementControlCode: cleanField(record[1]),
				AcquisitionAdviceCode: cleanField(record[2]),
				SourceOfSupply:        cleanField(record[3]),
				LastUpdated:           time.Now(),
			}

			// Parse numeric fields
			if lead, err := strconv.Atoi(cleanField(record[4])); err == nil {
				mgmt.LeadTime = lead
			}
			if reorder, err := strconv.Atoi(cleanField(record[5])); err == nil {
				mgmt.ReorderPoint = reorder
			}
			if qty, err := strconv.Atoi(cleanField(record[6])); err == nil {
				mgmt.ReorderQuantity = qty
			}

			data = append(data, mgmt)
		}
	}

	return data, nil
}

// ParseLine parses a single line with custom delimiter handling
func (p *Parser) ParseLine(line string) []string {
	// Handle quoted fields and escaped delimiters
	reader := csv.NewReader(strings.NewReader(line))
	reader.Comma = p.delimiter
	reader.LazyQuotes = true
	reader.TrimLeadingSpace = true

	record, err := reader.Read()
	if err != nil {
		// Fallback to simple split
		return strings.Split(line, string(p.delimiter))
	}
	return record
}

// cleanField removes extra whitespace and control characters
func cleanField(field string) string {
	// Trim spaces and tabs
	field = strings.TrimSpace(field)
	// Remove quotes if present
	field = strings.Trim(field, `"'`)
	// Replace multiple spaces with single space
	field = strings.Join(strings.Fields(field), " ")
	return field
}

// DetectDelimiter attempts to detect the delimiter used in a file
func DetectDelimiter(filepath string) (rune, error) {
	file, err := os.Open(filepath)
	if err != nil {
		return '\t', err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	if scanner.Scan() {
		line := scanner.Text()

		// Count occurrences of common delimiters
		tabCount := strings.Count(line, "\t")
		pipeCount := strings.Count(line, "|")
		commaCount := strings.Count(line, ",")

		// Return the most frequent delimiter
		if tabCount >= pipeCount && tabCount >= commaCount {
			return '\t', nil
		} else if pipeCount >= commaCount {
			return '|', nil
		} else {
			return ',', nil
		}
	}

	return '\t', nil // Default to tab
}
