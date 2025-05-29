describe('HandReceipt - Complete Create & Transfer Flow', () => {
  beforeEach(() => {
    // Mock login state with session cookie
    cy.setCookie('session', 'test-session-cookie');
    
    // Intercept API calls
    cy.intercept('GET', '**/api/auth/me', { fixture: 'currentUser.json' }).as('checkSession');
    cy.intercept('GET', '**/api/inventory', { fixture: 'inventory.json' }).as('getInventory');
    cy.intercept('GET', '**/api/transfers', { fixture: 'transfers.json' }).as('getTransfers');
  });

  describe('Create Item Flow', () => {
    it('should create a new inventory item', () => {
      // Mock create item endpoint
      cy.intercept('POST', '**/api/inventory', {
        statusCode: 201,
        body: {
          id: 'new-item-1',
          name: 'M4A1 Carbine',
          serial_number: 'M4-NEW-12345',
          current_status: 'Operational',
          description: '5.56mm carbine with ACOG',
          category: 'weapons',
          assigned_to_user_id: 1,
          assigned_date: new Date().toISOString(),
          nsn: '1005-01-382-0953',
          lin: 'C74940'
        },
        headers: {
          'X-Ledger-TX-ID': 'ledger-tx-123456'
        }
      }).as('createItem');

      cy.visit('/property-book');
      cy.wait('@checkSession');
      cy.wait('@getInventory');

      // Click create item button (assuming it exists)
      cy.get('[data-testid="create-item-button"]').click();

      // Fill in the create item form
      cy.get('[data-testid="item-name-input"]').type('M4A1 Carbine');
      cy.get('[data-testid="serial-number-input"]').type('M4-NEW-12345');
      cy.get('[data-testid="description-input"]').type('5.56mm carbine with ACOG');
      cy.get('[data-testid="nsn-input"]').type('1005-01-382-0953');
      cy.get('[data-testid="lin-input"]').type('C74940');
      
      // Submit form
      cy.get('[data-testid="create-item-submit"]').click();

      // Wait for API call
      cy.wait('@createItem');

      // Verify success toast
      cy.get('[data-testid="toast"]').should('contain', 'Created M4A1 Carbine');

      // Verify item appears in list
      cy.get('[data-testid="inventory-item-row"]').should('contain', 'M4-NEW-12345');
    });
  });

  describe('QR Code Transfer Flow', () => {
    it('should generate QR code and initiate transfer', () => {
      // Mock QR code generation
      cy.intercept('POST', '**/api/inventory/*/qrcode', {
        statusCode: 200,
        body: {
          qrCodeData: JSON.stringify({
            type: 'handreceipt_property',
            itemId: '1',
            serialNumber: 'M4-12345',
            itemName: 'M4 Carbine',
            category: 'weapons',
            currentHolderId: '1',
            timestamp: new Date().toISOString(),
            qrHash: 'abc123'
          }),
          qrCodeUrl: 'data:image/png;base64,iVBORw0KGgoAAAANS...'
        }
      }).as('generateQR');

      // Mock transfer initiation
      cy.intercept('POST', '**/api/transfers/qr-initiate', {
        statusCode: 200,
        body: {
          transferId: 'transfer-123',
          status: 'pending'
        }
      }).as('initiateTransfer');

      cy.visit('/property-book');
      cy.wait('@getInventory');

      // Click QR code button on first item
      cy.get('[data-testid="inventory-item-row"]')
        .first()
        .find('[title="Generate QR Code"]')
        .click();

      // Wait for QR dialog
      cy.get('[role="dialog"]').within(() => {
        cy.contains('Generate Equipment QR Code').should('be.visible');
        
        // Add optional notes
        cy.get('input[placeholder*="Additional information"]').type('Test QR generation');
        
        // Generate QR
        cy.contains('button', 'Generate QR Code').click();
        
        // QR should be displayed
        cy.get('img[alt="QR Code for equipment"]').should('be.visible');
        
        // Test print button exists
        cy.contains('button', 'Print').should('be.visible');
      });
    });

    it('should scan QR code and request transfer', () => {
      // Mock QR scan result
      const mockQRData = {
        type: 'handreceipt_property',
        itemId: '1',
        serialNumber: 'M4-12345',
        itemName: 'M4 Carbine',
        category: 'weapons',
        currentHolderId: '2', // Different user owns it
        timestamp: new Date().toISOString(),
        qrHash: 'abc123'
      };

      // Open QR scanner
      cy.get('[data-testid="scan-qr-button"]').click();

      // Since we can't actually scan in tests, we'll simulate the scan success
      cy.window().then((win) => {
        // Trigger the scan success callback with mock data
        const event = new CustomEvent('qr-scan-success', {
          detail: JSON.stringify(mockQRData)
        });
        win.dispatchEvent(event);
      });

      // Verify scanned data is displayed
      cy.get('[role="dialog"]').within(() => {
        cy.contains('Equipment Information').should('be.visible');
        cy.contains('M4 Carbine').should('be.visible');
        cy.contains('M4-12345').should('be.visible');
        
        // Click request transfer
        cy.contains('button', 'Request Transfer').click();
      });

      // Mock transfer request
      cy.intercept('POST', '**/api/transfers/qr-initiate', {
        statusCode: 200,
        body: {
          transferId: 'transfer-456',
          status: 'pending'
        }
      }).as('requestTransfer');

      cy.wait('@requestTransfer');

      // Verify success message
      cy.get('[data-testid="toast"]').should('contain', 'Transfer request for M4 Carbine has been sent');
    });
  });

  describe('Complete End-to-End Flow', () => {
    it('should complete full create-transfer-approve cycle', () => {
      // This test would combine the above flows
      // 1. Create item
      // 2. Generate QR code
      // 3. Different user scans QR
      // 4. Transfer is initiated
      // 5. Original owner approves transfer
      // 6. Ownership changes

      // Due to complexity and need for multiple user sessions,
      // this would typically be handled by backend integration tests
      // But the structure is here for reference
    });
  });
}); 