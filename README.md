# HandReceipt (HRX)

**HandReceipt (HRX)** is a modern, open-source application for military-grade asset and inventory management. It provides a **web-based interface** and a **RESTful API backend** to track equipment, manage hand receipts, and facilitate transfers of property between users with robust accountability. The system unifies a React front-end with a Go back-end, offering features like QR code-based item transfers, real-time notifications, audit logging, and integration with military catalog data – all designed to streamline equipment management in an intuitive, secure way.

## Project Overview

HandReceipt is built to simplify the process of issuing, tracking, and transferring equipment (e.g. weapons, gear, vehicles) among personnel. It combines a front-end web app and a back-end API server into a single cohesive platform for end-to-end property accountability. Key goals of the project include:

* **Accountability:** Maintain a clear chain-of-custody for each item through digital hand receipts (transfer records) and an immutable audit trail.
* **Efficiency:** Use QR codes and a mobile-friendly design to expedite the transfer of items – eliminating paperwork and reducing manual data entry.
* **Accuracy:** Integrate with National Stock Number (NSN) and Line Item Number (LIN) catalogs to auto-fill item details, ensuring consistency with official records.
* **Accessibility:** Provide a responsive web interface (and potential mobile clients) so users can manage inventory and transfers from anywhere, even with intermittent connectivity (offline support with sync is included).
* **Security:** Implement role-based user accounts, JWT authentication, and optional ledgering for tamper-evident records. All data transfers occur over secure APIs with proper access controls and CORS configuration.

By unifying the front-end and back-end in one project, HandReceipt ensures a smooth developer experience and consistent deployments. Whether used by a small unit or integrated into a larger system, HRX can serve as a standalone property book system or complement existing military inventory software.

## Features

* **Inventory Management:** Users can record and view detailed information about each piece of equipment. Each item (termed **Equipment** in the system) has fields for NSN, serial number, nomenclature, condition, status, location, etc. and can have associated attachments (e.g. photos, documents).
* **User Accounts & Roles:** Supports multiple user accounts (e.g. soldiers, supply officers, admins). An initial admin user is created on first run for bootstrapping (email: `admin@handreceipt.com`, password: `password`). Users have profile info including name, rank, unit, and status. (It's recommended to change the default password immediately in a real deployment.)
* **Hand Receipts (Transfers):** The system logs every transfer of equipment on a digital hand receipt. Transfers can represent issues, returns, temporary loans, or permanent transfers, and include metadata like transfer date, purpose, and optional digital signatures. Each hand receipt record links the item, the giver (FromUser) and receiver (ToUser), and tracks status (pending, approved, completed, etc.).
* **QR Code Transfers:** Simplifies field operations by allowing QR-based transfers. A user currently holding an item can generate a QR code for that item on the mobile app or web, which encodes transfer details and a secure hash. Another user can scan this QR code to initiate a transfer request instantly. The back-end verifies the QR data integrity (hash verification) and ensures the item's holder matches before creating a pending transfer request. The current holder then approves or rejects the transfer in the app, completing the hand-off workflow digitally.
* **Approval Workflow:** All transfers require appropriate approval. The current holder must approve a pending transfer (or offer) before ownership changes. Users cannot transfer items to themselves (self-transfers are prevented), and once approved, records update automatically. Rejections or cancellations are recorded along with reasons to maintain an audit trail.
* **Offers & Requests:** In addition to QR-initiated transfers, users can request transfers by serial number or create transfer offers. For example, a user can offer an item to another user, and that user can accept the offer via the API or interface. The system supports listing active offers and accepting them, enabling flexible transfer proposals.
* **Real-Time Notifications:** HandReceipt uses WebSockets for instant notifications. The back-end includes a notification hub service that pushes events to connected clients. For instance, when a transfer request is created or approved, the relevant users' browsers can be notified in real-time (e.g. a notification of a pending hand receipt requiring approval). The front-end registers a WebSocket at `/api/ws` to receive these live updates. This keeps users in sync without requiring constant page refreshes.
* **Offline Sync Support:** The application is designed with offline use in mind. The front-end uses IndexedDB (via the `idb` library) for local caching and Workbox service workers for offline functionality. An **OfflineSyncQueue** on the back-end tracks changes made while offline. When connectivity is restored, the app can synchronize local changes with the server, ensuring that field operations in low-connectivity environments don't result in data loss.
* **NSN/LIN Catalog Integration:** HandReceipt integrates with official catalogs of equipment. It provides an NSN/LIN lookup service so users can search or input an NSN (National Stock Number) or LIN and retrieve standardized item details. The back-end has endpoints for NSN search and lookup, and can import data from PUBLOG (the DLA's public logistics data source). This means when adding a new item, you can fetch its official name, part number, unit price, etc., by simply entering its NSN. Keeping an updated NSN database (via provided import scripts) ensures accurate nomenclature and specs for all equipment.
* **Audit Logging:** Every significant action is automatically logged. The back-end maintains an **AuditLog** table that records what entity was changed, when, by whom, and the before/after values. Actions like create, update, delete, transfers, and user logins are all captured. This provides a tamper-evident trail for inspections and compliance. Optionally, an immutable ledger mode can be enabled: for example, using PostgreSQL ledger tables or integration with immudb (configuration supports enabling a ledger service for production). In production mode, the system will attempt to use a ledger-backed database to make audit logs cryptographically verifiable.
* **Correction Log:** If mistakes in data entry occur (e.g. an item was assigned incorrectly), admins can record **correction events**. A correction captures the adjustment made to the data along with references to the original record and reason for the change. The application provides a "Correction Log" view where all such corrections are listed, ensuring transparency for any after-the-fact data changes.
* **Document Generation (DA-2062 Forms):** The system can generate official hand receipt documents (e.g. DA Form 2062 in the U.S. Army) as PDFs. When a hand receipt (transfer) is completed, a PDF can be generated containing the item details, involved parties, and signature blocks. The back-end uses a PDF generation service for DA-2062 and can even email these forms to users or command authority on demand. The "Documents" section of the app stores generated forms and other equipment-related documents, allows marking them as read, and supports emailing them through the app.
* **Digital Signatures & Witnesses:** The hand receipt workflow supports capturing digital signatures. Each transfer (hand receipt) record has fields for signature data (could be an image or cryptographic signature) and can include witness signatures if required. This is useful for formal issuance where a supervisor or witness also signs off. The front-end likely provides a signature pad or upload for users to sign electronically, storing the signature in the record.
* **Photo and File Attachments:** Users can upload photos of equipment or relevant documents (e.g. condition photos, receipts) to attach to an equipment record. The back-end integrates with object storage to save these files (either locally via MinIO or in the cloud via Azure Blob Storage, depending on configuration). There are dedicated API routes to upload, retrieve, and delete property photos. Each attachment is stored with a hash and can be verified for integrity on demand (to ensure the photo hasn't been tampered with), which is useful in audits or if using an external ledger to verify file hashes.
* **Maintenance Tracking:** The data model supports logging maintenance records for equipment. Although the UI's implementation of this feature may be evolving, the back-end can record scheduled maintenance, inspections, repairs, etc., along with technician info, dates, and costs. This enables the system to function not only as a hand receipt ledger but also as a lightweight maintenance management system, showing when an item is due for service or currently under maintenance.
* **Pluggable Notifications (Email/SMS):** In addition to in-app notifications, the architecture anticipates external notifications. For example, when a transfer is initiated or an important event occurs, the system can be extended to send an email or push notification. Hooks for an email service exist (e.g. a placeholder `DA2062EmailService` for sending form emails), and the QR transfer flow has a TODO to send a push notification or email to the current holder. This makes it possible to integrate with email servers or SMS gateways for critical alerts (though an email service would need to be configured separately).
* **Security & Authentication:** All API routes are secured with session-based auth or JWTs. The back-end uses **JWT tokens** for API authentication (with flexible support for cookie-based sessions as well). Passwords are stored as bcrypt hashes (the default admin's password is pre-hashed in the migration). The app enforces role-based access where appropriate (e.g. only admins can access certain user management or import functions). CORS is configurable – by default, development origins (like `http://localhost:3000` or Vite's port) are allowed, and in production the allowed origins list is locked down to known domains. This ensures the API is not inadvertently exposed to unknown origins.

## Tech Stack

**Front-End:** The web client is built with **React** (TypeScript) and modern libraries. It uses the Vite bundler for fast development and builds. Key technologies and libraries on the front-end include:

* **React 18** with functional components and Hooks.
* **TypeScript** for type-safe development.
* **Wouter** (a lightweight router) for client-side routing of the single-page app.
* **React Query** for data fetching and caching (ensuring UI stays in sync with server state).
* **Context API** for state management, with custom context providers for authentication, app settings, notifications, and WebSocket connections.
* **Tailwind CSS** for styling, with a custom design system. The project uses Radix UI Primitives (dropdowns, dialogs, etc.) for accessible, unstyled components, combined with utility classes (Tailwind) and shadcn UI patterns for a modern look and feel (multiple `@radix-ui/react-*` packages are included).
* **Headless UI Components:** Many UI elements (toasts, modals, tooltips, etc.) are built using headless libraries like Radix and other open-source components, giving a consistent UX.
* **Icons:** Lucide and FontAwesome for iconography.
* **Forms:** React Hook Form for form state management and validation, combined with Zod for schema validation.
* **Charts:** Recharts is included, suggesting some dashboard or visualization of inventory data.
* **State & Networking:** Aside from React Query for server state, the front-end uses WebSockets (via the native WebSocket API or an abstraction) for live updates, and the Notification API for user notifications. It likely uses a combination of context + reducers for certain global states (AuthContext, etc.). HTTP calls are centralized in an API client service, configured to hit the back-end's `/api` routes.
* **PWA Support:** The inclusion of Workbox libraries and a service worker setup indicates the app is a Progressive Web App. It can cache assets and even data for offline use, which is aligned with the offline sync feature.
* **Testing:** The presence of Cypress end-to-end testing framework suggests tests can be written to simulate user flows. (The repository likely contains some basic tests or is set up to add them.)

**Back-End:** The server is built with **Go** (Golang), providing a high-performance API server. Major components of the back-end stack:

* **Go + Gin Framework:** A Gin HTTP server powers the REST API. Gin provides routing, middleware support, and a lightweight footprint, ideal for cloud deployment.
* **PostgreSQL Database:** The primary data store is Postgres. The application uses GORM (Go's ORM) to model and persist data. Models are defined in Go with struct tags mapping to DB columns. All core entities (users, equipment, hand receipts, etc.) are migrated into the database on startup. For local development, you'll need a Postgres instance; in production, Azure SQL or any Postgres-compatible service can be used.
* **Object Storage:** For file uploads (like equipment photos), the app supports two back-ends:

  * *MinIO* (an S3-compatible local storage) for development or self-hosted use.
  * *Azure Blob Storage* for cloud deployments.

  The storage is abstracted by a `StorageService` interface, and configured via an environment variable to choose the provider. By default it will use MinIO (with a local server on port 9000) unless configured otherwise.
* **Authentication & Security:** Uses **JWT** (JSON Web Tokens) for stateless auth (via `github.com/golang-jwt/jwt`) and **secure cookies/sessions** for web session support. Passwords are hashed with **bcrypt**. The server implements middleware for authentication that checks for a valid session token or JWT on protected routes. It also has middleware for CORS, so only configured origins can access the API in production.
* **WebSockets:** Real-time features are enabled via Gorilla WebSocket library. The server upgrades connections on the `/api/ws` endpoint and uses a **Hub** pattern to broadcast messages to connected clients. This is used for notifications and could be extended to other live updates (e.g., showing who is currently editing a record or broadcasting alerts).
* **Scheduled Jobs:** The inclusion of `github.com/robfig/cron` suggests some background jobs or scheduled tasks. These might handle periodic sync tasks (the front-end also starts a periodic sync service on load), maintenance reminders, or data cleanup. For example, a demo refresh service is mentioned to run periodically in development (perhaps to seed or refresh demo data).
* **NSN Services:** A dedicated NSN service exists to manage the NSN/LIN data. The code references an `nsnService` that can query the NSN database. The project provides a Go script to import the PUBLOG CSV data into the database and sets up full-text search indexes for quick NSN lookups.
* **PDF Generation:** Uses the `gofpdf` library to generate PDF files for forms. This is how DA-2062 hand receipt forms are created on the back-end.
* **Email Sending:** An email service interface is present; likely integration with an SMTP server or email API can be configured. In Azure deployments, this could tie into an email service or SendGrid for sending out the generated PDFs or notifications.
* **Ledger & Integrity:** For heightened security, the back-end can use an immutable ledger. In Azure config, `ledger.enabled` is true, meaning it might leverage Azure SQL's ledger feature or fallback to a secure Postgres ledger table. Additionally, the config supports **immudb** (a blockchain-inspired immutable database) via environment flags, which could be used to store hashes of transactions for external verification.
* **AI and OCR Integration:** The project includes optional AI features for processing documents, as seen in the Azure config. It can integrate with **Azure Cognitive Services (OCR)** to read text from images (e.g., scanning a hand receipt form), and **Azure OpenAI** or other AI services to parse and interpret that text. Specifically, there's a module for DA-2062 form AI processing: it can take an uploaded form image, run OCR to extract text, then use an AI (GPT-4 model) to parse that into structured data, and even generate a clean digital form. These advanced features are configurable and can be enabled in the config. They demonstrate the forward-looking design of HandReceipt – leveraging AI to reduce manual data entry for legacy paper forms.
* **Multi-platform Client Support:** While this repository focuses on the web app, the project also has mobile clients (seen in the codebase structure, e.g. an iOS and Android app directory). They all share the same back-end API. The inclusion of Capacitor origins in CORS config and use of patterns like local storage syncing suggest the web app could be run as a progressive web app or in a WebView for mobile. Essentially, the tech stack is open to various clients: web, iOS, Android can all interoperate with the same API.

By using popular, well-supported technologies (React, Go, Postgres), HandReceipt is **cloud-native and easily extensible**. The stack choice emphasizes performance, scalability, and developer productivity. Both components of the app can be developed and tested independently, yet they work seamlessly together.

## Architecture & Directory Structure

HandReceipt's repository is organized as a monorepo containing both the back-end and front-end (and other client) code. At a high level, the structure is as follows:

```bash
hrx/  (root of repository)
├── backend/              # Go backend source code
│   ├── cmd/
│   │   └── server/       # Main entry point for the API server (main.go)
│   │   └── worker/       # (Optional) Entry for background worker or cron jobs (main.go)
│   ├── internal/
│   │   ├── api/          # API logic (routes and handlers)
│   │   │   ├── handlers/ # Individual HTTP handler functions for each resource (auth, property, transfer, etc.)
│   │   │   ├── middleware/ # Middleware (auth, CORS, sessions)
│   │   │   └── routes/   # Route definitions grouping endpoints and attaching handlers
│   │   ├── models/       # Data models (domain objects) and GORM model definitions
│   │   ├── repository/   # Database access layer (CRUD operations, queries)
│   │   ├── services/     # Core services (notification hub, NSN lookup, email, PDF generation, storage, AI, etc.)
│   │   ├── ledger/       # Ledger service implementations (Postgres ledger, immudb integration)
│   │   └── platform/     # Low-level platform code (e.g., database connection & migrations)
│   ├── configs/          # YAML configuration files (e.g., config.yaml, config.development.yaml, config.azure.yaml)
│   ├── migrations/       # SQL migration scripts (e.g., NSN catalog schema) for manual runs
│   ├── scripts/          # Utility scripts (shell and Go scripts for setup, data import, etc.)
│   ├── deployments/      # Deployment configurations
│   │   └── azure/        # Azure Container Apps and Static Web Apps deployment scripts
│   ├── Dockerfile        # Dockerfile to containerize the backend API
│   └── ...               # Other files (go.mod, etc.)
├── web/                  # React front-end source code
│   ├── src/              # Application source code (React components, pages, hooks, contexts)
│   │   ├── components/   # Reusable UI components (including layout, UI widgets, etc.)
│   │   ├── pages/        # Page-level components corresponding to app routes (Dashboard, Transfers, Login, etc.)
│   │   ├── contexts/     # React Context providers for Auth, App settings, Notifications, WebSocket, etc.
│   │   ├── services/     # Front-end services (API client, sync service, notification manager, etc.)
│   │   ├── lib/          # Utility libraries (e.g., local database (idb), data helpers, hooks)
│   │   └── ...           # (Other folders like hooks, types, etc., as needed)
│   ├── public/           # Static assets (icons, images, favicon, manifest, etc.)
│   ├── shared/           # Shared config or utilities (if any, e.g., design tokens)
│   ├── index.html        # HTML entry point for the React SPA
│   ├── vite.config.ts    # Vite configuration (build settings, dev server proxy)
│   ├── package.json      # Front-end package definitions and scripts
│   └── tsconfig.json     # TypeScript configuration for the web project
├── ios/                  # (Optional) iOS mobile app source (if included, not covered in this README)
├── android/              # (Optional) Android mobile app source (if included)
├── sql/                  # (Optional) Database schema definitions using Drizzle ORM (experimental)
└── docs/                 # Documentation guides and analysis (e.g., NSN integration guide)
```

In this structure, **`/backend`** and **`/web`** contain the core of the project. The back-end follows a typical Go project layout with a `cmd` folder for the entry point and an `internal` directory for application code. The front-end is a standard React project set up with Vite for bundling.

Notably, configuration is externalized: YAML files in `backend/configs` define default settings (which can be overridden by environment variables), and there is a separate config for Azure deployment which assumes production settings and cloud services. Secrets and sensitive values are **not** committed – you'll provide those via environment (for example, database credentials and JWT secrets).

The repository includes additional folders for mobile apps and an SQL schema definition using Drizzle (a TypeScript-based ORM). These indicate that HandReceipt is envisioned as a multi-platform solution. However, the primary deliverables are the web app and Go API. The docs directory contains supplemental guides for specific features (like integrating NSN data or analyzing form imports), which are useful for advanced setup but not required for basic usage.

By structuring the project in one repo, development is simplified: for instance, during development you can simultaneously update a Go handler and a React component without switching repositories. The directory structure also makes it clear which code belongs to which part of the application, aiding new contributors in navigation.

## Getting Started (Installation & Setup)

Follow these steps to set up a development environment for HandReceipt:

**1. Prerequisites:**

* **Go 1.19+** (the project uses Go 1.23, ensure you have a compatible version) to build and run the backend.
* **Node.js 18+** and **npm** to run the front-end development server and build tools.
* **PostgreSQL 13+** running locally (or accessible connection) for the database. You should have a database created for use (e.g., named `handreceipt_dev`).
* *(Optional)* **Docker** if you prefer containerized setup for the database or to run the backend in a container.
* *(Optional)* **Azure CLI** if you plan to use the provided Azure deployment scripts.

**2. Clone the Repository:**

```bash
git clone https://github.com/toole-brendan/hrx.git
cd hrx
```

**3. Backend Configuration:**

Navigate to the `backend/` directory. Copy the example environment file to set up your local configuration (if an example exists) or create a new `.env` file. This file will store environment variables for the backend. For example:

```bash
cp backend/dev.env.example backend/.env   # if a template is provided
# Then edit backend/.env with your settings
```

If no `dev.env.example` is present, create `backend/.env` manually and add the required variables.

Minimum required environment variables for development (with example values) are:

* **Database Connection:** Either set `HANDRECEIPT_DATABASE_URL` as a full connection string, or individually set:

  * `HANDRECEIPT_DATABASE_HOST=localhost`
  * `HANDRECEIPT_DATABASE_PORT=5432`
  * `HANDRECEIPT_DATABASE_USER=postgres`
  * `HANDRECEIPT_DATABASE_PASSWORD=<your_db_password>`
  * `HANDRECEIPT_DATABASE_NAME=handreceipt_dev`
  * `HANDRECEIPT_DATABASE_SSL_MODE=disable`  (disable SSL for local dev)
* **Auth Secrets:**

  * `HANDRECEIPT_JWT_SECRET_KEY=<random_string>` – secret for signing JWT tokens. **Choose a long, random string** (at least 32 characters for production).
  * `HANDRECEIPT_AUTH_SESSION_SECRET=<random_string>` – secret for encrypting session cookies (if using session auth).
* **Server Port (optional):**

  * `HANDRECEIPT_SERVER_PORT=8080` – port for the API server (default is 8080 if not set).
* **Storage Config (optional for dev):**
  By default, the backend will try to use MinIO for file storage. You can either run a local MinIO server or switch to a simpler file system or disable uploads for dev. For MinIO, you might set:

  * `HANDRECEIPT_STORAGE_TYPE=minio` (default)
  * `MINIO_ENDPOINT=localhost:9000` (MinIO default endpoint)
  * `MINIO_ACCESS_KEY=<minio_key>` and `MINIO_SECRET_KEY=<minio_secret>` (your MinIO creds)
    Alternatively, to disable file uploads, you can ignore these – the server will log a warning if no storage is configured.
* **Other Features (optional):**
  If you want to enable advanced features like immudb ledger or Azure services in dev, set those environment variables as needed (e.g., `HANDRECEIPT_IMMUDB_ENABLED=true` and related immudb settings, or Azure OCR/AI keys). These are not required to run the app for basic usage.

Once the `.env` file is ready, the development script will load it.

**4. Frontend Configuration:**

In most cases, the front-end can work without any special configuration in development. By default, the React app expects the local API at `http://localhost:8080` (and the dev server will proxy API calls to that address).

If your back-end is running on a different host/port, you can create a `.env` file in the `web/` directory and set `VITE_API_URL="http://<your-api-host>:<port>"`. Otherwise, no additional env vars are needed for front-end dev – it will use the proxy to `localhost:8080`.

**5. Install Dependencies:**

* **Backend:** (No manual install needed beyond Go modules) The Go modules will install when you run the application. However, ensure you have run `go mod download` if needed to fetch all dependencies.
* **Frontend:** Navigate to the `web/` directory and run npm install:

  ```bash
  cd ../web
  npm install
  ```

  This will install all Node dependencies for the React app (as listed in `package.json`).

**6. Database Setup:**

Make sure your PostgreSQL server is running. The Go backend will automatically run schema migrations on startup. This means you don't need to manually create tables – the application will create the schema. It will also create a default admin user if the users table is empty. Ensure the database credentials in your config are correct and that the configured database exists (create the database in Postgres if it doesn't yet).

*(Optional)*: If you want to preload NSN data or test specific features, you might need to run additional migrations or import scripts (found in `backend/migrations` and `backend/scripts`). For initial exploration, this is not necessary.

**7. Running the Development Servers:**

Open two terminal windows (one for the back-end, one for the front-end):

* **Start the Backend** – In the `backend` directory, you can use the provided convenience script:

  ```bash
  cd ../backend
  ./run-dev.sh
  ```

  This script will load your `.env`, set the config to development mode, and start the Go server on port 8080. You should see log output indicating it connected to the database and started listening (e.g., *"Starting server on :8080"*). If any configuration is missing, the script will alert you. For example, it checks that `HANDRECEIPT_DATABASE_PASSWORD` is set and prompts if not.

  *Alternatively*, you can run the server manually:

  ```bash
  go run cmd/server/main.go
  ```

  or compile and run the binary:

  ```bash
  go build -o bin/handreceipt ./cmd/server && bin/handreceipt
  ```

* **Start the Frontend** – In the `web` directory, start the dev server:

  ```bash
  cd ../web
  npm run dev
  ```

  This launches Vite's development server on a local port (by default 5001). The console will output the local URL (e.g., `http://localhost:5001`) to open in your browser.

  Vite is configured to proxy API requests to the backend, so as long as the backend is on port 8080, you don't need to configure anything else. The dev server will also enable hot-reloading for React code changes.

**8. Verify Setup:**

* Visit **`http://localhost:5001`** in your browser. You should see the HandReceipt web application loading. By default, it will show a login screen. Use the credentials of the default admin user to log in (email: `admin@handreceipt.com`, password: `password`).
* After logging in, you should reach the **Dashboard** page. Since this is a new setup with an empty database, the dashboard and other pages (Property Book, Transfers, etc.) will be mostly empty. You can start adding data:

  * Go to **Property Book** and add a new item (fill in some details or test the NSN lookup by entering a known NSN).
  * Go to **User Management** to create additional user accounts (so you can test transfers between users).
  * Try initiating a transfer: assign an item to one user, then log out and log in as another user (or open another browser as the other user) and use the Transfers page to request that item by serial number. Or generate a QR code from one user's session and scan it (you can copy the data URL or perhaps simulate by copying the code).
* Check that real-time updates work: for example, if you log in on two different browsers with two different users, and initiate a transfer from one, the other should receive a notification (often indicated by a toast or an alert icon in the UI) without needing a page refresh.
* You can also test the API directly. For instance, the health check endpoint is open: `curl http://localhost:8080/health` should return a JSON indicating the service is healthy.

If everything is configured correctly, you now have the HandReceipt application running locally in development mode. As you make changes to the React code, the browser will live-reload. If you change Go code, you'll need to restart the server (consider using tools like `air` or `reflex` for auto-reloading the Go server on code changes, if desired).

## Running the Application

### Running in Development

When developing, you will run the back-end and front-end as separate processes as described above. To recap:

* **Back-end:** runs on `http://localhost:8080` by default. It provides the JSON API under `/api/*` routes (e.g., `/api/auth/login`, `/api/property`, etc.) and also serves WebSocket connections on `/api/ws`.
* **Front-end:** runs on `http://localhost:5001` (or another port you specify) and proxies API calls to the back-end. It is purely static front-end in development (the Node server from Vite is only for serving the React app and proxying; it's not an API server).

During dev, you might encounter common issues:

* **CORS issues:** If you see errors calling the API, ensure that either you are using the proxy (so the requests appear to come from the same origin), or if the front-end is calling directly, that the back-end's CORS config allows the dev server's origin. By default, HandReceipt's server allows `http://localhost:3000` and `http://localhost:5173` for development. If you run your front-end on `5001`, Gin's CORS middleware (in development mode) will actually allow any origin as a fallback with a warning, so it should work. You'll see a log "WARNING: Allowing origin ... in development mode" in the server output if an unrecognized origin is used.
* **Database connection errors:** If the server can't reach the database, double-check your `.env` settings. The dev script prints out which database host and user it's trying to use. Ensure the database is up and the credentials are correct.
* **Missing data or functions:** If certain features (like NSN search or emailing forms) don't work, it might be because you haven't configured the external services (like importing the NSN data, or setting up an SMTP/SendGrid for email). These features will safely no-op or return errors if not configured. You can ignore them in dev or set them up according to the docs in the `docs/` folder.

Feel free to explore the application. The UI has multiple sections:

* **Dashboard:** Overview of pending actions or summary stats (e.g., number of items, transfers awaiting approval, etc.).
* **Property Book:** List of all equipment records in the system (with filters or search).
* **Transfers:** Manage pending and past transfers (view status, initiate new transfers, accept/reject offers).
* **Search:** A global search across items (and possibly users or documents).
* **Sensitive Items:** Quick access to items flagged as sensitive (e.g., weapons, COMSEC, etc.), which might need extra tracking.
* **Network (Connections):** If enabled, this might show connections between users or units (for example, who you are connected with for transfer purposes – perhaps the "UserConnection" model allows linking accounts between organizations).
* **Documents:** List of generated documents (like hand receipt PDFs). Here you can open a document, mark it as read, or email it out.
* **User Management:** (Admin-only) Manage user accounts – create new users, assign roles or deactivate accounts.
* **Audit Log:** View a log of all audited actions in the system. This likely shows a table of events like item created, updated, transfers approved, etc., with timestamps and user info.
* **Correction Log:** (Admin-only) View all data corrections made. Each entry would reference the original record that was corrected.
* **Settings/Profile:** Where users can update their profile, change password, etc.

All these pages correspond to React routes and have backing API endpoints.

### Running in Production

For production or deployment, you will typically build the app and run it in a more streamlined way:

* **Backend (API Server):** Compile the Go program and run it as a service or inside a container. The repository provides a `backend/Dockerfile` to build a lightweight container for the API. You can do:

  ```bash
  cd backend
  go build -o handreceipt ./cmd/server
  ./handreceipt   # runs with config.yaml by default
  ```

  Ensure you set the environment variables for production (database URL, JWT secret, etc.) or provide a `config.yaml`. In production, you'll want `server.environment` set to `"production"` (this triggers Gin's release mode and some additional checks). The Dockerfile and Azure config use `HANDRECEIPT_CONFIG_NAME=config.azure` to load production overrides – you can adapt this or just use a single config file.

* **Frontend (Web App):** Build the React app for production and serve it as static files. Run:

  ```bash
  cd web
  npm run build
  ```

  This will output static assets in `web/dist/public` (by Vite config). You can then serve these files with any web server or hosting service. For example:

  * Use a simple static server:

    ```bash
    npx serve -s dist/public  # or python -m http.server from that directory
    ```
  * Or configure Nginx/Apache to serve the files in `dist/public` (with routing fallback to `index.html` for the SPA).
  * Or deploy to a static hosting service (Netlify, Vercel, AWS S3 + CloudFront, Azure Blob Static Sites, etc.). The provided `deploy-frontend.sh` script shows how to deploy to Azure Static Web Apps (uploading files to an Azure Storage account).

  **Important:** Before building for production, set the `VITE_API_URL` environment variable to your API's URL. In development it's optional, but for a production build you need to embed the correct API endpoint. For example, if your API will be at `https://api.myhandreceiptapp.com`, do:

  ```bash
  export VITE_API_URL="https://api.myhandreceiptapp.com"
  export VITE_APP_ENVIRONMENT="production"
  npm run build
  ```

  This ensures the web app will call the correct URL for the API. (If the web is served on the same domain as the API under a path, you could instead set up a reverse proxy, but typically they'll be separate in this architecture.)

* **Environment & Config:** In production, supply all needed config via environment or a config file. At minimum: database connection, JWT secret, session secret. Also configure:

  * Mail server credentials (if you enable emailing).
  * Azure storage connection string (if using Azure Blob for file storage).
  * CORS allowed origins in config.yaml to include your front-end's URL.
  * If using Azure or other cloud OCR/AI services, their endpoints and API keys.
  * Setting `ledger.enabled=true` if you want to activate the ledger mode for audit logs (and ensure your database supports it, e.g., Azure SQL Ledger or immudb).
  * Any other optional features as needed (e.g., immudb settings, if you use an immudb instance for an extra layer of integrity).

* **Deploying Backend:** You can deploy the Go backend to any platform that can run a Go binary or container. Azure Container Apps configuration is provided (YAML in `backend/deployments/azure`). You could also use AWS ECS, DigitalOcean App Platform, Kubernetes, or even a simple VM/instance. Because it's stateless (all data in the DB and Blob storage), scaling horizontally is straightforward. Just ensure only one instance runs migrations and creates the default user on first launch (to avoid race conditions) – usually this is fine, it will simply run once with no harm if run simultaneously due to the user count check.

* **Deploying Frontend:** As mentioned, host the static files on a CDN or static host. The front-end does not require Node.js or any server once built – it's purely static. Just make sure to route all paths to `index.html` (since it's a single-page app, 404s on hard refresh should be directed to the SPA entry point). The Azure script sets the 404 document to index.html for this reason.

After deployment, you should be able to navigate to your front-end's URL, log in, and use the app with the production API. Monitor the logs of the backend for any issues (e.g., database errors, missing env vars). It's recommended to run the backend with something like systemd or in Docker so it restarts if it crashes, and to use an SSL termination (the app will be making API calls; in production those should be over HTTPS).

**Scaling:** HandReceipt can be scaled by running multiple instances of the API server behind a load balancer (since sessions are stored in the DB via gin-contrib/sessions + Postgres, they are shared; and WebSocket notifications hub might need sticky sessions or a shared message broker if scaling out to multiple nodes). For simplicity, a single instance can handle dozens of concurrent users easily (Go and Gin are quite efficient). If you anticipate heavy load, consider a Redis or Postgres LISTEN/NOTIFY based pub-sub for the notification hub to coordinate WebSocket messages across instances.

## Environment Configuration

HandReceipt's configuration is controlled through a combination of **YAML config files** and **environment variables**. The application uses Viper for config management, which means environment variables can override config file values. All environment variables are prefixed with `HANDRECEIPT_` for clarity.

Here are the key configuration points:

* **Database:**

  * Config File Keys: `database.host`, `database.port`, `database.user`, `database.password`, `database.name`, `database.ssl_mode`.
  * Env Variables: `HANDRECEIPT_DATABASE_URL` (if you prefer a full DSN) or the individual `HANDRECEIPT_DATABASE_*` vars corresponding to the above keys.
  * Example:

    ```env
    HANDRECEIPT_DATABASE_HOST=localhost
    HANDRECEIPT_DATABASE_PORT=5432
    HANDRECEIPT_DATABASE_USER=postgres
    HANDRECEIPT_DATABASE_PASSWORD=mypassword
    HANDRECEIPT_DATABASE_NAME=handreceipt_dev
    HANDRECEIPT_DATABASE_SSL_MODE=disable
    ```

    For production, use SSL as appropriate (e.g., require SSL on Azure DB).

* **Server:**

  * Keys: `server.port`, `server.environment`.
  * Vars: `HANDRECEIPT_SERVER_PORT` (to override the port), `HANDRECEIPT_SERVER_ENVIRONMENT` (to set environment mode, or simply use config file).
  * `server.environment` can be `development`, `production`, etc. This affects things like Gin mode and ledger usage.

* **Authentication & Sessions:**

  * Keys: `jwt.secret_key` (the HMAC secret for JWT) and `auth.session_secret` (secret for session encryption).
  * Vars: `HANDRECEIPT_JWT_SECRET_KEY` and `HANDRECEIPT_AUTH_SESSION_SECRET` (must be provided in production, and recommended in dev).
  * The JWT secret **must** be set or the server will refuse to start. It should be a long random string; if shorter than 32 chars in production, a warning is logged.

* **Storage:**

  * Keys: `storage.type` can be `minio` or `azure_blob`.
  * If using Azure Blob: provide `HANDRECEIPT_STORAGE_CONNECTION_STRING` and `HANDRECEIPT_STORAGE_CONTAINER_NAME` (or set in config file `storage.connection_string`, etc.).
  * If using MinIO: provide `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET` (bucket name). By default, endpoint is `localhost:9000` and bucket `handreceipt-photos`.

* **Ledger:**

  * Key: `ledger.enabled` (boolean), and possibly `ledger.type` (e.g. "azure_sql" as in azure config).
  * Var: `HANDRECEIPT_LEDGER_ENABLED=true` if you want to force ledger on. In production mode, the code enables it by default, attempting a Postgres ledger service.
  * If using immudb, set `HANDRECEIPT_IMMUDB_ENABLED=true` and `HANDRECEIPT_IMMUDB_HOST`, etc. (there are environment bindings for immudb config keys).

* **NSN Service:**

  * Config keys under `nsn.` (see `docs/NSN_INTEGRATION.md` and possibly `config.yaml`). e.g., `nsn.cache_enabled`, `nsn.timeout_seconds`, etc.. These can usually be left default.
  * For NSN data, the app expects the NSN tables to be present. The NSN import is a manual step (not automatic on startup). If you have not imported data, NSN search endpoints will just return empty results. This is fine if you don't need NSN lookup.

* **OCR & AI (optional):**

  * Keys in config: `ocr.type` (e.g., "azure") with `ocr.endpoint` and `ocr.api_key` for Azure Computer Vision. And `ai.provider` (e.g., "azure_openai") with `ai.endpoint`, `ai.api_key`, `ai.model`, etc..
  * Vars: `AZURE_OCR_ENDPOINT`, `AZURE_OCR_KEY`; `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_KEY`, etc. These are only needed if you want to enable the AI-powered form processing.
  * In production Azure config, `ocr.enabled` and `ai.enabled` are true, assuming those services are available. In a local/dev environment, you might not have these – leaving them blank or false is fine (the features depending on them will be disabled gracefully).

* **Notifications & External Integrations:**

  * If integrating email or push notifications, you might have additional config (not explicitly in default config). For instance, if you add SMTP, you'd configure that in code or as needed.
  * The back-end also uses a session store; in dev it defaults to cookie store, but in production you might consider using the Postgres session store. If using the provided Node/Express session in the front-end (there's some hint of express-session usage, possibly for local development of something), it's not typically used in production for the SPA.

* **CORS and Security:**

  * Key: `security.cors_allowed_origins` – list of allowed origins for API calls.
  * Var: `CORS_ORIGINS` can override the list (comma-separated).
  * In development, any origin is allowed (with a warning) if not explicitly production. In production, ensure you set this to your actual front-end URL(s) to prevent cross-site access.
  * Other security settings: you might see `security.frame_options` or similar in config (to set X-Frame-Options), not shown above but common. Configure as needed.

The application will look for a config file named `config.yaml` by default (or a different name if you set `HANDRECEIPT_CONFIG_NAME`). It checks multiple locations, including the current directory and `/etc/handreceipt`. For simplicity, you can keep your config alongside the binary or specify everything via env.

**Tip:** In development, using the `.env` file with `run-dev.sh` is easiest. In production, prefer explicit environment variables or a config file mounted with your deployment. Avoid committing any sensitive info (passwords, keys) to the config files in the repo.

## Deployment Notes

Deploying HandReceipt involves deploying the back-end API and the front-end web app, and ensuring your environment is configured for production use.

**Backend Deployment:**

* **Containerization:** Use the provided Dockerfile to build a container image for the API. The Dockerfile is multi-stage; it compiles the Go binary in an alpine builder and then copies it into a smaller runtime image. It also copies in necessary config files (like `config.azure.yaml`). To build the image:

  ```bash
  docker build -t handreceipt-backend:latest -f backend/Dockerfile .
  ```

  Ensure you supply configuration via environment when running the container (the Dockerfile's default CMD uses `config.azure`, so you might want to use that approach or override envs).

* **Azure Container Apps:** The repo includes Azure deployment YAML for Container Apps (`backend/deployments/azure/container-apps/backend-api.yml`). You can use these as a reference for deploying on Azure. Adjust the image name, environment variables (Azure provides a way to supply secrets securely), and deploy via Azure CLI or the portal.

* **Alternate Hosting:** If not using containers, you can also deploy the binary directly to a VM or use a PaaS:

  * For example, on AWS Elastic Beanstalk or Google Cloud Run (with Docker), or a Heroku-like service. As long as the binary runs and has access to the Postgres database and any needed services, it should work.
  * If using a VM, set it up as a systemd service for the Go binary and ensure it restarts on failure.

* **Database:** Use a managed Postgres service or ensure your database is secure and backed up. Run any necessary migrations on the production DB. HandReceipt auto-migrates on start, which is convenient, but in a controlled environment you might want to run migrations manually (especially if using multiple instances or wanting more control over schema changes).

* **Domain & SSL:** If you host the API at a domain (say, `api.handreceipt.myorg.com`), secure it with SSL (e.g., behind an Nginx with Let's Encrypt, or if on Azure/AWS, use their HTTPS endpoints). The front-end will be calling this domain, so it needs to be accessible via HTTPS for security (and if running as a PWA, required for service worker).

**Frontend Deployment:**

* **Build and Host:** After running `npm run build`, take the contents of `web/dist/public`. You can:

  * Serve them via an Nginx container or VM (just configure Nginx to serve that folder on your site's domain).
  * Upload to a cloud storage bucket configured for website hosting (Azure Storage, AWS S3, Google Cloud Storage). The Azure script uses an Azure Storage static website and optionally Azure CDN.
  * Use a static site hosting service (Netlify, Vercel, GitHub Pages, etc.). Note that if you use an all-in-one service like Netlify, you might have to handle proxying to the API (Netlify can proxy `/api/*` to your API domain).
* **Configure the Front-end Base URL:** If your front-end will be served at a specific path or you have a custom domain, ensure that's reflected if needed in the build (usually not needed unless the app is not at root path). Set `BASE_URL` in Vite config if deploying to a subfolder.
* **CDN:** Using a CDN or edge caching is recommended for front-end assets, especially if serving users in various regions. The static assets can be cached long-term since the build outputs have hashed filenames for cache-busting.
* **PWA considerations:** If deploying as a PWA, configure your manifest and service worker scope correctly. The default likely does this, allowing the app to be installed on devices and function offline to some extent.

**Environment-specific Adjustments:**

* In production, you might want to tighten security: e.g., enforce strong passwords, possibly disable the auto-creation of the default admin after initial setup (you can create real users and then remove that code or user).
* If your use case is within a military network or intranet, ensure the host names and ports comply with that environment's restrictions. The app can run on internal hosts just as well – no cloud dependencies unless you enable them.
* Monitor resource usage: The Go API is efficient and low-footprint. The front-end is static and only limited by the client's browser. Use monitoring on your Postgres database as that's where a lot of state lives. Also consider enabling logs for audit trail (especially if ledger is off, the AuditLog table itself is the record – you might want to archive it or monitor its size over time).

**Azure Deployment Example:** The repository's Azure config suggests a deployment where:

* The API is deployed as a container in Azure Container Apps (with environment variables set for DB, etc.).
* The database is likely Azure Database for PostgreSQL (with ledger tables for audit, if using ledger).
* The front-end is built and uploaded to an Azure Storage static website, served via an Azure CDN endpoint for global distribution.
* Services like Azure Cognitive Services (OCR) and Azure OpenAI are used by providing their endpoints and keys via env.
* Azure Notification Hubs could be integrated if push notifications were extended, but currently it appears in-app WS notifications suffice.

You can mirror this setup or adapt it to your own infrastructure. The key point is decoupling: the front-end and back-end communicate over HTTPS, so they can be hosted independently.

Finally, always test your deployment in a staging environment. Use the same steps to run the application, and ensure all critical paths (login, CRUD operations, transfers, etc.) work in the production environment.

## Contribution Guidelines

Contributions to HandReceipt are welcome! Whether you found a bug, have an improvement in mind, or want to add a new feature, please feel free to get involved:

* **Issue Tracking:** Use the GitHub Issues to report bugs or request features. Please provide as much detail as possible, including steps to reproduce for bugs or use cases for feature requests.
* **Branching:** It's recommended to create a feature branch for your work (e.g., `feature/add-export-functionality` or `bugfix/fix-login-redirect`). Avoid committing directly to the main branch.
* **Coding Standards:** Follow the existing coding style in each project:

  * For **Go code**, use `gofmt` (which is typically enforced automatically) and try to follow idiomatic Go practices. Group imports, name things clearly, and document public functions.
  * For **React/TypeScript code**, ensure your code passes the TypeScript compiler (`npm run check` runs `tsc` type-checking). Write clean, functional components. We use hooks and context rather than Redux for state, so continue that paradigm unless there's reason to introduce new patterns. If you install new NPM packages, make sure they are necessary and up-to-date.
  * **Linting/Formatting:** This project might include linters or formatters (e.g., ESLint, Prettier). If configured, run them before committing. If not configured, please try to match the code style (e.g., 2-space indentation in JSON, certain naming conventions).
* **Testing:** If you fix a bug or add a feature, try to add tests. We use Cypress for end-to-end tests – adding a test that covers your change (if applicable in the UI) would be great. For the backend, if possible, add unit tests or integration tests for critical logic (though note that not all parts of the project have exhaustive tests yet). At minimum, manually test your changes.
* **Commits:** Write clear commit messages. A good format is to start with a short summary (<= 72 characters), then provide details if needed. For example:
  `fix(auth): refresh token expiration logic`
  Ensure each commit is focused; use multiple commits for multiple logically separate changes.
* **Pull Requests:** When you believe your contribution is ready, open a PR. Describe *what* you changed and *why*. If it fixes an open issue, reference the issue number. The maintainers will review your PR; please be open to feedback and respond or adjust as needed.
* **Code Review:** We encourage code reviews for all changes. Be respectful and constructive in code review comments. The aim is to improve the project together.
* **Contributor License Agreement (CLA):** Not applicable unless otherwise noted by the repository maintainers (for an open-source MIT project, typically a CLA is not required).
* **Community Conduct:** Please adhere to a professional and welcoming tone in all interactions. Harassment or discrimination of any kind is not tolerated.

By contributing, you agree that your contributions will be licensed under the same MIT license that covers the project.

If you're unsure where to start, you can look at open issues labeled "help wanted" or "good first issue." If you want to propose a significant change, it might be wise to open an issue to discuss it first.

Thank you for helping make HandReceipt better for everyone!

## License

This project is licensed under the **MIT License**. You are free to use, modify, and distribute this software as permitted under the MIT terms.

For full details, see the `LICENSE` file in the repository (if available) or the MIT License text below:

<details>
<summary>MIT License Text</summary>

*(MIT License text would be included here.)*

</details>

---

By providing a robust set of features and a modern tech stack, HandReceipt (HRX) aims to modernize military inventory management and hand receipt processes. We welcome you to try it out, contribute, and adapt it to your organization's needs. With its modular design and open-source license, HandReceipt can serve as a foundation for secure and efficient property accountability in various contexts. Let's build a community around it and continue to improve its capabilities!