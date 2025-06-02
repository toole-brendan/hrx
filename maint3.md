# Simplified Maintenance Form Implementation

## Overview
A streamlined feature that allows users to generate auto-populated DA maintenance forms from their property items and send them to any connection. Recipients receive these forms in a new "Documents" inbox.

## Database Schema Updates

### 1. Add Documents Table
```sql
-- Add to schema.ts
export const documents = pgTable("documents", {
  id: serial("id").primaryKey(),
  type: text("type").notNull(), // 'maintenance_form', 'transfer_form', etc.
  subtype: text("subtype"), // 'DA2404', 'DA5988E', etc.
  title: text("title").notNull(),
  senderUserId: integer("sender_user_id").references(() => users.id).notNull(),
  recipientUserId: integer("recipient_user_id").references(() => users.id).notNull(),
  propertyId: integer("property_id").references(() => properties.id),
  formData: jsonb("form_data").notNull(), // Complete form data
  description: text("description"),
  attachments: jsonb("attachments"), // Array of photo URLs
  status: text("status").default("unread").notNull(), // unread, read, archived
  sentAt: timestamp("sent_at").defaultNow().notNull(),
  readAt: timestamp("read_at"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
```

## Backend Implementation

### 1. Document Models
```go
// backend/internal/models/document.go
package models

import (
    "time"
    "encoding/json"
)

type Document struct {
    ID               uint            `json:"id" gorm:"primaryKey"`
    Type             string          `json:"type"`
    Subtype          *string         `json:"subtype"`
    Title            string          `json:"title"`
    SenderUserID     uint            `json:"sender_user_id"`
    Sender           *User           `json:"sender,omitempty" gorm:"foreignKey:SenderUserID"`
    RecipientUserID  uint            `json:"recipient_user_id"`
    Recipient        *User           `json:"recipient,omitempty" gorm:"foreignKey:RecipientUserID"`
    PropertyID       *uint           `json:"property_id"`
    Property         *Property       `json:"property,omitempty" gorm:"foreignKey:PropertyID"`
    FormData         json.RawMessage `json:"form_data"`
    Description      *string         `json:"description"`
    Attachments      json.RawMessage `json:"attachments"`
    Status           string          `json:"status"`
    SentAt           time.Time       `json:"sent_at"`
    ReadAt           *time.Time      `json:"read_at"`
    CreatedAt        time.Time       `json:"created_at"`
    UpdatedAt        time.Time       `json:"updated_at"`
}

// MaintenanceFormData represents the data for maintenance forms
type MaintenanceFormData struct {
    FormType         string    `json:"form_type"` // DA2404, DA5988E
    EquipmentName    string    `json:"equipment_name"`
    SerialNumber     string    `json:"serial_number"`
    NSN              string    `json:"nsn"`
    Location         string    `json:"location"`
    Description      string    `json:"description"`
    FaultDescription string    `json:"fault_description"`
    RequestDate      time.Time `json:"request_date"`
    // Form-specific fields would be in a nested object
    FormFields       map[string]interface{} `json:"form_fields"`
}
```

### 2. Document Handler
```go
// backend/internal/api/handlers/document_handler.go
package handlers

import (
    "encoding/json"
    "fmt"
    "net/http"
    "strconv"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/toole-brendan/handreceipt-go/internal/models"
    "github.com/toole-brendan/handreceipt-go/internal/repository"
)

type DocumentHandler struct {
    Repo   repository.Repository
    Ledger ledger.LedgerService
}

func NewDocumentHandler(repo repository.Repository, ledger ledger.LedgerService) *DocumentHandler {
    return &DocumentHandler{
        Repo:   repo,
        Ledger: ledger,
    }
}

// CreateMaintenanceForm generates and sends a maintenance form
func (h *DocumentHandler) CreateMaintenanceForm(c *gin.Context) {
    userID := c.MustGet("userID").(uint)
    
    var req struct {
        PropertyID      uint     `json:"property_id" binding:"required"`
        RecipientUserID uint     `json:"recipient_user_id" binding:"required"`
        FormType        string   `json:"form_type" binding:"required"` // DA2404, DA5988E
        Description     string   `json:"description" binding:"required"`
        FaultDescription string  `json:"fault_description"`
        Attachments     []string `json:"attachments"` // Photo URLs
    }
    
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }
    
    // Get property details
    property, err := h.Repo.GetPropertyByID(req.PropertyID)
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Property not found"})
        return
    }
    
    // Verify property ownership
    if property.AssignedToUserID == nil || *property.AssignedToUserID != userID {
        c.JSON(http.StatusForbidden, gin.H{"error": "You can only create maintenance forms for your own properties"})
        return
    }
    
    // Check if recipient is in connections
    connected, err := h.Repo.CheckUserConnection(userID, req.RecipientUserID)
    if err != nil || !connected {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Recipient must be in your connections"})
        return
    }
    
    // Get recipient details
    recipient, err := h.Repo.GetUserByID(req.RecipientUserID)
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Recipient not found"})
        return
    }
    
    // Generate form data based on form type
    formData := h.generateMaintenanceFormData(req.FormType, property, req.Description, req.FaultDescription)
    
    formDataJSON, err := json.Marshal(formData)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate form"})
        return
    }
    
    attachmentsJSON, _ := json.Marshal(req.Attachments)
    
    // Create document
    document := &models.Document{
        Type:            "maintenance_form",
        Subtype:         &req.FormType,
        Title:           fmt.Sprintf("%s Maintenance Request - %s", req.FormType, property.Name),
        SenderUserID:    userID,
        RecipientUserID: req.RecipientUserID,
        PropertyID:      &req.PropertyID,
        FormData:        formDataJSON,
        Description:     &req.Description,
        Attachments:     attachmentsJSON,
        Status:          "unread",
        SentAt:          time.Now(),
    }
    
    if err := h.Repo.CreateDocument(document); err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send document"})
        return
    }
    
    // Log to ImmuDB
    h.Ledger.LogDocumentEvent(document.ID, "MAINTENANCE_FORM_SENT", userID, req.RecipientUserID)
    
    c.JSON(http.StatusCreated, gin.H{
        "document": document,
        "message": fmt.Sprintf("Maintenance form sent to %s %s", recipient.Rank, recipient.Name),
    })
}

// GetDocuments retrieves documents for a user
func (h *DocumentHandler) GetDocuments(c *gin.Context) {
    userID := c.MustGet("userID").(uint)
    
    box := c.Query("box") // "inbox", "sent", "all"
    status := c.Query("status") // "unread", "read", "archived"
    docType := c.Query("type") // "maintenance_form", etc.
    
    var documents []models.Document
    var err error
    
    switch box {
    case "inbox":
        documents, err = h.Repo.GetDocumentsByRecipient(userID, status, docType)
    case "sent":
        documents, err = h.Repo.GetDocumentsBySender(userID, status, docType)
    default:
        documents, err = h.Repo.GetDocumentsForUser(userID, status, docType)
    }
    
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch documents"})
        return
    }
    
    // Get unread count
    unreadCount, _ := h.Repo.GetUnreadDocumentCount(userID)
    
    c.JSON(http.StatusOK, gin.H{
        "documents": documents,
        "count": len(documents),
        "unread_count": unreadCount,
    })
}

// MarkDocumentRead marks a document as read
func (h *DocumentHandler) MarkDocumentRead(c *gin.Context) {
    userID := c.MustGet("userID").(uint)
    docID, _ := strconv.ParseUint(c.Param("id"), 10, 32)
    
    document, err := h.Repo.GetDocumentByID(uint(docID))
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Document not found"})
        return
    }
    
    // Verify recipient
    if document.RecipientUserID != userID {
        c.JSON(http.StatusForbidden, gin.H{"error": "You can only mark your own documents as read"})
        return
    }
    
    // Update status
    now := time.Now()
    document.Status = "read"
    document.ReadAt = &now
    
    if err := h.Repo.UpdateDocument(document); err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update document"})
        return
    }
    
    c.JSON(http.StatusOK, gin.H{"message": "Document marked as read"})
}

// Helper method to generate form data
func (h *DocumentHandler) generateMaintenanceFormData(
    formType string, 
    property *domain.Property, 
    description string,
    faultDescription string,
) models.MaintenanceFormData {
    
    formData := models.MaintenanceFormData{
        FormType:         formType,
        EquipmentName:    property.Name,
        SerialNumber:     property.SerialNumber,
        NSN:              property.NSN,
        Location:         property.Location,
        Description:      description,
        FaultDescription: faultDescription,
        RequestDate:      time.Now(),
        FormFields:       make(map[string]interface{}),
    }
    
    // Add form-specific fields based on type
    switch formType {
    case "DA2404":
        formData.FormFields["equipment_model"] = property.Name
        formData.FormFields["admin_number"] = property.SerialNumber
        formData.FormFields["deficiency_class"] = "O" // Default to Operational
        formData.FormFields["inspection_type"] = "Operator Request"
        
    case "DA5988E":
        formData.FormFields["equipment_model"] = property.Name
        formData.FormFields["registration_num"] = property.SerialNumber
        formData.FormFields["fault_date"] = time.Now().Format("2006-01-02")
        formData.FormFields["fault_time"] = time.Now().Format("15:04")
    }
    
    return formData
}

// RegisterRoutes registers document routes
func (h *DocumentHandler) RegisterRoutes(router *gin.RouterGroup) {
    documents := router.Group("/documents")
    {
        documents.GET("", h.GetDocuments)
        documents.POST("/maintenance-form", h.CreateMaintenanceForm)
        documents.PUT("/:id/read", h.MarkDocumentRead)
        documents.GET("/:id", h.GetDocument)
    }
}
```

## Frontend Implementation

### 1. Send Maintenance Form Component
```tsx
// web/src/components/property/SendMaintenanceForm.tsx
import React, { useState } from 'react';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { useQuery } from '@tanstack/react-query';
import { connectionService } from '@/services/connectionService';
import { documentService } from '@/services/documentService';
import { Camera, Send, FileText, User } from 'lucide-react';

interface SendMaintenanceFormProps {
  property: Property;
  open: boolean;
  onClose: () => void;
}

export const SendMaintenanceForm: React.FC<SendMaintenanceFormProps> = ({
  property,
  open,
  onClose,
}) => {
  const [formType, setFormType] = useState<'DA2404' | 'DA5988E'>('DA2404');
  const [recipientId, setRecipientId] = useState<number | null>(null);
  const [description, setDescription] = useState('');
  const [faultDescription, setFaultDescription] = useState('');
  const [attachments, setAttachments] = useState<string[]>([]);
  const [sending, setSending] = useState(false);
  
  const { data: connections } = useQuery({
    queryKey: ['connections'],
    queryFn: connectionService.getConnections,
  });
  
  const handleSend = async () => {
    if (!recipientId || !description) return;
    
    setSending(true);
    try {
      await documentService.sendMaintenanceForm({
        property_id: property.id,
        recipient_user_id: recipientId,
        form_type: formType,
        description,
        fault_description: faultDescription,
        attachments,
      });
      
      toast.success('Maintenance form sent successfully');
      onClose();
    } catch (error) {
      toast.error('Failed to send maintenance form');
    } finally {
      setSending(false);
    }
  };
  
  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-lg">
        <DialogHeader>
          <DialogTitle>Send Maintenance Form</DialogTitle>
        </DialogHeader>
        
        <div className="space-y-4">
          {/* Property Info */}
          <div className="bg-muted p-3 rounded-lg">
            <div className="text-sm font-medium mb-1">{property.name}</div>
            <div className="text-xs text-muted-foreground">
              SN: {property.serial_number} | NSN: {property.nsn || 'N/A'}
            </div>
          </div>
          
          {/* Form Type Selection */}
          <div>
            <label className="text-sm font-medium mb-2 block">Form Type</label>
            <div className="grid grid-cols-2 gap-2">
              <Button
                type="button"
                variant={formType === 'DA2404' ? 'default' : 'outline'}
                onClick={() => setFormType('DA2404')}
                className="h-auto py-3"
              >
                <div>
                  <div className="font-medium">DA Form 2404</div>
                  <div className="text-xs opacity-70">Equipment Inspection</div>
                </div>
              </Button>
              <Button
                type="button"
                variant={formType === 'DA5988E' ? 'default' : 'outline'}
                onClick={() => setFormType('DA5988E')}
                className="h-auto py-3"
              >
                <div>
                  <div className="font-medium">DA Form 5988-E</div>
                  <div className="text-xs opacity-70">Equipment Maintenance</div>
                </div>
              </Button>
            </div>
          </div>
          
          {/* Recipient Selection */}
          <div>
            <label className="text-sm font-medium mb-2 block">Send To</label>
            <select
              className="w-full p-2 border rounded-md"
              value={recipientId || ''}
              onChange={(e) => setRecipientId(parseInt(e.target.value))}
            >
              <option value="">Select recipient...</option>
              {connections?.filter(c => c.status === 'connected').map(conn => (
                <option key={conn.connected_user.id} value={conn.connected_user.id}>
                  {conn.connected_user.rank} {conn.connected_user.name} - {conn.connected_user.unit}
                </option>
              ))}
            </select>
          </div>
          
          {/* Description */}
          <div>
            <label className="text-sm font-medium mb-2 block">
              Description <span className="text-destructive">*</span>
            </label>
            <Textarea
              placeholder="Describe the maintenance needed..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={3}
            />
          </div>
          
          {/* Fault Description */}
          <div>
            <label className="text-sm font-medium mb-2 block">
              Fault/Issue Description (Optional)
            </label>
            <Textarea
              placeholder="Describe any specific faults or issues..."
              value={faultDescription}
              onChange={(e) => setFaultDescription(e.target.value)}
              rows={2}
            />
          </div>
          
          {/* Photo Attachment */}
          <div>
            <label className="text-sm font-medium mb-2 block">Photos (Optional)</label>
            <Button
              type="button"
              variant="outline"
              className="w-full"
              onClick={() => {/* Handle photo upload */}}
            >
              <Camera className="w-4 h-4 mr-2" />
              Add Photos
            </Button>
            {attachments.length > 0 && (
              <div className="mt-2 text-sm text-muted-foreground">
                {attachments.length} photo(s) attached
              </div>
            )}
          </div>
          
          {/* Actions */}
          <div className="flex justify-end gap-2 pt-4">
            <Button variant="outline" onClick={onClose}>
              Cancel
            </Button>
            <Button 
              onClick={handleSend} 
              disabled={!recipientId || !description || sending}
            >
              <Send className="w-4 h-4 mr-2" />
              Send Form
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
};
```

### 2. Documents Inbox Component
```tsx
// web/src/components/documents/DocumentsInbox.tsx
import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { documentService } from '@/services/documentService';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { FileText, User, Calendar, Paperclip } from 'lucide-react';
import { format } from 'date-fns';

export const DocumentsInbox: React.FC = () => {
  const [selectedTab, setSelectedTab] = useState('inbox');
  
  const { data, isLoading } = useQuery({
    queryKey: ['documents', selectedTab],
    queryFn: () => documentService.getDocuments(selectedTab),
  });
  
  const handleViewDocument = async (doc: Document) => {
    if (doc.status === 'unread') {
      await documentService.markAsRead(doc.id);
    }
    // Open document viewer
    openDocumentViewer(doc);
  };
  
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold">Documents</h2>
        <p className="text-muted-foreground">Maintenance forms and other documents</p>
      </div>
      
      <Tabs value={selectedTab} onValueChange={setSelectedTab}>
        <TabsList>
          <TabsTrigger value="inbox">
            Inbox
            {data?.unread_count > 0 && (
              <Badge variant="destructive" className="ml-2">
                {data.unread_count}
              </Badge>
            )}
          </TabsTrigger>
          <TabsTrigger value="sent">Sent</TabsTrigger>
          <TabsTrigger value="all">All Documents</TabsTrigger>
        </TabsList>
        
        <TabsContent value={selectedTab} className="mt-6">
          {isLoading ? (
            <div>Loading...</div>
          ) : data?.documents.length === 0 ? (
            <Card className="p-8 text-center">
              <FileText className="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
              <p className="text-muted-foreground">No documents</p>
            </Card>
          ) : (
            <div className="space-y-4">
              {data?.documents.map((doc) => (
                <Card
                  key={doc.id}
                  className={`p-4 cursor-pointer transition-colors ${
                    doc.status === 'unread' ? 'border-primary' : ''
                  }`}
                  onClick={() => handleViewDocument(doc)}
                >
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-2">
                        {doc.status === 'unread' && (
                          <Badge variant="secondary" className="text-xs">NEW</Badge>
                        )}
                        <Badge variant="outline" className="text-xs">
                          {doc.subtype || doc.type}
                        </Badge>
                      </div>
                      
                      <h3 className="font-medium mb-1">{doc.title}</h3>
                      
                      <div className="flex items-center gap-4 text-sm text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <User className="w-3 h-3" />
                          {selectedTab === 'sent' ? 
                            `To: ${doc.recipient?.rank} ${doc.recipient?.name}` : 
                            `From: ${doc.sender?.rank} ${doc.sender?.name}`
                          }
                        </span>
                        <span className="flex items-center gap-1">
                          <Calendar className="w-3 h-3" />
                          {format(new Date(doc.sent_at), 'MMM d, yyyy')}
                        </span>
                        {doc.attachments && JSON.parse(doc.attachments).length > 0 && (
                          <span className="flex items-center gap-1">
                            <Paperclip className="w-3 h-3" />
                            {JSON.parse(doc.attachments).length}
                          </span>
                        )}
                      </div>
                      
                      {doc.description && (
                        <p className="text-sm text-muted-foreground mt-2 line-clamp-2">
                          {doc.description}
                        </p>
                      )}
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>
      </Tabs>
    </div>
  );
};
```

### 3. Property Book Integration
```tsx
// Add to PropertyBook.tsx or MyProperties component
import { SendMaintenanceForm } from '@/components/property/SendMaintenanceForm';

// In the property actions dropdown or button group:
<DropdownMenuItem onClick={() => openMaintenanceForm(property)}>
  <FileText className="w-4 h-4 mr-2" />
  Send Maintenance Form
</DropdownMenuItem>
```

## iOS Implementation

### 1. Documents Model
```swift
// ios/HandReceipt/Models/Document.swift
struct Document: Codable, Identifiable {
    let id: Int
    let type: String
    let subtype: String?
    let title: String
    let senderUserId: Int
    var sender: User?
    let recipientUserId: Int
    var recipient: User?
    let propertyId: Int?
    var property: Property?
    let formData: [String: Any]
    let description: String?
    let attachments: [String]?
    let status: DocumentStatus
    let sentAt: Date
    var readAt: Date?
    
    enum DocumentStatus: String, Codable {
        case unread = "unread"
        case read = "read"
        case archived = "archived"
    }
}
```

### 2. Send Form View
```swift
// ios/HandReceipt/Views/SendMaintenanceFormView.swift
struct SendMaintenanceFormView: View {
    let property: Property
    @Environment(\.dismiss) private var dismiss
    @State private var selectedForm: FormType = .da2404
    @State private var selectedRecipient: User?
    @State private var description = ""
    @State private var faultDescription = ""
    @State private var selectedPhoto: UIImage?
    @State private var showingPhotoPicker = false
    @StateObject private var connectionService = ConnectionService()
    
    enum FormType: String, CaseIterable {
        case da2404 = "DA2404"
        case da5988e = "DA5988E"
        
        var title: String {
            switch self {
            case .da2404: return "DA Form 2404 - Equipment Inspection"
            case .da5988e: return "DA Form 5988-E - Equipment Maintenance"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Property Info
                    WebAlignedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(property.itemName)
                                .font(AppFonts.headline)
                            Text("SN: \(property.serialNumber)")
                                .font(AppFonts.mono)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .padding()
                    }
                    
                    // Form Type Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FORM TYPE")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        ForEach(FormType.allCases, id: \.self) { form in
                            Button(action: { selectedForm = form }) {
                                HStack {
                                    Image(systemName: "doc.text")
                                    VStack(alignment: .leading) {
                                        Text(form.rawValue)
                                            .font(AppFonts.bodyBold)
                                        Text(form.title)
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.secondaryText)
                                    }
                                    Spacer()
                                    if selectedForm == form {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.accent)
                                    }
                                }
                                .padding()
                                .background(AppColors.secondaryBackground)
                                .overlay(
                                    Rectangle()
                                        .stroke(selectedForm == form ? AppColors.accent : AppColors.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Recipient Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SEND TO")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if let recipient = selectedRecipient {
                            UserCard(user: recipient, showRemove: true) {
                                selectedRecipient = nil
                            }
                        } else {
                            Button(action: { showingConnectionPicker = true }) {
                                HStack {
                                    Image(systemName: "person.badge.plus")
                                    Text("Select Recipient")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(AppColors.secondaryBackground)
                                .overlay(
                                    Rectangle()
                                        .stroke(AppColors.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DESCRIPTION *")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(AppColors.secondaryBackground)
                            .overlay(
                                Rectangle()
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // Fault Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FAULT DESCRIPTION (OPTIONAL)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        TextEditor(text: $faultDescription)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(AppColors.secondaryBackground)
                            .overlay(
                                Rectangle()
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal)
                    
                    // Photo Attachment
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PHOTO (OPTIONAL)")
                            .font(AppFonts.caption)
                            .foregroundColor(AppColors.secondaryText)
                        
                        if let photo = selectedPhoto {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { showingPhotoPicker = true }) {
                            HStack {
                                Image(systemName: "camera")
                                Text(selectedPhoto == nil ? "Add Photo" : "Change Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppColors.secondaryBackground)
                            .overlay(
                                Rectangle()
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(AppColors.appBackground)
            .navigationTitle("Send Maintenance Form")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendForm()
                    }
                    .disabled(!isValid)
                }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(image: $selectedPhoto)
        }
    }
    
    private var isValid: Bool {
        selectedRecipient != nil && !description.isEmpty
    }
    
    private func sendForm() {
        Task {
            do {
                // Upload photo if exists
                var attachments: [String] = []
                if let photo = selectedPhoto {
                    let url = try await uploadPhoto(photo)
                    attachments.append(url)
                }
                
                // Send form
                try await DocumentService.shared.sendMaintenanceForm(
                    propertyId: property.id,
                    recipientUserId: selectedRecipient!.id,
                    formType: selectedForm.rawValue,
                    description: description,
                    faultDescription: faultDescription.isEmpty ? nil : faultDescription,
                    attachments: attachments
                )
                
                showSuccessAlert(
                    message: "Maintenance form sent to \(selectedRecipient!.rank ?? "") \(selectedRecipient!.name)"
                )
                
                dismiss()
            } catch {
                showErrorAlert(error: error)
            }
        }
    }
}
```

### 3. Documents Inbox View
```swift
// ios/HandReceipt/Views/DocumentsView.swift
struct DocumentsView: View {
    @StateObject private var viewModel = DocumentsViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                AppColors.secondaryBackground
                Text("DOCUMENTS")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.primaryText)
                    .kerning(1.2)
            }
            .frame(height: 36)
            
            // Tabs
            Picker("", selection: $selectedTab) {
                Text("Inbox").tag(0)
                Text("Sent").tag(1)
                Text("All").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Document List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.filteredDocuments(for: selectedTab)) { document in
                        DocumentCard(document: document) {
                            viewModel.openDocument(document)
                        }
                    }
                }
                .padding()
            }
            
            if viewModel.documents.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.tertiaryText)
                    Text("No documents")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.secondaryText)
                }
                Spacer()
            }
        }
        .background(AppColors.appBackground)
        .task {
            await viewModel.loadDocuments()
        }
    }
}

struct DocumentCard: View {
    let document: Document
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            WebAlignedCard {
                HStack {
                    // Status indicator
                    if document.status == .unread {
                        Rectangle()
                            .fill(AppColors.accent)
                            .frame(width: 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        // Header
                        HStack {
                            if document.status == .unread {
                                Text("NEW")
                                    .font(AppFonts.caption2)
                                    .foregroundColor(AppColors.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(AppColors.accent.opacity(0.2))
                            }
                            
                            Text(document.subtype ?? document.type)
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                            
                            Spacer()
                            
                            Text(document.sentAt.timeAgo())
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.tertiaryText)
                        }
                        
                        // Title
                        Text(document.title)
                            .font(AppFonts.bodyBold)
                            .foregroundColor(AppColors.primaryText)
                        
                        // Sender/Recipient
                        HStack {
                            Image(systemName: "person")
                                .font(.caption)
                            Text("From: \(document.sender?.rank ?? "") \(document.sender?.name ?? "Unknown")")
                                .font(AppFonts.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        // Description preview
                        if let description = document.description {
                            Text(description)
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.secondaryText)
                                .lineLimit(2)
                        }
                        
                        // Attachments indicator
                        if let attachments = document.attachments, !attachments.isEmpty {
                            HStack {
                                Image(systemName: "paperclip")
                                    .font(.caption)
                                Text("\(attachments.count) attachment(s)")
                                    .font(AppFonts.caption)
                            }
                            .foregroundColor(AppColors.tertiaryText)
                        }
                    }
                    .padding()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
```

## Integration Points

1. **My Properties Page**: Add "Send Maintenance Form" action to each property
2. **Navigation**: Add "Documents" tab/section to main navigation  
3. **Notifications**: Badge on Documents tab shows unread count
4. **ImmuDB Logging**: All document sends are logged for audit trail

## Key Benefits

- **Simple Flow**: Click property → Fill form → Send to connection
- **Auto-population**: Forms pre-filled with property data
- **Flexibility**: Any user can send to any connection
- **Documents Inbox**: Central place for all received forms
- **Photo Support**: Optional photos for visual documentation
- **Audit Trail**: All form sends logged to ImmuDB

This simplified approach focuses on the core value - making it easy to generate and share maintenance forms - without requiring complex role systems or dedicated dashboards.