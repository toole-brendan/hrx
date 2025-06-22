CREATE TABLE "activities" (
	"id" serial PRIMARY KEY NOT NULL,
	"type" text NOT NULL,
	"description" text NOT NULL,
	"user_id" integer,
	"related_property_id" integer,
	"related_transfer_id" integer,
	"timestamp" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "attachments" (
	"id" serial PRIMARY KEY NOT NULL,
	"property_id" integer NOT NULL,
	"file_name" text NOT NULL,
	"file_url" text NOT NULL,
	"file_size" bigint,
	"mime_type" text,
	"uploaded_by_user_id" integer NOT NULL,
	"description" text,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "catalog_updates" (
	"id" serial PRIMARY KEY NOT NULL,
	"update_source" text NOT NULL,
	"update_date" timestamp NOT NULL,
	"items_added" integer DEFAULT 0,
	"items_updated" integer DEFAULT 0,
	"items_removed" integer DEFAULT 0,
	"notes" text,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "da2062_import_items" (
	"id" bigint PRIMARY KEY NOT NULL,
	"import_id" bigint NOT NULL,
	"line_number" integer NOT NULL,
	"raw_data" jsonb NOT NULL,
	"property_id" bigint,
	"status" text DEFAULT 'pending' NOT NULL,
	"error_message" text,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "da2062_imports" (
	"id" bigint PRIMARY KEY NOT NULL,
	"file_name" text NOT NULL,
	"file_url" text,
	"imported_by_user_id" bigint NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"total_items" integer DEFAULT 0,
	"processed_items" integer DEFAULT 0,
	"failed_items" integer DEFAULT 0,
	"error_log" jsonb,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"completed_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "documents" (
	"id" serial PRIMARY KEY NOT NULL,
	"type" text NOT NULL,
	"subtype" text,
	"title" text NOT NULL,
	"sender_user_id" integer NOT NULL,
	"recipient_user_id" integer NOT NULL,
	"property_id" integer,
	"form_data" jsonb NOT NULL,
	"description" text,
	"attachments" jsonb,
	"status" text DEFAULT 'unread' NOT NULL,
	"sent_at" timestamp DEFAULT now() NOT NULL,
	"read_at" timestamp,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "immudb_references" (
	"id" serial PRIMARY KEY NOT NULL,
	"entity_type" text NOT NULL,
	"entity_id" integer NOT NULL,
	"immudb_key" text NOT NULL,
	"immudb_index" bigint NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "notifications" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"type" text NOT NULL,
	"title" text NOT NULL,
	"message" text NOT NULL,
	"data" jsonb,
	"read" boolean DEFAULT false NOT NULL,
	"read_at" timestamp,
	"priority" text DEFAULT 'normal' NOT NULL,
	"expires_at" timestamp,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "nsn_records" (
	"id" bigint PRIMARY KEY NOT NULL,
	"nsn" text,
	"lin" text,
	"item_name" text NOT NULL,
	"description" text,
	"category" text,
	"unit_of_issue" text,
	"unit_price" numeric(12, 2),
	"hazmat_code" text,
	"demil_code" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "nsn_records_nsn_unique" UNIQUE("nsn")
);
--> statement-breakpoint
CREATE TABLE "offline_sync_queue" (
	"id" serial PRIMARY KEY NOT NULL,
	"client_id" text NOT NULL,
	"operation_type" text NOT NULL,
	"entity_type" text NOT NULL,
	"entity_id" integer,
	"payload" jsonb NOT NULL,
	"sync_status" text DEFAULT 'pending',
	"retry_count" integer DEFAULT 0,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"synced_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "properties" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"serial_number" text NOT NULL,
	"description" text,
	"current_status" text NOT NULL,
	"condition" text DEFAULT 'serviceable',
	"condition_notes" text,
	"nsn" text,
	"lin" text,
	"location" text,
	"acquisition_date" timestamp,
	"unit_price" numeric(12, 2) DEFAULT '0',
	"quantity" integer DEFAULT 1,
	"photo_url" text,
	"assigned_to_user_id" integer,
	"last_verified_at" timestamp,
	"last_maintenance_at" timestamp,
	"sync_status" text DEFAULT 'synced',
	"last_synced_at" timestamp,
	"client_id" text,
	"version" integer DEFAULT 1,
	"is_attachable" boolean DEFAULT false,
	"attachment_points" jsonb,
	"compatible_with" jsonb,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "properties_serial_number_unique" UNIQUE("serial_number")
);
--> statement-breakpoint
CREATE TABLE "property_components" (
	"id" serial PRIMARY KEY NOT NULL,
	"parent_property_id" integer NOT NULL,
	"component_property_id" integer NOT NULL,
	"attached_at" timestamp DEFAULT now() NOT NULL,
	"attached_by_user_id" integer NOT NULL,
	"notes" text,
	"attachment_type" text DEFAULT 'field',
	"position" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "property_components_component_property_id_unique" UNIQUE("component_property_id")
);
--> statement-breakpoint
CREATE TABLE "transfer_items" (
	"id" serial PRIMARY KEY NOT NULL,
	"transfer_id" integer NOT NULL,
	"property_id" integer NOT NULL,
	"quantity" integer DEFAULT 1,
	"notes" text,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transfer_offer_recipients" (
	"id" bigint PRIMARY KEY NOT NULL,
	"transfer_offer_id" bigint NOT NULL,
	"recipient_user_id" bigint NOT NULL,
	"notified_at" timestamp,
	"viewed_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "transfer_offers" (
	"id" bigint PRIMARY KEY NOT NULL,
	"property_id" bigint NOT NULL,
	"offering_user_id" bigint NOT NULL,
	"offer_status" text DEFAULT 'active' NOT NULL,
	"notes" text,
	"expires_at" timestamp,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"accepted_by_user_id" bigint,
	"accepted_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "transfers" (
	"id" serial PRIMARY KEY NOT NULL,
	"property_id" integer NOT NULL,
	"from_user_id" integer NOT NULL,
	"to_user_id" integer NOT NULL,
	"status" text NOT NULL,
	"transfer_type" text DEFAULT 'offer' NOT NULL,
	"initiator_id" integer,
	"requested_serial_number" text,
	"request_date" timestamp DEFAULT now() NOT NULL,
	"resolved_date" timestamp,
	"notes" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_connections" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"connected_user_id" integer NOT NULL,
	"connection_status" text DEFAULT 'pending' NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" serial PRIMARY KEY NOT NULL,
	"email" text NOT NULL,
	"password" text NOT NULL,
	"first_name" text,
	"last_name" text,
	"name" text NOT NULL,
	"rank" text,
	"unit" text,
	"role" text DEFAULT 'user',
	"phone" text,
	"dodid" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "users_email_unique" UNIQUE("email"),
	CONSTRAINT "users_dodid_unique" UNIQUE("dodid")
);
--> statement-breakpoint
ALTER TABLE "activities" ADD CONSTRAINT "activities_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activities" ADD CONSTRAINT "activities_related_property_id_properties_id_fk" FOREIGN KEY ("related_property_id") REFERENCES "public"."properties"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "activities" ADD CONSTRAINT "activities_related_transfer_id_transfers_id_fk" FOREIGN KEY ("related_transfer_id") REFERENCES "public"."transfers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_uploaded_by_user_id_users_id_fk" FOREIGN KEY ("uploaded_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "da2062_import_items" ADD CONSTRAINT "da2062_import_items_import_id_da2062_imports_id_fk" FOREIGN KEY ("import_id") REFERENCES "public"."da2062_imports"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "da2062_import_items" ADD CONSTRAINT "da2062_import_items_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "da2062_imports" ADD CONSTRAINT "da2062_imports_imported_by_user_id_users_id_fk" FOREIGN KEY ("imported_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "documents" ADD CONSTRAINT "documents_sender_user_id_users_id_fk" FOREIGN KEY ("sender_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "documents" ADD CONSTRAINT "documents_recipient_user_id_users_id_fk" FOREIGN KEY ("recipient_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "documents" ADD CONSTRAINT "documents_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "properties" ADD CONSTRAINT "properties_assigned_to_user_id_users_id_fk" FOREIGN KEY ("assigned_to_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "property_components" ADD CONSTRAINT "property_components_parent_property_id_properties_id_fk" FOREIGN KEY ("parent_property_id") REFERENCES "public"."properties"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "property_components" ADD CONSTRAINT "property_components_component_property_id_properties_id_fk" FOREIGN KEY ("component_property_id") REFERENCES "public"."properties"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "property_components" ADD CONSTRAINT "property_components_attached_by_user_id_users_id_fk" FOREIGN KEY ("attached_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfer_items" ADD CONSTRAINT "transfer_items_transfer_id_transfers_id_fk" FOREIGN KEY ("transfer_id") REFERENCES "public"."transfers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfer_items" ADD CONSTRAINT "transfer_items_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfer_offer_recipients" ADD CONSTRAINT "transfer_offer_recipients_transfer_offer_id_transfer_offers_id_fk" FOREIGN KEY ("transfer_offer_id") REFERENCES "public"."transfer_offers"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfer_offer_recipients" ADD CONSTRAINT "transfer_offer_recipients_recipient_user_id_users_id_fk" FOREIGN KEY ("recipient_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfer_offers" ADD CONSTRAINT "transfer_offers_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfer_offers" ADD CONSTRAINT "transfer_offers_offering_user_id_users_id_fk" FOREIGN KEY ("offering_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfer_offers" ADD CONSTRAINT "transfer_offers_accepted_by_user_id_users_id_fk" FOREIGN KEY ("accepted_by_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_property_id_properties_id_fk" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_from_user_id_users_id_fk" FOREIGN KEY ("from_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_to_user_id_users_id_fk" FOREIGN KEY ("to_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transfers" ADD CONSTRAINT "transfers_initiator_id_users_id_fk" FOREIGN KEY ("initiator_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_connections" ADD CONSTRAINT "user_connections_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_connections" ADD CONSTRAINT "user_connections_connected_user_id_users_id_fk" FOREIGN KEY ("connected_user_id") REFERENCES "public"."users"("id") ON DELETE no action ON UPDATE no action;