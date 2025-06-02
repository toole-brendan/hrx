SAMPLE CODE FOR additional parts to my properties page

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HandReceipt - Send Maintenance Form</title>
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
        
        /* Property Book View */
        .property-book {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .page-header {
            background: linear-gradient(135deg, #1a1a1a 0%, #2a2a2a 100%);
            border: 1px solid #333;
            padding: 24px;
            margin-bottom: 24px;
            position: relative;
        }
        
        .page-header::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, #00ff00 0%, #00cc00 100%);
        }
        
        .page-header h1 {
            font-size: 20px;
            font-weight: 600;
            letter-spacing: 1.5px;
            text-transform: uppercase;
            color: #ffffff;
        }
        
        .property-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        
        .property-card {
            background: #1a1a1a;
            border: 1px solid #333;
            padding: 20px;
            position: relative;
            transition: all 0.3s ease;
        }
        
        .property-card:hover {
            border-color: #666;
        }
        
        .property-name {
            font-size: 16px;
            font-weight: 600;
            color: #00ff00;
            margin-bottom: 8px;
        }
        
        .property-details {
            font-size: 13px;
            color: #888;
            margin-bottom: 12px;
            font-family: 'Courier New', monospace;
        }
        
        .property-actions {
            display: flex;
            gap: 8px;
        }
        
        .action-btn {
            padding: 6px 12px;
            font-size: 12px;
            background: transparent;
            border: 1px solid #333;
            color: #888;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .action-btn:hover {
            border-color: #666;
            color: #ccc;
        }
        
        /* Maintenance Form Modal */
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
        
        .modal-overlay.active {
            display: flex;
        }
        
        .modal {
            background: #1a1a1a;
            border: 1px solid #333;
            max-width: 600px;
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
        
        .close-btn {
            background: none;
            border: none;
            color: #666;
            font-size: 24px;
            cursor: pointer;
            padding: 0;
            width: 32px;
            height: 32px;
        }
        
        .close-btn:hover {
            color: #fff;
        }
        
        .modal-body {
            padding: 24px;
        }
        
        .form-section {
            margin-bottom: 24px;
        }
        
        .form-section h3 {
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #888;
            margin-bottom: 12px;
        }
        
        .property-preview {
            background: #0a0a0a;
            border: 1px solid #333;
            padding: 16px;
            margin-bottom: 24px;
        }
        
        .property-preview .name {
            font-weight: 600;
            color: #00ff00;
            margin-bottom: 4px;
        }
        
        .property-preview .details {
            font-size: 12px;
            color: #666;
            font-family: 'Courier New', monospace;
        }
        
        .form-tabs {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 12px;
            margin-bottom: 24px;
        }
        
        .form-tab {
            padding: 16px;
            background: #0a0a0a;
            border: 2px solid #333;
            cursor: pointer;
            transition: all 0.3s ease;
            text-align: center;
        }
        
        .form-tab.active {
            border-color: #00ff00;
            background: #1a1a1a;
        }
        
        .form-tab-title {
            font-weight: 600;
            margin-bottom: 4px;
        }
        
        .form-tab-desc {
            font-size: 11px;
            color: #666;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-label {
            display: block;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #888;
            margin-bottom: 8px;
        }
        
        .form-control {
            width: 100%;
            padding: 12px;
            background: #0a0a0a;
            border: 1px solid #333;
            color: #fff;
            font-size: 14px;
            transition: all 0.3s ease;
        }
        
        .form-control:focus {
            outline: none;
            border-color: #00ff00;
        }
        
        textarea.form-control {
            resize: vertical;
            min-height: 100px;
        }
        
        .recipient-select {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px;
            background: #0a0a0a;
            border: 1px solid #333;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .recipient-select:hover {
            border-color: #666;
        }
        
        .recipient-avatar {
            width: 40px;
            height: 40px;
            background: #333;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 600;
            color: #00ff00;
        }
        
        .recipient-info {
            flex: 1;
        }
        
        .recipient-name {
            font-weight: 500;
            margin-bottom: 2px;
        }
        
        .recipient-unit {
            font-size: 12px;
            color: #666;
        }
        
        .photo-upload {
            border: 2px dashed #333;
            padding: 32px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .photo-upload:hover {
            border-color: #666;
            background: rgba(255, 255, 255, 0.02);
        }
        
        .photo-icon {
            font-size: 32px;
            margin-bottom: 8px;
            opacity: 0.5;
        }
        
        .photo-text {
            font-size: 14px;
            color: #666;
        }
        
        .form-actions {
            display: flex;
            gap: 12px;
            margin-top: 32px;
            padding-top: 24px;
            border-top: 1px solid #333;
        }
        
        .btn {
            padding: 12px 24px;
            font-size: 14px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            border: 2px solid;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .btn-cancel {
            background: transparent;
            border-color: #666;
            color: #888;
        }
        
        .btn-cancel:hover {
            border-color: #888;
            color: #aaa;
        }
        
        .btn-send {
            background: #00ff00;
            border-color: #00ff00;
            color: #000;
        }
        
        .btn-send:hover {
            background: #00cc00;
            border-color: #00cc00;
        }
        
        /* Success animation */
        .success-message {
            position: fixed;
            top: 20px;
            right: 20px;
            background: #00ff00;
            color: #000;
            padding: 16px 24px;
            font-weight: 600;
            display: none;
            animation: slideIn 0.3s ease;
            box-shadow: 0 4px 12px rgba(0, 255, 0, 0.3);
        }
        
        .success-message.show {
            display: block;
        }
        
        @keyframes slideIn {
            from {
                transform: translateX(100%);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }
        
        /* Connection List */
        .connection-list {
            display: none;
            position: absolute;
            top: 100%;
            left: 0;
            right: 0;
            background: #1a1a1a;
            border: 1px solid #333;
            border-top: none;
            max-height: 300px;
            overflow-y: auto;
            z-index: 10;
        }
        
        .connection-list.show {
            display: block;
        }
        
        .connection-item {
            padding: 12px;
            display: flex;
            align-items: center;
            gap: 12px;
            cursor: pointer;
            transition: background 0.2s ease;
        }
        
        .connection-item:hover {
            background: #2a2a2a;
        }
        
        .connection-avatar {
            width: 32px;
            height: 32px;
            background: #333;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
            font-weight: 600;
            color: #00ff00;
        }
    </style>
</head>
<body>
    <!-- Property Book View -->
    <div class="property-book">
        <div class="page-header">
            <h1>My Properties</h1>
        </div>
        
        <div class="property-grid">
            <div class="property-card">
                <div class="property-name">M4A1 Carbine</div>
                <div class="property-details">
                    SN: M4-789012<br>
                    NSN: 1005-01-231-0973<br>
                    Location: Arms Room, B-4501
                </div>
                <div class="property-actions">
                    <button class="action-btn" onclick="openMaintenanceForm()">📝 Send Maintenance Form</button>
                    <button class="action-btn">🔄 Transfer</button>
                    <button class="action-btn">📷 View</button>
                </div>
            </div>
            
            <div class="property-card">
                <div class="property-name">AN/PRC-152 Radio</div>
                <div class="property-details">
                    SN: PRC152-4567<br>
                    NSN: 5820-01-492-5922<br>
                    Location: Comms Cage
                </div>
                <div class="property-actions">
                    <button class="action-btn">📝 Send Maintenance Form</button>
                    <button class="action-btn">🔄 Transfer</button>
                    <button class="action-btn">📷 View</button>
                </div>
            </div>
            
            <div class="property-card">
                <div class="property-name">ACOG TA31F</div>
                <div class="property-details">
                    SN: ACOG-123456<br>
                    NSN: 1240-01-412-6608<br>
                    Location: Arms Room, B-4501
                </div>
                <div class="property-actions">
                    <button class="action-btn">📝 Send Maintenance Form</button>
                    <button class="action-btn">🔄 Transfer</button>
                    <button class="action-btn">📷 View</button>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Maintenance Form Modal -->
    <div class="modal-overlay" id="maintenanceModal">
        <div class="modal">
            <div class="modal-header">
                <h2 class="modal-title">Send Maintenance Form</h2>
                <button class="close-btn" onclick="closeModal()">×</button>
            </div>
            
            <div class="modal-body">
                <!-- Property Preview -->
                <div class="property-preview">
                    <div class="name">M4A1 Carbine</div>
                    <div class="details">SN: M4-789012 | NSN: 1005-01-231-0973</div>
                </div>
                
                <!-- Form Type Selection -->
                <div class="form-section">
                    <h3>Select Form Type</h3>
                    <div class="form-tabs">
                        <div class="form-tab active" onclick="selectFormType('DA2404')">
                            <div class="form-tab-title">DA Form 2404</div>
                            <div class="form-tab-desc">Equipment Inspection</div>
                        </div>
                        <div class="form-tab" onclick="selectFormType('DA5988E')">
                            <div class="form-tab-title">DA Form 5988-E</div>
                            <div class="form-tab-desc">Equipment Maintenance</div>
                        </div>
                    </div>
                </div>
                
                <!-- Recipient Selection -->
                <div class="form-group" style="position: relative;">
                    <label class="form-label">Send To</label>
                    <div class="recipient-select" onclick="toggleConnectionList()">
                        <div class="recipient-avatar">SW</div>
                        <div class="recipient-info">
                            <div class="recipient-name">SGT Williams</div>
                            <div class="recipient-unit">Motor Pool - 1st Battalion Maintenance</div>
                        </div>
                        <div style="color: #666;">▼</div>
                    </div>
                    
                    <!-- Connection Dropdown -->
                    <div class="connection-list" id="connectionList">
                        <div class="connection-item" onclick="selectConnection('SGT Williams', 'Motor Pool - 1st Battalion Maintenance', 'SW')">
                            <div class="connection-avatar">SW</div>
                            <div>
                                <div style="font-weight: 500;">SGT Williams</div>
                                <div style="font-size: 12px; color: #666;">Motor Pool - 1st Battalion Maintenance</div>
                            </div>
                        </div>
                        <div class="connection-item" onclick="selectConnection('SSG Martinez', 'Supply NCO - HQ Company', 'SM')">
                            <div class="connection-avatar">SM</div>
                            <div>
                                <div style="font-weight: 500;">SSG Martinez</div>
                                <div style="font-size: 12px; color: #666;">Supply NCO - HQ Company</div>
                            </div>
                        </div>
                        <div class="connection-item" onclick="selectConnection('SFC Thompson', 'Armorer - Brigade Support', 'ST')">
                            <div class="connection-avatar">ST</div>
                            <div>
                                <div style="font-weight: 500;">SFC Thompson</div>
                                <div style="font-size: 12px; color: #666;">Armorer - Brigade Support</div>
                            </div>
                        </div>
                        <div class="connection-item" onclick="selectConnection('CW2 Davis', 'Maintenance Tech - Division', 'CD')">
                            <div class="connection-avatar">CD</div>
                            <div>
                                <div style="font-weight: 500;">CW2 Davis</div>
                                <div style="font-size: 12px; color: #666;">Maintenance Tech - Division</div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Description -->
                <div class="form-group">
                    <label class="form-label">Description <span style="color: #ff0000;">*</span></label>
                    <textarea class="form-control" placeholder="Describe the maintenance needed...">Weapon experiencing failure to extract during qualification. Extractor spring appears weak. Request immediate inspection and repair to maintain readiness for upcoming deployment training.</textarea>
                </div>
                
                <!-- Fault Description -->
                <div class="form-group">
                    <label class="form-label">Fault Description (Optional)</label>
                    <textarea class="form-control" placeholder="Describe any specific faults or issues...">During Table VI qualification, weapon failed to extract spent casing on 3 separate occasions. Manual extraction required.</textarea>
                </div>
                
                <!-- Photo Upload -->
                <div class="form-group">
                    <label class="form-label">Photos (Optional)</label>
                    <div class="photo-upload" onclick="uploadPhotos()">
                        <div class="photo-icon">📷</div>
                        <div class="photo-text">Click to add photos</div>
                    </div>
                </div>
                
                <!-- Actions -->
                <div class="form-actions">
                    <button class="btn btn-cancel" onclick="closeModal()">Cancel</button>
                    <button class="btn btn-send" onclick="sendForm()">Send Form</button>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Success Message -->
    <div class="success-message" id="successMessage">
        Maintenance form sent to SGT Williams
    </div>
    
    <script>
        let selectedRecipient = {
            name: 'SGT Williams',
            unit: 'Motor Pool - 1st Battalion Maintenance',
            initials: 'SW'
        };
        
        function openMaintenanceForm() {
            document.getElementById('maintenanceModal').classList.add('active');
        }
        
        function closeModal() {
            document.getElementById('maintenanceModal').classList.remove('active');
            document.getElementById('connectionList').classList.remove('show');
        }
        
        function selectFormType(type) {
            document.querySelectorAll('.form-tab').forEach(tab => {
                tab.classList.remove('active');
            });
            event.target.closest('.form-tab').classList.add('active');
        }
        
        function toggleConnectionList() {
            document.getElementById('connectionList').classList.toggle('show');
        }
        
        function selectConnection(name, unit, initials) {
            selectedRecipient = { name, unit, initials };
            
            // Update display
            document.querySelector('.recipient-avatar').textContent = initials;
            document.querySelector('.recipient-name').textContent = name;
            document.querySelector('.recipient-unit').textContent = unit;
            
            // Close dropdown
            document.getElementById('connectionList').classList.remove('show');
        }
        
        function uploadPhotos() {
            console.log('Upload photos');
        }
        
        function sendForm() {
            // Close modal
            closeModal();
            
            // Show success message
            const successMsg = document.getElementById('successMessage');
            successMsg.textContent = `Maintenance form sent to ${selectedRecipient.name}`;
            successMsg.classList.add('show');
            
            // Hide after 3 seconds
            setTimeout(() => {
                successMsg.classList.remove('show');
            }, 3000);
        }
        
        // Close dropdown when clicking outside
        document.addEventListener('click', function(event) {
            const connectionList = document.getElementById('connectionList');
            const recipientSelect = document.querySelector('.recipient-select');
            
            if (!recipientSelect.contains(event.target) && !connectionList.contains(event.target)) {
                connectionList.classList.remove('show');
            }
        });
    </script>
</body>
</html>