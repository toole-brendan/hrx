import { pgTable, text, serial, integer, boolean, timestamp } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

// Users Table
export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  username: text("username").notNull().unique(),
  password: text("password").notNull(),
  name: text("name").notNull(),
  rank: text("rank").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insertUserSchema = createInsertSchema(users).omit({
  id: true,
  createdAt: true,
});

// Inventory Items Table
export const inventoryItems = pgTable("inventory_items", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  serialNumber: text("serial_number").notNull().unique(),
  description: text("description"),
  category: text("category"),
  status: text("status").notNull(),
  assignedUserId: integer("assigned_user_id").references(() => users.id),
  assignedDate: timestamp("assigned_date"),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insertInventoryItemSchema = createInsertSchema(inventoryItems).omit({
  id: true,
  createdAt: true,
});

// Transfers Table
export const transfers = pgTable("transfers", {
  id: serial("id").primaryKey(),
  itemId: integer("item_id").references(() => inventoryItems.id).notNull(),
  fromUserId: integer("from_user_id").references(() => users.id).notNull(),
  toUserId: integer("to_user_id").references(() => users.id).notNull(),
  status: text("status").notNull(),
  requestDate: timestamp("request_date").defaultNow().notNull(),
  resolvedDate: timestamp("resolved_date"),
  notes: text("notes"),
});

export const insertTransferSchema = createInsertSchema(transfers).omit({
  id: true,
  requestDate: true,
  resolvedDate: true,
});

// Activities Table
export const activities = pgTable("activities", {
  id: serial("id").primaryKey(),
  type: text("type").notNull(),
  description: text("description").notNull(),
  userId: integer("user_id").references(() => users.id),
  relatedItemId: integer("related_item_id").references(() => inventoryItems.id),
  relatedTransferId: integer("related_transfer_id").references(() => transfers.id),
  timestamp: timestamp("timestamp").defaultNow().notNull(),
});

export const insertActivitySchema = createInsertSchema(activities).omit({
  id: true,
  timestamp: true,
});

// Types
export type InsertUser = z.infer<typeof insertUserSchema>;
export type User = typeof users.$inferSelect;

export type InsertInventoryItem = z.infer<typeof insertInventoryItemSchema>;
export type InventoryItem = typeof inventoryItems.$inferSelect;

export type InsertTransfer = z.infer<typeof insertTransferSchema>;
export type Transfer = typeof transfers.$inferSelect;

export type InsertActivity = z.infer<typeof insertActivitySchema>;
export type Activity = typeof activities.$inferSelect;

// NSN Catalog Tables

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

export const insertNsnItemSchema = createInsertSchema(nsnItems).omit({
  createdAt: true,
  updatedAt: true,
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

export const insertNsnPartSchema = createInsertSchema(nsnParts).omit({
  id: true,
  createdAt: true,
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

export const insertLinItemSchema = createInsertSchema(linItems).omit({
  createdAt: true,
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

export const insertCageCodeSchema = createInsertSchema(cageCodes).omit({
  createdAt: true,
});

// NSN Synonyms Table
export const nsnSynonyms = pgTable("nsn_synonyms", {
  id: serial("id").primaryKey(),
  nsn: text("nsn").references(() => nsnItems.nsn).notNull(),
  synonym: text("synonym").notNull(),
  synonymType: text("synonym_type"), // 'common_name', 'abbreviation', 'slang'
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insertNsnSynonymSchema = createInsertSchema(nsnSynonyms).omit({
  id: true,
  createdAt: true,
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

export const insertCatalogUpdateSchema = createInsertSchema(catalogUpdates).omit({
  id: true,
  createdAt: true,
});

// NSN Types
export type InsertNsnItem = z.infer<typeof insertNsnItemSchema>;
export type NsnItem = typeof nsnItems.$inferSelect;

export type InsertNsnPart = z.infer<typeof insertNsnPartSchema>;
export type NsnPart = typeof nsnParts.$inferSelect;

export type InsertLinItem = z.infer<typeof insertLinItemSchema>;
export type LinItem = typeof linItems.$inferSelect;

export type InsertCageCode = z.infer<typeof insertCageCodeSchema>;
export type CageCode = typeof cageCodes.$inferSelect;

export type InsertNsnSynonym = z.infer<typeof insertNsnSynonymSchema>;
export type NsnSynonym = typeof nsnSynonyms.$inferSelect;

export type InsertCatalogUpdate = z.infer<typeof insertCatalogUpdateSchema>;
export type CatalogUpdate = typeof catalogUpdates.$inferSelect;
