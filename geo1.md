Got it. I’ll analyze the `handreceipt/backend` and `handreceipt/ios` modules in your `toole-brendan/hrx` repository to identify all inline TODOs, stubbed-out functions, and placeholder code. I’ll also highlight the most pressing ones and suggest concrete implementation strategies tailored to their context.

I’ll let you know once I have a detailed report ready.


## 1. Full List of TODOs and Stub Implementations (Backend & iOS)

* **`backend/internal/api/routes/routes.go:48`** – `emailService := &email.DA2062EmailService{} // TODO: Initialize with proper email service`
  &#x20;– *Placeholder email service used for DA Form 2062 emails. A real email service (SMTP or API-based) should be injected here instead of the dummy instance.*

* **`backend/internal/api/routes/routes.go:62`** – `// TODO: Update other handlers to use repository when needed`
  &#x20;– *Comment indicating some handlers should utilize the repository layer. Likely intended to refactor handlers to use the `repo` for data access where applicable.*

* **`backend/internal/api/routes/routes.go:135`** – `// TODO: Add route for full cryptographic document verification`
  &#x20;– *A route for end-to-end cryptographic ledger/document verification is not yet implemented. This suggests a future endpoint to verify data integrity (perhaps using ImmuDB’s proofs).*

* **`backend/internal/api/routes/routes.go:145`** – `// TODO: Add routes for querying/viewing correction events?`
  &#x20;– *No endpoint exists yet for retrieving or viewing correction events in the audit log. Intended for querying correction history of ledger events.*

* **`backend/internal/api/routes/routes.go:152`** – `// TODO: Add route for item-specific history (/ledger/item/:itemId/history) ?`
  &#x20;– *No specific route for fetching ledger history of a single item. Likely meant to retrieve all ledger events related to a given item ID.*

* **`backend/internal/api/routes/nsn_routes.go:25`** – `// TODO: Implement role-based access control middleware`
  &#x20;– *Admin NSN routes (import/refresh) currently have no RBAC protection. The comment and commented-out code suggest adding a middleware (e.g. `RequireRole("admin")`) to restrict these endpoints to admin users.*

* **`backend/internal/api/middleware/auth.go:146`** – `secret = "your-secret-key" // TODO: Use actual secure secret`
  &#x20;– *A hard-coded JWT secret is used as fallback. In production this should be replaced by a secure secret from config or env. (Also appears again at line 179 for token validation.)*

* **`backend/internal/ledger/ledger_service.go:54`** – `// TODO: Add filtering/pagination parameters (e.g., time range, event type, user ID, property ID).`
  &#x20;– *The `GetGeneralHistory()` interface method lacks filters. The comment notes plans to support query parameters (date range, event type, etc.) for retrieving ledger history.*

* **`backend/internal/ledger/azure_sql_ledger_service.go:27`** – `// TODO: Make sure the correct Azure SQL driver is imported above`
  &#x20;– *Reminder to ensure the proper database driver is in use. Likely a check because the code uses `"sqlserver"` in `sql.Open`, and this TODO notes verifying the import for Azure SQL.*

* **`backend/internal/ledger/azure_sql_ledger_service.go:52`** – `// TODO: Optionally, check if required ledger tables exist and create/configure if needed.`
  &#x20;– *Initialization stub: the `Initialize()` method currently does nothing except log. Ideally, it would verify or create ledger-enabled tables (using `CREATE TABLE ... WITH LEDGER`), especially if running for the first time.*

* **`backend/internal/ledger/immudb_ledger_service.go:227`** – *(Placeholder return in `GetPropertyHistory`)* – The implementation simply returns a dummy entry: e.g. a map with a message `"ImmuDB history retrieval for item X is being implemented"`, appended to history and returned. *This indicates `GetPropertyHistory` is not yet fully implemented; it doesn’t actually fetch real history from ImmuDB.*

* **`backend/internal/ledger/immudb_ledger_service.go:254`** – `// Placeholder implementation` in `GetAllCorrectionEvents` returning an empty list. *No real retrieval of correction events from the ledger – just returns an empty slice.*

* **`backend/internal/ledger/immudb_ledger_service.go:260`** – `// Placeholder implementation` in `GetCorrectionEventsByOriginalID` (also returns empty list).

* **`backend/internal/ledger/immudb_ledger_service.go:266`** – `// Placeholder implementation` in `GetCorrectionEventByID` returning a “not found” error always.

* **`backend/internal/ledger/immudb_ledger_service.go:272`** – `// Placeholder implementation` in `GetGeneralHistory` returning an empty slice.
  **(The above five methods in ImmuDBLedgerService are stubs; they do not query actual data yet.)**

* **`backend/internal/api/handlers/nsn_handler.go:179`** – `// This is a placeholder - implement your actual authorization logic`
  &#x20;– *In the `ImportCSV` handler for NSN, the admin privilege check is rudimentary. It simply reads a `user_role` from context and denies access if not “admin”. This placeholder implies a more robust auth check (or middleware) should replace it.*

* **`backend/internal/services/nsn/nsn_service.go:364`** – `// This is a placeholder for the actual implementation`
  &#x20;– *In `RefreshCachedNSNData`, no real refresh happens. The method logs start/end but does not fetch or update anything. It’s a stub; actual logic to call an external NSN data source and update the local DB is missing.*

* **`backend/internal/services/nsn/nsn_service.go:419`** – `// This is a placeholder for external API integration`
  &#x20;– *In the helper `fetchFromExternalAPI`, the code simply logs and returns “not implemented”. This function is a stub for actually querying an external NSN API to retrieve item details.*

* **`ios/HandReceipt/Services/TransferService.swift:44`** – `// For now, throw not implemented`
  &#x20;– *The `rejectOffer(_:)` function is not implemented; it immediately throws a 501 “Not implemented” error. This indicates no backend endpoint exists for rejecting a transfer offer, and the app is handling it as unimplemented.*

* **`ios/HandReceipt/Services/CoreDataStack.swift:54`** – `// TODO: Implement these methods when Core Data entities are created`
  &#x20;– *A note preceding several commented-out Core Data methods. It indicates that offline-sync Core Data entities (like `SyncQueueItem`, `CachedProperty`, etc.) are planned but not yet added to the model, so the related functions are left unimplemented.*

* **`ios/HandReceipt/Services/CoreDataStack.swift:110`** – `// TODO: Implement when CachedProperty entity is created`
  &#x20;– *Placeholder for a `cacheProperty(_:)` method (currently commented out). Without a `CachedProperty` Core Data entity, this method remains unimplemented.*

* **`ios/HandReceipt/Services/CoreDataStack.swift:159`** – `// TODO: Implement when CachedTransfer entity is created`
  &#x20;– *Placeholder for a `cacheTransfer(_:)` method (commented out) to store transfer info offline. Depends on adding a `CachedTransfer` entity.*

* **`ios/HandReceipt/Services/CoreDataStack.swift:209`** – `// TODO: Implement when PendingPhotoUpload entity is created`
  &#x20;– *Stub for a `queuePhotoUpload` method (commented out) to enqueue photo uploads in Core Data. Requires a `PendingPhotoUpload` entity.*

* **`ios/HandReceipt/Services/CoreDataStack.swift:244`** – `// TODO: Implement when SyncQueueItem entity is created`
  &#x20;– *Marks an unimplemented section for cleaning up completed sync queue items. The code to delete or manage `SyncQueueItem` entries is commented out pending the entity’s creation.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:89`** – `// TODO: Uncomment when Core Data entities are implemented`
  &#x20;– *In `syncAll()`, step 1 (processing the sync queue) is commented out entirely. It should be enabled once offline sync entities (like SyncQueueItem) are in place.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:108`** – `// TODO: Implement when SyncQueueItem entity is created`
  &#x20;– *The `processSyncQueue()` function is fully commented out (stub). It’s intended to asynchronously process pending sync items from Core Data (once they exist).*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:172`** – `propertyModelId: nil, // TODO: Link to property model if NSN/LIN is provided`
  &#x20;– *In creating a new property via sync, the code leaves `propertyModelId` as nil. The TODO suggests linking the property to a model record if NSN/LIN info is available (likely after implementing reference data lookup).*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:181`** – `// TODO: Uncomment when Core Data entities are implemented` (cacheProperty call) – *After creating a property on the server, caching it locally is commented out. It should be activated once the `cacheProperty` Core Data method/entity is ready.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:186`** – `// TODO: Uncomment when Core Data entities are implemented` (pending photo updates) – *Intended to update any pending photo-upload records with the new property’s ID. This logic is on hold until offline photo upload entities exist.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:202`** – `// TODO: Uncomment when Core Data entities are implemented`
  &#x20;– *In the catch block after creating a property, there’s a commented-out cache of the property. Also pending the Core Data integration.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:220`** – `// TODO: Uncomment when Core Data entities are implemented` (caching transfer) – *After creating a transfer offer, the code would cache it locally; currently commented out.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:226`** – `// TODO: Uncomment when Core Data entities are implemented` (caching transfer) – *Another point where caching a transfer locally is skipped due to missing Core Data support.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:232`** – `// TODO: Uncomment when Core Data entities are implemented` (caching transfer) – *Similarly, caching transfer data after a different operation is disabled for now.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:242`** – `// TODO: Uncomment when PendingPhotoUpload entity is implemented`
  &#x20;– *In `uploadPendingPhotos()`, the code to fetch pending photos from Core Data and upload each is commented out. A placeholder `debugPrint` indicates this will be implemented once the `PendingPhotoUpload` entity and `uploadPhoto` logic are in place.*

* **`ios/HandReceipt/Services/OfflineSyncService.swift:311`** – `// TODO: Store in Core Data with pending_sync flag`
  &#x20;– *In `queuePropertyCreation`, instead of persisting the queued operation, the code currently just logs to an in-memory array. The comment notes that it should save to Core Data (marking the property as pending sync) once offline persistence is set up.*

* **`ios/HandReceipt/Views/Settings/SettingsView.swift:226`** – `// TODO: Implement actual cache clearing`
  &#x20;– *The `clearCache()` action simply prints a message. The real implementation should purge cached app data (e.g. stored Core Data or file caches).*

* **`ios/HandReceipt/Views/Settings/SettingsView.swift:231`** – `// TODO: Calculate actual storage`
  &#x20;– *The `calculateStorageUsed()` function returns a hard-coded “42.3 MB”. It should compute the real storage usage of the app’s data (perhaps by checking file sizes, database sizes, etc.).*

* **`ios/HandReceipt/Views/Settings/SettingsView.swift:244`** – `// TODO: Get actual last sync time`
  &#x20;– *The UI for “Last Sync Time” is using a placeholder “2 minutes ago”. This should be replaced with the actual timestamp of the last successful sync (likely stored in user defaults or Core Data once offline sync is implemented).*

* **`ios/HandReceipt/ViewModels/TransfersViewModel.swift:61`** – `// TODO: We need access to the current user's ID to implement direction filtering correctly...`
  &#x20;– *The view-model currently ignores the “Incoming/Outgoing” filter for transfers because it doesn’t have the current user’s ID. This comment indicates the design to inject or determine the user’s ID (via an Auth model or session) so that it can filter transfers by whether the user is sender or recipient.*

* **`ios/HandReceipt/ViewModels/TransfersViewModel.swift:110`** – `// TODO: Update API call if backend supports server-side filtering for status/direction`
  &#x20;– *The `fetchTransfers()` method always fetches all transfers and filters on the client. This note suggests that if the backend can query transfers by status or direction, the API call should be adjusted to pass those parameters instead of fetching everything.*

*(Any occurrences of `pass` or `return None` were not found in this codebase – the placeholders above are indicated via comments, dummy returns, or throwing not-implemented errors.)*

## 2. Implementation Suggestions for Key TODOs/Stubs

### **Offline Sync & Core Data Integration (iOS)**

The offline sync system is largely stubbed out. To implement it:

1. **Define Core Data Entities:** Add the missing entities (`SyncQueueItem`, `CachedProperty`, `CachedTransfer`, `PendingPhotoUpload`, etc.) to the `.xcdatamodeld`. For example, `SyncQueueItem` might have fields like `id (UUID)`, `action` (e.g. "CREATE\_PROPERTY"), `endpoint`/`payload` (for the request data), `status` (`pending/failed/completed`), timestamps, etc. Similarly, define `CachedProperty` and `CachedTransfer` to mirror the server’s `Property` and `Transfer` models for offline storage, and `PendingPhotoUpload` to store photo data and a hash/status.
2. **Implement CoreDataStack Methods:** Un-comment and flesh out the methods in **CoreDataStack.swift**. For instance:

   * `addToSyncQueue(action:endpoint:payload:)`: Create a `SyncQueueItem` object in a background context, set its fields (use `JSONSerialization` to store payload dictionaries as Data), mark status as "pending", then save the context.
   * `getPendingSyncItems(limit:)`: Fetch `SyncQueueItem` objects with status `"pending"`, sorted by priority or creation date.
   * `updateSyncItemStatus(item:status:errorMessage:)`: Mark a given `SyncQueueItem` as "completed" or "failed" with timestamp and error info, increment retry count if failed.
   * Similarly, implement `cacheProperty(_:)` and `cacheTransfer(_:)` to save or update `CachedProperty/Transfer` entries (perhaps upsert by ID) so the app can quickly access recently viewed items offline. Use a background context, fetch existing object by ID, update or insert accordingly, then save.
   * `getCachedProperties()` / `getCachedTransfers()`: fetch from Core Data for display in UI when offline.
   * In `queuePhotoUpload(propertyId:imageData:)`: create a `PendingPhotoUpload` object with a generated UUID, store the image binary (or file path) and property ID, plus a calculated SHA-256 hash of the image for integrity.
   * A method to fetch pending photo uploads (`getPendingPhotoUploads`) can retrieve all `PendingPhotoUpload` with status "pending".
3. **OfflineSyncService Logic:** With Core Data support in place, integrate it in **OfflineSyncService.swift**:

   * Enable and implement `processSyncQueue()`. For example, fetch pending sync items from CoreDataStack (`coreDataStack.getPendingSyncItems()`), then for each item:

     * Inspect the `action/endpoint` to determine which API call to make (e.g. if action == "CREATE\_PROPERTY", call `apiService.createProperty` with the stored payload). This can be done in an async loop.
     * On success, remove the item or mark it completed. On failure, update its status and perhaps leave it for retry (increment `retryCount`). You might use a maximum retry policy and if exceeded, mark as failed.
     * Save changes via CoreDataStack. Optionally, after processing, call a CoreDataStack method to clean up all "completed" items (the commented-out code hints at using `NSBatchDeleteRequest` to delete processed items).
   * In `syncAll()`, un-comment the call to `processSyncQueue()` so that whenever the app regains connectivity, it will flush queued operations to the server.
   * Implement `uploadPendingPhotos()`: retrieve pending photo uploads from Core Data (e.g. `coreDataStack.getPendingPhotoUploads()`), log how many, and iterate through them. For each:

     * Read the image file or data, verify its SHA-256 hash matches the saved hash (to ensure the file wasn’t corrupted).
     * Call an API endpoint to upload the photo. *(This requires adding a corresponding endpoint in APIService; for example, an `uploadPhoto(propertyId:imageData:hash:)` method.)*.
     * On success, mark the `PendingPhotoUpload` status as "COMPLETED" and possibly remove the local file to save space. On failure, increment `retryCount` and if too many retries, mark it "FAILED". Save these changes.
     * You may perform photo uploads in parallel or sequentially; since this is within a `Task`, using `await` sequentially is acceptable if the number is small, or use `TaskGroup` for parallel uploads if needed.
   * In `queuePropertyCreation(_ property, photoData)`: instead of just logging to `pendingSyncOperations`, actually persist this intent. For example, create a new `SyncQueueItem` with action "CREATE\_PROPERTY", endpoint "/property", payload containing the property data (and perhaps a reference to photo if available), and status "pending". Save it via CoreDataStack (this will be picked up by the next sync). This way, if the app is closed, the queued creation isn’t lost.
   * The same approach can be applied to other queuing functions (e.g., if `queueTransferCreation` exists, queue a "CREATE\_TRANSFER" action with needed details).
4. **Last Sync Time:** Once the above is in place, each sync cycle could update a timestamp in UserDefaults or a small Core Data record for “lastSyncTime”. The `SettingsView.getLastSyncTime()` can then pull that real value instead of a placeholder.
5. **Testing:** After implementing, test by putting the device offline, performing an action (create property, etc.), then coming online to ensure the sync queue processes correctly, the data gets to the server, and local caches update. Also ensure the UI (e.g., “My Properties” list) uses cached data when offline (using `CachedProperty` objects).

Overall, this turns the placeholders into a robust offline mode: the app will accumulate changes in Core Data while offline and flush them when connectivity is restored. The coding style in the project favors using Core Data on background threads (`context.perform`) and printing debug logs on success/failure, so follow that pattern. Make sure to handle errors gracefully (update statuses, etc.) rather than using `fatalError` so that the app continues running even if a sync item fails.

### **NSN Data Refresh & External API Integration (Backend)**

The NSN service is intended to fetch and cache National Stock Number data, but the refresh function is a stub. To implement the TODOs in **NSNService**:

1. **Configure Data Source:** Determine the external source of NSN data. The code references a `config.NSNConfig.APIEndpoint` – presumably a URL for a government NSN API or an internal service. Ensure this is set in configuration. If an official API exists (or a CSV dataset), use that. For example, an endpoint might return JSON for a given NSN or allow bulk retrieval.
2. **Implement `RefreshCachedNSNData`:** This function should call the external API to update the local NSN database:

   * If an **official API**: perform an HTTP GET (using `s.client`, which is an `http.Client` already in NSNService). Possibly the service returns all updates since last fetch or the entire dataset. Stream the response if it’s large (e.g., if it’s a big JSON or CSV dump).
   * If the data is provided via **files (CSV)**: the function could download the latest NSN catalog file and then reuse the CSV parsing logic that is already in `ImportFromCSV`.
   * In either case, parse the incoming data. For example, if JSON, unmarshal into appropriate structs (`NSNDetails` or a list of them). If CSV, you might reuse the CSV reader approach similar to `ImportFromCSV` (which reads line by line and batches inserts).
   * Update the database: use the GORM `db` field to upsert records. Likely:

     * Find existing NSN by key and update, or insert new. You might use `nsnRepository.BulkSave(...)` if provided, or perform a loop of create/update.
     * If the data source is complete (full list of NSNs), you might also remove entries that are no longer present. There is a `DeleteOld(ctx, olderThan…)` in `NSNRepository` – perhaps you set a timestamp on each NSN and then remove those not updated in the refresh window.
   * Consider wrapping the refresh in a transaction if possible, or mark new data as it comes. Given potential size, batch the updates (the existing code batches 100 records for CSV imports for efficiency).
   * Use locking or a mutex if concurrent calls are possible, since `RefreshCachedNSNData` may be triggered by an admin endpoint. The `NSNService` has a `rateLimiter` channel and cache; ensure refresh doesn’t conflict with read operations. You might set a flag or acquire a write lock during refresh.
   * Finally, update in-memory cache if used. The struct has `cache *cache.Cache` (from “patrickmn/go-cache”). If this cache is used for NSN lookups, the refresh should either clear and repopulate it, or at least invalidate stale entries. For example, after updating the DB, you could do `s.cache.Flush()` and maybe pre-load some frequently used NSNs.
   * Log the outcome: number of records fetched/updated, etc., then log “NSN data refresh completed” (as already in code).
3. **Implement `fetchFromExternalAPI(nsn)`:** This helper is called when a specific NSN isn’t found in the local DB (presumably to live-fetch it). Replace the placeholder by actually performing the request:

   * Construct the external API URL using the NSN (the `NSNConfig` may include a base URL). For example: `GET https://api.nsn.example.com/nsn/1234-00-ABC-...`.
   * Send the request via `s.client`. Handle errors or non-200 responses (return an error if the item can’t be fetched).
   * Parse the JSON (or XML, etc.) from the response into an `NSNRecord` or `NSNDetails`. The code defines an `NSNDetails` struct for external data which includes nomenclature, price, manufacturer, etc. Map the API response into this structure.
   * Save the data: You can convert `NSNDetails` into your `models.NSNData` (which likely corresponds to the GORM model for NSN records) and either save to the database via `NSNRepository.Save`, or directly insert with GORM. This ensures the NSN will be available next time without another API call.
   * Update the in-memory cache: e.g., `s.cache.Set(nsn, details, defaultExpiration)` so future lookups use the cached value.
   * Return the populated `NSNRecord/Details`. If nothing is found (API returns 404 or empty), return a not-found error so the caller (NSNHandler) can respond accordingly.
4. **NSN Import/Cache Stats:** The admin import (CSV upload) is already implemented. After adding refresh, also consider the “RefreshCache” endpoint: it should call `RefreshCachedNSNData`. Since we implement that, the `ImportCSV` and `RefreshCache` admin routes will both populate the NSN store. Ensure that one does not override the other’s data in unintended ways (e.g., if both are invoked).

   * The “GetCacheStats” (GetCacheStats handler calls `service.GetCacheStats()`) should reflect meaningful info. If not already done, implement `GetCacheStats` to return metrics like cache item count, maybe last refresh time, etc. If using go-cache, you can get item count from it. Also you might include database counts (the code’s `GetStatistics` already returns total records and category counts). Integrating these stats into one response could be useful.
5. **Testing:** After implementation, test the following scenarios:

   * NSN lookup for an NSN that is in DB vs not in DB (to ensure `fetchFromExternalAPI` triggers and populates correctly).
   * The `/api/nsn/refresh` endpoint: after invoking it, verify that new or updated NSNs appear in the database (and maybe the in-memory cache).
   * Performance: if the NSN dataset is large (thousands of records), ensure the refresh process is reasonably fast (batching inserts, perhaps using transactions or bulk operations). Also ensure it doesn’t block the application server excessively – you might execute heavy refresh logic in a separate goroutine if needed, while returning an immediate response (or use a long-running request with proper timeouts).
   * Ensure that during refresh, normal NSN lookups either wait or still serve old data. One approach is to lock writes during refresh, but allow reads; another is to serve stale cache data until new data is ready, then swap. Given the application context (inventory data that doesn’t change rapidly), a brief period of stale data is likely acceptable.

By completing these steps, the NSN service will no longer use placeholder logic. Instead, it will maintain an up-to-date local NSN database by periodically pulling from authoritative sources, and fetch on-demand details for NSNs not yet seen. This aligns with the intended use of the `publog` integration mentioned in the code (possibly referring to a public logistics dataset) and ensures the app can provide NSN details even offline or under heavy use.

### **Ledger History & Correction Events (Immutable Ledger Service)**

Several methods in **ImmuDBLedgerService** are left as stubs, which are critical for audit trail and history features. Here’s how to flesh them out:

1. **GetPropertyHistory(propertyID)**: Instead of returning a placeholder note, implement a retrieval of all ledger events for a given item:

   * **Approach A (Key Scanning in ImmuDB):** If events were stored in ImmuDB with keys that include the property or item ID, use an ImmuDB client method to scan keys. For example, if keys were prefixed like `"item_<ID>_"`, you could fetch all keys with that prefix. The ImmuDB client library might support iterating through keys. If not, one workaround is to maintain, in parallel, a simple index in a regular database.
   * **Approach B (Maintain Index):** On every `LogPropertyCreation/LogTransferEvent/...`, also insert a row in a relational table (e.g., `PropertyEvents`) with the itemID and a reference to the ledger entry (or a copy of the event data). Then `GetPropertyHistory` could simply query this SQL table for all events matching the property. This denormalizes the ledger data for easy querying, at the cost of duplicate storage. Given immutability requirements, the SQL copy is just for convenience; the source of truth is still ImmuDB.
   * **Approach C (ImmuDB SQL integration):** If using ImmuDB’s experimental SQL or history features, you might directly query the ledger database if it were set up with tables. However, in this code it appears events are stored via `s.client.Set(key, value)`. So likely Approach A or B is needed.
   * For simplicity, let’s assume Approach A using key patterns: Suppose keys were formatted like `"property_<propertyID>_<timestamp>"` for each event. You could:

     * Use `s.client.Scan(prefix)` or similar if available, to get all keys for `property_<ID>_`. (ImmuDB’s API provides functions like `Scan` or `ZScan` for sorted sets. The basic key-value store might not easily list by prefix, but one can store a secondary index inside ImmuDB, e.g., as a sorted set of keys per property.)
     * Retrieve each event by key (using `s.client.Get(key)` which you already use in `VerifyDocument`) and unmarshal the JSON back into a map or a domain struct.
     * Collect all events, sort them by timestamp (if not inherently sorted by key), and return them as a list of maps or a structured history list. The `domain.GeneralLedgerEvent` type could be a union of different event types – if so, map your results to that.
   * If a quick solution is acceptable: since each log method uses a composite key with timestamps (like `"item_creation_<id>_<unixTime>"`), you could fetch *all* ledger entries for the property by scanning through an ImmuDB “reference” of keys. For example, maintain an additional key like `"history_index_<propertyID>"` that appends every new event’s key to a list (ImmuDB doesn’t have a native list, but you could use a sorted set or a JSON array stored under that key).
   * **Return Value:** The code expects `[]map[string]interface{}` for history. So you can return an array of event data maps. Populate each map with the event fields and metadata (event type, timestamp, user, etc.). This would replace the dummy “SystemNote” entry currently returned.
2. **GetAllCorrectionEvents / GetCorrectionEventsByOriginalID / GetCorrectionEventByID**: The Correction Events are likely a special subset of ledger events that denote corrections to previous records (maybe analogous to append-only corrections). The placeholders currently return empty or nil. To implement:

   * Ensure that `LogCorrectionEvent(originalEventID, ...)` (presumably implemented elsewhere) actually writes a correction event to ImmuDB. It likely uses a key containing the original event’s ID and marks it as a correction.
   * *Option 1:* Use a similar strategy as above: e.g., keep a sorted set or index of all correction events in ImmuDB. For instance, every time a correction is logged, also append its key to a `corrections_index` list (or maybe the keys themselves have a prefix like `"correction_"`). Then:

     * `GetAllCorrectionEvents` would scan that index or all keys starting with `"correction_"` and retrieve each event, convert to `domain.CorrectionEvent` (make sure this domain struct matches what was stored).
     * `GetCorrectionEventsByOriginalID(originalEventID)` could filter the above list by matching a field `original_event_id == originalEventID`. If storing events as JSON, that field is part of the value; you’d need to check it after unmarshaling. Alternatively, if keys are structured like `"correction_<originalEventID>_<something>"`, you could scan by prefix `"correction_<originalEventID>"` to directly fetch those.
     * `GetCorrectionEventByID(eventID)` implies each correction event itself has an ID (maybe a UUID or ledger sequence). If the keys or values contain a unique ID, you can retrieve by that. Perhaps the `eventID` here refers to ImmuDB’s transaction ID or a GUID stored in the event details. If the latter, consider maintaining a mapping from that ID to the key. (For example, include the correction’s own ID in the JSON and also store a separate KV of `correction:<ID> -> eventKey` for quick lookup.)
   * *Option 2:* Simpler but less ideal – since these might not be too many, you could implement `GetAllCorrectionEvents()` by calling `GetGeneralHistory()` (once implemented) and filtering events of type "Correction". However, that could be inefficient if the history is large.
   * In either approach, populate and return slices of `domain.CorrectionEvent` objects. This likely involves mapping the generic event map to the strongly-typed `CorrectionEvent` domain struct. Ensure fields like reason, originalEventID, userID, etc., are filled.
   * For `GetCorrectionEventByID`, if no direct lookup is available, you could call `GetAllCorrectionEvents()` and then find the one with matching ID. But ideally, have an index or direct key for it. Since the placeholder returns a “not found” error with the ID included, implementing this properly will probably require storing correction events such that they can be retrieved by an ID (perhaps the key itself could be the ID if we use a UUID as the key).
3. **GetGeneralHistory**: This is meant to return a consolidated list of all ledger events (possibly across all types: property events, transfers, verifications, corrections, etc.). As noted in the TODO, adding filters would be ideal, but at minimum:

   * Retrieve all events. If using ImmuDB alone, this is tricky without scanning every key. If the ledger events are stored in a dedicated ImmuDB database or table, one approach is to maintain a chronological log. For example, every event logged could also be inserted into a separate structure (like an ImmuDB `Set` or a SQL table) with a timestamp that can be sorted.
   * A practical solution: If `Log...` functions also log to a traditional database table `GeneralLedgerEvents` (with fields: eventType, itemID, userID, timestamp, details, etc.), then `GetGeneralHistory()` can just do a SQL SELECT of all events (or the most recent N) and map to `domain.GeneralLedgerEvent`.
   * If sticking to ImmuDB: you might have to scan a range of keys if they share a common ordering. The code keys all have timestamps in them, but they are prefixed by type. ImmuDB doesn’t inherently sort across different prefixes. In absence of a global index, another approach is to combine results from each type-specific query (e.g., get all properties events, all transfers, etc., then merge-sort by timestamp). That could be done by:

     * Getting all keys for property events, transfers events, etc., as separate lists.
     * Decoding them and merging the sorted lists by the timestamp field inside.
   * The comment suggests adding query params like time range or user filter. You could plan to accept optional parameters (perhaps from the handler via query strings) and apply them to whichever data source you use (SQL query with WHERE clauses, or filter the in-memory merged list).
   * For now, implement the basic version: return everything (or maybe impose a sane limit, e.g., last 100 events to avoid huge payloads). This will replace the empty slice placeholder.
4. **Cryptographic Document Verification Route:** Though not explicitly asked in the list, for completeness, the TODO in routes for “full cryptographic document verification” likely ties into verifying the integrity of ledger data. Implementation strategy:

   * If using Azure SQL Ledger or ImmuDB, each has a way to verify the entire chain. For Azure SQL Ledger, one would call a stored procedure or use the digest to confirm no tampering. For ImmuDB, the client can fetch a global state or use `client.VerifiedGet` which ensures the server’s proof of inclusion.
   * A concrete approach for ImmuDB: each `storeEvent` could store and then immediately verify using `client.VerifiedSet` or retrieving the state root. To verify after the fact, you could retrieve the root hash from ImmuDB and compare it with a trusted root (or ask ImmuDB to verify a key’s inclusion and consistency). For now, if implementing the route, it could simply call `VerifyDocument(documentID, tableName)` on the ledger service for each relevant table or item and aggregate results. Because the ledger service’s `VerifyDocument` for ImmuDB currently just checks existence, a full implementation would involve more rigorous cryptographic checks (which ImmuDB client libraries typically handle internally). This might be a longer-term feature.
5. **Testing & Verification:** After implementing these:

   * Log some events (create a property, transfer, etc.), then call the new endpoints for history and corrections. Ensure that the data returned matches what was logged.
   * Create a correction event (if that feature exists, e.g., a user edits an entry creating a correction log) and test the correction queries.
   * If using a relational table for indexing, verify that it stays in sync with ImmuDB writes (perhaps wrap ledger writes in a function that logs to both places, and handle rollback if one fails).
   * Test edge cases: property with no history should return empty list (not error), an unknown correction ID returns not found, etc.
   * Performance: if the history is large, ensure the approach (especially if merging lists in memory) is efficient enough. Add pagination parameters as noted, so the client can request history in chunks rather than everything at once.

By implementing these, the system’s audit trail features will move from placeholders to functional. Users will be able to retrieve a property’s entire history of changes, verify ledger entries, and view any corrections, which are central to an immutable ledger-backed system. The coding style here should continue to emphasize not failing hard; e.g., return errors where appropriate rather than panicking, and use the existing `logrus` logger for any error logging (as seen in other handlers).

### **Security and Role-Based Access Control Improvements**

Some security-related todos should be addressed to harden the application:

* **JWT Secret Configuration (Auth Middleware)**: Remove the hard-coded `"your-secret-key"` default. Instead, make it mandatory to supply a secret via config or environment. For example, on startup, if `viper.GetString("auth.jwt_secret")` is empty and no env var is set, **refuse to start** or generate a secure random secret and log a strong warning. This ensures tokens are properly signed. In code, you might do:

  ```go
  secret := viper.GetString("auth.jwt_secret")
  if secret == "" {
      log.Fatal("JWT secret not configured – aborting startup")
  }
  ```

  (In development you can allow a dummy, but in production never use a placeholder.)
* **Session Secret**: Similar to JWT, ensure `auth.session_secret` is provided. The code currently falls back to a default and prints a warning. For production, consider making that fatal or at least very explicit to change it.
* **Implement Role Middleware**: The NSN admin routes hint at a `middleware.RequireRole("admin")` usage. To implement this:

  1. Determine how user roles are stored. Perhaps the `users` table has a role field or a separate roles table. Assume each user has a role like "user", "admin", etc.
  2. When a user logs in or their JWT is created, include the role in the token claims (or fetch from DB in session middleware). For example, extend the JWT `Claims` to include a `Role` field, and set it on login. Or, store the user’s role in the session cookie (`session.Set("user_role", role)` on login).
  3. Implement `RequireRole(allowedRoles... string) gin.HandlerFunc`. This middleware will:

     * Look up the user’s role from context. In the session-based approach, after `SessionAuthMiddleware` runs, you might have user ID in context; use that to query the DB for the role (and cache it short-term). Or if `user_role` was set in session (as the placeholder code expects with `c.GetString("user_role")`), retrieve it.
     * If the user’s role is not in the `allowedRoles` list, respond with 403 Forbidden (as done in the placeholder). Otherwise, call `c.Next()` to proceed.
  4. Attach this middleware to routes: e.g., in `nsn_routes.go`, use it for the adminGroup:

     ```go
     adminGroup := nsnGroup.Group("")
     adminGroup.Use(middleware.RequireRole("admin","super_admin"))
     {
         adminGroup.POST("/import", handler.ImportCSV)
         ...
     }
     ```

     This would replace the inline placeholder check currently in `ImportCSV` handler.
  5. Repeat for any other admin endpoints (user management, etc.) as needed.
  6. **Testing**: Create a normal user token and an admin token, ensure that admin-only endpoints are inaccessible to the normal user (get 403), but work for admin. Also test what happens if no role is present – probably default to safest (deny access).
* **Password Handling**: (Not explicitly in TODOs, but worth mentioning) If any part of the code uses plain secrets or placeholders (like default credentials), ensure to replace them. E.g., the default admin credentials or any “change-me” defaults in config should be documented and enforced to change in production.
* **Email Service Initialization**: As noted, currently the email service is a stub. For a production-ready system, integrate a proper email sender:

  * Implement an `EmailService` (if one isn’t already in code) that has a method `SendEmail(emailRequest EmailRequest) error`. Possible implementations:

    * Use an SMTP library (Go’s `net/smtp`) to connect to an SMTP server. Config could provide SMTP host, port, user, pass. The `SendEmail` method constructs the MIME message with attachments (the code already Base64-encodes the PDF and prepares the MIME parts in `DA2062EmailService`), then sends it out via SMTP.
    * Or integrate a service like AWS SES, SendGrid, etc. (via their API or SDK).
  * Initialize this in `main` or `SetupRoutes`: for example, if using SMTP, do:

    ```go
    smtpService := email.NewSMTPService(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPass)
    emailService := email.NewDA2062EmailService(smtpService)
    da2062Handler := handlers.NewDA2062Handler(..., emailService)
    ```

    This provides a real email sender to the DA2062 handler. The TODO at routes.go:48 would be resolved by removing the stub `&email.DA2062EmailService{}` and using the constructed service.
  * Ensure to handle errors (if email fails to send, the handler should return an error response). Possibly, queue email sending in background if it’s slow (to not block the API response), but since sending a single email is usually quick, it could be done inline with proper timeouts.
  * Test by triggering the DA2062 generation feature and confirming an email is sent to the specified recipients with the PDF attached.

By addressing these, we ensure the application is secure and that critical admin operations are protected. The coding style in this project uses `logrus` for warnings (e.g., printing a WARNING for default secrets) and `gin` middleware for auth checks, so follow those conventions. For example, the new middleware should use `c.JSON(http.StatusForbidden, gin.H{"error": "Insufficient permissions"})` as in the placeholder. Similarly, externalizing secrets to config and failing fast if not provided aligns with twelve-factor app principles and avoids accidentally running with insecure defaults.
