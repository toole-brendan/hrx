describe('QR-Based Transfer Flow', () => {
  beforeEach(() => {
    // Login as test user
    cy.visit('/login');
    cy.get('input[name="username"]').type('testuser1');
    cy.get('input[name="password"]').type('password123');
    cy.get('button[type="submit"]').click();
    cy.url().should('include', '/property-book');
  });

  describe('QR Code Generation', () => {
    it('should generate QR code for owned property', () => {
      // Navigate to property details
      cy.get('[data-testid="property-list"]')
        .find('[data-testid="property-item"]')
        .first()
        .click();

      // Click generate QR code button
      cy.get('[data-testid="generate-qr-btn"]').click();

      // Verify QR code is displayed
      cy.get('[data-testid="qr-code-display"]').should('be.visible');
      cy.get('[data-testid="qr-code-data"]').should('contain', 'handreceipt_property');
      
      // Verify print button is available
      cy.get('[data-testid="print-qr-btn"]').should('be.visible');
    });

    it('should not allow QR generation for non-owned property', () => {
      // Navigate to transfers page to find property owned by others
      cy.visit('/transfers');
      
      // Try to access property not owned by current user
      cy.get('[data-testid="transfer-item"]')
        .contains('From: Other User')
        .parents('[data-testid="transfer-item"]')
        .find('[data-testid="view-property-btn"]')
        .click();

      // Generate QR button should not exist or be disabled
      cy.get('[data-testid="generate-qr-btn"]').should('not.exist');
    });

    it('should generate QR code from QR Management page', () => {
      // Navigate to QR Management
      cy.visit('/qr-management');

      // Click generate new QR code
      cy.get('[data-testid="generate-new-qr-btn"]').click();

      // Fill in item details
      cy.get('[data-testid="new-item-name"]').type('Test Equipment');
      cy.get('[data-testid="new-serial-number"]').type('TEST-12345');

      // Generate QR code
      cy.get('[data-testid="generate-qr-code-btn"]').click();

      // Verify success message
      cy.get('[data-testid="toast"]').should('contain', 'QR Code Generated');

      // Verify QR code appears in list
      cy.get('[data-testid="qr-code-list"]')
        .should('contain', 'Test Equipment')
        .and('contain', 'TEST-12345');
    });
  });

  describe('QR-Based Transfer Initiation', () => {
    it('should initiate transfer by scanning QR code', () => {
      // Mock QR data for testing
      const mockQRData = {
        type: 'handreceipt_property',
        itemId: '123',
        serialNumber: 'M4-12345',
        itemName: 'M4 Carbine',
        category: 'weapons',
        currentHolderId: '456',
        timestamp: new Date().toISOString(),
        qrHash: 'abc123def456'
      };

      // Navigate to transfers page
      cy.visit('/transfers');

      // Click scan QR code button
      cy.get('[data-testid="scan-qr-btn"]').click();

      // Verify scanner dialog opens
      cy.get('[data-testid="qr-scanner-dialog"]').should('be.visible');

      // Since we can't actually scan, we'll trigger the file upload
      // In real implementation, you'd mock the QR scanning library
      cy.get('input[type="file"]').selectFile({
        contents: Cypress.Buffer.from(JSON.stringify(mockQRData)),
        fileName: 'qr-code.json',
        mimeType: 'application/json',
      }, { force: true });

      // Confirm transfer dialog should appear
      cy.get('[data-testid="confirm-transfer-dialog"]').should('be.visible');
      cy.get('[data-testid="transfer-item-name"]').should('contain', 'M4 Carbine');
      cy.get('[data-testid="transfer-serial-number"]').should('contain', 'M4-12345');

      // Confirm transfer
      cy.get('[data-testid="confirm-transfer-btn"]').click();

      // Verify success message
      cy.get('[data-testid="toast"]').should('contain', 'Transfer request created');

      // Verify transfer appears in list
      cy.get('[data-testid="transfer-list"]')
        .should('contain', 'M4 Carbine')
        .and('contain', 'Pending');
    });

    it('should prevent self-transfer', () => {
      // Mock QR data with current user as holder
      const mockQRData = {
        type: 'handreceipt_property',
        itemId: '123',
        serialNumber: 'M4-12345',
        itemName: 'M4 Carbine',
        category: 'weapons',
        currentHolderId: '1', // Same as logged-in user
        timestamp: new Date().toISOString(),
        qrHash: 'abc123def456'
      };

      cy.visit('/transfers');
      cy.get('[data-testid="scan-qr-btn"]').click();

      // Attempt to scan own QR code
      cy.get('input[type="file"]').selectFile({
        contents: Cypress.Buffer.from(JSON.stringify(mockQRData)),
        fileName: 'qr-code.json',
        mimeType: 'application/json',
      }, { force: true });

      // Should show error
      cy.get('[data-testid="toast"]')
        .should('contain', 'Cannot transfer to yourself');
    });

    it('should handle invalid QR code format', () => {
      // Mock invalid QR data
      const invalidQRData = {
        type: 'invalid_type',
        someData: 'invalid'
      };

      cy.visit('/transfers');
      cy.get('[data-testid="scan-qr-btn"]').click();

      cy.get('input[type="file"]').selectFile({
        contents: Cypress.Buffer.from(JSON.stringify(invalidQRData)),
        fileName: 'invalid-qr.json',
        mimeType: 'application/json',
      }, { force: true });

      // Should show error
      cy.get('[data-testid="toast"]')
        .should('contain', 'Invalid QR code format');
    });
  });

  describe('Transfer Approval/Rejection', () => {
    it('should allow property holder to approve transfer', () => {
      // Navigate to incoming transfers
      cy.visit('/transfers');
      cy.get('[data-testid="tab-incoming"]').click();
      
      // Find pending transfer where current user is the holder
      cy.get('[data-testid="transfer-list"]')
        .find('[data-testid="transfer-status"]')
        .contains('Pending')
        .parents('[data-testid="transfer-item"]')
        .as('pendingTransfer');

      // Click approve button
      cy.get('@pendingTransfer')
        .find('[data-testid="approve-transfer-btn"]')
        .click();

      // Confirm in dialog
      cy.get('[data-testid="confirm-dialog"]').should('be.visible');
      cy.get('[data-testid="confirm-approve-btn"]').click();

      // Verify status change
      cy.get('@pendingTransfer')
        .find('[data-testid="transfer-status"]')
        .should('contain', 'Approved');

      // Verify property is no longer in user's inventory
      cy.visit('/property-book');
      cy.get('[data-testid="property-list"]')
        .should('not.contain', 'M4-12345');
    });

    it('should allow property holder to reject transfer', () => {
      cy.visit('/transfers');
      cy.get('[data-testid="tab-incoming"]').click();
      
      // Find pending transfer
      cy.get('[data-testid="transfer-list"]')
        .find('[data-testid="transfer-status"]')
        .contains('Pending')
        .parents('[data-testid="transfer-item"]')
        .as('pendingTransfer');

      // Click reject button
      cy.get('@pendingTransfer')
        .find('[data-testid="reject-transfer-btn"]')
        .click();

      // Enter rejection reason
      cy.get('[data-testid="rejection-reason"]')
        .type('Item is currently in use for training');
      
      cy.get('[data-testid="confirm-reject-btn"]').click();

      // Verify status change
      cy.get('@pendingTransfer')
        .find('[data-testid="transfer-status"]')
        .should('contain', 'Rejected');

      // Verify property remains in user's inventory
      cy.visit('/property-book');
      cy.get('[data-testid="property-list"]')
        .should('contain', 'M4-12345');
    });

    it('should show transfer history after completion', () => {
      // Complete a transfer and check history
      cy.visit('/transfers');
      cy.get('[data-testid="tab-history"]').click();

      // Verify completed transfers appear
      cy.get('[data-testid="transfer-list"]')
        .find('[data-testid="transfer-status"]')
        .should('contain.oneOf', ['Approved', 'Rejected']);

      // Click on a completed transfer to view details
      cy.get('[data-testid="transfer-item"]')
        .first()
        .click();

      // Verify transfer details modal
      cy.get('[data-testid="transfer-details-modal"]').should('be.visible');
      cy.get('[data-testid="transfer-timeline"]').should('be.visible');
    });
  });

  describe('QR Code Security', () => {
    it('should reject tampered QR codes', () => {
      // Mock QR data with invalid hash
      const tamperedQRData = {
        type: 'handreceipt_property',
        itemId: '123',
        serialNumber: 'M4-99999', // Changed serial number
        itemName: 'M4 Carbine',
        category: 'weapons',
        currentHolderId: '456',
        timestamp: new Date().toISOString(),
        qrHash: 'abc123def456' // Hash doesn't match modified data
      };

      cy.visit('/transfers');
      cy.get('[data-testid="scan-qr-btn"]').click();

      cy.get('input[type="file"]').selectFile({
        contents: Cypress.Buffer.from(JSON.stringify(tamperedQRData)),
        fileName: 'qr-code.json',
        mimeType: 'application/json',
      }, { force: true });

      // Should show error about invalid QR code
      cy.get('[data-testid="toast"]')
        .should('contain', 'Invalid QR code');
    });

    it('should reject outdated QR codes', () => {
      // Mock QR data where holder has changed
      const outdatedQRData = {
        type: 'handreceipt_property',
        itemId: '123',
        serialNumber: 'M4-12345',
        itemName: 'M4 Carbine',
        category: 'weapons',
        currentHolderId: '999', // Different from actual current holder
        timestamp: new Date(Date.now() - 86400000).toISOString(), // Yesterday
        qrHash: 'validhash'
      };

      cy.visit('/transfers');
      cy.get('[data-testid="scan-qr-btn"]').click();

      cy.get('input[type="file"]').selectFile({
        contents: Cypress.Buffer.from(JSON.stringify(outdatedQRData)),
        fileName: 'qr-code.json',
        mimeType: 'application/json',
      }, { force: true });

      // Should show error about outdated QR code
      cy.get('[data-testid="toast"]')
        .should('contain', 'QR code is outdated - property holder has changed');
    });

    it('should validate QR code hash integrity', () => {
      // Test with proper hash validation
      const validQRData = {
        type: 'handreceipt_property',
        itemId: '123',
        serialNumber: 'M4-12345',
        itemName: 'M4 Carbine',
        category: 'weapons',
        currentHolderId: '456',
        timestamp: new Date().toISOString()
      };

      // Calculate proper hash for the data
      const dataString = JSON.stringify(validQRData);
      const expectedHash = 'proper_calculated_hash'; // In real test, use actual hash calculation

      const qrDataWithHash = {
        ...validQRData,
        qrHash: expectedHash
      };

      cy.visit('/transfers');
      cy.get('[data-testid="scan-qr-btn"]').click();

      cy.get('input[type="file"]').selectFile({
        contents: Cypress.Buffer.from(JSON.stringify(qrDataWithHash)),
        fileName: 'valid-qr.json',
        mimeType: 'application/json',
      }, { force: true });

      // Should proceed to confirmation dialog
      cy.get('[data-testid="confirm-transfer-dialog"]').should('be.visible');
    });
  });

  describe('QR Management Features', () => {
    it('should report damaged QR codes', () => {
      cy.visit('/qr-management');

      // Find an active QR code
      cy.get('[data-testid="qr-code-item"]')
        .contains('Active')
        .parents('[data-testid="qr-code-item"]')
        .as('activeQRCode');

      // Click report damaged button
      cy.get('@activeQRCode')
        .find('[data-testid="report-damaged-btn"]')
        .click();

      // Enter damage reason
      cy.get('[data-testid="damage-reason"]')
        .type('QR code is scratched and unreadable');

      // Confirm report
      cy.get('[data-testid="confirm-report-btn"]').click();

      // Verify status change
      cy.get('@activeQRCode')
        .find('[data-testid="qr-status"]')
        .should('contain', 'Damaged');

      // Verify success message
      cy.get('[data-testid="toast"]')
        .should('contain', 'QR code reported as damaged');
    });

    it('should batch replace damaged QR codes', () => {
      cy.visit('/qr-management');

      // Navigate to damaged tab
      cy.get('[data-testid="tab-damaged"]').click();

      // Verify damaged QR codes are listed
      cy.get('[data-testid="qr-code-list"]')
        .find('[data-testid="qr-status"]')
        .should('contain', 'Damaged');

      // Click batch replace button
      cy.get('[data-testid="batch-replace-btn"]').click();

      // Confirm batch replacement
      cy.get('[data-testid="confirm-batch-replace"]').click();

      // Verify success message
      cy.get('[data-testid="toast"]')
        .should('contain', 'QR codes have been replaced successfully');

      // Verify replaced QR codes no longer show as damaged
      cy.get('[data-testid="tab-damaged"]').click();
      cy.get('[data-testid="empty-state"]')
        .should('contain', 'No damaged QR codes');
    });

    it('should print QR codes', () => {
      cy.visit('/qr-management');

      // Find QR code to print
      cy.get('[data-testid="qr-code-item"]')
        .first()
        .as('qrCode');

      // Click print button
      cy.get('@qrCode')
        .find('[data-testid="print-qr-btn"]')
        .click();

      // Verify print dialog opens
      cy.get('[data-testid="print-dialog"]').should('be.visible');

      // Verify QR code preview
      cy.get('[data-testid="qr-preview"]').should('be.visible');

      // Click print button (this would open browser print dialog)
      cy.get('[data-testid="confirm-print-btn"]').click();

      // Verify success message
      cy.get('[data-testid="toast"]')
        .should('contain', 'QR code has been prepared for printing');
    });
  });

  describe('Integration with Property Book', () => {
    it('should link QR codes to property items', () => {
      // Navigate to property book
      cy.visit('/property-book');

      // Click on a property item
      cy.get('[data-testid="property-item"]')
        .first()
        .click();

      // Verify QR code section is visible
      cy.get('[data-testid="property-qr-section"]').should('be.visible');

      // If QR code exists, verify it's displayed
      cy.get('[data-testid="property-qr-code"]').should('be.visible');

      // If no QR code, should show generate button
      cy.get('[data-testid="generate-qr-btn"]').should('be.visible');
    });

    it('should show QR code status in property details', () => {
      cy.visit('/property-book');

      // Click on property with QR code
      cy.get('[data-testid="property-item"]')
        .contains('[data-testid="qr-indicator"]')
        .parents('[data-testid="property-item"]')
        .click();

      // Verify QR code status is displayed
      cy.get('[data-testid="qr-status-badge"]')
        .should('be.visible')
        .and('contain.oneOf', ['Active', 'Damaged', 'Missing']);
    });
  });
}); 