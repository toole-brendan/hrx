import { pgTable, text, serial, integer, boolean, timestamp, decimal, bigint, jsonb } from "drizzle-orm/pg-core";

// Users Table - Updated with military fields
export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  username: text("username").notNull().unique(),
  email: text("email").unique(),
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

// Property Types Table
export const propertyTypes = pgTable("property_types", {
  id: serial("id").primaryKey(),
  name: text("name").notNull().unique(),
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// Property Models Table
export const propertyModels = pgTable("property_models", {
  id: serial("id").primaryKey(),
  propertyTypeId: integer("property_type_id").references(() => propertyTypes.id).notNull(),
  modelName: text("model_name").notNull(),
  manufacturer: text("manufacturer"),
  nsn: text("nsn").unique(),
  description: text("description"),
  specifications: jsonb("specifications"),
  imageUrl: text("image_url"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// Properties Table - Renamed from inventoryItems and enhanced
export const properties = pgTable("properties", {
  id: serial("id").primaryKey(),
  propertyModelId: integer("property_model_id").references(() => propertyModels.id),
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

// QR Codes Table - DEPRECATED (Phase 1 refactor)
export const qrCodes = pgTable("qr_codes", {
  id: serial("id").primaryKey(),
  propertyId: integer("property_id").references(() => properties.id).notNull(),
  qrCodeData: text("qr_code_data").notNull(),
  qrCodeHash: text("qr_code_hash").notNull().unique(),
  generatedByUserId: integer("generated_by_user_id").references(() => users.id).notNull(),
  isActive: boolean("is_active").default(true).notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  deactivatedAt: timestamp("deactivated_at"),
  deprecatedAt: timestamp("deprecated_at"), // Added for Phase 1 deprecation
});

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

// ImmuDB References Table - For audit trail integration
export const immudbReferences = pgTable("immudb_references", {
  id: serial("id").primaryKey(),
  entityType: text("entity_type").notNull(),
  entityId: integer("entity_id").notNull(),
  immudbKey: text("immudb_key").notNull(),
  immudbIndex: bigint("immudb_index", { mode: "number" }).notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// NSN Catalog Tables (keeping existing structure)

// NSN Items Table
export const nsnItems = pgTable("nsn_items", {
  nsn: text("nsn").primaryKey(),
  niin: text("niin").notNull(),
  fsc: text("fsc").notNull(),
  fscName: text("fsc_name"),
  itemName: text("item_name").notNull(),
  incCode: text("inc_code"),
  lin: text("lin"),
  unitOfIssue: text("unit_of_issue"),
  unitPrice: text("unit_price"), // Using text to avoid precision issues
  demilCode: text("demil_code"),
  shelfLifeCode: text("shelf_life_code"),
  hazmatCode: text("hazmat_code"),
  preciousMetalIndicator: text("precious_metal_indicator"),
  itemCategory: text("item_category"),
  description: text("description"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

// NSN Parts Table
export const nsnParts = pgTable("nsn_parts", {
  id: serial("id").primaryKey(),
  nsn: text("nsn").references(() => nsnItems.nsn).notNull(),
  partNumber: text("part_number").notNull(),
  cageCode: text("cage_code").notNull(),
  manufacturerName: text("manufacturer_name"),
  isPrimary: boolean("is_primary").default(false),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// LIN Items Table
export const linItems = pgTable("lin_items", {
  lin: text("lin").primaryKey(),
  nomenclature: text("nomenclature").notNull(),
  typeClassification: text("type_classification"),
  ui: text("ui"),
  aac: text("aac"),
  slc: text("slc"),
  ciic: text("ciic"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// CAGE Codes Table
export const cageCodes = pgTable("cage_codes", {
  cageCode: text("cage_code").primaryKey(),
  companyName: text("company_name").notNull(),
  address: text("address"),
  city: text("city"),
  state: text("state"),
  country: text("country"),
  status: text("status"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

// NSN Synonyms Table
export const nsnSynonyms = pgTable("nsn_synonyms", {
  id: serial("id").primaryKey(),
  nsn: text("nsn").references(() => nsnItems.nsn).notNull(),
  synonym: text("synonym").notNull(),
  synonymType: text("synonym_type"), // 'common_name', 'abbreviation', 'slang'
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

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

// Export types for all tables

// User Types
export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

// Property Types
export type PropertyType = typeof propertyTypes.$inferSelect;
export type InsertPropertyType = typeof propertyTypes.$inferInsert;

export type PropertyModel = typeof propertyModels.$inferSelect;
export type InsertPropertyModel = typeof propertyModels.$inferInsert;

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

// QR Code Types
export type QrCode = typeof qrCodes.$inferSelect;
export type InsertQrCode = typeof qrCodes.$inferInsert;

// Attachment Types
export type Attachment = typeof attachments.$inferSelect;
export type InsertAttachment = typeof attachments.$inferInsert;

// Sync Types
export type OfflineSyncQueue = typeof offlineSyncQueue.$inferSelect;
export type InsertOfflineSyncQueue = typeof offlineSyncQueue.$inferInsert;

export type ImmudbReference = typeof immudbReferences.$inferSelect;
export type InsertImmudbReference = typeof immudbReferences.$inferInsert;

// NSN Types
export type NsnItem = typeof nsnItems.$inferSelect;
export type InsertNsnItem = typeof nsnItems.$inferInsert;

export type NsnPart = typeof nsnParts.$inferSelect;
export type InsertNsnPart = typeof nsnParts.$inferInsert;

export type LinItem = typeof linItems.$inferSelect;
export type InsertLinItem = typeof linItems.$inferInsert;

export type CageCode = typeof cageCodes.$inferSelect;
export type InsertCageCode = typeof cageCodes.$inferInsert;

export type NsnSynonym = typeof nsnSynonyms.$inferSelect;
export type InsertNsnSynonym = typeof nsnSynonyms.$inferInsert;

export type CatalogUpdate = typeof catalogUpdates.$inferSelect;
export type InsertCatalogUpdate = typeof catalogUpdates.$inferInsert;
