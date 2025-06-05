# DA2062 Import Feature - Testing Guide

## 🧪 **Testing the Enhanced DA2062 Import Feature**

This guide covers how to test the fully enhanced DA2062 import feature with Azure Computer Vision integration, ledger logging, and comprehensive error handling.

## 🎯 **Key Enhancements Implemented**

### 1. **OCR Mode Toggle**
- **Azure Computer Vision**: Cloud-based OCR with superior accuracy
- **Local Vision Framework**: On-device processing for privacy/offline use
- **UI Toggle**: Switch between modes in settings or during testing

### 2. **Sample Image Testing**
- **Built-in Sample**: Pre-configured DA2062 form for testing
- **Photo Picker**: Select images from device/simulator
- **Fallback Generation**: Creates test image if sample not available

### 3. **Enhanced Error Handling**
- **Partial Success Reporting**: Shows "X of Y items imported successfully"
- **Automatic Fallback**: Azure OCR → Local OCR if Azure fails
- **Task Cancellation**: Proper cancellation of ongoing imports

### 4. **Comprehensive Ledger Logging**
- **Individual Property Logging**: Each property creation logged separately
- **Import Event Logging**: Batch imports logged with full metadata
- **Audit Trail**: Complete chain of custody from scan to database

## 📱 **Testing in iOS Simulator**

### **Step 1: Enable Debug Mode**

1. Launch the app in iOS Simulator
2. Navigate to DA2062 Scanner
3. Tap the gear icon (⚙️) in the top-right
4. Enable "Debug Mode" toggle
5. Choose your preferred OCR mode (Azure/Local)

### **Step 2: Test with Sample Form**

```swift
// The app includes these testing options:
1. "Use Sample DA 2062" - Tests with built-in form
2. "Sample Form (Azure)" - Forces Azure OCR testing
3. "Sample Form (Local)" - Forces local OCR testing
4. "Choose Image from Photos" - Photo picker integration
```

### **Step 3: Monitor Import Process**

Watch for these progress phases:
1. **Scanning/Uploading** → Image processing begins
2. **Azure/Local OCR** → Text extraction
3. **Parsing Items** → Converting OCR to structured data
4. **Validating** → Checking data quality
5. **Enriching** → NSN lookups and metadata enhancement
6. **Creating & Logging** → Property creation with ledger logging
7. **Complete** → Success summary with statistics

## 🔄 **Testing Scenarios**

### **Scenario 1: Azure OCR Success**
```
1. Set OCR Mode → Azure
2. Tap "Sample Form (Azure)"
3. Expected: Fast, accurate processing
4. Result: High-confidence items with minimal verification needs
```

### **Scenario 2: Azure OCR Fallback**
```
1. Set OCR Mode → Azure
2. Disable network OR configure invalid Azure endpoint
3. Tap "Sample Form (Azure)"
4. Expected: Automatic fallback to local processing
5. Result: "Azure OCR failed, falling back to local processing..."
```

### **Scenario 3: Local OCR Only**
```
1. Set OCR Mode → Local
2. Tap "Sample Form (Local)"
3. Expected: On-device processing
4. Result: Local Vision Framework processing with enhanced validation
```

### **Scenario 4: Partial Success Testing**
```
1. Import items with duplicate serial numbers
2. Expected: Partial success with detailed reporting
3. Result: "Successfully imported X of Y items. Z items failed due to errors."
```

### **Scenario 5: Import Cancellation**
```
1. Start a large import
2. Tap "Cancel" during processing
3. Expected: Immediate cancellation
4. Result: "Import cancelled by user"
```

## 📊 **Verification Points**

### **Progress Tracking**
- [ ] Real-time progress indicators
- [ ] Phase-specific status messages
- [ ] OCR mode clearly displayed
- [ ] Ledger logging confirmation

### **Error Handling**
- [ ] Graceful Azure OCR fallback
- [ ] Partial success reporting
- [ ] Clear error messages
- [ ] Recovery options provided

### **Data Quality**
- [ ] NSN validation (XXXX-XX-XXX-XXXX format)
- [ ] Serial number cleaning
- [ ] Description enhancement
- [ ] Confidence scoring

### **Ledger Integration**
- [ ] Individual property logging
- [ ] Batch import event logging
- [ ] Import metadata preservation
- [ ] Audit trail completeness

## 🛠 **Advanced Testing**

### **Custom Test Images**

```swift
// Create custom test scenarios:
1. Low-quality scans → Test confidence thresholds
2. Incomplete forms → Test validation logic
3. Multi-quantity items → Test expansion logic
4. Missing data → Test error recovery
```

### **Network Conditions**

```swift
// Test different network scenarios:
1. Fast WiFi → Azure OCR performance
2. Slow connection → Timeout handling
3. No network → Local fallback
4. Intermittent → Retry logic
```

### **Error Injection**

```swift
// Test error scenarios:
1. Duplicate serials → Partial success
2. Invalid NSNs → Validation errors
3. Backend errors → Error handling
4. Malformed responses → Recovery
```

## 📈 **Performance Metrics**

### **Expected Performance**
- **Azure OCR**: 2-5 seconds for standard forms
- **Local OCR**: 3-8 seconds depending on complexity
- **Batch Import**: <1 second for typical item counts
- **Ledger Logging**: Near-instantaneous

### **Success Rates**
- **Azure OCR Accuracy**: 95%+ for standard DA2062 forms
- **Local OCR Accuracy**: 80-90% for clean scans
- **Import Success**: 99%+ for valid data
- **Ledger Logging**: 100% for successful imports

## 🎯 **Expected Test Results**

### **Successful Azure OCR Test**
```
✅ Uploading to Azure OCR...
✅ Processing with Azure Computer Vision...
✅ Converting OCR results...
✅ Creating property records with ledger logging...
✅ Import completed! 5 items created
✅ Logged to Azure Immutable Ledger
```

### **Successful Local OCR Test**
```
✅ Processing image...
✅ Running enhanced local OCR...
✅ Identifying items...
✅ Validating data...
✅ Looking up item details...
✅ Creating property records with ledger logging...
✅ Import completed successfully!
```

### **Partial Success Example**
```
⚠️ Partial import completed: 3 of 5 items created
❌ 2 items failed due to errors:
   - Duplicate serial number: W123456789
   - Invalid NSN format: 1005-01-XXX-0973
✅ Logged to Azure Immutable Ledger
```

## 🔧 **Troubleshooting**

### **Common Issues**

1. **"No text found in image"**
   - Solution: Use higher quality scan or built-in sample

2. **"Azure OCR processing failed"**
   - Solution: Check network connection or use local mode

3. **"Duplicate serial number"**
   - Solution: Expected behavior, check existing inventory

4. **"Failed to log to ledger"**
   - Solution: Check backend connectivity and Azure configuration

### **Debug Information**

The app logs detailed information to the Xcode console:
```
DEBUG: [DA2062ImportViewModel] Azure OCR processing started
DEBUG: [APIService] Uploading to /api/da2062/upload
DEBUG: [DA2062ImportViewModel] ✅ Logged DA2062 property creation to immutable ledger
```

## 📝 **Test Checklist**

- [ ] OCR mode toggle works correctly
- [ ] Sample image testing functional
- [ ] Photo picker integration working
- [ ] Azure OCR processes successfully
- [ ] Local OCR fallback functional
- [ ] Progress tracking accurate
- [ ] Error handling comprehensive
- [ ] Partial success reporting clear
- [ ] Import cancellation works
- [ ] Ledger logging confirmed
- [ ] Property creation successful
- [ ] Verification workflow functional

## 🏁 **Success Criteria**

The feature is working correctly when:

1. **Flexibility**: Both Azure and local OCR modes functional
2. **Reliability**: Automatic fallback and error recovery
3. **Transparency**: Clear progress and status reporting
4. **Compliance**: All actions logged to Azure Immutable Ledger
5. **Usability**: Intuitive testing and import workflow

## 📞 **Support**

If you encounter issues during testing:

1. **Enable Debug Mode** for detailed logging
2. **Check Xcode Console** for error details
3. **Test with Sample Form** to isolate issues
4. **Verify Network Connectivity** for Azure features
5. **Review Backend Logs** for server-side issues

The enhanced DA2062 import feature provides a robust, scalable, and compliant solution for military property management with comprehensive testing capabilities.