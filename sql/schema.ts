import { pgTable, text, serial, integer, boolean, timestamp, decimal, bigint, jsonb } from "drizzle-orm/pg-core";

// Users Table - Updated with military fields
export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  email: text("email").notNull().unique(),
  password: text("password").notNull(),
  firstName: text("first_name"),
  lastName: text("last_name"),
  name: text("name").notNull(),
  rank: text("rank"),
  unit: text("unit"),
  role: text("role").default("user"),
  phone: text("phone"),
  dodid: text("dodid").unique(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// NSN Records Table (Simplified NSN catalog)
export const nsnRecords = pgTable("nsn_records", {
  id: bigint("id", { mode: "number" }).primaryKey(),
  nsn: text("nsn").unique(),
  lin: text("lin"),
  itemName: text("item_name").notNull(),
  description: text("description"),
  category: text("category"),
  unitOfIssue: text("unit_of_issue"),
  unitPrice: decimal("unit_price", { precision: 12, scale: 2 }),
  hazmatCode: text("hazmat_code"),
  demilCode: text("demil_code"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// Properties Table - The main property tracking table
export const properties = pgTable("properties", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  serialNumber: text("serial_number").notNull().unique(),
  description: text("description"),
  currentStatus: text("current_status").notNull(),
  condition: text("condition").default("serviceable"),
  conditionNotes: text("condition_notes"),
  nsn: text("nsn"),
  lin: text("lin"),
  location: text("location"),
  acquisitionDate: timestamp("acquisition_date"),
  unitPrice: decimal("unit_price", { precision: 12, scale: 2 }).default("0"),
  quantity: integer("quantity").default(1),
  photoUrl: text("photo_url"),
  assignedToUserId: integer("assigned_to_user_id").references(() => users.id),
  lastVerifiedAt: timestamp("last_verified_at"),
  lastMaintenanceAt: timestamp("last_maintenance_at"),
  syncStatus: text("sync_status").default("synced"),
  lastSyncedAt: timestamp("last_synced_at"),
  clientId: text("client_id"),
  version: integer("version").default(1),
  // Component association fields
  isAttachable: boolean("is_attachable").default(false),
  attachmentPoints: jsonb("attachment_points"), // ["rail_top", "rail_side", "barrel"]
  compatibleWith: jsonb("compatible_with"), // ["M4", "M16", "AR15"]
  // DA 2062 required fields
  unitOfIssue: text("unit_of_issue").default("EA"),
  conditionCode: text("condition_code").default("A"),
  category: text("category"),
  manufacturer: text("manufacturer"),
  partNumber: text("part_number"),
  securityClassification: text("security_classification").default("U"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// User Connections Table - Friends Network (like Venmo)
export const userConnections = pgTable("user_connections", {
  id: serial("id").primaryKey(),
  userId: integer("user_id").references(() => users.id).notNull(),
  connectedUserId: integer("connected_user_id").references(() => users.id).notNull(),
  connectionStatus: text("connection_status").default("pending").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// Transfers Table - Updated for serial number-based system
export const transfers = pgTable("transfers", {
  id: serial("id").primaryKey(),
  propertyId: integer("property_id").references(() => properties.id).notNull(),
  fromUserId: integer("from_user_id").references(() => users.id).notNull(),
  toUserId: integer("to_user_id").references(() => users.id).notNull(),
  status: text("status").notNull(),
  transferType: text("transfer_type").default("offer").notNull(), // 'request' or 'offer'
  initiatorId: integer("initiator_id").references(() => users.id),
  requestedSerialNumber: text("requested_serial_number"),
  requestDate: timestamp("request_date").defaultNow().notNull(),
  resolvedDate: timestamp("resolved_date"),
  notes: text("notes"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// Transfer Items Table - For bulk transfers
export const transferItems = pgTable("transfer_items", {
  id: serial("id").primaryKey(),
  transferId: integer("transfer_id").references(() => transfers.id).notNull(),
  propertyId: integer("property_id").references(() => properties.id).notNull(),
  quantity: integer("quantity").default(1),
  notes: text("notes"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// Activities Table - Updated to reference properties
export const activities = pgTable("activities", {
  id: serial("id").primaryKey(),
  type: text("type").notNull(),
  description: text("description").notNull(),
  userId: integer("user_id").references(() => users.id),
  relatedPropertyId: integer("related_property_id").references(() => properties.id),
  relatedTransferId: integer("related_transfer_id").references(() => transfers.id),
  timestamp: timestamp("timestamp").defaultNow().notNull(),
});

// Tables below this line are deprecated or removed

// Attachments Table - For photos and documents
export const attachments = pgTable("attachments", {
  id: serial("id").primaryKey(),
  propertyId: integer("property_id").references(() => properties.id).notNull(),
  fileName: text("file_name").notNull(),
  fileUrl: text("file_url").notNull(),
  fileSize: bigint("file_size", { mode: "number" }),
  mimeType: text("mime_type"),
  uploadedByUserId: integer("uploaded_by_user_id").references(() => users.id).notNull(),
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// Offline Sync Queue Table - For iOS offline support
export const offlineSyncQueue = pgTable("offline_sync_queue", {
  id: serial("id").primaryKey(),
  clientId: text("client_id").notNull(),
  operationType: text("operation_type").notNull(), // 'create', 'update', 'delete'
  entityType: text("entity_type").notNull(), // 'property', 'transfer', etc.
  entityId: integer("entity_id"),
  payload: jsonb("payload").notNull(),
  syncStatus: text("sync_status").default("pending"),
  retryCount: integer("retry_count").default(0),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  syncedAt: timestamp("synced_at"),
});

// Ledger References Table - For audit trail integration with Azure SQL Database ledger tables
export const ledgerReferences = pgTable("ledger_references", {
  id: serial("id").primaryKey(),
  entityType: text("entity_type").notNull(),
  entityId: integer("entity_id").notNull(),
  ledgerTransactionId: text("ledger_transaction_id").notNull(),
  ledgerSequenceNumber: bigint("ledger_sequence_number", { mode: "number" }).notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// The old NSN tables have been replaced by the simpler nsnRecords table above

// Catalog Updates Table
export const catalogUpdates = pgTable("catalog_updates", {
  id: serial("id").primaryKey(),
  updateSource: text("update_source").notNull(), // 'PUBLOG', 'MANUAL', etc
  updateDate: timestamp("update_date").notNull(),
  itemsAdded: integer("items_added").default(0),
  itemsUpdated: integer("items_updated").default(0),
  itemsRemoved: integer("items_removed").default(0),
  notes: text("notes"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// Unit of Issue Codes Table
export const unitOfIssueCodes = pgTable("unit_of_issue_codes", {
  code: text("code").primaryKey(),
  description: text("description").notNull(),
  category: text("category"),
  sortOrder: integer("sort_order").default(0),
});

// Property Categories Table
export const propertyCategories = pgTable("property_categories", {
  code: text("code").primaryKey(),
  name: text("name").notNull(),
  description: text("description"),
  isSensitive: boolean("is_sensitive").default(false),
  defaultSecurityClass: text("default_security_class").default("U"),
  sortOrder: integer("sort_order").default(0),
});

// Property Condition History Table
export const propertyConditionHistory = pgTable("property_condition_history", {
  id: serial("id").primaryKey(),
  propertyId: integer("property_id").references(() => properties.id).notNull(),
  previousCondition: text("previous_condition"),
  newCondition: text("new_condition").notNull(),
  changedBy: integer("changed_by").references(() => users.id),
  changedAt: timestamp("changed_at").defaultNow(),
  reason: text("reason"),
  notes: text("notes"),
});

// DA2062 Import Tables
export const da2062Imports = pgTable("da2062_imports", {
  id: bigint("id", { mode: "number" }).primaryKey(),
  fileName: text("file_name").notNull(),
  fileUrl: text("file_url"),
  importedByUserId: bigint("imported_by_user_id", { mode: "number" }).references(() => users.id).notNull(),
  status: text("status").default("pending").notNull(),
  totalItems: integer("total_items").default(0),
  processedItems: integer("processed_items").default(0),
  failedItems: integer("failed_items").default(0),
  errorLog: jsonb("error_log"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  completedAt: timestamp("completed_at"),
});

export const da2062ImportItems = pgTable("da2062_import_items", {
  id: bigint("id", { mode: "number" }).primaryKey(),
  importId: bigint("import_id", { mode: "number" }).references(() => da2062Imports.id).notNull(),
  lineNumber: integer("line_number").notNull(),
  rawData: jsonb("raw_data").notNull(),
  propertyId: bigint("property_id", { mode: "number" }).references(() => properties.id),
  status: text("status").default("pending").notNull(),
  errorMessage: text("error_message"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// Transfer Offers Tables
export const transferOffers = pgTable("transfer_offers", {
  id: bigint("id", { mode: "number" }).primaryKey(),
  propertyId: bigint("property_id", { mode: "number" }).references(() => properties.id).notNull(),
  offeringUserId: bigint("offering_user_id", { mode: "number" }).references(() => users.id).notNull(),
  offerStatus: text("offer_status").default("active").notNull(),
  notes: text("notes"),
  expiresAt: timestamp("expires_at"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  acceptedByUserId: bigint("accepted_by_user_id", { mode: "number" }).references(() => users.id),
  acceptedAt: timestamp("accepted_at"),
});

export const transferOfferRecipients = pgTable("transfer_offer_recipients", {
  id: bigint("id", { mode: "number" }).primaryKey(),
  transferOfferId: bigint("transfer_offer_id", { mode: "number" }).references(() => transferOffers.id).notNull(),
  recipientUserId: bigint("recipient_user_id", { mode: "number" }).references(() => users.id).notNull(),
  notifiedAt: timestamp("notified_at"),
  viewedAt: timestamp("viewed_at"),
});

// Export types for all tables

// User Types
export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

// NSN Records Types
export type NsnRecord = typeof nsnRecords.$inferSelect;
export type InsertNsnRecord = typeof nsnRecords.$inferInsert;

// Property Types
export type Property = typeof properties.$inferSelect;
export type InsertProperty = typeof properties.$inferInsert;

// User Connection Types
export type UserConnection = typeof userConnections.$inferSelect;
export type InsertUserConnection = typeof userConnections.$inferInsert;

// Transfer Types
export type Transfer = typeof transfers.$inferSelect;
export type InsertTransfer = typeof transfers.$inferInsert;

export type TransferItem = typeof transferItems.$inferSelect;
export type InsertTransferItem = typeof transferItems.$inferInsert;

// Activity Types
export type Activity = typeof activities.$inferSelect;
export type InsertActivity = typeof activities.$inferInsert;

// Attachment Types
export type Attachment = typeof attachments.$inferSelect;
export type InsertAttachment = typeof attachments.$inferInsert;

// Sync Types
export type OfflineSyncQueue = typeof offlineSyncQueue.$inferSelect;
export type InsertOfflineSyncQueue = typeof offlineSyncQueue.$inferInsert;

export type LedgerReference = typeof ledgerReferences.$inferSelect;
export type InsertLedgerReference = typeof ledgerReferences.$inferInsert;

// Catalog Update Types
export type CatalogUpdate = typeof catalogUpdates.$inferSelect;
export type InsertCatalogUpdate = typeof catalogUpdates.$inferInsert;

// Unit of Issue Types
export type UnitOfIssueCode = typeof unitOfIssueCodes.$inferSelect;
export type InsertUnitOfIssueCode = typeof unitOfIssueCodes.$inferInsert;

// Property Category Types
export type PropertyCategory = typeof propertyCategories.$inferSelect;
export type InsertPropertyCategory = typeof propertyCategories.$inferInsert;

// Property Condition History Types
export type PropertyConditionHistory = typeof propertyConditionHistory.$inferSelect;
export type InsertPropertyConditionHistory = typeof propertyConditionHistory.$inferInsert;

// DA2062 Import Types
export type Da2062Import = typeof da2062Imports.$inferSelect;
export type InsertDa2062Import = typeof da2062Imports.$inferInsert;

export type Da2062ImportItem = typeof da2062ImportItems.$inferSelect;
export type InsertDa2062ImportItem = typeof da2062ImportItems.$inferInsert;

// Transfer Offer Types
export type TransferOffer = typeof transferOffers.$inferSelect;
export type InsertTransferOffer = typeof transferOffers.$inferInsert;

export type TransferOfferRecipient = typeof transferOfferRecipients.$inferSelect;
export type InsertTransferOfferRecipient = typeof transferOfferRecipients.$inferInsert;

// Document Types
export type Document = typeof documents.$inferSelect;
export type InsertDocument = typeof documents.$inferInsert;

// Property Component Types
export type PropertyComponent = typeof propertyComponents.$inferSelect;
export type InsertPropertyComponent = typeof propertyComponents.$inferInsert;

// Documents Table - For maintenance forms and other documents
export const documents = pgTable("documents", {
  id: serial("id").primaryKey(),
  type: text("type").notNull(), // 'maintenance_form', 'transfer_form', etc.
  subtype: text("subtype"), // 'DA2404', 'DA5988E', etc.
  title: text("title").notNull(),
  senderUserId: integer("sender_user_id").references(() => users.id).notNull(),
  recipientUserId: integer("recipient_user_id").references(() => users.id).notNull(),
  propertyId: integer("property_id").references(() => properties.id),
  formData: jsonb("form_data").notNull(), // Complete form data
  description: text("description"),
  attachments: jsonb("attachments"), // Array of photo URLs
  status: text("status").default("unread").notNull(), // unread, read, archived
  sentAt: timestamp("sent_at").defaultNow().notNull(),
  readAt: timestamp("read_at"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// Notifications Table - For persistent notifications
export const notifications = pgTable("notifications", {
  id: serial("id").primaryKey(),
  userId: integer("user_id").references(() => users.id, { onDelete: "cascade" }).notNull(),
  type: text("type").notNull(), // 'transfer_update', 'transfer_created', 'property_update', 'connection_request', 'connection_accepted', 'document_received', 'general'
  title: text("title").notNull(),
  message: text("message").notNull(),
  data: jsonb("data"), // Additional data for the notification (e.g., transferId, propertyId, etc.)
  read: boolean("read").default(false).notNull(),
  readAt: timestamp("read_at"),
  priority: text("priority").default("normal").notNull(), // 'low', 'normal', 'high', 'urgent'
  expiresAt: timestamp("expires_at"), // Optional expiration date
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// Property Components Table - For component associations
export const propertyComponents = pgTable("property_components", {
  id: serial("id").primaryKey(),
  parentPropertyId: integer("parent_property_id").references(() => properties.id, { onDelete: "cascade" }).notNull(),
  componentPropertyId: integer("component_property_id").references(() => properties.id, { onDelete: "cascade" }).notNull().unique(), // Ensure component can only be attached to one parent
  attachedAt: timestamp("attached_at").defaultNow().notNull(),
  attachedByUserId: integer("attached_by_user_id").references(() => users.id).notNull(),
  notes: text("notes"),
  attachmentType: text("attachment_type").default("field"), // 'permanent', 'temporary', 'field'
  position: text("position"), // 'rail_top', 'rail_side', 'barrel', etc.
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});
