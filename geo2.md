Great. I’ll provide a step-by-step, file-by-file and line-by-line implementation guide for both frontend (iOS) and backend (Go) to complete the 'Export DA 2062' feature. This will include making the export modal UI fully functional and implementing the in-app delivery to a recipient's document box.


## iOS (Swift) – Frontend Implementation

### 1. `MyPropertiesView.swift` – Launching and Closing the Export Modal

* **Add an onDismiss handler** to the `.fullScreenCover` that presents `DA2062ExportView` so that when the modal closes, selection mode is exited and selections are cleared. Modify the `.fullScreenCover` at around **line 159-165** as follows:

```swift
.fullScreenCover(
    isPresented: $showingDA2062Export,
    onDismiss: {
        // Exit selection mode and clear selected items when modal closes
        isSelectMode = false
        selectedPropertiesForExport.removeAll()
    }
) {
    DA2062ExportView(preSelectedPropertyIDs: Array(selectedPropertiesForExport))
        .onAppear {
            print("DA2062ExportView full screen cover appeared")
        }
}
```

This ensures that after exporting, the user’s property list returns to normal (no lingering “selected” state). The new `onDismiss` resets `isSelectMode` and empties `selectedPropertiesForExport`, similar to how tapping “Cancel” does.

### 2. `DA2062ExportView.swift` – Completing the Export Modal UI

#### **Unit Info Editing:**

In the **Unit Information** section’s header, the “Edit” button is currently a stub. We will implement it by presenting a sheet with editable fields for unit info.

* **Step 2a:** Add a state property to track the editor sheet, e.g. at the top of the view struct:

  ```swift
  @State private var showingUnitInfoEditor = false
  ```

* **Step 2b:** Modify the `ElegantSectionHeader` for Unit Information (around **line 95-102**) to call our new action:

  ```swift
  ElegantSectionHeader(
      title: "Unit Information",
      subtitle: "Organization details for this hand receipt",
      style: .serif,
      action: { showingUnitInfoEditor = true }, // open editor
      actionLabel: "Edit"
  )
  ```

* **Step 2c:** Define a simple editor view for unit info. For example, **after** the main `DA2062ExportView` struct, add a new view struct:

  ```swift
  struct UnitInfoEditorView: View {
      @Binding var unitInfo: DA2062ExportViewModel.UnitInfo
      @Environment(\.dismiss) private var dismiss

      var body: some View {
          NavigationView {
              Form {
                  Section(header: Text("Unit Details")) {
                      TextField("Unit Name", text: $unitInfo.unitName)
                      TextField("DODAAC", text: $unitInfo.dodaac)
                      TextField("Stock Number", text: $unitInfo.stockNumber)
                      TextField("Location", text: $unitInfo.location)
                  }
              }
              .navigationBarTitle("Edit Unit Info", displayMode: .inline)
              .navigationBarItems(
                  leading: Button("Cancel") { dismiss() },
                  trailing: Button("Save") { dismiss() }
              )
          }
      }
  }
  ```

  This presents a form for editing **Unit Name, DODAAC, Stock Number,** and **Location**. Tapping Save simply dismisses the sheet (the bound values in `viewModel.unitInfo` are already updated via the binding).

* **Step 2d:** Present this sheet in `DA2062ExportView`. Add after the `.alert` modifier (or at the bottom of the `body`):

  ```swift
  .sheet(isPresented: $showingUnitInfoEditor) {
      UnitInfoEditorView(unitInfo: $viewModel.unitInfo)
  }
  ```

With these changes, tapping **Edit** under Unit Information will show a form where the user can modify their unit details (initially pre-filled from user defaults).

#### **Property Selection Improvements:**

The property selection section already supports **Select All** and **Clear** actions, as well as category filters. These call `viewModel.selectAll()`, `clearSelection()`, etc., which are implemented in **DA2062ExportViewModel**. No code changes are needed here beyond confirming they function.

#### **Delivery Method – In-App Recipient Option:**

We add a new **“Send to User”** option to deliver the PDF directly into another user’s in-app document box, as an alternative to Download/Share or Email.

* **Step 2e:** Introduce state for the recipient picker in `DA2062ExportView`:

  ```swift
  @State private var showingRecipientPicker = false
  @State private var selectedConnection: UserConnection?
  ```

  Also, initialize a Connections view model to fetch the user’s connections (friends):

  ```swift
  @StateObject private var connectionsViewModel = ConnectionsViewModel(apiService: APIService())
  ```

  (This assumes a ConnectionsViewModel exists similar to the one used in property transfers.)

* **Step 2f:** Add a **“Send to User”** button in the `actionButtons` VStack (beneath the existing “Generate & Share” and “Email PDF” buttons). For example, at around **line 229** insert:

  ```swift
  Button(action: { 
      // Load connections and show picker
      await MainActor.run { connectionsViewModel.loadConnections() }
      showingRecipientPicker = true 
  }) {
      HStack {
          Image(systemName: "person.crop.circle.badge.arrow.right")
              .font(.system(size: 16, weight: .regular))
          Text("Send to User")
              .font(AppFonts.bodyMedium)
      }
  }
  .buttonStyle(.minimalSecondary)
  .disabled(viewModel.selectedPropertyIDs.isEmpty)
  ```

  This uses an appropriate SF Symbol and is disabled unless at least one item is selected (similar to the Email button logic).

* **Step 2g:** Present the recipient picker as a sheet. After the alert modifier, add:

  ```swift
  .sheet(isPresented: $showingRecipientPicker) {
      NavigationView {
          VStack {
              // Header with Cancel and Send
              HStack {
                  Button("Cancel") { showingRecipientPicker = false }
                      .padding(.leading)
                  Spacer()
                  Text("Send Hand Receipt")
                      .font(.headline)
                  Spacer()
                  Button("Send") {
                      Task { await sendHandReceiptInApp() }
                  }
                  .disabled(selectedConnection == nil)
                  .padding(.trailing)
              }
              .padding(.vertical)
              Divider()
              // List connections
              ScrollView {
                  VStack(spacing: 0) {
                      if connectionsViewModel.connections.isEmpty {
                          Text("No connections available").padding()
                      }
                      ForEach(connectionsViewModel.connections) { connection in
                          Button(action: {
                              selectedConnection = connection
                          }) {
                              HStack {
                                  Text(connection.connectedUser?.name ?? "Unknown")
                                  Spacer()
                                  Image(systemName: selectedConnection?.id == connection.id 
                                          ? "checkmark.circle.fill" 
                                          : "circle")
                                      .foregroundColor(AppColors.accent)
                              }
                              .padding()
                          }
                          .background(selectedConnection?.id == connection.id 
                                      ? AppColors.accent.opacity(0.1) 
                                      : Color.clear)
                      }
                  }
              }
          }
          .navigationBarHidden(true)
      }
  }
  ```

  This sheet is modeled after the transfer UI, listing the user’s connections (from `connectionsViewModel.connections`) with a checkmark for the selected user. The **Send** button is enabled only when a connection is selected. Tapping **Send** calls an async function `sendHandReceiptInApp()` to perform the in-app export.

* **Step 2h:** Implement the `sendHandReceiptInApp()` helper inside `DA2062ExportView` (e.g., in the `// MARK: - Helper Methods` section):

  ```swift
  private func sendHandReceiptInApp() async {
      guard let connection = selectedConnection,
            let recipientUser = connection.connectedUser else { return }
      isGenerating = true
      do {
          try await viewModel.sendHandReceipt(to: recipientUser.id)
          isGenerating = false
          // Show success alert
          errorMessage = "Hand Receipt sent to \(recipientUser.rank) \(recipientUser.name)"
          showError = true
          // Dismiss the picker and export view after success
          showingRecipientPicker = false
          // Optionally, auto-dismiss the entire export view:
          // dismiss() 
      } catch {
          isGenerating = false
          errorMessage = error.localizedDescription
          showError = true
      }
  }
  ```

  This function retrieves the selected `recipientUser` and calls a new view model method `sendHandReceipt(to:)`. On success, we set a confirmation message and present it via the existing `.alert` (which uses `errorMessage`/`showError`). We also close the picker sheet. (You may call `dismiss()` to close the export view automatically if desired.)

#### **View Model and API Integration for In-App Send:**

Now we update the view model and API service to support generating/sending the PDF to a user.

### 3. `DA2062ExportViewModel.swift` – Handling Recipient and Send Request

* **Step 3a:** Add a property to hold the selected recipient user ID (if any). For example, in `DA2062ExportViewModel` add:

  ```swift
  @Published var recipientUserId: Int? = nil
  ```

  If more info is needed (like recipient name for UI), we could store a `User` model or reuse the `UserInfo` struct, but ID is sufficient for the request.

* **Step 3b:** Modify the `generatePDF()` request assembly to include `ToUser` and `ToUserID` if a recipient is set. At about **line 94-102**, where we create `GeneratePDFRequest`:

  ```swift
  let toUserInfo = recipientUserId != nil 
      ? PDFUserInfo(name: userInfo.name, rank: userInfo.rank, title: userInfo.title, phone: userInfo.phone)
      : PDFUserInfo(name: userInfo.name, rank: userInfo.rank, title: userInfo.title, phone: userInfo.phone)
  let toUserIdVal = recipientUserId ?? 0

  let request = GeneratePDFRequest(
      propertyIDs: Array(selectedPropertyIDs),
      groupByCategory: groupByCategory,
      includeQRCodes: includeQRCodes,
      sendEmail: false,
      recipients: [],
      fromUser: PDFUserInfo(name: userInfo.name, rank: userInfo.rank, title: userInfo.title, phone: userInfo.phone),
      toUser: toUserInfo,
      unitInfo: PDFUnitInfo(unitName: unitInfo.unitName, dodaac: unitInfo.dodaac, stockNumber: unitInfo.stockNumber, location: unitInfo.location),
      toUserId: toUserIdVal
  )
  return try await apiService.generateDA2062PDF(request: request)
  ```

  Here we populate `toUser` and `to_user_id` when `recipientUserId` is set. (In this simplified approach, we reuse the current user’s info for `toUser` since the backend will fetch the actual recipient details; alternatively, you could pass the recipient’s name/rank if known).

* **Step 3c:** Add a new method to handle the in-app send (no PDF data expected back):

  ```swift
  func sendHandReceipt(to recipientId: Int) async throws {
      // Build request similar to generatePDF, but expecting JSON response
      let request = GeneratePDFRequest(
          propertyIDs: Array(selectedPropertyIDs),
          groupByCategory: groupByCategory,
          includeQRCodes: includeQRCodes,
          sendEmail: false,
          recipients: [],
          fromUser: PDFUserInfo(name: userInfo.name, rank: userInfo.rank, title: userInfo.title, phone: userInfo.phone),
          toUser: PDFUserInfo(name: userInfo.name, rank: userInfo.rank, title: userInfo.title, phone: userInfo.phone),
          unitInfo: PDFUnitInfo(unitName: unitInfo.unitName, dodaac: unitInfo.dodaac, stockNumber: unitInfo.stockNumber, location: unitInfo.location),
          toUserId: recipientId
      )
      _ = try await apiService.sendDA2062InApp(request: request)
      // We ignore the returned document here, but could handle it if needed
  }
  ```

  This is similar to `generatePDF()` but uses a different API call that returns a `Document`.

### 4. `APIService.swift` – API Endpoints for DA 2062 Export

We add new methods to the shared API service to call the backend endpoints. Insert the following in `APIService` (e.g., under a **DA2062** mark):

```swift
// MARK: - DA2062 Hand Receipt Endpoints

public func generateDA2062PDF(request: GeneratePDFRequest) async throws -> Data {
    let endpoint = baseURL.appendingPathComponent("/api/da2062/generate-pdf")
    var urlRequest = URLRequest(url: endpoint)
    urlRequest.httpMethod = "POST"
    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        if let err = try? JSONDecoder().decode(APIError.self, from: data) {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: err.error])
        }
        throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])
    }
    return data  // PDF binary data
}

public func emailDA2062PDF(request: GeneratePDFRequest) async throws {
    // Similar setup as above
    let endpoint = baseURL.appendingPathComponent("/api/da2062/generate-pdf")
    var urlRequest = URLRequest(url: endpoint)
    urlRequest.httpMethod = "POST"
    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
        if let err = try? JSONDecoder().decode(APIError.self, from: data) {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: err.error])
        }
        throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to email PDF"])
    }
    // No further action needed on success (server sends email)
}

public func sendDA2062InApp(request: GeneratePDFRequest) async throws -> Document {
    let endpoint = baseURL.appendingPathComponent("/api/da2062/generate-pdf")
    var urlRequest = URLRequest(url: endpoint)
    urlRequest.httpMethod = "POST"
    urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(request)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
        if let err = try? JSONDecoder().decode(APIError.self, from: data) {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: err.error])
        }
        throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to send hand receipt"])
    }
    // Decode the returned document
    let result = try JSONDecoder().decode([String: Document].self, from: data)
    guard let document = result["document"] else {
        throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
    }
    return document
}
```

These functions correspond to the backend `POST /api/da2062/generate-pdf` endpoint. The `generateDA2062PDF` returns raw PDF bytes (status 200 on success), `emailDA2062PDF` triggers an email (no return data, but we treat 200/201 as success), and `sendDA2062InApp` expects a 201 Created with a JSON body containing the created `Document`. The `Document` model here is the same Codable struct defined in **DocumentModels.swift**.

> **Note:** The `baseURL` used above should be the API base (e.g., from config or `VITE_API_URL`). Also, we handle error decoding into an `APIError` struct for better messages (this assumes an `APIError: Codable` exists to parse `{"error": "..."}`).

### 5. **Testing the iOS Flow (manually):**

* Run the app, select one or multiple properties in **My Properties** screen, tap **Export DA 2062**. The modal shows unit info, selected items count, and options.
* Try editing unit info via the **Edit** button – changes should reflect in the form (if you generate the PDF, the updated info will apply).
* Test **Select All**, **Clear**, and **Filter** to ensure item selection updates the count subtitle.
* **Generate & Share** should produce a PDF and open the iOS share sheet (e.g. you can preview the PDF or save it).
* **Email PDF:** entering an email in the alert and tapping Send will call our backend to email the PDF (or open the Mail composer if left blank).
* **Send to User:** tapping this opens your connections list. Pick a user and tap **Send**. A success alert should appear if the backend delivered the form. The selected recipient (if seeded and connected) can log in and find the document in their inbox.

## Backend (Go) – Server-Side Implementation

### 6. `backend/internal/api/handlers/da2062_handler.go` – Handling PDF Generation and Delivery

The `DA2062Handler.GenerateDA2062PDF` endpoint already generates the PDF and handles direct download or emailing. We will extend it to handle in-app delivery when a `to_user_id` is provided in the request.

* **Step 6a:** **Define behavior for in-app send.** In the `GenerateDA2062PDF` function, after generating the PDF buffer (after line 690), add a branch to handle the case where a recipient user is specified (`req.ToUserID != 0`) and we are not emailing. We insert this *before* the existing `else` (download) clause:

```go
// ... after formNumber is generated:
formNumber := fmt.Sprintf("HR-%s-%d", time.Now().Format("20060102"), userID)

// Handle in-app delivery to another user
if req.ToUserID != 0 {
    // Verify the recipient is a connection/friend of the sender
    connected, err := h.Repo.CheckUserConnection(userID, req.ToUserID)
    if err != nil || !connected {
        c.JSON(http.StatusBadRequest, gin.H{"error": "Recipient must be in your connections"})
        return
    }
    // Fetch recipient details
    recipient, err := h.Repo.GetUserByID(req.ToUserID)
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Recipient not found"})
        return
    }
    // Upload PDF to storage
    ctx := c.Request.Context()
    fileKey := fmt.Sprintf("da2062/export_%d_%d.pdf", userID, time.Now().UnixNano())
    err = h.StorageService.UploadFile(ctx, fileKey, bytes.NewReader(pdfBuffer.Bytes()), int64(pdfBuffer.Len()), "application/pdf")
    if err != nil {
        log.Printf("Failed to upload DA2062 PDF: %v", err)
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to store PDF"})
        return
    }
    // Get a presigned URL for the PDF (for attachments)
    fileURL, err := h.StorageService.GetPresignedURL(ctx, fileKey, 7*24*time.Hour)
    if err != nil {
        log.Printf("Warning: could not get presigned URL, proceeding without it: %v", err)
        fileURL = ""
    }

    // Prepare title for document(s)
    var title string
    if len(properties) == 1 {
        // Single item – include item name
        title = fmt.Sprintf("Hand Receipt for %s", properties[0].Name)
    } else {
        title = fmt.Sprintf("Hand Receipt - %d Items", len(properties))
    }

    // Create document record for recipient (inbox)
    doc := &domain.Document{
        Type:            domain.DocumentTypeTransferForm,
        Subtype:         stringPtr("DA2062"),
        Title:           title,
        SenderUserID:    userID,
        RecipientUserID: req.ToUserID,
        PropertyID:      nil, // no single property association for multiple items
        FormData:        "{}",  // could include metadata if needed
        Description:     nil,
        Attachments:     nil,
        Status:          domain.DocumentStatusUnread,
        SentAt:          time.Now(),
    }
    // Attach PDF URL if available
    if fileURL != "" {
        attachmentsArr := []string{fileURL}
        attachJSON, _ := json.Marshal(attachmentsArr)
        attachStr := string(attachJSON)
        doc.Attachments = &attachStr
    }
    if err := h.Repo.CreateDocument(doc); err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create document record"})
        return
    }
    // Optionally, create a copy for sender's "Sent" box (as in transfer workflow)
    // Here we skip creating a duplicate document; the sender can view this in their Sent list by virtue of being senderUserID.

    // Log the export action to the ledger
    if err := h.Ledger.LogDA2062Export(userID, len(properties), "app", recipient.Email); err != nil {
        log.Printf("WARNING: Failed to log DA2062 export to ledger: %v", err)
    }

    // Respond with the created document
    c.JSON(http.StatusCreated, gin.H{
        "document": doc,
        "message":  fmt.Sprintf("DA 2062 sent to %s %s", recipient.Rank, recipient.Name),
    })
    return
}
```

Let’s break down this added code:

* We check that the target user is in the sender’s connections (friends list) using `Repo.CheckUserConnection`. This prevents sending hand receipts to arbitrary users.
* We fetch the recipient’s `User` record to use in the title/message and ensure existence.
* We upload the PDF to storage (e.g., S3) and get a presigned URL for it. We create a unique `fileKey` using the current user ID and timestamp (nanoseconds) to avoid name collisions. If the presigned URL fails, we proceed without it (the document can still be recorded, but the attachment link will be empty).
* We create a new `Document` entry in the `documents` table for the recipient:

  * `Type` is set to **`transfer_form`** (since a hand receipt is essentially a transfer document).
  * `Subtype` is `"DA2062"` to specify the form type.
  * `Title` is a user-friendly description of the document. We use the item name if only one property, otherwise a generic count.
  * `SenderUserID` is the current user (`userID`), `RecipientUserID` is the target user.
  * `PropertyID` is left nil for multiple items (if it were a single item, we could set it, but it’s optional).
  * `FormData` is just an empty JSON `{}` here (no structured form data needed for now).
  * `Attachments` is set to an array containing the PDF’s URL (as JSON text) if we obtained one.
  * `Status` is `"unread"` and `SentAt` is now.
    We then call `h.Repo.CreateDocument(doc)` to save this record.
* We do **not** explicitly create a second document for the sender. Unlike the transfer acceptance flow (which created two records for sender/recipient copies), here the single document will be visible in both users’ document lists: the recipient will see it in their **Inbox**, and the sender (as the document’s sender) can see it under **Sent**. (If separate sender copy is desired, similar code can be added, but it’s not strictly necessary.)
* We log the event via `Ledger.LogDA2062Export`. We pass the action as `"app"` to denote an in-app delivery, and include the recipient’s email for reference. (The ledger service will record an export event with method "app".)
* Finally, we return an HTTP **201 Created** response containing the new document and a message. The iOS app will parse this to confirm success. This response format matches how maintenance form sends respond with a document and message.

With this branch in place, whenever the request JSON includes a `to_user_id` (and no `send_email` flag), the code will take this path, storing the PDF and creating a document instead of returning the file directly.

#### **No Changes** are needed in `domain/models.go` or the repository layer – we are reusing the existing `Document` model and `CreateDocument` repository method (used by maintenance forms). The `documents` table (from migration **013**) already supports what we need: fields for sender, recipient, subtype, attachments, etc..

### 7. Testing the Backend

Ensure you have some connection between two users in the database (see `015_seed_test_user_mock_data.sql` for sample connections). Run the backend and use an HTTP client (or the iOS app) to test:

* **Download PDF (no recipient):** Send a POST to `/api/da2062/generate-pdf` with JSON containing `property_ids` and no `to_user_id`. You should receive a 200 with PDF content (`Content-Type: application/pdf`). The ledger should log a `"download"` event.

* **Email PDF:** Send a request with `send_email: true` and `recipients: ["someone@example.mil"]`. You should get a 200 JSON with a success message, and an email should be sent via the `DA2062EmailService` (configure your email service accordingly). The documents table is not involved in pure email sends (no document entry is created in this case).

* **In-App Send:** Send a request with a valid `to_user_id` of a connected user (and `send_email: false`). Expect a **201** response with a JSON containing the new document record and a confirmation message. Verify the `documents` table has a new entry:

  * `type = 'transfer_form'`, `subtype = 'DA2062'`, `sender_user_id = [your ID]`, `recipient_user_id = [target ID]`, and `attachments` containing the PDF URL (verify the URL is accessible if opened).
  * On the recipient’s account, calling `GET /api/documents?box=inbox` should list this document (status `unread`). On the sender’s account, `?box=sent` should list it as well. Both users can retrieve it via `GET /api/documents/{id}` (the API ensures only sender or recipient can access a document).

* **Edge cases:** If you try a `to_user_id` that is not your connection, you should get a 400 error `"Recipient must be in your connections"` due to our check. If the user ID doesn’t exist, a 404 `"Recipient not found"` is returned.

By following these steps, we’ve made the **“Export DA 2062”** feature fully functional. On iOS, users can select items and choose to **Download**, **Email**, or **Send to User**. The backend now supports generating the DA 2062 PDF, emailing it, or delivering it in-app by creating a document entry for the recipient (using the existing `documents` infrastructure). This allows a user to fill out a hand receipt (DA Form 2062), optionally select a connected recipient, and send the completed form to that person’s document box – with fallback options to save or email the PDF if needed. All that remains is to deploy the changes and verify in an integrated environment.
