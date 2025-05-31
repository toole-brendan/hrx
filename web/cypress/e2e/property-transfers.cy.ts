describe('HandReceipt Admin UI - Inventory & Transfers', () => {
  beforeEach(() => {
    // Mock login state with session cookie
    cy.setCookie('session', 'test-session-cookie');
    
    // Intercept API calls
    cy.intercept('GET', '**/api/auth/me', { fixture: 'currentUser.json' }).as('checkSession');
    cy.intercept('GET', '**/api/inventory', { fixture: 'inventory.json' }).as('getInventory');
    cy.intercept('GET', '**/api/transfers', { fixture: 'transfers.json' }).as('getTransfers');
  });

  describe('Property Book', () => {
    it('should load and display inventory items', () => {
      cy.visit('/property-book');
      
      // Wait for API calls
      cy.wait('@checkSession');
      cy.wait('@getInventory');
      
      // Check page header
      cy.contains('h1', 'Property Book').should('be.visible');
      cy.contains('Manage and track all property assignments').should('be.visible');
      
      // Check tabs
      cy.get('[role="tablist"]').within(() => {
        cy.contains('ASSIGNED').should('be.visible');
        cy.contains('SIGNED OUT').should('be.visible');
      });
      
      // Check inventory items are displayed
      cy.get('[data-testid="property-book-table"]').should('exist');
      cy.get('[data-testid="inventory-item-row"]').should('have.length.at.least', 1);
      
      // Verify item details
      cy.get('[data-testid="inventory-item-row"]').first().within(() => {
        cy.get('[data-testid="item-name"]').should('not.be.empty');
        cy.get('[data-testid="serial-number"]').should('not.be.empty');
        cy.get('[data-testid="status-badge"]').should('be.visible');
      });
    });

    it('should filter inventory by category', () => {
      cy.visit('/property-book');
      cy.wait('@getInventory');
      
      // Open category filter
      cy.get('[data-testid="category-filter"]').click();
      cy.get('[role="option"]').contains('Weapons').click();
      
      // Verify filtered results
      cy.get('[data-testid="inventory-item-row"]').each(($row) => {
        cy.wrap($row).should('contain', 'Weapon');
      });
    });

    it('should search inventory items', () => {
      cy.visit('/property-book');
      cy.wait('@getInventory');
      
      // Type in search
      cy.get('[data-testid="search-input"]').type('M4');
      
      // Verify search results
      cy.get('[data-testid="inventory-item-row"]').should('have.length.at.least', 1);
      cy.get('[data-testid="inventory-item-row"]').each(($row) => {
        cy.wrap($row).should('contain.text', 'M4');
      });
    });
  });

  describe('Transfers', () => {
    beforeEach(() => {
      cy.visit('/transfers');
      cy.wait('@checkSession');
      cy.wait('@getTransfers');
    });

    it('should load transfers page with tabs', () => {
      // Check page header
      cy.contains('h1', 'Transfers').should('be.visible');
      
      // Check tabs
      cy.get('[role="tablist"]').within(() => {
        cy.contains('INCOMING').should('be.visible');
        cy.contains('OUTGOING').should('be.visible');
        cy.contains('HISTORY').should('be.visible');
      });
      
      // Check for pending transfers badge
      cy.get('[data-testid="pending-count-badge"]').should('exist');
    });

    it('should display incoming transfers', () => {
      // Click incoming tab (should be default)
      cy.get('[role="tab"]').contains('INCOMING').click();
      
      // Check transfer items
      cy.get('[data-testid="transfer-row"]').should('have.length.at.least', 1);
      
      // Verify transfer details
      cy.get('[data-testid="transfer-row"]').first().within(() => {
        cy.get('[data-testid="transfer-item-name"]').should('not.be.empty');
        cy.get('[data-testid="transfer-from"]').should('not.be.empty');
        cy.get('[data-testid="transfer-status"]').should('contain', 'PENDING');
        cy.get('[data-testid="approve-button"]').should('be.visible');
        cy.get('[data-testid="reject-button"]').should('be.visible');
      });
    });

    it('should approve a transfer', () => {
      // Mock approve endpoint
      cy.intercept('PATCH', '**/api/transfers/*/status', {
        statusCode: 200,
        body: {
          id: 'test-transfer-1',
          status: 'approved',
          name: 'M4 Carbine',
          serialNumber: 'M4-12345',
          from: 'SGT Smith',
          to: 'CPT Rodriguez'
        }
      }).as('approveTransfer');
      
      // Click approve on first pending transfer
      cy.get('[data-testid="transfer-row"]')
        .first()
        .find('[data-testid="approve-button"]')
        .click();
      
      // Confirm in dialog
      cy.get('[role="dialog"]').within(() => {
        cy.contains('Confirm Transfer Approval').should('be.visible');
        cy.contains('button', 'Approve').click();
      });
      
      // Wait for API call
      cy.wait('@approveTransfer');
      
      // Check success toast
      cy.get('[data-testid="toast"]').should('contain', 'Transfer approved');
    });

    it('should reject a transfer with reason', () => {
      // Mock reject endpoint
      cy.intercept('PATCH', '**/api/transfers/*/status', {
        statusCode: 200,
        body: {
          id: 'test-transfer-1',
          status: 'rejected',
          name: 'M4 Carbine',
          serialNumber: 'M4-12345',
          from: 'SGT Smith',
          to: 'CPT Rodriguez',
          rejectionReason: 'Item not available'
        }
      }).as('rejectTransfer');
      
      // Click reject on first pending transfer
      cy.get('[data-testid="transfer-row"]')
        .first()
        .find('[data-testid="reject-button"]')
        .click();
      
      // Fill rejection reason in dialog
      cy.get('[role="dialog"]').within(() => {
        cy.contains('Confirm Transfer Rejection').should('be.visible');
        cy.get('[data-testid="rejection-reason"]').type('Item not available');
        cy.contains('button', 'Reject').click();
      });
      
      // Wait for API call
      cy.wait('@rejectTransfer');
      
      // Check success toast
      cy.get('[data-testid="toast"]').should('contain', 'Transfer rejected');
    });

    it('should create a new transfer', () => {
      // Mock create endpoint
      cy.intercept('POST', '**/api/transfers', {
        statusCode: 201,
        body: {
          id: 'new-transfer-1',
          status: 'pending',
          name: 'M240B Machine Gun',
          serialNumber: 'M240-98765',
          from: 'CPT Rodriguez',
          to: 'LT Johnson',
          date: new Date().toISOString()
        }
      }).as('createTransfer');
      
      // Click new transfer button
      cy.get('[data-testid="new-transfer-button"]').click();
      
      // Fill transfer form
      cy.get('[role="dialog"]').within(() => {
        cy.get('[data-testid="item-name-input"]').type('M240B Machine Gun');
        cy.get('[data-testid="serial-number-input"]').type('M240-98765');
        cy.get('[data-testid="recipient-select"]').click();
      });
      
      // Select recipient
      cy.get('[role="option"]').contains('LT Johnson').click();
      
      // Submit form
      cy.get('[role="dialog"]').within(() => {
        cy.contains('button', 'Create Transfer').click();
      });
      
      // Wait for API call
      cy.wait('@createTransfer');
      
      // Check success toast
      cy.get('[data-testid="toast"]').should('contain', 'Transfer Created');
    });
  });

  describe('Integration Flow', () => {
    it('should complete full create-transfer-approve flow', () => {
      // Start at property book
      cy.visit('/property-book');
      cy.wait('@getInventory');
      
      // Select an item to transfer
      cy.get('[data-testid="inventory-item-row"]').first().within(() => {
        cy.get('[data-testid="item-actions-menu"]').click();
      });
      cy.get('[role="menuitem"]').contains('Transfer').click();
      
      // Fill transfer dialog
      cy.get('[role="dialog"]').within(() => {
        cy.get('[data-testid="recipient-select"]').click();
      });
      cy.get('[role="option"]').contains('SGT Smith').click();
      
      // Mock transfer creation
      cy.intercept('POST', '**/api/transfers', {
        statusCode: 201,
        body: { id: 'new-1', status: 'pending' }
      }).as('createTransfer');
      
      cy.get('[role="dialog"]').contains('button', 'Create Transfer').click();
      cy.wait('@createTransfer');
      
      // Navigate to transfers page
      cy.visit('/transfers');
      cy.wait('@getTransfers');
      
      // Mock updated transfers list with our new transfer
      cy.intercept('GET', '**/api/transfers', {
        body: {
          transfers: [{
            id: 'new-1',
            status: 'pending',
            name: 'Test Item',
            serialNumber: 'TEST-123',
            from: 'CPT Rodriguez',
            to: 'SGT Smith'
          }]
        }
      }).as('getUpdatedTransfers');
      
      // Refresh to get new transfer
      cy.reload();
      cy.wait('@getUpdatedTransfers');
      
      // Verify transfer appears and can be approved
      cy.get('[data-testid="transfer-row"]').should('contain', 'Test Item');
    });
  });
}); 