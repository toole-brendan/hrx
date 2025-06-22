# Backend Implementation Guide for QR-Based Transfer Flow

## Overview
This guide outlines the backend endpoints that need to be implemented to support the complete QR-based transfer flow.

## New Endpoints Required

### 1. QR Code Generation
**Endpoint:** `POST /api/inventory/:propertyId/qrcode`

**Purpose:** Generate a QR code for a property item. Only the current holder can generate QR codes.

**Implementation:**
```go
func (h *InventoryHandler) GeneratePropertyQRCode(c *gin.Context) {
    propertyId := c.Param("propertyId")
    userID := getUserIDFromSession(c)
    
    // 1. Verify user is current holder
    property, err := h.repo.GetPropertyByID(propertyId)
    if err != nil || property.AssignedToUserID != userID {
        c.JSON(403, gin.H{"error": "Only current holder can generate QR codes"})
        return
    }
    
    // 2. Create QR data structure
    qrData := map[string]interface{}{
        "type": "handreceipt_property",
        "itemId": property.ID,
        "serialNumber": property.SerialNumber,
        "itemName": property.Name,
        "category": property.Category,
        "currentHolderId": userID,
        "timestamp": time.Now().UTC().Format(time.RFC3339),
    }
    
    // 3. Generate hash for verification
    qrJSON, _ := json.Marshal(qrData)
    hash := sha256.Sum256(qrJSON)
    qrData["qrHash"] = hex.EncodeToString(hash[:])
    
    // 4. Save QR record to database
    qrRecord := domain.QRCode{
        InventoryItemID: property.ID,
        QRCodeData: string(qrJSON),
        QRCodeHash: qrData["qrHash"].(string),
        GeneratedByUserID: userID,
        IsActive: true,
    }
    h.repo.CreateQRCode(&qrRecord)
    
    // 5. Generate actual QR image (base64)
    qrCodeImage, _ := qr.Encode(string(qrJSON), qr.Medium, 256)
    
    c.JSON(200, gin.H{
        "qrCodeData": string(qrJSON),
        "qrCodeUrl": "data:image/png;base64," + base64.StdEncoding.EncodeToString(qrCodeImage),
    })
}
```

### 2. QR-Based Transfer Initiation
**Endpoint:** `POST /api/transfers/qr-initiate`

**Purpose:** Initiate a transfer by scanning a QR code. Creates a transfer request from the scanner to the current holder.

**Request Body:**
```json
{
    "qrData": {
        "type": "handreceipt_property",
        "itemId": "123",
        "serialNumber": "M4-12345",
        "itemName": "M4 Carbine",
        "category": "weapons",
        "currentHolderId": "456",
        "timestamp": "2024-01-01T00:00:00Z",
        "qrHash": "abc123..."
    },
    "scannedAt": "2024-01-01T00:00:00Z"
}
```

**Implementation:**
```go
func (h *TransferHandler) InitiateTransferByQR(c *gin.Context) {
    var req QRTransferRequest
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": "Invalid request"})
        return
    }
    
    scannerUserID := getUserIDFromSession(c)
    
    // 1. Verify QR code hash
    qrDataWithoutHash := copyMapWithoutKey(req.QRData, "qrHash")
    computedHash := computeSHA256(qrDataWithoutHash)
    if computedHash != req.QRData["qrHash"] {
        c.JSON(400, gin.H{"error": "Invalid QR code"})
        return
    }
    
    // 2. Verify property exists and current holder matches
    property, err := h.repo.GetPropertyByID(req.QRData["itemId"].(string))
    if err != nil {
        c.JSON(404, gin.H{"error": "Property not found"})
        return
    }
    
    if property.AssignedToUserID != req.QRData["currentHolderId"] {
        c.JSON(400, gin.H{"error": "QR code is outdated - property holder has changed"})
        return
    }
    
    // 3. Prevent self-transfer
    if scannerUserID == property.AssignedToUserID {
        c.JSON(400, gin.H{"error": "Cannot transfer to yourself"})
        return
    }
    
    // 4. Create transfer request
    transfer := domain.Transfer{
        PropertyID: property.ID,
        FromUserID: property.AssignedToUserID,
        ToUserID: scannerUserID,
        Status: "pending",
        Notes: fmt.Sprintf("Transfer initiated via QR scan at %s", req.ScannedAt),
    }
    
    if err := h.repo.CreateTransfer(&transfer); err != nil {
        c.JSON(500, gin.H{"error": "Failed to create transfer"})
        return
    }
    
    // 5. Log to Azure SQL ledger table
    h.ledger.LogTransferEvent(transfer, property.SerialNumber)
    
    // 6. Send notification to current holder
    // TODO: Implement push notification or email
    
    c.JSON(200, gin.H{
        "transferId": transfer.ID,
        "status": "pending",
    })
}
```

### 3. Update Transfer Handler for Approval
The existing `PATCH /api/transfers/:id/status` endpoint needs to be updated to handle the QR-based transfers properly:

```go
func (h *TransferHandler) UpdateTransferStatus(c *gin.Context) {
    transferID := c.Param("id")
    userID := getUserIDFromSession(c)
    
    var req struct {
        Status string `json:"status" binding:"required,oneof=Approved Rejected"`
        Reason string `json:"reason"`
    }
    
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(400, gin.H{"error": "Invalid request"})
        return
    }
    
    // Get transfer
    transfer, err := h.repo.GetTransferByID(transferID)
    if err != nil {
        c.JSON(404, gin.H{"error": "Transfer not found"})
        return
    }
    
    // Only the FROM user can approve/reject
    if transfer.FromUserID != userID {
        c.JSON(403, gin.H{"error": "Only the current holder can approve/reject transfers"})
        return
    }
    
    // Update transfer status
    transfer.Status = req.Status
    if req.Status == "Rejected" {
        transfer.Notes = transfer.Notes + " | Rejection reason: " + req.Reason
    }
    
    if err := h.repo.UpdateTransfer(&transfer); err != nil {
        c.JSON(500, gin.H{"error": "Failed to update transfer"})
        return
    }
    
    // If approved, update property ownership
    if req.Status == "Approved" {
        property, _ := h.repo.GetPropertyByID(transfer.PropertyID)
        property.AssignedToUserID = transfer.ToUserID
        h.repo.UpdateProperty(&property)
        
        // Deactivate old QR codes for this property
        h.repo.DeactivateQRCodesForProperty(property.ID)
    }
    
    // Log to Azure SQL ledger table
    h.ledger.LogTransferEvent(transfer, property.SerialNumber)
    
    c.JSON(200, transfer)
}
```

## Database Schema Updates

Add the following to your PostgreSQL schema:

```sql
-- QR Codes table
CREATE TABLE qr_codes (
    id SERIAL PRIMARY KEY,
    inventory_item_id INTEGER REFERENCES inventory_items(id) NOT NULL,
    qr_code_data TEXT NOT NULL,
    qr_code_hash VARCHAR(64) UNIQUE NOT NULL,
    generated_by_user_id INTEGER REFERENCES users(id) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    deactivated_at TIMESTAMP
);

-- Index for faster lookups
CREATE INDEX idx_qr_codes_item_active ON qr_codes(inventory_item_id, is_active);
CREATE INDEX idx_qr_codes_hash ON qr_codes(qr_code_hash);
```

## Security Considerations

1. **QR Code Expiry**: Consider adding expiry timestamps to QR codes
2. **Rate Limiting**: Limit QR generation to prevent abuse
3. **Audit Trail**: All QR generations should be logged
4. **Hash Verification**: Always verify QR code integrity before processing
5. **Permission Checks**: Strictly enforce that only current holders can generate QR codes

## Testing

1. **Unit Tests**: Test each handler function with mock repositories
2. **Integration Tests**: Test the complete flow with a test database
3. **Security Tests**: Test unauthorized access attempts
4. **Performance Tests**: Test with large numbers of QR codes

## Future Enhancements

1. **Bulk QR Generation**: Generate QR codes for multiple items at once
2. **QR Code Templates**: Customizable QR code designs for printing
3. **Mobile Push Notifications**: Real-time transfer notifications
4. **QR Code Analytics**: Track scan patterns and usage
5. **Offline QR Verification**: Allow basic verification without network 