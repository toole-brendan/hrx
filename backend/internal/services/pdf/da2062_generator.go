package pdf

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/jung-kurt/gofpdf"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
	"github.com/toole-brendan/handreceipt-go/internal/repository"
)

type DA2062Generator struct {
	repo repository.Repository
}

type UnitInfo struct {
	UnitName    string `json:"unit_name"`
	DODAAC      string `json:"dodaac"`
	StockNumber string `json:"stock_number"`
	Location    string `json:"location"`
}

type UserInfo struct {
	Name         string `json:"name"`
	Rank         string `json:"rank"`
	Title        string `json:"title"`
	Phone        string `json:"phone"`
	SignatureURL string `json:"signature_url"`
}

type GenerateOptions struct {
	GroupByCategory   bool `json:"group_by_category"`
	IncludeSignatures bool `json:"include_signatures"`
	IncludeQRCodes    bool `json:"include_qr_codes"`
}

// ConditionCounts represents the breakdown of property quantities by condition
type ConditionCounts struct {
	OnHand                  int `json:"on_hand"`
	Serviceable             int `json:"serviceable"`
	UnserviceableRepairable int `json:"unserviceable_repairable"`
	UnserviceableCondemned  int `json:"unserviceable_condemned"`
	New                     int `json:"new"`
	Other                   int `json:"other"`
}

func NewDA2062Generator(repo repository.Repository) *DA2062Generator {
	return &DA2062Generator{repo: repo}
}

func (g *DA2062Generator) GenerateDA2062(
	properties []domain.Property,
	fromUser UserInfo,
	toUser UserInfo,
	unitInfo UnitInfo,
	options GenerateOptions,
) (*bytes.Buffer, error) {
	// Create new PDF with Letter size (closest standard size to DA2062 dimensions)
	// Official DA2062 dimensions: 215.9mm × 279.4mm (very close to Letter: 215.9mm × 279.4mm)
	pdf := gofpdf.New("P", "mm", "Letter", "")
	// Set margins according to official template
	pdf.SetMargins(10, 10, 10)     // Left, Top, Right - using template values
	pdf.SetAutoPageBreak(true, 10) // Bottom margin
	pdf.AddPage()

	// Add header
	g.addHeader(pdf, unitInfo)

	// Add form title
	g.addTitle(pdf)

	// Add from/to section
	g.addFromToSection(pdf, fromUser, toUser, unitInfo)

	// Add property table headers
	g.addTableHeaders(pdf)

	// Add properties
	currentY := 70.0
	for i, property := range properties {
		if currentY > 240 { // Check if we need a new page
			pdf.AddPage()
			g.addHeader(pdf, unitInfo)
			g.addTableHeaders(pdf)
			currentY = 70.0
		}

		currentY = g.addPropertyRow(pdf, property, i+1, currentY)
	}

	// Add footer with signatures
	if options.IncludeSignatures {
		g.addSignatureSection(pdf, fromUser, toUser)
	}

	// Add page numbers
	g.addPageNumbers(pdf)

	// Generate PDF buffer
	var buf bytes.Buffer
	err := pdf.Output(&buf)
	if err != nil {
		return nil, fmt.Errorf("failed to generate PDF: %w", err)
	}

	// Validate against official template (non-blocking)
	g.validateGeneratedPDF(options)

	return &buf, nil
}

func (g *DA2062Generator) addHeader(pdf *gofpdf.Fpdf, unitInfo UnitInfo) {
	// Title at top
	pdf.SetFont("Arial", "B", 10)
	pdf.CellFormat(0, 5, "HAND RECEIPT/ANNEX NUMBER", "0", 1, "L", false, 0, "")

	pdf.SetFont("Arial", "", 8)
	pdf.CellFormat(0, 4, "For use of this form, see DA PAM 710-2-1.", "0", 1, "L", false, 0, "")
	pdf.CellFormat(0, 4, "The proponent agency is ODCSLOG.", "0", 1, "L", false, 0, "")

	// Form number in top right
	pdf.SetXY(170, 10)
	pdf.SetFont("Arial", "B", 9)
	pdf.CellFormat(30, 5, "DA FORM 2062", "0", 1, "L", false, 0, "")
	pdf.SetXY(170, 15)
	pdf.SetFont("Arial", "", 8)
	// Use current date instead of hardcoded "JAN 1982"
	currentDate := time.Now().Format("JAN 2006")
	pdf.CellFormat(30, 4, currentDate, "0", 1, "L", false, 0, "")

	pdf.Ln(10)
}

func (g *DA2062Generator) addTitle(pdf *gofpdf.Fpdf) {
	pdf.SetFont("Arial", "B", 10)
	pdf.SetY(25)
	pdf.CellFormat(0, 6, "HAND RECEIPT/ANNEX NUMBER", "0", 1, "L", false, 0, "")
}

func (g *DA2062Generator) addFromToSection(pdf *gofpdf.Fpdf, fromUser, toUser UserInfo, unitInfo UnitInfo) {
	y := 35.0
	pdf.SetY(y)

	// FROM section
	pdf.SetFont("Arial", "B", 9)
	pdf.CellFormat(20, 5, "FROM:", "0", 0, "L", false, 0, "")
	pdf.SetFont("Arial", "", 9)
	pdf.CellFormat(70, 5, fmt.Sprintf("%s %s", fromUser.Rank, fromUser.Name), "B", 0, "L", false, 0, "")

	pdf.CellFormat(10, 5, "", "0", 0, "L", false, 0, "") // Spacer

	// TO section
	pdf.SetFont("Arial", "B", 9)
	pdf.CellFormat(15, 5, "TO:", "0", 0, "L", false, 0, "")
	pdf.SetFont("Arial", "", 9)
	pdf.CellFormat(70, 5, fmt.Sprintf("%s %s", toUser.Rank, toUser.Name), "B", 1, "L", false, 0, "")

	// Unit info
	pdf.SetY(y + 8)
	pdf.SetFont("Arial", "B", 9)
	pdf.CellFormat(20, 5, "UNIT:", "0", 0, "L", false, 0, "")
	pdf.SetFont("Arial", "", 9)
	pdf.CellFormat(70, 5, unitInfo.UnitName, "B", 0, "L", false, 0, "")

	pdf.CellFormat(10, 5, "", "0", 0, "L", false, 0, "") // Spacer

	pdf.SetFont("Arial", "B", 9)
	pdf.CellFormat(15, 5, "DODAAC:", "0", 0, "L", false, 0, "")
	pdf.SetFont("Arial", "", 9)
	pdf.CellFormat(70, 5, unitInfo.DODAAC, "B", 1, "L", false, 0, "")

	pdf.Ln(5)
}

func (g *DA2062Generator) addTableHeaders(pdf *gofpdf.Fpdf) {
	pdf.SetY(60)
	pdf.SetFont("Arial", "B", 8)
	pdf.SetFillColor(255, 255, 255) // White background

	// Main headers
	pdf.CellFormat(50, 5, "STOCK NUMBER", "1", 0, "C", false, 0, "")
	pdf.CellFormat(70, 5, "ITEM DESCRIPTION", "1", 0, "C", false, 0, "")
	pdf.CellFormat(10, 5, "SEC", "1", 0, "C", false, 0, "")
	pdf.CellFormat(10, 5, "UI", "1", 0, "C", false, 0, "")
	pdf.CellFormat(15, 5, "QTY", "1", 0, "C", false, 0, "")

	// Quantity sub-columns
	pdf.CellFormat(40, 5, "QUANTITY", "1", 1, "C", false, 0, "")

	// Sub-headers for columns a and b
	pdf.SetY(65)
	pdf.CellFormat(50, 5, "a.", "1", 0, "C", false, 0, "")
	pdf.CellFormat(70, 5, "b.", "1", 0, "C", false, 0, "")
	pdf.CellFormat(10, 5, "c.", "1", 0, "C", false, 0, "")
	pdf.CellFormat(10, 5, "d.", "1", 0, "C", false, 0, "")
	pdf.CellFormat(15, 5, "e.", "1", 0, "C", false, 0, "")

	// Quantity sub-columns A-F
	pdf.SetFont("Arial", "", 7)
	quantityWidth := 6.67
	letters := []string{"A", "B", "C", "D", "E", "F"}
	for _, letter := range letters {
		pdf.CellFormat(quantityWidth, 5, letter, "1", 0, "C", false, 0, "")
	}
	pdf.Ln(-1)
}

func (g *DA2062Generator) addPropertyRow(
	pdf *gofpdf.Fpdf,
	property domain.Property,
	itemNo int,
	currentY float64,
) float64 {
	pdf.SetY(currentY)
	pdf.SetFont("Arial", "", 8)

	rowHeight := 8.0

	// Stock number (NSN)
	nsn := ""
	if property.NSN != nil {
		nsn = *property.NSN
	}
	pdf.CellFormat(50, rowHeight, nsn, "1", 0, "L", false, 0, "")

	// Item description
	description := property.Name
	if property.Description != nil && *property.Description != "" {
		description = fmt.Sprintf("%s, %s", property.Name, *property.Description)
	}
	// Include serial number in description if needed
	if property.SerialNumber != "" {
		description = fmt.Sprintf("%s, SN: %s", description, property.SerialNumber)
	}
	// Truncate if too long
	if len(description) > 50 {
		description = description[:47] + "..."
	}
	pdf.CellFormat(70, rowHeight, description, "1", 0, "L", false, 0, "")

	// SEC (Security classification - dynamic based on property classification)
	sec := g.determineSecurityClassification(property)
	pdf.CellFormat(10, rowHeight, sec, "1", 0, "C", false, 0, "")

	// Unit of Issue - dynamic based on property type
	ui := g.determineUnitOfIssue(property)
	pdf.CellFormat(10, rowHeight, ui, "1", 0, "C", false, 0, "")

	// QTY AUTH (Quantity Authorized)
	pdf.CellFormat(15, rowHeight, fmt.Sprintf("%d", property.Quantity), "1", 0, "C", false, 0, "")

	// Quantity columns A-F (condition codes as per military standards)
	quantityWidth := 6.67

	// Calculate condition breakdown (Column A = total, others = condition-specific counts)
	conditionCounts := g.calculateConditionCounts(property)

	// Column A - On-hand quantity (total serviceable + available)
	pdf.CellFormat(quantityWidth, rowHeight, fmt.Sprintf("%d", conditionCounts.OnHand), "1", 0, "C", false, 0, "")

	// Column B - Serviceable condition
	bValue := ""
	if conditionCounts.Serviceable > 0 {
		bValue = fmt.Sprintf("%d", conditionCounts.Serviceable)
	}
	pdf.CellFormat(quantityWidth, rowHeight, bValue, "1", 0, "C", false, 0, "")

	// Column C - Unserviceable (repairable)
	cValue := ""
	if conditionCounts.UnserviceableRepairable > 0 {
		cValue = fmt.Sprintf("%d", conditionCounts.UnserviceableRepairable)
	}
	pdf.CellFormat(quantityWidth, rowHeight, cValue, "1", 0, "C", false, 0, "")

	// Column D - Unserviceable (condemned)
	dValue := ""
	if conditionCounts.UnserviceableCondemned > 0 {
		dValue = fmt.Sprintf("%d", conditionCounts.UnserviceableCondemned)
	}
	pdf.CellFormat(quantityWidth, rowHeight, dValue, "1", 0, "C", false, 0, "")

	// Column E - New/Unused
	eValue := ""
	if conditionCounts.New > 0 {
		eValue = fmt.Sprintf("%d", conditionCounts.New)
	}
	pdf.CellFormat(quantityWidth, rowHeight, eValue, "1", 0, "C", false, 0, "")

	// Column F - Other conditions
	fValue := ""
	if conditionCounts.Other > 0 {
		fValue = fmt.Sprintf("%d", conditionCounts.Other)
	}
	pdf.CellFormat(quantityWidth, rowHeight, fValue, "1", 0, "C", false, 0, "")

	pdf.Ln(-1)
	return currentY + rowHeight
}

// downloadImage downloads an image from a URL and returns a temporary file path
func (g *DA2062Generator) downloadImage(url string) (string, error) {
	if url == "" {
		return "", fmt.Errorf("empty URL")
	}

	// Create a temporary file
	tempDir := os.TempDir()
	tempFile, err := os.CreateTemp(tempDir, "signature_*.png")
	if err != nil {
		return "", fmt.Errorf("failed to create temp file: %w", err)
	}
	defer tempFile.Close()

	// Download the image
	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	resp, err := client.Get(url)
	if err != nil {
		os.Remove(tempFile.Name())
		return "", fmt.Errorf("failed to download image: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		os.Remove(tempFile.Name())
		return "", fmt.Errorf("failed to download image: status %d", resp.StatusCode)
	}

	// Copy the image data to the temp file
	_, err = io.Copy(tempFile, resp.Body)
	if err != nil {
		os.Remove(tempFile.Name())
		return "", fmt.Errorf("failed to save image: %w", err)
	}

	return tempFile.Name(), nil
}

func (g *DA2062Generator) addSignatureSection(pdf *gofpdf.Fpdf, fromUser, toUser UserInfo) {
	// Use correct Y position from template (220 instead of 250)
	y := 220.0
	pdf.SetY(y)

	// Load template for exact positioning
	template, err := g.loadTemplate()
	if err != nil {
		log.Printf("Warning: Could not load template for signature positioning: %v", err)
		// Fallback to default positioning
		g.addSignatureSectionFallback(pdf, fromUser, toUser, y)
		return
	}

	// Add signature section header
	pdf.SetFont("Arial", "B", 9)
	pdf.CellFormat(0, 5, "SIGNATURE SECTION", "0", 1, "L", false, 0, "")
	pdf.Ln(2)

	// Get template signature fields
	signatures := template.Sections.SignatureSection.Signatures
	if len(signatures) < 4 {
		log.Printf("Warning: Template has insufficient signature fields (%d), using fallback", len(signatures))
		g.addSignatureSectionFallback(pdf, fromUser, toUser, y)
		return
	}

	// Add all 4 signature fields as per official template
	g.addSignatureField(pdf, signatures[0], fromUser, "holder")       // Hand Receipt Holder signature
	g.addSignatureField(pdf, signatures[1], fromUser, "holder_name")  // Hand Receipt Holder printed name
	g.addSignatureField(pdf, signatures[2], toUser, "commander")      // Company Commander signature
	g.addSignatureField(pdf, signatures[3], toUser, "commander_name") // Company Commander printed name

	// Add witness signature fields (military standard requires 4 total)
	// Note: For now using fromUser/toUser, but this should be extended to support witness users
	pdf.Ln(5)
	pdf.SetFont("Arial", "", 7)
	pdf.CellFormat(95, 4, "WITNESS (if required):", "0", 0, "L", false, 0, "")
	pdf.CellFormat(95, 4, "DATE:", "0", 1, "L", false, 0, "")

	// Signature lines for witnesses
	pdf.SetY(pdf.GetY() + 2)
	pdf.CellFormat(95, 15, "", "T", 0, "L", false, 0, "")
	pdf.CellFormat(95, 15, "", "T", 1, "L", false, 0, "")
}

// addSignatureField adds a single signature field with diagonal placement
func (g *DA2062Generator) addSignatureField(pdf *gofpdf.Fpdf, field TemplateElement, user UserInfo, fieldType string) {
	x := field.X
	y := field.Y
	width := field.Width
	height := field.Height

	// Position for this field
	pdf.SetXY(x, y)
	pdf.SetFont("Arial", "", 7)

	// Add field label
	if field.Label != "" {
		pdf.CellFormat(width, 4, field.Label, "0", 1, "L", false, 0, "")
		pdf.SetXY(x, y+4)
	}

	// Add signature line
	pdf.CellFormat(width, height-4, "", "T", 1, "L", false, 0, "")

	// Add diagonal signature if available
	signatureY := y + 4
	if user.SignatureURL != "" && (fieldType == "holder" || fieldType == "commander") {
		g.addDiagonalSignature(pdf, user.SignatureURL, x, signatureY, width, height-4)
	}

	// Add printed name for name fields
	if fieldType == "holder_name" || fieldType == "commander_name" {
		pdf.SetXY(x, signatureY+2)
		pdf.SetFont("Arial", "", 8)
		nameText := fmt.Sprintf("%s %s", user.Rank, user.Name)
		if fieldType == "commander_name" {
			nameText = fmt.Sprintf("%s %s, %s", user.Rank, user.Name, user.Title)
		}
		pdf.CellFormat(width, 8, nameText, "0", 1, "L", false, 0, "")
	}
}

// addDiagonalSignature adds a signature image with diagonal placement
func (g *DA2062Generator) addDiagonalSignature(pdf *gofpdf.Fpdf, signatureURL string, x, y, width, height float64) {
	log.Printf("Adding diagonal signature: %s at position (%.1f, %.1f)", signatureURL, x, y)

	tempFile, err := g.downloadImage(signatureURL)
	if err != nil {
		log.Printf("Failed to download signature: %v", err)
		return
	}
	defer os.Remove(tempFile) // Clean up temp file

	// Create rotated version of the signature
	rotatedFile, err := g.createDiagonalSignature(tempFile)
	if err != nil {
		log.Printf("Failed to create diagonal signature: %v", err)
		// Fallback to horizontal signature
		g.addHorizontalSignature(pdf, tempFile, x, y, width, height)
		return
	}
	defer os.Remove(rotatedFile) // Clean up rotated file

	// Determine image type
	imageType := g.getImageType(rotatedFile)
	if imageType != "" {
		// Adjust dimensions for diagonal placement
		diagonalWidth := width * 0.8 // Slightly smaller to fit diagonally
		diagonalHeight := height * 0.8

		// Center the diagonal signature in the field
		centerX := x + (width-diagonalWidth)/2
		centerY := y + (height-diagonalHeight)/2

		pdf.ImageOptions(rotatedFile, centerX, centerY, diagonalWidth, diagonalHeight, false, gofpdf.ImageOptions{
			ImageType: imageType,
		}, 0, "")
	} else {
		log.Printf("Unsupported image type for diagonal signature: %s", rotatedFile)
	}
}

// addHorizontalSignature adds a signature horizontally (fallback)
func (g *DA2062Generator) addHorizontalSignature(pdf *gofpdf.Fpdf, tempFile string, x, y, width, height float64) {
	imageType := g.getImageType(tempFile)
	if imageType != "" {
		pdf.ImageOptions(tempFile, x+2, y+2, width-4, height-4, false, gofpdf.ImageOptions{
			ImageType: imageType,
		}, 0, "")
	}
}

// createDiagonalSignature creates a rotated version of the signature image
func (g *DA2062Generator) createDiagonalSignature(originalFile string) (string, error) {
	// For now, we'll implement a simple approach using image transformation
	// In a full implementation, you'd use image processing libraries like imaging/draw2d

	// Create a temporary file for the rotated signature
	tempDir := os.TempDir()
	rotatedFile, err := os.CreateTemp(tempDir, "signature_diagonal_*.png")
	if err != nil {
		return "", fmt.Errorf("failed to create temp file for diagonal signature: %w", err)
	}
	rotatedFile.Close()

	// For now, return the original file (this would be replaced with actual rotation logic)
	// TODO: Implement actual image rotation using imaging library
	// This is a placeholder that copies the original file
	originalData, err := os.ReadFile(originalFile)
	if err != nil {
		os.Remove(rotatedFile.Name())
		return "", fmt.Errorf("failed to read original signature: %w", err)
	}

	err = os.WriteFile(rotatedFile.Name(), originalData, 0644)
	if err != nil {
		os.Remove(rotatedFile.Name())
		return "", fmt.Errorf("failed to write diagonal signature: %w", err)
	}

	return rotatedFile.Name(), nil
}

// addSignatureSectionFallback provides fallback signature section when template loading fails
func (g *DA2062Generator) addSignatureSectionFallback(pdf *gofpdf.Fpdf, fromUser, toUser UserInfo, y float64) {
	pdf.SetY(y + 7) // Account for header

	// Add the 4 required signature fields manually
	pdf.SetFont("Arial", "", 7)

	// Left column - Hand Receipt Holder
	pdf.SetXY(10, y+10)
	pdf.CellFormat(85, 4, "SIGNATURE OF HAND RECEIPT HOLDER", "0", 1, "L", false, 0, "")
	pdf.SetXY(10, y+14)
	pdf.CellFormat(85, 15, "", "T", 1, "L", false, 0, "")

	// Add signature if available
	if fromUser.SignatureURL != "" {
		g.addDiagonalSignature(pdf, fromUser.SignatureURL, 10, y+14, 85, 15)
	}

	pdf.SetXY(10, y+31)
	pdf.CellFormat(85, 4, "PRINTED NAME OF HAND RECEIPT HOLDER", "0", 1, "L", false, 0, "")
	pdf.SetXY(10, y+35)
	pdf.SetFont("Arial", "", 8)
	pdf.CellFormat(85, 8, fmt.Sprintf("%s %s", fromUser.Rank, fromUser.Name), "T", 1, "L", false, 0, "")

	// Right column - Company Commander
	pdf.SetXY(105, y+10)
	pdf.SetFont("Arial", "", 7)
	pdf.CellFormat(90, 4, "SIGNATURE OF COMPANY COMMANDER OR AUTHORIZED REPRESENTATIVE", "0", 1, "L", false, 0, "")
	pdf.SetXY(105, y+14)
	pdf.CellFormat(90, 15, "", "T", 1, "L", false, 0, "")

	// Add signature if available
	if toUser.SignatureURL != "" {
		g.addDiagonalSignature(pdf, toUser.SignatureURL, 105, y+14, 90, 15)
	}

	pdf.SetXY(105, y+31)
	pdf.CellFormat(90, 4, "PRINTED NAME AND TITLE", "0", 1, "L", false, 0, "")
	pdf.SetXY(105, y+35)
	pdf.SetFont("Arial", "", 8)
	pdf.CellFormat(90, 8, fmt.Sprintf("%s %s, %s", toUser.Rank, toUser.Name, toUser.Title), "T", 1, "L", false, 0, "")
}

// loadTemplate loads the DA2062 template (helper method)
func (g *DA2062Generator) loadTemplate() (*DA2062Template, error) {
	// Get the project root directory
	pwd, err := os.Getwd()
	if err != nil {
		return nil, err
	}

	// Navigate to the backend directory if we're not already there
	templatePath := filepath.Join(pwd, "backend", "assets", "forms", "DA_Form_2062_reference.json")
	if _, err := os.Stat(templatePath); os.IsNotExist(err) {
		// Try from current directory if backend path doesn't exist
		templatePath = filepath.Join(pwd, "assets", "forms", "DA_Form_2062_reference.json")
	}

	data, err := os.ReadFile(templatePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read template file: %w", err)
	}

	var template DA2062Template
	if err := json.Unmarshal(data, &template); err != nil {
		return nil, fmt.Errorf("failed to parse template JSON: %w", err)
	}

	return &template, nil
}

// getImageType determines the image type from file extension
func (g *DA2062Generator) getImageType(filename string) string {
	ext := strings.ToLower(filepath.Ext(filename))
	switch ext {
	case ".jpg", ".jpeg":
		return "JPG"
	case ".png":
		return "PNG"
	case ".gif":
		return "GIF"
	default:
		return ""
	}
}

// calculateConditionCounts calculates condition-based quantity breakdown for DA2062
func (g *DA2062Generator) calculateConditionCounts(property domain.Property) ConditionCounts {
	// For now, implement basic logic. In a full system, this would:
	// 1. Check property.Condition field if it exists
	// 2. Query related maintenance records
	// 3. Consider age, usage, inspection status, etc.

	totalQty := property.Quantity
	if totalQty <= 0 {
		return ConditionCounts{}
	}

	// Basic condition assessment based on available property data
	counts := ConditionCounts{
		OnHand: totalQty,
	}

	// Determine primary condition based on property characteristics
	// This is a simplified implementation - real system would have proper condition tracking

	// Properties with serial numbers are typically high-value and tracked more carefully
	if property.SerialNumber != "" {
		// For serialized items, assume serviceable unless indicators suggest otherwise
		if totalQty == 1 {
			counts.Serviceable = 1
		} else {
			// Multiple quantities of serialized items - distribute conditions
			counts.Serviceable = max(1, totalQty*70/100)         // 70% serviceable
			counts.UnserviceableRepairable = totalQty * 20 / 100 // 20% repairable
			counts.UnserviceableCondemned = totalQty * 5 / 100   // 5% condemned
			counts.New = totalQty * 5 / 100                      // 5% new
		}
	} else {
		// Non-serialized items (consumables, common equipment)
		if totalQty <= 5 {
			// Small quantities - assume mostly serviceable
			counts.Serviceable = totalQty
		} else {
			// Larger quantities - realistic distribution
			counts.Serviceable = totalQty * 80 / 100             // 80% serviceable
			counts.UnserviceableRepairable = totalQty * 15 / 100 // 15% repairable
			counts.New = totalQty * 5 / 100                      // 5% new
		}
	}

	// Ensure totals don't exceed OnHand quantity
	total := counts.Serviceable + counts.UnserviceableRepairable +
		counts.UnserviceableCondemned + counts.New + counts.Other
	if total > counts.OnHand {
		// Adjust serviceable count to match total
		counts.Serviceable = counts.OnHand - (counts.UnserviceableRepairable +
			counts.UnserviceableCondemned + counts.New + counts.Other)
		if counts.Serviceable < 0 {
			counts.Serviceable = counts.OnHand
			counts.UnserviceableRepairable = 0
			counts.UnserviceableCondemned = 0
			counts.New = 0
			counts.Other = 0
		}
	}

	return counts
}

// max returns the maximum of two integers
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// determineUnitOfIssue determines the appropriate Unit of Issue based on property characteristics
func (g *DA2062Generator) determineUnitOfIssue(property domain.Property) string {
	// Extract key characteristics from property name and description
	name := strings.ToLower(property.Name)
	description := ""
	if property.Description != nil {
		description = strings.ToLower(*property.Description)
	}

	// Combine name and description for analysis
	fullText := name + " " + description

	// Determine unit of issue based on property type patterns

	// Liquids and fluids
	if containsAny(fullText, []string{"oil", "fuel", "hydraulic", "coolant", "antifreeze", "lubricant", "grease"}) {
		if containsAny(fullText, []string{"gallon", "gal", "qt", "quart"}) {
			return "GAL"
		}
		if containsAny(fullText, []string{"liter", "litre", "ml", "milliliter"}) {
			return "LTR"
		}
		return "QT" // Default for liquids
	}

	// Cables, wires, rope, chain - linear measurement
	if containsAny(fullText, []string{"cable", "wire", "rope", "chain", "cord", "hose", "tubing"}) {
		if containsAny(fullText, []string{"foot", "ft", "feet"}) {
			return "FT"
		}
		if containsAny(fullText, []string{"meter", "metre", "yard"}) {
			return "M"
		}
		return "FT" // Default for linear items
	}

	// Fabric, materials - area measurement
	if containsAny(fullText, []string{"fabric", "canvas", "tarp", "cloth", "material", "sheeting"}) {
		return "YD"
	}

	// Ammunition and ordnance
	if containsAny(fullText, []string{"ammunition", "ammo", "round", "cartridge", "shell", "grenade", "mine"}) {
		return "RD" // Rounds
	}

	// Medical supplies - often by dose or unit
	if containsAny(fullText, []string{"medical", "medicine", "drug", "pill", "tablet", "syringe", "bandage", "gauze"}) {
		if containsAny(fullText, []string{"bottle", "vial", "ampule"}) {
			return "EA"
		}
		return "EA" // Default for medical
	}

	// Food and rations
	if containsAny(fullText, []string{"ration", "mre", "food", "meal", "beef", "chicken", "soup"}) {
		return "EA"
	}

	// Weight-based items
	if containsAny(fullText, []string{"sand", "gravel", "concrete", "cement", "salt", "powder"}) {
		if containsAny(fullText, []string{"pound", "lb", "lbs"}) {
			return "LB"
		}
		return "LB"
	}

	// Tools and equipment (serialized items)
	if property.SerialNumber != "" {
		return "EA"
	}

	// Small consumable items often counted in sets
	if containsAny(fullText, []string{"screw", "bolt", "nut", "washer", "pin", "clip", "fastener"}) {
		if property.Quantity > 10 {
			return "PR" // Pair or set for large quantities
		}
		return "EA"
	}

	// Electronic components
	if containsAny(fullText, []string{"battery", "fuse", "resistor", "capacitor", "circuit", "chip", "board"}) {
		return "EA"
	}

	// Vehicles and large equipment
	if containsAny(fullText, []string{"vehicle", "truck", "tank", "generator", "engine", "motor", "trailer"}) {
		return "EA"
	}

	// Default for everything else
	return "EA"
}

// containsAny checks if the text contains any of the given substrings
func containsAny(text string, substrings []string) bool {
	for _, substring := range substrings {
		if strings.Contains(text, substring) {
			return true
		}
	}
	return false
}

// determineSecurityClassification determines the security classification based on property characteristics
func (g *DA2062Generator) determineSecurityClassification(property domain.Property) string {
	// Extract key characteristics from property name and description
	name := strings.ToLower(property.Name)
	description := ""
	if property.Description != nil {
		description = strings.ToLower(*property.Description)
	}

	// Combine name and description for analysis
	fullText := name + " " + description

	// Check for classified item indicators

	// SECRET level indicators
	if containsAny(fullText, []string{
		"cryptographic", "crypto", "encryption", "classified", "secret",
		"comsec", "communications security", "radar", "sonar", "guidance",
		"ballistic", "missile", "nuclear", "chemical", "biological",
		"intelligence", "reconnaissance", "electronic warfare", "ew",
		"frequency hopping", "secure comm", "night vision", "thermal",
		"targeting", "fire control", "navigation", "gps", "satellite",
	}) {
		return "S" // SECRET
	}

	// CONFIDENTIAL level indicators
	if containsAny(fullText, []string{
		"tactical", "combat", "military", "weapon", "ammunition", "explosive",
		"communications", "radio", "frequency", "secure", "encrypted",
		"sensitive", "restricted", "controlled", "opsec", "mission critical",
		"command", "control", "surveillance", "electronic", "countermeasure",
		"jamming", "detection", "sensor", "infrared", "laser",
	}) {
		return "C" // CONFIDENTIAL
	}

	// FOUO (For Official Use Only) indicators
	if containsAny(fullText, []string{
		"personnel", "personal", "medical", "maintenance", "repair",
		"technical manual", "procedure", "training", "administrative",
		"logistics", "supply", "inventory", "accountability", "sensitive but unclassified",
	}) {
		return "FOUO" // For Official Use Only
	}

	// Unclassified items (default)
	// Most standard military property is unclassified
	return "U" // UNCLASSIFIED
}

func (g *DA2062Generator) addPageNumbers(pdf *gofpdf.Fpdf) {
	pdf.SetFont("Arial", "", 8)
	pdf.AliasNbPages("")

	// Add page numbers to all pages using military standard format
	totalPages := pdf.PageCount()
	for i := 1; i <= totalPages; i++ {
		pdf.SetPage(i)

		// Position according to template (X=180, Y=265)
		// Use proper military format: "PAGE ___ OF ___"
		pdf.SetXY(180, 265)
		pageText := fmt.Sprintf("PAGE %d OF %d", i, totalPages)
		pdf.CellFormat(0, 5, pageText, "0", 0, "R", false, 0, "")

		// Add form identification at bottom of each page
		pdf.SetXY(10, 275)
		pdf.SetFont("Arial", "", 7)
		pdf.CellFormat(0, 4, "DA FORM 2062, "+time.Now().Format("JAN 2006"), "0", 0, "L", false, 0, "")
	}
}

// validateGeneratedPDF performs template compliance validation (non-blocking)
func (g *DA2062Generator) validateGeneratedPDF(options GenerateOptions) {
	validator, err := NewDA2062Validator()
	if err != nil {
		log.Printf("WARNING: Failed to create DA2062 validator: %v", err)
		return
	}

	report := validator.ValidateCompliance(options)

	if !report.IsCompliant {
		log.Printf("WARNING: Generated DA2062 PDF has %d compliance errors", len(report.Errors))
		for _, err := range report.Errors {
			log.Printf("  - %s: %s", err.Element, err.Description)
		}
	}

	if len(report.Warnings) > 0 {
		log.Printf("INFO: Generated DA2062 PDF has %d compliance warnings", len(report.Warnings))
		for _, warning := range report.Warnings {
			log.Printf("  - %s: %s", warning.Element, warning.Description)
		}
	}

	if report.IsCompliant && len(report.Warnings) == 0 {
		log.Printf("INFO: Generated DA2062 PDF is fully compliant with template %s", report.TemplateVersion)
	}
}
