# DA 2062 PDF Generation & Email Feature Design

## Overview
This feature allows users to generate official DA Form 2062 (Hand Receipt) PDFs from their digital inventory and email them to recipients. The system will auto-populate the form with property data and support both individual items and batch exports.

## Architecture Components

### 1. Backend Implementation

#### New Go Package: `backend/internal/services/pdf`
```go
// pdf_generator.go
package pdf

import (
    "bytes"
    "github.com/jung-kurt/gofpdf"
    "github.com/toole-brendan/handreceipt-go/internal/domain"
)

type DA2062Generator struct {
    repo repository.Repository
}

func (g *DA2062Generator) GenerateDA2062(
    properties []domain.Property,
    userInfo UserInfo,
    unitInfo UnitInfo,
) (*bytes.Buffer, error) {
    // Generate PDF using gofpdf library
    // Layout matches official DA Form 2062-R
}
```

#### New Endpoints in `da2062_handler.go`
```go
// GenerateDA2062PDF generates a PDF from selected properties
func (h *DA2062Handler) GenerateDA2062PDF(c *gin.Context) {
    var req GeneratePDFRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
        return
    }
    
    // Generate PDF
    pdfBuffer, err := h.pdfGenerator.GenerateDA2062(...)
    
    // Return PDF or prepare for email
    if req.SendEmail {
        // Queue email job
        h.emailService.QueueDA2062Email(req.Recipients, pdfBuffer)
    } else {
        // Return PDF for download
        c.Data(http.StatusOK, "application/pdf", pdfBuffer.Bytes())
    }
}

// New models
type GeneratePDFRequest struct {
    PropertyIDs    []uint   `json:"property_ids"`
    IncludeQRCodes bool     `json:"include_qr_codes"`
    SendEmail      bool     `json:"send_email"`
    Recipients     []string `json:"recipients"`
    UnitInfo       UnitInfo `json:"unit_info"`
}
```

#### Email Service Integration
```go
// backend/internal/services/email/da2062_email.go
func (s *EmailService) SendDA2062Email(
    recipients []string,
    pdfBuffer *bytes.Buffer,
    formNumber string,
) error {
    // Use SendGrid/AWS SES to send email with PDF attachment
    message := &mail.SGMailV3{}
    message.SetFrom("noreply@handreceipt.com")
    message.Subject = fmt.Sprintf("DA Form 2062 - %s", formNumber)
    
    // Attach PDF
    attachment := mail.NewAttachment()
    attachment.SetContent(base64.StdEncoding.EncodeToString(pdfBuffer.Bytes()))
    attachment.SetFilename(fmt.Sprintf("DA2062_%s.pdf", formNumber))
    attachment.SetType("application/pdf")
    
    message.AddAttachment(attachment)
    // Send email...
}
```

### 2. iOS Implementation

#### New View: `DA2062ExportView.swift`
```swift
import SwiftUI
import MessageUI

struct DA2062ExportView: View {
    @StateObject private var viewModel = DA2062ExportViewModel()
    @State private var showingMailComposer = false
    @State private var showingShareSheet = false
    @State private var generatedPDF: Data?
    
    var body: some View {
        NavigationView {
            VStack {
                // Header with unit info
                DA2062HeaderSection(viewModel: viewModel)
                
                // Property selection
                PropertySelectionList(
                    properties: viewModel.properties,
                    selectedIDs: $viewModel.selectedPropertyIDs
                )
                
                // Export options
                ExportOptionsSection(
                    includeQRCodes: $viewModel.includeQRCodes,
                    groupByCategory: $viewModel.groupByCategory
                )
                
                // Action buttons
                HStack {
                    Button(action: generateAndShare) {
                        Label("Generate & Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button(action: generateAndEmail) {
                        Label("Email PDF", systemImage: "envelope")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(!MFMailComposeViewController.canSendMail())
                }
                .padding()
            }
            .navigationTitle("Export DA 2062")
            .sheet(isPresented: $showingMailComposer) {
                MailComposerView(
                    pdfData: generatedPDF,
                    formNumber: viewModel.formNumber
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [generatedPDF])
            }
        }
    }
}
```

#### View Model: `DA2062ExportViewModel.swift`
```swift
class DA2062ExportViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var selectedPropertyIDs: Set<Int> = []
    @Published var includeQRCodes = true
    @Published var groupByCategory = true
    @Published var unitInfo = UnitInfo()
    
    private let apiService: APIService
    
    func generatePDF() async throws -> Data {
        let request = GeneratePDFRequest(
            propertyIDs: Array(selectedPropertyIDs),
            includeQRCodes: includeQRCodes,
            sendEmail: false,
            recipients: [],
            unitInfo: unitInfo
        )
        
        return try await apiService.generateDA2062PDF(request)
    }
    
    func emailPDF(to recipients: [String]) async throws {
        let request = GeneratePDFRequest(
            propertyIDs: Array(selectedPropertyIDs),
            includeQRCodes: includeQRCodes,
            sendEmail: true,
            recipients: recipients,
            unitInfo: unitInfo
        )
        
        try await apiService.generateAndEmailDA2062(request)
    }
}
```

### 3. Web Implementation

#### React Component: `DA2062ExportModal.tsx`
```typescript
import React, { useState } from 'react';
import { useProperty } from '@/hooks/useProperty';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';
import { Mail, Download, QrCode } from 'lucide-react';

export const DA2062ExportModal: React.FC<{
  open: boolean;
  onClose: () => void;
  preselectedItems?: string[];
}> = ({ open, onClose, preselectedItems = [] }) => {
  const { properties } = useProperty();
  const [selectedItems, setSelectedItems] = useState<Set<string>>(
    new Set(preselectedItems)
  );
  const [includeQRCodes, setIncludeQRCodes] = useState(true);
  const [emailMode, setEmailMode] = useState(false);
  const [recipients, setRecipients] = useState<string[]>([]);
  
  const handleGenerate = async () => {
    const response = await fetch('/api/da2062/generate-pdf', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        property_ids: Array.from(selectedItems),
        include_qr_codes: includeQRCodes,
        send_email: emailMode,
        recipients: recipients,
        unit_info: {
          unit_name: userProfile.unit,
          dodaac: userProfile.dodaac,
          // ...other unit info
        }
      })
    });
    
    if (!emailMode) {
      // Download PDF
      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `DA2062_${new Date().toISOString()}.pdf`;
      a.click();
    } else {
      // Show success message
      toast.success('DA 2062 emailed successfully!');
    }
    onClose();
  };
  
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-3xl">
        <DialogHeader>
          <DialogTitle>Export DA Form 2062</DialogTitle>
        </DialogHeader>
        
        <div className="space-y-6">
          {/* Property Selection */}
          <PropertySelectionTable
            properties={properties}
            selectedItems={selectedItems}
            onSelectionChange={setSelectedItems}
          />
          
          {/* Export Options */}
          <div className="border rounded-lg p-4">
            <h3 className="font-semibold mb-3">Export Options</h3>
            <div className="space-y-2">
              <label className="flex items-center gap-2">
                <input
                  type="checkbox"
                  checked={includeQRCodes}
                  onChange={(e) => setIncludeQRCodes(e.target.checked)}
                />
                <QrCode className="w-4 h-4" />
                Include QR codes for each item
              </label>
            </div>
          </div>
          
          {/* Delivery Method */}
          <div className="flex gap-4">
            <Button
              variant={!emailMode ? 'default' : 'outline'}
              onClick={() => setEmailMode(false)}
            >
              <Download className="w-4 h-4 mr-2" />
              Download PDF
            </Button>
            <Button
              variant={emailMode ? 'default' : 'outline'}
              onClick={() => setEmailMode(true)}
            >
              <Mail className="w-4 h-4 mr-2" />
              Email PDF
            </Button>
          </div>
          
          {emailMode && (
            <EmailRecipientsInput
              recipients={recipients}
              onChange={setRecipients}
            />
          )}
          
          {/* Generate Button */}
          <Button onClick={handleGenerate} className="w-full">
            {emailMode ? 'Send Email' : 'Generate PDF'}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
};
```

## UI/UX Flow

### Mobile (iOS) Flow:
1. **Access Point**: 
   - Tab bar: "More" → "Export DA 2062"
   - Property list: Select items → "Export as DA 2062"
   
2. **Export Screen**:
   - Unit information auto-filled from user profile
   - Property selection with search/filter
   - Toggle options (QR codes, grouping)
   - Preview button to see PDF layout
   
3. **Delivery Options**:
   - Share sheet (AirDrop, Messages, Mail)
   - Direct email with pre-filled subject/body
   - Save to Files app

### Web Flow:
1. **Access Points**:
   - Dashboard: Quick action button
   - Property Book: Bulk action menu
   - Individual property: Export button
   
2. **Export Modal**:
   - Multi-select property table
   - Real-time count of selected items
   - Form preview thumbnail
   
3. **Delivery**:
   - Direct download
   - Email with recipient management
   - Save to cloud storage (future)

## PDF Layout Features

1. **Official Form Compliance**:
   - Matches DA Form 2062-R layout
   - Proper headers and footers
   - Signature blocks

2. **Enhanced Features**:
   - QR codes for each item (optional)
   - Hyperlinked serial numbers
   - Grouped by category/location
   - Page numbers and timestamps

3. **Data Population**:
   - Auto-fills from digital inventory
   - Calculates totals
   - Formats dates properly
   - Includes all required fields

## Security Considerations

1. **Access Control**:
   - Users can only export their assigned items
   - Role-based permissions for unit-wide exports
   - Audit trail for all exports

2. **Email Security**:
   - Encrypted PDF attachments (optional)
   - Email verification for new recipients
   - Rate limiting on email sends

3. **Data Protection**:
   - No sensitive data in email body
   - PDFs generated server-side
   - Temporary file cleanup

## Implementation Timeline

### Phase 1 (Week 1-2):
- Backend PDF generation
- Basic iOS implementation
- Simple web modal

### Phase 2 (Week 3-4):
- Email integration
- QR code generation
- Advanced formatting options

### Phase 3 (Week 5-6):
- Bulk operations
- Template customization
- Analytics and tracking