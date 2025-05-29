describe('HandReceipt - Complete Create & Transfer Flow', () => {
  beforeEach(() => {
    // Mock login state with session cookie
    cy.setCookie('session', 'test-session-cookie');
    
    // Intercept API calls
    cy.intercept('GET', '**/api/auth/me', { 
      statusCode: 200,
      body: {
        id: 1,
        username: 'testuser',
        name: 'CPT Rodriguez, Michael',
        rank: 'CPT'
      }
    }).as('checkSession');
    
    cy.intercept('GET', '**/api/inventory', { 
      statusCode: 200,
      body: {
        items: [
          {
            id: 1,
            name: 'M4 Carbine',
            serial_number: 'M4-12345',
            current_status: 'Operational',
            assigned_to_user_id: 1,
            category: 'weapons'
          }
        ]
      }
    }).as('getInventory');
    
    cy.intercept('GET', '**/api/transfers', { 
      statusCode: 200,
      body: {
        transfers: []
      }
    }).as('getTransfers');
  });

  describe('Create Item Flow', () => {
    it('should create a new inventory item with unique serial number', () => {
      // Mock create item endpoint
      cy.intercept('POST', '**/api/inventory', {
        statusCode: 201,
        body: {
          id: 2,
          name: 'M4A1 Carbine',
          serial_number: 'M4-NEW-12345',
          current_status: 'Operational',
          description: '5.56mm carbine with ACOG',
          category: 'weapons',
          assigned_to_user_id: 1,
          assigned_date: new Date().toISOString(),
          nsn: '1005-01-382-0953',
          lin: 'C74940'
        }
      }).as('createItem');

      cy.visit('/property-book');
      cy.wait('@checkSession');
      cy.wait('@getInventory');

      // Click create item button
      cy.contains('button', 'CREATE ITEM').click();

      // Fill in the create item form
      cy.get('input[id="serial-number"]').type('M4-NEW-12345');
      cy.get('input[id="item-name"]').type('M4A1 Carbine');
      cy.get('button[id="category"]').click();
      cy.get('[role="option"]').contains('Weapons').click();
      cy.get('input[id="nsn"]').type('1005-01-382-0953');
      cy.get('input[id="lin"]').type('C74940');
      cy.get('textarea[id="description"]').type('5.56mm carbine with ACOG');
      cy.get('input[id="assign-to-self"]').check();
      
      // Submit form
      cy.contains('button', 'Create Digital Twin').click();

      // Wait for API call
      cy.wait('@createItem');

      // Verify success toast
      cy.contains('Digital Twin Created').should('be.visible');
      cy.contains('M4A1 Carbine (SN: M4-NEW-12345) has been registered successfully').should('be.visible');
    });

    it('should prevent duplicate serial numbers', () => {
      // Mock API to return duplicate error
      cy.intercept('POST', '**/api/inventory', {
        statusCode: 400,
        body: {
          error: "A digital twin with serial number 'M4-12345' already exists"
        }
      }).as('createDuplicate');

      cy.visit('/property-book');
      cy.wait('@getInventory');

      // Click create item button
      cy.contains('button', 'CREATE ITEM').click();

      // Try to create item with existing serial number
      cy.get('input[id="serial-number"]').type('M4-12345');
      cy.get('input[id="item-name"]').type('Another M4');
      cy.get('button[id="category"]').click();
      cy.get('[role="option"]').contains('Weapons').click();
      
      // Submit form
      cy.contains('button', 'Create Digital Twin').click();

      // Wait for API call
      cy.wait('@createDuplicate');

      // Verify error toast
      cy.contains('Duplicate Serial Number').should('be.visible');
      cy.contains('An item with serial number M4-12345 already exists').should('be.visible');
    });
  });

  describe('Transfer Flow', () => {
    it('should create a transfer request', () => {
      // Mock create transfer endpoint
      cy.intercept('POST', '**/api/transfers', {
        statusCode: 200,
        body: {
          id: 1,
          property_id: 1,
          from_user_id: 1,
          to_user_id: 2,
          status: 'Requested',
          request_date: new Date().toISOString()
        }
      }).as('createTransfer');

      cy.visit('/property-book');
      cy.wait('@getInventory');

      // Click transfer button on first item
      cy.get('table tbody tr').first().within(() => {
        cy.get('button[title="Transfer Equipment"]').click();
      });

      // Fill transfer form
      cy.get('[role="dialog"]').within(() => {
        cy.contains('Transfer Request').should('be.visible');
        
        // Select recipient
        cy.get('button').contains('Select recipient').click();
      });
      cy.get('[role="option"]').contains('SGT James Wilson').click();
      
      cy.get('[role="dialog"]').within(() => {
        // Add reason
        cy.get('textarea[id="reason"]').type('Transferring to new squad leader');
        
        // Select urgency
        cy.get('button').contains('Normal').click();
      });
      cy.get('[role="option"]').contains('High - Required soon').click();

      // Submit transfer
      cy.get('[role="dialog"]').within(() => {
        cy.contains('button', 'Submit Request').click();
      });

      // Wait for API call
      cy.wait('@createTransfer');

      // Verify success
      cy.contains('Transfer Request Submitted').should('be.visible');
    });
  });

  describe('QR Code Transfer Flow', () => {
    it('should generate QR code for current holder', () => {
      // Mock QR code generation
      cy.intercept('POST', '**/api/inventory/qrcode/*', {
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
            qrHash: 'abc123def456'
          }),
          qrCodeUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='
        }
      }).as('generateQR');

      cy.visit('/property-book');
      cy.wait('@getInventory');

      // Click QR code button on first item
      cy.get('table tbody tr').first().within(() => {
        cy.get('button[title="Generate QR Code"]').click();
      });

      // Wait for QR generation
      cy.wait('@generateQR');

      // Verify QR code is displayed in some UI element
      // This depends on how the QR code is displayed in your app
    });

    it('should initiate transfer via QR scan', () => {
      // Mock QR scan initiation
      cy.intercept('POST', '**/api/transfers/qr-initiate', {
        statusCode: 200,
        body: {
          transferId: 'transfer-123',
          status: 'Requested'
        }
      }).as('initiateQRTransfer');

      cy.visit('/transfers');
      cy.wait('@getTransfers');

      // Click scan QR button
      cy.contains('button', 'SCAN QR').click();

      // Since we can't actually scan in tests, we'll need to mock the scan result
      // This would depend on your QR scanner implementation
      
      // For now, just verify the scanner modal opens
      cy.get('[role="dialog"]').within(() => {
        cy.contains('Scan QR Code').should('be.visible');
        cy.contains('Position the QR code within the scanning area').should('be.visible');
      });
    });
  });

  describe('Transfer Approval Flow', () => {
    it('should approve incoming transfer', () => {
      // Mock transfers with pending transfer
      cy.intercept('GET', '**/api/transfers', {
        statusCode: 200,
        body: {
          transfers: [{
            id: 1,
            property: {
              id: 1,
              name: 'M4 Carbine',
              serial_number: 'M4-12345'
            },
            from_user: {
              id: 2,
              name: 'SGT Smith, John'
            },
            to_user: {
              id: 1,
              name: 'CPT Rodriguez, Michael'
            },
            status: 'Requested',
            request_date: new Date().toISOString()
          }]
        }
      }).as('getTransfersWithPending');

      // Mock approve transfer
      cy.intercept('PATCH', '**/api/transfers/*/status', {
        statusCode: 200,
        body: {
          id: 1,
          status: 'Approved',
          resolved_date: new Date().toISOString()
        }
      }).as('approveTransfer');

      cy.visit('/transfers');
      cy.wait('@getTransfersWithPending');

      // Find pending transfer and approve
      cy.contains('M4 Carbine').parents('tr').within(() => {
        cy.contains('button', 'Approve').click();
      });

      // Confirm in dialog
      cy.get('[role="alertdialog"]').within(() => {
        cy.contains('Approve Transfer').should('be.visible');
        cy.contains('button', 'Approve').click();
      });

      // Wait for API call
      cy.wait('@approveTransfer');

      // Verify success
      cy.contains('Transfer Approved').should('be.visible');
    });
  });
}); 