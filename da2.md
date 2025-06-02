// backend/internal/services/pdf/da2062_generator.go
package pdf

import (
    "bytes"
    "fmt"
    "time"
    
    "github.com/jung-kurt/gofpdf"
    "github.com/toole-brendan/handreceipt-go/internal/domain"
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
    Name     string `json:"name"`
    Rank     string `json:"rank"`
    Title    string `json:"title"`
    Phone    string `json:"phone"`
}

type GenerateOptions struct {
    GroupByCategory bool `json:"group_by_category"`
    IncludeSignatures bool `json:"include_signatures"`
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
    // Create new PDF with Letter size
    pdf := gofpdf.New("P", "mm", "Letter", "")
    pdf.SetMargins(10, 10, 10)
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
    
    return &buf, nil
}

func (g *DA2062Generator) addHeader(pdf *gofpdf.Fpdf, unitInfo UnitInfo) {
    // Title at top
    pdf.SetFont("Arial", "B", 10)
    pdf.Cell(0, 5, "HAND RECEIPT/ANNEX NUMBER", "0", 1, "L")
    
    pdf.SetFont("Arial", "", 8)
    pdf.Cell(0, 4, "For use of this form, see DA PAM 710-2-1.", "0", 1, "L")
    pdf.Cell(0, 4, "The proponent agency is ODCSLOG.", "0", 1, "L")
    
    // Form number in top right
    pdf.SetXY(170, 10)
    pdf.SetFont("Arial", "B", 9)
    pdf.Cell(30, 5, "DA FORM 2062", "0", 1, "L")
    pdf.SetXY(170, 15)
    pdf.SetFont("Arial", "", 8)
    pdf.Cell(30, 4, "JAN 1982", "0", 1, "L")
    
    pdf.Ln(10)
}

func (g *DA2062Generator) addTitle(pdf *gofpdf.Fpdf) {
    pdf.SetFont("Arial", "B", 10)
    pdf.SetY(25)
    pdf.Cell(0, 6, "HAND RECEIPT/ANNEX NUMBER", "0", 1, "L")
}

func (g *DA2062Generator) addFromToSection(pdf *gofpdf.Fpdf, fromUser, toUser UserInfo, unitInfo UnitInfo) {
    y := 35.0
    pdf.SetY(y)
    
    // FROM section
    pdf.SetFont("Arial", "B", 9)
    pdf.Cell(20, 5, "FROM:", "0", 0, "L")
    pdf.SetFont("Arial", "", 9)
    pdf.Cell(70, 5, fmt.Sprintf("%s %s", fromUser.Rank, fromUser.Name), "B", 0, "L")
    
    pdf.Cell(10, 5, "", "0", 0, "L") // Spacer
    
    // TO section
    pdf.SetFont("Arial", "B", 9)
    pdf.Cell(15, 5, "TO:", "0", 0, "L")
    pdf.SetFont("Arial", "", 9)
    pdf.Cell(70, 5, fmt.Sprintf("%s %s", toUser.Rank, toUser.Name), "B", 1, "L")
    
    // Unit info
    pdf.SetY(y + 8)
    pdf.SetFont("Arial", "B", 9)
    pdf.Cell(20, 5, "UNIT:", "0", 0, "L")
    pdf.SetFont("Arial", "", 9)
    pdf.Cell(70, 5, unitInfo.UnitName, "B", 0, "L")
    
    pdf.Cell(10, 5, "", "0", 0, "L") // Spacer
    
    pdf.SetFont("Arial", "B", 9)
    pdf.Cell(15, 5, "DODAAC:", "0", 0, "L")
    pdf.SetFont("Arial", "", 9)
    pdf.Cell(70, 5, unitInfo.DODAAC, "B", 1, "L")
    
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
    
    // SEC (Security classification - usually blank)
    pdf.CellFormat(10, rowHeight, "", "1", 0, "C", false, 0, "")
    
    // Unit of Issue
    ui := "EA"
    if property.Unit != nil {
        ui = *property.Unit
    }
    pdf.CellFormat(10, rowHeight, ui, "1", 0, "C", false, 0, "")
    
    // QTY AUTH (Quantity Authorized)
    pdf.CellFormat(15, rowHeight, fmt.Sprintf("%d", property.Quantity), "1", 0, "C", false, 0, "")
    
    // Quantity columns A-F (typically used for condition codes or actual counts)
    quantityWidth := 6.67
    // Column A - typically shows on-hand quantity
    pdf.CellFormat(quantityWidth, rowHeight, fmt.Sprintf("%d", property.Quantity), "1", 0, "C", false, 0, "")
    // Columns B-F - empty for basic hand receipt
    for i := 0; i < 5; i++ {
        pdf.CellFormat(quantityWidth, rowHeight, "", "1", 0, "C", false, 0, "")
    }
    
    pdf.Ln(-1)
    return currentY + rowHeight
}

func (g *DA2062Generator) addSignatureSection(pdf *gofpdf.Fpdf, fromUser, toUser UserInfo) {
    y := 250.0
    pdf.SetY(y)
    
    pdf.SetFont("Arial", "B", 9)
    pdf.Cell(0, 5, "SIGNATURE SECTION", "0", 1, "L")
    pdf.Ln(2)
    
    // From signature
    pdf.SetFont("Arial", "", 8)
    pdf.Cell(90, 5, "FROM (Signature and Date):", "T", 0, "L")
    pdf.Cell(10, 5, "", "0", 0, "L")
    pdf.Cell(90, 5, "TO (Signature and Date):", "T", 1, "L")
    
    pdf.Ln(10)
    
    // Typed names
    pdf.Cell(90, 5, fmt.Sprintf("%s %s", fromUser.Rank, fromUser.Name), "0", 0, "L")
    pdf.Cell(10, 5, "", "0", 0, "L")
    pdf.Cell(90, 5, fmt.Sprintf("%s %s", toUser.Rank, toUser.Name), "0", 1, "L")
    
    // Titles
    pdf.SetFont("Arial", "", 7)
    pdf.Cell(90, 4, fromUser.Title, "0", 0, "L")
    pdf.Cell(10, 4, "", "0", 0, "L")
    pdf.Cell(90, 4, toUser.Title, "0", 1, "L")
}

func (g *DA2062Generator) addPageNumbers(pdf *gofpdf.Fpdf) {
    pdf.SetFont("Arial", "", 8)
    pdf.AliasNbPages("")
    
    // Add page numbers to all pages
    totalPages := pdf.PageCount()
    for i := 1; i <= totalPages; i++ {
        pdf.SetPage(i)
        pdf.SetXY(190, 280)
        pdf.CellFormat(0, 5, fmt.Sprintf("Page %d of %d", i, totalPages), "0", 0, "R", false, 0, "")
    }
}

// Handler extension for da2062_handler.go
func (h *DA2062Handler) GenerateDA2062PDF(c *gin.Context) {
    userIDVal, exists := c.Get("userID")
    if !exists {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
        return
    }
    userID, ok := userIDVal.(uint)
    if !ok {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID format"})
        return
    }
    
    var req GeneratePDFRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: " + err.Error()})
        return
    }
    
    // Fetch properties
    var properties []domain.Property
    for _, id := range req.PropertyIDs {
        property, err := h.Repo.GetPropertyByID(id)
        if err != nil {
            continue
        }
        // Verify user has access
        if property.AssignedToUserID != nil && *property.AssignedToUserID == userID {
            properties = append(properties, *property)
        }
    }
    
    if len(properties) == 0 {
        c.JSON(http.StatusBadRequest, gin.H{"error": "No valid properties found"})
        return
    }
    
    // Get user info
    fromUser, _ := h.Repo.GetUserByID(userID)
    toUser := req.ToUser
    if toUser.Name == "" {
        toUser = req.FromUser // Self hand receipt
    }
    
    // Generate PDF
    generator := NewDA2062Generator(h.Repo)
    pdfBuffer, err := generator.GenerateDA2062(
        properties,
        req.FromUser,
        toUser,
        req.UnitInfo,
        GenerateOptions{
            GroupByCategory: req.GroupByCategory,
            IncludeSignatures: true,
        },
    )
    
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate PDF"})
        return
    }
    
    // Handle email or download
    if req.SendEmail {
        // Queue email job
        formNumber := fmt.Sprintf("HR-%s-%d", time.Now().Format("20060102"), userID)
        err = h.emailService.SendDA2062Email(req.Recipients, pdfBuffer, formNumber)
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send email"})
            return
        }
        
        // Log to ledger
        h.Ledger.LogDA2062Export(userID, len(properties), "email", strings.Join(req.Recipients, ","))
        
        c.JSON(http.StatusOK, gin.H{
            "message": "DA 2062 emailed successfully",
            "form_number": formNumber,
            "recipients": req.Recipients,
        })
    } else {
        // Return PDF for download
        filename := fmt.Sprintf("DA2062_%s.pdf", time.Now().Format("20060102_150405"))
        
        // Log to ledger
        h.Ledger.LogDA2062Export(userID, len(properties), "download", "")
        
        c.Header("Content-Type", "application/pdf")
        c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", filename))
        c.Data(http.StatusOK, "application/pdf", pdfBuffer.Bytes())
    }
}

// Request models
type GeneratePDFRequest struct {
    PropertyIDs      []uint     `json:"property_ids" binding:"required"`
    GroupByCategory  bool       `json:"group_by_category"`
    SendEmail        bool       `json:"send_email"`
    Recipients       []string   `json:"recipients"`
    FromUser         UserInfo   `json:"from_user" binding:"required"`
    ToUser           UserInfo   `json:"to_user"`
    UnitInfo         UnitInfo   `json:"unit_info" binding:"required"`
}