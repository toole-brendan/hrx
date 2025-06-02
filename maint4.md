SAMPLE CODE FOR DOCUMENTS INBOX

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HandReceipt - Documents Inbox</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            background-color: #0a0a0a;
            color: #ffffff;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #1a1a1a 0%, #2a2a2a 100%);
            border: 1px solid #333;
            padding: 24px;
            margin-bottom: 24px;
            position: relative;
            overflow: hidden;
        }
        
        .header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, #0088ff 0%, #0066cc 100%);
        }
        
        .header h1 {
            font-size: 20px;
            font-weight: 600;
            letter-spacing: 1.5px;
            text-transform: uppercase;
            color: #ffffff;
            margin-bottom: 8px;
        }
        
        .header p {
            color: #888;
            font-size: 14px;
        }
        
        .tabs {
            display: flex;
            gap: 2px;
            background: #0a0a0a;
            padding: 2px;
            margin-bottom: 24px;
            border: 1px solid #333;
        }
        
        .tab {
            flex: 1;
            padding: 12px 24px;
            background: #1a1a1a;
            color: #888;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 14px;
            font-weight: 500;
            text-align: center;
            position: relative;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
        }
        
        .tab.active {
            background: #2a2a2a;
            color: #ffffff;
        }
        
        .tab.active::after {
            content: '';
            position: absolute;
            bottom: 0;
            left: 0;
            right: 0;
            height: 2px;
            background: #0088ff;
        }
        
        .badge {
            display: inline-block;
            background: #ff0000;
            color: #ffffff;
            padding: 2px 8px;
            border-radius: 12px;
            font-size: 11px;
            font-weight: 700;
            min-width: 20px;
            text-align: center;
        }
        
        .document-list {
            display: flex;
            flex-direction: column;
            gap: 16px;
        }
        
        .document-card {
            background: #1a1a1a;
            border: 1px solid #333;
            padding: 0;
            transition: all 0.3s ease;
            cursor: pointer;
            overflow: hidden;
        }
        
        .document-card:hover {
            border-color: #666;
            transform: translateY(-2px);
        }
        
        .document-card.unread {
            border-left: 4px solid #00ff00;
        }
        
        .document-content {
            padding: 20px;
        }
        
        .document-header {
            display: flex;
            justify-content: space-between;
            align-items: start;
            margin-bottom: 12px;
        }
        
        .document-badges {
            display: flex;
            gap: 8px;
            margin-bottom: 8px;
        }
        
        .document-badge {
            padding: 4px 12px;
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 1px;
            background: #333;
            color: #888;
        }
        
        .document-badge.new {
            background: rgba(0, 255, 0, 0.2);
            color: #00ff00;
            border: 1px solid #00ff00;
        }
        
        .document-badge.form-type {
            background: #0a0a0a;
            border: 1px solid #333;
            color: #ccc;
        }
        
        .document-time {
            font-size: 12px;
            color: #666;
            font-family: 'Courier New', monospace;
        }
        
        .document-title {
            font-size: 16px;
            font-weight: 600;
            color: #ffffff;
            margin-bottom: 8px;
        }
        
        .document-meta {
            display: flex;
            gap: 20px;
            font-size: 13px;
            color: #888;
            margin-bottom: 12px;
        }
        
        .document-meta-item {
            display: flex;
            align-items: center;
            gap: 6px;
        }
        
        .document-meta-item .icon {
            font-size: 14px;
            color: #666;
        }
        
        .document-description {
            font-size: 14px;
            color: #ccc;
            line-height: 1.6;
            margin-bottom: 12px;
        }
        
        .document-attachments {
            display: flex;
            align-items: center;
            gap: 6px;
            font-size: 12px;
            color: #666;
        }
        
        .property-preview {
            background: #0a0a0a;
            border: 1px solid #333;
            padding: 12px;
            margin-top: 12px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .property-info {
            font-size: 13px;
        }
        
        .property-name {
            color: #00ff00;
            font-weight: 600;
            margin-bottom: 4px;
        }
        
        .property-details {
            color: #666;
            font-family: 'Courier New', monospace;
            font-size: 12px;
        }
        
        .action-button {
            padding: 8px 16px;
            background: transparent;
            border: 1px solid #0088ff;
            color: #0088ff;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .action-button:hover {
            background: #0088ff;
            color: #ffffff;
        }
        
        .empty-state {
            text-align: center;
            padding: 80px 20px;
        }
        
        .empty-icon {
            font-size: 64px;
            color: #333;
            margin-bottom: 20px;
        }
        
        .empty-title {
            font-size: 18px;
            font-weight: 600;
            color: #666;
            margin-bottom: 8px;
        }
        
        .empty-text {
            font-size: 14px;
            color: #666;
        }
        
        /* Document Viewer Modal */
        .modal-overlay {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(0, 0, 0, 0.8);
            display: none;
            align-items: center;
            justify-content: center;
            z-index: 1000;
            padding: 20px;
        }
        
        .modal-content {
            background: #1a1a1a;
            border: 1px solid #333;
            max-width: 800px;
            width: 100%;
            max-height: 90vh;
            overflow-y: auto;
            position: relative;
        }
        
        .modal-header {
            background: #2a2a2a;
            padding: 20px;
            border-bottom: 1px solid #333;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .modal-title {
            font-size: 16px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
        }
        
        .close-button {
            background: none;
            border: none;
            color: #666;
            font-size: 24px;
            cursor: pointer;
            padding: 0;
            width: 32px;
            height: 32px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .close-button:hover {
            color: #fff;
        }
        
        .form-viewer {
            padding: 24px;
        }
        
        .form-section {
            margin-bottom: 24px;
        }
        
        .form-section-title {
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #888;
            margin-bottom: 12px;
        }
        
        .form-field {
            display: flex;
            padding: 12px 0;
            border-bottom: 1px solid #2a2a2a;
        }
        
        .form-label {
            flex: 0 0 200px;
            font-size: 13px;
            color: #666;
        }
        
        .form-value {
            flex: 1;
            font-size: 14px;
            color: #ccc;
            font-weight: 500;
        }
        
        .attachment-preview {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
            gap: 12px;
            margin-top: 12px;
        }
        
        .attachment-image {
            aspect-ratio: 1;
            background: #333;
            border-radius: 4px;
            overflow: hidden;
            cursor: pointer;
        }
        
        .attachment-image img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        @media (max-width: 768px) {
            .tabs {
                flex-direction: column;
            }
            
            .document-meta {
                flex-direction: column;
                gap: 8px;
            }
            
            .form-field {
                flex-direction: column;
            }
            
            .form-label {
                margin-bottom: 4px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>Documents</h1>
            <p>Maintenance forms and other documents from your connections</p>
        </div>
        
        <!-- Tabs -->
        <div class="tabs">
            <div class="tab active" onclick="switchTab('inbox')">
                Inbox
                <span class="badge">2</span>
            </div>
            <div class="tab" onclick="switchTab('sent')">
                Sent
            </div>
            <div class="tab" onclick="switchTab('all')">
                All Documents
            </div>
        </div>
        
        <!-- Document List -->
        <div class="document-list" id="inbox-content">
            <!-- Unread Document 1 -->
            <div class="document-card unread" onclick="openDocument(1)">
                <div class="document-content">
                    <div class="document-header">
                        <div>
                            <div class="document-badges">
                                <span class="document-badge new">NEW</span>
                                <span class="document-badge form-type">DA FORM 2404</span>
                            </div>
                        </div>
                        <div class="document-time">10 MIN AGO</div>
                    </div>
                    
                    <div class="document-title">DA2404 Maintenance Request - M4A1 Carbine</div>
                    
                    <div class="document-meta">
                        <div class="document-meta-item">
                            <span class="icon">👤</span>
                            <span>From: SPC Johnson, Bravo Company</span>
                        </div>
                        <div class="document-meta-item">
                            <span class="icon">📎</span>
                            <span>2 attachments</span>
                        </div>
                    </div>
                    
                    <div class="document-description">
                        Weapon experiencing failure to extract during qualification. Extractor spring appears weak. Request immediate inspection and repair to maintain readiness for upcoming deployment training.
                    </div>
                    
                    <div class="property-preview">
                        <div class="property-info">
                            <div class="property-name">M4A1 Carbine</div>
                            <div class="property-details">SN: M4-789012 | NSN: 1005-01-231-0973</div>
                        </div>
                        <button class="action-button">VIEW FORM</button>
                    </div>
                </div>
            </div>
            
            <!-- Unread Document 2 -->
            <div class="document-card unread" onclick="openDocument(2)">
                <div class="document-content">
                    <div class="document-header">
                        <div>
                            <div class="document-badges">
                                <span class="document-badge new">NEW</span>
                                <span class="document-badge form-type">DA FORM 5988-E</span>
                            </div>
                        </div>
                        <div class="document-time">2 HOURS AGO</div>
                    </div>
                    
                    <div class="document-title">DA5988-E Maintenance Request - AN/PRC-152 Radio</div>
                    
                    <div class="document-meta">
                        <div class="document-meta-item">
                            <span class="icon">👤</span>
                            <span>From: SSG Martinez, HQ Company</span>
                        </div>
                        <div class="document-meta-item">
                            <span class="icon">📎</span>
                            <span>1 attachment</span>
                        </div>
                    </div>
                    
                    <div class="document-description">
                        Radio display intermittently blanking out during operations. Possible loose internal connection. Unit is primary comms for platoon leader.
                    </div>
                    
                    <div class="property-preview">
                        <div class="property-info">
                            <div class="property-name">AN/PRC-152 Multiband Radio</div>
                            <div class="property-details">SN: PRC152-4567 | NSN: 5820-01-492-5922</div>
                        </div>
                        <button class="action-button">VIEW FORM</button>
                    </div>
                </div>
            </div>
            
            <!-- Read Document -->
            <div class="document-card" onclick="openDocument(3)">
                <div class="document-content">
                    <div class="document-header">
                        <div>
                            <div class="document-badges">
                                <span class="document-badge form-type">DA FORM 2404</span>
                            </div>
                        </div>
                        <div class="document-time">YESTERDAY</div>
                    </div>
                    
                    <div class="document-title">DA2404 Maintenance Request - ACOG TA31F</div>
                    
                    <div class="document-meta">
                        <div class="document-meta-item">
                            <span class="icon">👤</span>
                            <span>From: CPL Davis, Alpha Company</span>
                        </div>
                    </div>
                    
                    <div class="document-description">
                        Reticle illumination not functioning. Tritium appears depleted. Requesting replacement or service.
                    </div>
                    
                    <div class="property-preview">
                        <div class="property-info">
                            <div class="property-name">ACOG TA31F Rifle Scope</div>
                            <div class="property-details">SN: ACOG-123456 | NSN: 1240-01-412-6608</div>
                        </div>
                        <button class="action-button">VIEW FORM</button>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Sent Tab Content (Hidden) -->
        <div class="document-list" id="sent-content" style="display: none;">
            <div class="document-card" onclick="openDocument(4)">
                <div class="document-content">
                    <div class="document-header">
                        <div>
                            <div class="document-badges">
                                <span class="document-badge form-type">DA FORM 5988-E</span>
                            </div>
                        </div>
                        <div class="document-time">3 DAYS AGO</div>
                    </div>
                    
                    <div class="document-title">DA5988-E Maintenance Request - M240B Machine Gun</div>
                    
                    <div class="document-meta">
                        <div class="document-meta-item">
                            <span class="icon">👤</span>
                            <span>To: SGT Williams, Motor Pool</span>
                        </div>
                        <div class="document-meta-item">
                            <span class="icon">✓</span>
                            <span>Read</span>
                        </div>
                    </div>
                    
                    <div class="document-description">
                        Barrel showing excessive wear after range qualification. Requesting gauging and possible replacement.
                    </div>
                </div>
            </div>
        </div>
        
        <!-- All Tab Content (Hidden) -->
        <div class="document-list" id="all-content" style="display: none;">
            <div class="empty-state">
                <div class="empty-icon">📄</div>
                <div class="empty-title">All Documents</div>
                <div class="empty-text">View all sent and received documents here</div>
            </div>
        </div>
    </div>
    
    <!-- Document Viewer Modal -->
    <div class="modal-overlay" id="documentModal" onclick="closeModal(event)">
        <div class="modal-content" onclick="event.stopPropagation()">
            <div class="modal-header">
                <h2 class="modal-title">DA FORM 2404 - EQUIPMENT INSPECTION</h2>
                <button class="close-button" onclick="closeDocument()">×</button>
            </div>
            
            <div class="form-viewer">
                <!-- Equipment Information -->
                <div class="form-section">
                    <h3 class="form-section-title">Equipment Information</h3>
                    <div class="form-field">
                        <div class="form-label">Equipment Name</div>
                        <div class="form-value">M4A1 Carbine</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">Serial Number</div>
                        <div class="form-value">M4-789012</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">NSN</div>
                        <div class="form-value">1005-01-231-0973</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">Location</div>
                        <div class="form-value">Arms Room, Building 4501</div>
                    </div>
                </div>
                
                <!-- Request Information -->
                <div class="form-section">
                    <h3 class="form-section-title">Request Information</h3>
                    <div class="form-field">
                        <div class="form-label">Submitted By</div>
                        <div class="form-value">SPC Johnson, Michael A.</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">Unit</div>
                        <div class="form-value">B Co, 1-23 IN</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">Date/Time</div>
                        <div class="form-value">02 JUN 2025 0830</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">Deficiency Class</div>
                        <div class="form-value">X - Deadline (Safety)</div>
                    </div>
                </div>
                
                <!-- Maintenance Details -->
                <div class="form-section">
                    <h3 class="form-section-title">Maintenance Details</h3>
                    <div class="form-field">
                        <div class="form-label">Description</div>
                        <div class="form-value">Weapon experiencing failure to extract during qualification. Extractor spring appears weak. Request immediate inspection and repair to maintain readiness for upcoming deployment training.</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">Fault Description</div>
                        <div class="form-value">During Table VI qualification, weapon failed to extract spent casing on 3 separate occasions. Manual extraction required. Extractor visually appears to have reduced spring tension.</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">Last Service</div>
                        <div class="form-value">15 MAY 2025 - Routine cleaning and inspection</div>
                    </div>
                    <div class="form-field">
                        <div class="form-label">Rounds Fired</div>
                        <div class="form-value">Approx. 3,500 rounds</div>
                    </div>
                </div>
                
                <!-- Attachments -->
                <div class="form-section">
                    <h3 class="form-section-title">Attachments</h3>
                    <div class="attachment-preview">
                        <div class="attachment-image">
                            <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='150' height='150'%3E%3Crect width='150' height='150' fill='%23333'/%3E%3Ctext x='75' y='75' text-anchor='middle' dy='.3em' fill='%23888' font-family='sans-serif' font-size='12'%3EExtractor%3C/text%3E%3C/svg%3E" alt="Extractor" />
                        </div>
                        <div class="attachment-image">
                            <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='150' height='150'%3E%3Crect width='150' height='150' fill='%23333'/%3E%3Ctext x='75' y='75' text-anchor='middle' dy='.3em' fill='%23888' font-family='sans-serif' font-size='12'%3EChamber%3C/text%3E%3C/svg%3E" alt="Chamber" />
                        </div>
                    </div>
                </div>
                
                <!-- Actions -->
                <div class="form-section" style="display: flex; gap: 12px; justify-content: flex-end; padding-top: 20px; border-top: 1px solid #333;">
                    <button class="action-button" onclick="printForm()">PRINT FORM</button>
                    <button class="action-button" onclick="forwardForm()">FORWARD</button>
                    <button class="action-button" style="background: #00ff00; color: #000; border-color: #00ff00;">MARK AS READ</button>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        function switchTab(tab) {
            // Hide all content
            document.getElementById('inbox-content').style.display = 'none';
            document.getElementById('sent-content').style.display = 'none';
            document.getElementById('all-content').style.display = 'none';
            
            // Remove active class from all tabs
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            
            // Show selected content and mark tab as active
            if (tab === 'inbox') {
                document.getElementById('inbox-content').style.display = 'flex';
                document.querySelectorAll('.tab')[0].classList.add('active');
            } else if (tab === 'sent') {
                document.getElementById('sent-content').style.display = 'flex';
                document.querySelectorAll('.tab')[1].classList.add('active');
            } else if (tab === 'all') {
                document.getElementById('all-content').style.display = 'flex';
                document.querySelectorAll('.tab')[2].classList.add('active');
            }
        }
        
        function openDocument(id) {
            document.getElementById('documentModal').style.display = 'flex';
            
            // Mark as read (remove unread class)
            event.currentTarget.classList.remove('unread');
            
            // Update badge count
            const badge = document.querySelector('.badge');
            if (badge) {
                const count = parseInt(badge.textContent) - 1;
                if (count > 0) {
                    badge.textContent = count;
                } else {
                    badge.style.display = 'none';
                }
            }
        }
        
        function closeDocument() {
            document.getElementById('documentModal').style.display = 'none';
        }
        
        function closeModal(event) {
            if (event.target === event.currentTarget) {
                closeDocument();
            }
        }
        
        function printForm() {
            window.print();
        }
        
        function forwardForm() {
            alert('Forward form to another connection');
        }
    </script>
</body>
</html>