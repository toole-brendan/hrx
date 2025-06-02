SAMPLE CODE FOR FORM


<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HandReceipt - Maintenance Request Form</title>
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
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        
        .header {
            background: linear-gradient(135deg, #1a1a1a 0%, #2a2a2a 100%);
            border: 1px solid #333;
            padding: 20px;
            margin-bottom: 24px;
            border-radius: 0;
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
            background: linear-gradient(90deg, #00ff00 0%, #00cc00 100%);
        }
        
        .header h1 {
            font-size: 18px;
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
        
        .property-info {
            background: #1a1a1a;
            border: 1px solid #333;
            padding: 20px;
            margin-bottom: 24px;
        }
        
        .property-info h3 {
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1.2px;
            color: #888;
            margin-bottom: 12px;
        }
        
        .property-details {
            display: grid;
            gap: 8px;
        }
        
        .property-details p {
            font-size: 14px;
            color: #ccc;
        }
        
        .property-details strong {
            color: #00ff00;
            font-family: 'Courier New', monospace;
        }
        
        .form-section {
            background: #1a1a1a;
            border: 1px solid #333;
            padding: 24px;
            margin-bottom: 24px;
        }
        
        .form-tabs {
            display: flex;
            gap: 12px;
            margin-bottom: 24px;
        }
        
        .form-tab {
            flex: 1;
            padding: 12px 20px;
            background: #0a0a0a;
            border: 2px solid #333;
            color: #888;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 14px;
            font-weight: 500;
            text-align: center;
            position: relative;
        }
        
        .form-tab.active {
            background: #1a1a1a;
            border-color: #00ff00;
            color: #00ff00;
        }
        
        .form-tab.active::after {
            content: '';
            position: absolute;
            bottom: -2px;
            left: 0;
            right: 0;
            height: 2px;
            background: #00ff00;
        }
        
        .form-group {
            margin-bottom: 20px;
        }
        
        .form-group label {
            display: block;
            font-size: 12px;
            text-transform: uppercase;
            letter-spacing: 1px;
            color: #888;
            margin-bottom: 8px;
        }
        
        .form-control {
            width: 100%;
            padding: 12px 16px;
            background: #0a0a0a;
            border: 1px solid #333;
            color: #ffffff;
            font-size: 14px;
            transition: all 0.3s ease;
        }
        
        .form-control:focus {
            outline: none;
            border-color: #00ff00;
            box-shadow: 0 0 0 2px rgba(0, 255, 0, 0.1);
        }
        
        .form-control::placeholder {
            color: #666;
        }
        
        select.form-control {
            cursor: pointer;
        }
        
        textarea.form-control {
            resize: vertical;
            min-height: 100px;
        }
        
        .user-select {
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 12px 16px;
            background: #0a0a0a;
            border: 1px solid #333;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .user-select:hover {
            border-color: #00ff00;
        }
        
        .user-avatar {
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
        
        .user-info {
            flex: 1;
        }
        
        .user-name {
            font-size: 14px;
            font-weight: 500;
            color: #ffffff;
        }
        
        .user-unit {
            font-size: 12px;
            color: #888;
        }
        
        .priority-grid {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 12px;
        }
        
        .priority-option {
            padding: 12px;
            background: #0a0a0a;
            border: 2px solid #333;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s ease;
            font-size: 12px;
            text-transform: uppercase;
        }
        
        .priority-option.routine { border-color: #666; }
        .priority-option.priority { border-color: #0088ff; }
        .priority-option.urgent { border-color: #ff8800; }
        .priority-option.emergency { border-color: #ff0000; }
        
        .priority-option.active {
            background: #1a1a1a;
        }
        
        .priority-option.routine.active { 
            border-color: #666;
            color: #ccc;
        }
        .priority-option.priority.active { 
            border-color: #0088ff;
            color: #0088ff;
        }
        .priority-option.urgent.active { 
            border-color: #ff8800;
            color: #ff8800;
        }
        .priority-option.emergency.active { 
            border-color: #ff0000;
            color: #ff0000;
        }
        
        .photo-upload {
            border: 2px dashed #333;
            padding: 40px;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s ease;
            position: relative;
        }
        
        .photo-upload:hover {
            border-color: #00ff00;
            background: rgba(0, 255, 0, 0.05);
        }
        
        .photo-icon {
            font-size: 48px;
            color: #666;
            margin-bottom: 12px;
        }
        
        .photo-text {
            color: #888;
            font-size: 14px;
        }
        
        .photo-preview {
            display: grid;
            grid-template-columns: repeat(4, 1fr);
            gap: 12px;
            margin-top: 20px;
        }
        
        .photo-thumb {
            aspect-ratio: 1;
            background: #333;
            border-radius: 4px;
            position: relative;
            overflow: hidden;
        }
        
        .photo-thumb img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        .actions {
            display: flex;
            gap: 12px;
            margin-top: 32px;
        }
        
        .btn {
            padding: 14px 28px;
            font-size: 14px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            border: 2px solid;
            cursor: pointer;
            transition: all 0.3s ease;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .btn-primary {
            background: #00ff00;
            border-color: #00ff00;
            color: #000000;
        }
        
        .btn-primary:hover {
            background: #00cc00;
            border-color: #00cc00;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0, 255, 0, 0.3);
        }
        
        .btn-secondary {
            background: transparent;
            border-color: #666;
            color: #888;
        }
        
        .btn-secondary:hover {
            border-color: #888;
            color: #aaa;
        }
        
        .success-message {
            position: fixed;
            top: 20px;
            right: 20px;
            background: #00ff00;
            color: #000000;
            padding: 16px 24px;
            font-weight: 600;
            display: none;
            animation: slideIn 0.3s ease;
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
        
        .form-row {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
        }
        
        @media (max-width: 768px) {
            .form-row {
                grid-template-columns: 1fr;
            }
            
            .priority-grid {
                grid-template-columns: repeat(2, 1fr);
            }
            
            .photo-preview {
                grid-template-columns: repeat(2, 1fr);
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <h1>Create Maintenance Request</h1>
            <p>Submit a maintenance form to your connected maintenance personnel</p>
        </div>
        
        <!-- Property Information -->
        <div class="property-info">
            <h3>Equipment Information</h3>
            <div class="property-details">
                <p><strong>M240B Machine Gun</strong></p>
                <p>Serial Number: <strong>M240B-123456</strong></p>
                <p>NSN: <strong>1005-01-544-4709</strong></p>
                <p>Location: <strong>Arms Room, Building 4501</strong></p>
            </div>
        </div>
        
        <!-- Form Section -->
        <div class="form-section">
            <!-- Form Type Selection -->
            <div class="form-tabs">
                <div class="form-tab active" onclick="selectForm('DA2404')">
                    <div>DA Form 2404</div>
                    <div style="font-size: 11px; color: #666; margin-top: 4px;">Equipment Inspection</div>
                </div>
                <div class="form-tab" onclick="selectForm('DA5988E')">
                    <div>DA Form 5988-E</div>
                    <div style="font-size: 11px; color: #666; margin-top: 4px;">Equipment Maintenance</div>
                </div>
            </div>
            
            <!-- Assign To -->
            <div class="form-group">
                <label>Assign To</label>
                <div class="user-select" onclick="showUserPicker()">
                    <div class="user-avatar">SW</div>
                    <div class="user-info">
                        <div class="user-name">SGT Williams</div>
                        <div class="user-unit">Motor Pool - 1st Battalion Maintenance</div>
                    </div>
                    <div style="color: #666;">▼</div>
                </div>
            </div>
            
            <!-- Priority -->
            <div class="form-group">
                <label>Priority</label>
                <div class="priority-grid">
                    <div class="priority-option routine active" onclick="selectPriority('routine')">Routine</div>
                    <div class="priority-option priority" onclick="selectPriority('priority')">Priority</div>
                    <div class="priority-option urgent" onclick="selectPriority('urgent')">Urgent</div>
                    <div class="priority-option emergency" onclick="selectPriority('emergency')">Emergency</div>
                </div>
            </div>
            
            <!-- Form Fields -->
            <div id="da2404-fields">
                <div class="form-row">
                    <div class="form-group">
                        <label>Rounds Fired</label>
                        <input type="number" class="form-control" value="2500" />
                    </div>
                    <div class="form-group">
                        <label>Last Cleaning Date</label>
                        <input type="date" class="form-control" value="2025-05-15" />
                    </div>
                </div>
                
                <div class="form-group">
                    <label>Deficiency Class</label>
                    <select class="form-control">
                        <option>Select deficiency class...</option>
                        <option>X - Deadline (Safety)</option>
                        <option selected>O - Operational</option>
                        <option>P - Preventive</option>
                    </select>
                </div>
                
                <div class="form-group">
                    <label>Inspection Type</label>
                    <select class="form-control">
                        <option>Annual Service</option>
                        <option selected>Semi-Annual Inspection</option>
                        <option>Quarterly Check</option>
                        <option>Pre-Combat Inspection</option>
                    </select>
                </div>
            </div>
            
            <!-- Description -->
            <div class="form-group">
                <label>Description</label>
                <textarea class="form-control" placeholder="Describe the maintenance needed...">Weapon requires semi-annual inspection and barrel gauging. Bolt shows signs of carbon buildup. Feed tray cover spring tension needs verification. Request full disassembly and inspection per TM 9-1005-313-10.</textarea>
            </div>
            
            <!-- Fault Description -->
            <div class="form-group">
                <label>Fault Description (Optional)</label>
                <textarea class="form-control" placeholder="Describe any specific faults or issues...">Occasional failure to feed during sustained fire. Suspected worn feed pawl assembly.</textarea>
            </div>
            
            <!-- Photo Upload -->
            <div class="form-group">
                <label>Photos</label>
                <div class="photo-upload" onclick="uploadPhotos()">
                    <div class="photo-icon">📷</div>
                    <div class="photo-text">Click to upload photos or drag and drop</div>
                </div>
                <div class="photo-preview">
                    <div class="photo-thumb">
                        <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='100' height='100'%3E%3Crect width='100' height='100' fill='%23444'/%3E%3Ctext x='50' y='50' text-anchor='middle' dy='.3em' fill='%23888' font-family='sans-serif' font-size='12'%3EPhoto 1%3C/text%3E%3C/svg%3E" alt="Photo 1" />
                    </div>
                    <div class="photo-thumb">
                        <img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='100' height='100'%3E%3Crect width='100' height='100' fill='%23444'/%3E%3Ctext x='50' y='50' text-anchor='middle' dy='.3em' fill='%23888' font-family='sans-serif' font-size='12'%3EPhoto 2%3C/text%3E%3C/svg%3E" alt="Photo 2" />
                    </div>
                </div>
            </div>
        </div>
        
        <!-- Actions -->
        <div class="actions">
            <button class="btn btn-secondary" onclick="cancel()">Cancel</button>
            <button class="btn btn-primary" onclick="submitRequest()">
                <span>✓</span>
                Submit Maintenance Request
            </button>
        </div>
    </div>
    
    <!-- Success Message -->
    <div class="success-message" id="successMessage">
        Maintenance form submitted to SGT Williams at Motor Pool
    </div>
    
    <script>
        function selectForm(formType) {
            document.querySelectorAll('.form-tab').forEach(tab => {
                tab.classList.remove('active');
            });
            event.target.closest('.form-tab').classList.add('active');
        }
        
        function selectPriority(priority) {
            document.querySelectorAll('.priority-option').forEach(option => {
                option.classList.remove('active');
            });
            event.target.classList.add('active');
        }
        
        function showUserPicker() {
            // In real app, would show user selection modal
            console.log('Show user picker');
        }
        
        function uploadPhotos() {
            // In real app, would trigger file upload
            console.log('Upload photos');
        }
        
        function cancel() {
            if (confirm('Are you sure you want to cancel this maintenance request?')) {
                // Navigate back
                console.log('Cancelled');
            }
        }
        
        function submitRequest() {
            // Show success message
            const successMsg = document.getElementById('successMessage');
            successMsg.style.display = 'block';
            
            // Hide after 3 seconds
            setTimeout(() => {
                successMsg.style.display = 'none';
                // In real app, would navigate back to maintenance list
            }, 3000);
            
            // Log to console (in real app, would submit to API)
            console.log('Maintenance request submitted');
        }
    </script>
</body>
</html>