Got it. I’ll go through the latest version of the `toole-brendan/hrx` repository and identify the exact files and lines you need to update in both the iOS Swift client and the Go backend to resolve the PDF export 'incorrect format' error. I’ll provide a line-by-line breakdown of the changes required.

I’ll follow up shortly with a detailed implementation plan.


## Backend (Go) Code Changes

**1. Update Document Model Definition**
**File:** `backend/internal/domain/models.go`

* **Line 413 (Before):**

  ```go
  Attachments     *string    `json:"attachments" gorm:"type:jsonb"` // Array of photo URLs
  ```
* **Line 413 (After):**

  ```go
  Attachments     []string   `json:"attachments" gorm:"type:jsonb"` // Array of photo URLs
  ```

  *Justification:* Change the `Document.Attachments` field from a JSON string pointer to a slice of strings. This ensures that when encoding to JSON, `attachments` will be a native array (e.g. `["file1.jpg","file2.png"]`) instead of a quoted JSON string (e.g. `"[\"file1.jpg\",\"file2.png\"]"`), matching the client’s expected structure.

**2. Fix Attachments Handling in Maintenance Form Creation**
**File:** `backend/internal/api/handlers/document_handler.go` (`CreateMaintenanceForm` function)

* **Lines 82–90:** **Remove** the block that marshals attachments into a JSON string:

  ```diff
   var attachmentsJSON *string
   if len(req.Attachments) > 0 {
  ```
* ```
     attachmentsBytes, err := json.Marshal(req.Attachments)
  ```
* ```
     if err != nil {
  ```
* ```
         c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process attachments"})
  ```
* ```
         return
  ```
* ```
     }
  ```
* ```
     attachmentsStr := string(attachmentsBytes)
  ```
* ```
     attachmentsJSON = &attachmentsStr
  ```

- ```
     // (No JSON marshalling needed; we will assign the slice directly)
  ```
- ```
     attachmentsJSON = nil  // (this variable will be unused or removed)
  ```

  }

  ```
  ```

* **Line 103:** Replace the attachment assignment with direct slice assignment:

  ```diff
        Title:        fmt.Sprintf("%s Maintenance Request - %s", req.FormType, property.Name),
        // ... other fields ...
  ```
* ```
    Attachments:  attachmentsJSON,
  ```

- ```
    Attachments:  req.Attachments,
    Status:       domain.DocumentStatusUnread,
    SentAt:       time.Now(),
  ```

  ```
  *Justification:* We no longer need to serialize attachments to a JSON string. By assigning `req.Attachments` (a `[]string`) directly to `Document.Attachments` (now a `[]string`), the JSON response will include a proper array. Removing the JSON marshaling block prevents double-encoding of the attachments data.
  ```

**3. Use Native Array in DA-2062 PDF Generation Handler**
**File:** `backend/internal/api/handlers/da2062_handler.go` (`GenerateDA2062PDF` function)

* **Lines 851–855 (Before):**

  ```go
  // Attach PDF URL if available
  if fileURL != "" {
      attachmentsArr := []string{fileURL}
      attachJSON, _ := json.Marshal(attachmentsArr)
      attachStr := string(attachJSON)
      doc.Attachments = &attachStr
  }
  ```
* **Lines 851–855 (After):**

  ```go
  // Attach PDF URL if available
  if fileURL != "" {
      doc.Attachments = []string{fileURL}
  }
  ```

  *Justification:* Assign the PDF’s URL directly as a single-element array. This ensures the `attachments` field on the created `Document` record is stored and returned as a JSON array (`["<pdf_url>"]`). We remove the manual JSON string construction (`attachStr`) since `doc.Attachments` is now a slice of strings.

**4. Use Native Array in Transfer Form Attachment Logic**
**File:** `backend/internal/api/handlers/transfer_handler.go` (within `CreateTransfer` logic around PDF generation)

* **Lines 1029–1033 (Before):**

  ```go
  if fileURL != "" {
      attachments := []string{fileURL}
      attachJSON, _ := json.Marshal(attachments)
      doc.Attachments = stringPtr(string(attachJSON))
  }
  ```
* **Lines 1029–1033 (After):**

  ```go
  if fileURL != "" {
      doc.Attachments = []string{fileURL}
  }
  ```

  *Justification:* Instead of converting the attachments array to a JSON string, directly assign the slice. The helper `stringPtr` is no longer needed here. This change ensures that the `attachments` field in the new transfer-form `Document` is an array of URLs, aligning with the client’s expected JSON format.

**5. Adjust PDF Email Extraction Logic**
**File:** `backend/internal/api/handlers/document_handler.go` (DA-2062 email sending section)

* **Lines 264–268 (Before):**

  ```go
  // Extract PDF URL from attachments
  var pdfURL string
  if document.Attachments != nil {
      var attachments []string
      if err := json.Unmarshal([]byte(*document.Attachments), &attachments); err == nil && len(attachments) > 0 {
          pdfURL = attachments[0]
      }
  }
  ```
* **Lines 264–268 (After):**

  ```go
  // Extract PDF URL from attachments
  var pdfURL string
  if len(document.Attachments) > 0 {
      pdfURL = document.Attachments[0]
  }
  ```

  *Justification:* With `document.Attachments` as a slice, we can retrieve the first element directly. This simplifies the code and avoids decoding a JSON string. The `pdfURL` will contain the first attachment (the PDF link) if available. If `Attachments` is empty or nil, `pdfURL` remains empty and the code correctly handles the “no PDF attachment” case in the following lines.

> **Note:** After these backend changes, **all new JSON API responses will represent `attachments` as an array** (or an empty array if no attachments). For consistency, you may want to ensure that if `Attachments` is `nil` it is rendered as an empty list (`[]`) rather than `null`. One approach is to initialize `Attachments` to an empty slice when creating a `Document` without attachments (so the JSON output shows `"attachments": []`). This guarantees the client decoders handle the field uniformly. Existing document records in the database that still store `attachments` as a JSON string may require migration or a special case in decoding, but adjusting the code as above fixes the format for all newly created or updated documents.

## iOS (Swift) Code Changes

**1. Update Document Model to Expect Array for Attachments**
**File:** `ios/HandReceipt/Models/DocumentModels.swift`

* **Line 17 (Before):**

  ```swift
  public let attachments: String?
  ```

* **Line 17 (After):**

  ```swift
  public let attachments: [String]?
  ```

  *Justification:* Change the `Document.attachments` property to an optional array of strings. The iOS app will now expect `attachments` as a JSON array of strings. This matches the updated backend response (an array of attachment URLs). Using `[String]?` allows the field to be absent or null (decoded as `nil` if no attachments), or a list of URL strings if present.

* **Line 24 (Initializer Before):** The initializer’s parameter for attachments is defined as `attachments: String?`. For example:

  ```swift
  public init(... description: String?, attachments: String?, status: DocumentStatus, sentAt: Date, ... ) {
      self.description = description
      self.attachments = attachments
      ...
  }
  ```

* **Line 24 (Initializer After):** Change that parameter to `attachments: [String]?` and keep the assignment the same:

  ```swift
  public init(... description: String?, attachments: [String]?, status: DocumentStatus, sentAt: Date, ... ) {
      self.description = description
      self.attachments = attachments
      ...
  }
  ```

  *Justification:* This aligns the initializer with the new property type. Any code constructing a `Document` (for example, marking a document as read in `DocumentService.markAsRead`) will now pass an array for the attachments field. After this change, `Document` models can be decoded from the new JSON structure without errors.

**2. Decoding Strategy and Usage**
No code changes are required in JSON decoder configuration, but it’s worth noting: the `JSONDecoder` is already configured with a custom date strategy and `.convertFromSnakeCase` for keys. Our keys like `"attachments"` are unchanged (they were already lowercase/camelCase in JSON), and we’ve explicitly defined CodingKeys for the `Document` struct (including `"attachments"`). Therefore, decoding will automatically map the JSON array into the `[String]?` property. The existing date decoding strategy will continue to handle `sentAt`, `readAt`, etc. as before.

**3. Update Any Usage of the Attachments Field** (if applicable):
Ensure that any logic depending on `Document.attachments` is updated to handle an array instead of a string. For example, if previously the app parsed the JSON string manually or assumed a single PDF URL, it should now use the array directly. In the current codebase, there isn’t a complex parsing on iOS – but if you later display or use attachments, you can do so directly (e.g. use `document.attachments?.first` for the first URL). The new type will prevent the format mismatch that led to the decoding error.

> **Note:** With these Swift model changes, the decoding error *“The data couldn’t be read because it isn’t in the correct format.”* will be resolved. The client’s `Document` decoder will successfully parse the `attachments` field as an array of strings (or nil/empty if no attachments) instead of encountering a type mismatch. Make sure to run the app or relevant unit tests after these changes – for example, any JSON fixture or sample data for documents should be adjusted to use an array for attachments. If the app has stored any `Document` objects (e.g., in cache) with the old format, those may need refreshing or migration to the new format.

## Affected Test Cases / Sample Data

* **Backend Unit Tests:** If there are any tests or fixtures asserting the JSON structure of `Document` (e.g., in API responses), update them to expect `"attachments"` as an array. For instance, a test that previously expected `"attachments": "[\"file1.png\"]"` should now expect `"attachments": ["file1.png"]`. Adjust any mock `Document` objects created in tests to use `[]string` for attachments instead of `*string`. (If no such tests exist, no changes are needed beyond verifying the API responses manually.)

* **iOS Unit/UI Tests:** If the iOS project includes tests decoding `Document` JSON or using sample JSON files, ensure those samples represent attachments as an array. Update any hard-coded JSON in tests from `"attachments": "…"` to an array structure. For example, in a JSON fixture:

  ```json
  {
    "id": 101,
    "...": "...",
    "attachments": ["https://example.com/att1.png", "https://example.com/att2.png"],
    "status": "unread",
    "sentAt": "2025-06-06T17:30:00Z",
    "readAt": null,
    ...
  }
  ```

  This will confirm that the `Document` model decodes properly with the new schema.

* **Sample Data / Migration:** Existing documents stored in the backend with attachments may have been saved as JSON strings. Going forward, the code will save them correctly as JSON arrays. You might consider a one-time migration to convert any old stringified attachment entries into proper JSON arrays in the database (e.g., update `documents.attachments` from `"<encoded array string>"` to an actual JSON array). This ensures consistency for older records. If migration is not immediate, handle potential `attachments` decoding gracefully on the client if a null or unexpected format arises for legacy data.

By applying these fixes, the **DA 2062 PDF export workflow** will produce a `Document` JSON that the iOS client can decode without errors. The `attachments` field will be a true JSON array of strings in the API response, matching the Swift `Document` model. This resolves the format mismatch and the export error, and keeps attachments (and other document metadata like dates) handled consistently across the backend and iOS app.
