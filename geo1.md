Thanks for the context! I’ll dive into how to migrate your Docker-based `hrx` application from AWS Lightsail to Azure, keeping ImmuDB and switching the rest of the infrastructure to well-suited Azure alternatives. I’ll also recommend the right Azure services for hosting your containers and databases.

I’ll let you know once the migration strategy and service recommendations are ready.


# Migrating a Docker-Compose Application from AWS Lightsail to Azure

## Introduction

Migrating from AWS Lightsail to Microsoft Azure involves mapping your current Docker-based stack to Azure's equivalent services. In the current setup, an AWS Lightsail instance runs a Docker Compose deployment with the following components:

* **PostgreSQL** – Relational database (running in a container)
* **ImmuDB** – Immutable ledger database (running in a container)
* **MinIO** – S3-compatible object storage (running in a container)
* **Nginx** – Reverse proxy handling HTTP/HTTPS and routing (containerized)
* **Go Application** – The main backend API server (containerized)

The goal is to use Azure-managed services for PostgreSQL and object storage while continuing to run ImmuDB in containers. We will also choose an appropriate Azure service to host the Docker containers (for the application, ImmuDB, and possibly Nginx if needed). This guide provides recommendations on Azure services, a step-by-step migration strategy, and best practices to ensure a smooth transition.

## Service Comparison: AWS Lightsail vs Azure Equivalents

| **Service Component**   | **Current (AWS Lightsail)**                       | **Azure Equivalent / Recommendation**                                                                                                                                                                         |
| ----------------------- | ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Container Hosting**   | Lightsail instance with Docker Compose (VM-based) | **Azure Container Apps** (serverless containers) or **Azure App Service** (Web App for Containers) for simple deployments, or **Azure Kubernetes Service (AKS)** for full orchestration.                      |
| **Relational Database** | PostgreSQL (containerized on Lightsail)           | **Azure Database for PostgreSQL** – Managed PostgreSQL service with high availability and backups.                                                                                                            |
| **Object Storage**      | MinIO (S3-compatible storage in a container)      | **Azure Blob Storage** – Durable, scalable object storage service.                                                                                                                                            |
| **Immutable Ledger DB** | ImmuDB (containerized on Lightsail)               | **ImmuDB in Azure** – Continue running ImmuDB in a container on Azure (no fully-managed equivalent; alternative Azure ledger services exist but ImmuDB will be self-hosted).                                  |
| **Reverse Proxy / TLS** | Nginx (containerized, handling SSL termination)   | **Azure-managed ingress** – e.g. built-in HTTP/S endpoints in App Service or Container Apps (custom domains and TLS certificates provided by Azure), or an Azure Application Gateway/Front Door if using AKS. |

*Table: Current Lightsail stack vs. Azure alternatives.*

In the next sections, we’ll explore the Azure services in detail and then outline a migration plan.

## Choosing Azure Services for Containers, Database, and Storage

### Azure Container Hosting Options

**Azure Container Apps (ACA)** – Azure Container Apps is a fully managed platform for running containerized applications without needing to manage Kubernetes clusters or VMs. It is ideal for deploying your Docker containers (the application and ImmuDB) as microservices. Container Apps supports internal service discovery and ingress within a Container Apps Environment, so your app and ImmuDB can communicate privately. It provides built-in HTTP endpoints with load balancing, automatic scaling (down to zero) based on HTTP requests or events, integrated monitoring, and versioned deployments. This option offloads all orchestration concerns to Azure and is well-suited for modern microservice or containerized workloads.

**Azure Kubernetes Service (AKS)** – AKS is a managed Kubernetes service, giving you full control over orchestration. It’s the most flexible option, allowing custom configurations and use of Kubernetes add-ons. AKS is appropriate if you require complex deployments or need to run many containers/services with custom networking, but it does introduce more management overhead (cluster maintenance, scaling configuration, etc.). Given that your current setup is relatively small, AKS may be more than you need unless you anticipate significant growth or complexity.

**Azure App Service (Web App for Containers)** – App Service is a PaaS offering for hosting web applications, including the ability to deploy Docker containers. **Web App for Containers** provides a fully managed hosting environment with built-in infrastructure maintenance, security patching, and straightforward scaling for containerized web apps. This service is ideal if your application is primarily a web/API service. It supports single-container deployments easily, and also supports multi-container deployments using Docker Compose configurations in a limited way. App Service gives you built-in CI/CD integration and handles TLS certificates and custom domain mappings out-of-the-box, which can simplify the replacement of Nginx. For a two-container scenario (app + ImmuDB), you can use App Service's multi-container feature (by providing a Compose file) or run the ImmuDB container as a sidecar. Keep in mind that volumes for persistent storage can be mounted in App Service via Azure Storage if needed.

**Azure Container Instances (ACI)** – ACI allows you to run standalone containers on demand. It’s a lightweight option but is typically used for single containers or ephemeral workloads. For a long-running application with multiple services, ACI alone is not sufficient (it has no built-in orchestration for multiple containers beyond simple container groups). It could be used for running ImmuDB as a single container, but you would still need to wire up networking and persistence manually. In most cases, ACA or App Service will be preferable for your scenario.

**Recommendation:** For most cases like yours, **Azure Container Apps** provides an excellent balance – it can run both your application and ImmuDB containers in the same environment, giving them internal network access to each other, and it spares you from managing any servers or Kubernetes. Azure Container Apps also supports mounting Azure Files volumes for persistent storage, which you can use to persist ImmuDB’s data files. If your application is straightforward (a web API) and you want the simplest deployment, you could also consider **Azure App Service**; it will manage the web front-end aspects (HTTP(S) endpoints, SSL) very easily. However, App Service’s multi-container support is slightly more constrained than ACA. AKS should only be chosen if you need the full flexibility of Kubernetes or plan to scale out to many services.

### Managed PostgreSQL on Azure

For PostgreSQL, the best route is to use **Azure Database for PostgreSQL**, which is Azure’s fully managed PostgreSQL service. This service takes care of running PostgreSQL server for you, with built-in high availability (99.99% uptime SLA), automated backups, point-in-time restore, and scaling of compute/storage on demand. There are two deployment options: **Flexible Server** (recommended for most new deployments) and **Single Server** (older). Flexible Server offers more control (custom maintenance windows, stop/start, zone-redundant high availability, VNet integration for private access, etc.) and is generally the preferred choice.

Using Azure’s managed PostgreSQL means you won’t have to maintain the database container anymore, and you can offload patching and backups to Azure. Key considerations when migrating PostgreSQL to Azure:

* **Sizing:** Choose a tier (compute and storage size) that matches your workload. Start with a smaller tier for testing and scale up as needed. Azure allows scaling up the CPU/Memory and storage with minimal downtime.
* **Security:** By default, Azure PostgreSQL requires SSL connections and can be configured to allow access only from certain IPs or Azure services. You should plan to **enable SSL in your application’s PostgreSQL connection string** (Azure’s default is to enforce SSL). For example, you may need to add `sslmode=require` in the connection string or config. Alternatively, you can disable the enforcement in the server settings, but using SSL is best practice.
* **Networking:** If you deploy your application in Azure Container Apps or App Service, you have two main ways to connect to the PostgreSQL server:

  * **Public endpoint with firewall rules:** You can allow Azure services to access the database (there’s an option "Allow access to Azure services" which effectively allows any service in your subscription to connect), or specify the outbound IP address of your App Service/Container environment in the PostgreSQL firewall. *This is the simpler approach* for initial migration and testing.
  * **Private endpoint/VNet integration:** For stronger security, you can deploy the PostgreSQL Flexible Server in a private Azure Virtual Network and use VNet integration on your Container App or App Service to allow direct private access. This avoids exposing the DB to the internet at all. This approach requires more network setup (creating a delegated subnet for the DB and enabling regional VNet integration for the app). It’s a best practice for production if you need a locked-down environment.
* **Migration of Data:** You’ll need to copy your data from the Lightsail PostgreSQL to Azure. The typical method is using **pg\_dump/pg\_restore**. For example, create a backup on Lightsail:

  ```bash
  pg_dump -h localhost -U <username> -Fc -f backup.dump <database>
  ```

  Transfer this dump file to your machine or directly to the Azure environment, and then restore it to the Azure PostgreSQL instance:

  ```bash
  pg_restore -h <azure-postgres-host> -U <adminuser>@<server> -d <database> -Fc backup.dump
  ```

  Ensure the target database is created on Azure beforehand, and update user permissions as needed. If downtime is a concern, you can minimize it by doing an initial dump/restore for most data, then apply any incremental changes manually or do a final dump during a maintenance window.
* **Configuring the App:** Once the Azure PostgreSQL is running, update your application’s configuration (environment variables or config files) to point to the new database host, port (usually 5432), database name, and credentials. Azure will provide a connection string in the portal. Be sure to include SSL parameters if required.

### Replacing MinIO with Azure Blob Storage

MinIO was used as an S3-compatible object storage. In Azure, the direct equivalent is **Azure Blob Storage**, which is Microsoft’s object storage solution for the cloud. Azure Blob Storage is highly durable and scalable, and is suitable for storing files, documents, images, backups – essentially any unstructured data. Key points about using Azure Blob Storage:

* You will create an **Azure Storage Account** (general-purpose v2 type) in your chosen region. Within this Storage Account, you create a Blob Container (similar to an S3 bucket) to store your application’s files.
* **Access and APIs:** Azure Blob has its own REST API and SDKs. It does not natively support the S3 API. This means if your application currently talks to MinIO using S3-compatible calls (for example, AWS SDK or MinIO SDK with an S3 endpoint), you will likely need to refactor that part to use Azure’s SDK or REST calls for Blob. Alternatively, you could consider running MinIO in **gateway mode** pointing to Azure Blob, but that adds complexity and is usually unnecessary if you can modify the code. Since you are open to switching to Azure services, plan to update the storage interface in your app. Azure’s SDKs for Blob Storage are available in many languages.
* **Authentication:** The simplest way to use Blob is to generate a connection string or use an access key from the Storage Account and configure the app with it. However, a more secure approach is to use Azure AD integration. For example, in Azure, you can assign a **Managed Identity** to your application and grant that identity access to Blob storage (using RBAC roles like “Storage Blob Data Contributor”). This would allow your app to get access tokens and interact with Blob without storing any access keys. This is a best practice, but it requires using Azure SDK methods to obtain tokens. If that’s too complex to implement initially, you can start with an access key or a Shared Access Signature (SAS) token for the blob container.
* **Migrating Data from MinIO:** If you have existing files in MinIO that need to be moved to Azure Blob, you can use **AzCopy**, a command-line tool provided by Azure. AzCopy supports copying data directly from an AWS S3 source to Azure Blob Storage. Since MinIO is S3-compatible, you might be able to use AzCopy by pointing it to the MinIO endpoint (if it’s publicly reachable) and using the appropriate S3 access key/secret from MinIO. The command format is:

  ```bash
  azcopy copy 'https://<minio-endpoint>/<bucket>/<path>*' 'https://<yourstorageaccount>.blob.core.windows.net/<container>' --recursive
  ```

  You would set environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` for your MinIO credentials before running the command (AzCopy uses them to authenticate to S3 sources). If AzCopy cannot directly connect to a self-hosted MinIO, an alternative is to download the files from MinIO (since it’s on your Lightsail, you might use `mc` (MinIO client) or simply access via the MinIO web console to retrieve files) and then upload to Azure using AzCopy or Azure CLI. Plan this data migration carefully if you have a large volume of files.
* **Application Changes:** Update your app configuration for storage. For instance, if you have environment variables for MinIO like `MINIO_ENDPOINT`, `MINIO_ACCESS_KEY`, etc., you might replace these with `AZURE_STORAGE_ACCOUNT` and `AZURE_STORAGE_KEY` or a connection string. If using an SDK, the connection string or the account name/key can be used to initialize the client. Also, note that Azure Blob does **not** have an equivalent of MinIO’s web console on port 9001 (though Azure Portal provides a UI to view blobs). If your workflow involved that console, you’ll use Azure Portal or tools like Azure Storage Explorer to manage files.

### Deploying ImmuDB in Azure

ImmuDB (an immutable ledger database) does not have a native Azure managed service equivalent. You will continue to run ImmuDB in a container, but now on Azure’s platform:

* **Container Deployment:** You can containerize ImmuDB just as you do now. In fact, you likely already have an ImmuDB Docker image (or use the official one). This image can be deployed to Azure Container Apps, App Service, or AKS alongside your application. If using Container Apps, you might deploy it as a separate container app within the same Container Apps Environment as the backend API – this allows the backend to talk to ImmuDB over the internal network. In Azure Container Apps, services in the same environment get an internal DNS name and can communicate without exposing a public endpoint. In AKS, you could deploy ImmuDB as a Deployment or StatefulSet with a Service. In App Service with multi-container, you would include ImmuDB in the docker-compose configuration.
* **Storage/Persistence:** One crucial aspect is ensuring ImmuDB’s data is persisted. Running on Lightsail, the ImmuDB container likely writes to a volume (perhaps a Docker volume or bind mount on the Lightsail disk). In Azure, if you deploy on a fully managed service, the container’s filesystem may be ephemeral. For example, Azure Container Apps and App Service containers have ephemeral storage by default (resets on restart). To persist data, use **Azure Files** as a mounted volume. Azure Container Apps supports mounting Azure File Share volumes into your container, so any data written there will persist and be stored in Azure Files. Similarly, App Service allows mounting a storage account file share through the portal settings. On AKS, you can use Azure Disks or Azure Files via PersistentVolumeClaims. Plan to create an Azure File Share (e.g., `immudb-data`) and configure your container hosting environment to mount it at the path where ImmuDB stores its data (per ImmuDB documentation, likely `/var/lib/immudb` or similar). This way, if the container is restarted or moved, the ledger data remains intact on the file share.
* **Configuration:** Keep the ImmuDB configuration (username, password, ports) the same, so that your application can reconnect to it in the new environment. You might need to adjust the host the app uses to reach ImmuDB (e.g., if using Container Apps and both are in same environment, use the internal FQDN of the immudb container app; if using App Service multi-container, Docker Compose service name; if AKS, the Service DNS name).
* **Scaling & Performance:** If your use of ImmuDB is not heavy, running a single instance is fine. Ensure the container service plan you choose (ACA or App Service plan) has enough CPU/memory for ImmuDB’s needs, especially since it retains an in-memory index. If you need high throughput or redundancy for ImmuDB, you might consider running multiple instances and sharding or a clustering approach, but ImmuDB clustering is not trivial. Alternatively, Azure does offer an **Azure Confidential Ledger** service and Azure SQL Ledger feature (on Azure SQL Database) as managed tamper-evident ledger solutions – those could be future considerations, but since you specifically need to keep ImmuDB, the container approach is the way to go for now.

## Migration Strategy and Steps

Moving the application to Azure can be done in phases. Below is a step-by-step plan:

### 1. Prepare Azure Environment and Resources

**a. Set up Azure Resource Group:** Create a new Resource Group in Azure (via the Azure Portal or CLI) to contain all resources (e.g., `handreceipt-prod-rg`). This helps manage and tear down resources together.

**b. Set up Azure Container Registry (ACR):** If you plan to use Azure Container Apps, AKS, or App Service with custom images, create an Azure Container Registry. Push your application’s Docker image and ensure you have (or can get) an ImmuDB image. You can push the official ImmuDB image to your registry for consistency. ACR will integrate with Azure services for authentication, especially if you enable “admin user” or use managed identities. (If you use App Service and your image is on Docker Hub or another public registry, you can skip ACR, but using ACR is recommended for privacy and reliability).

**c. Choose and set up the Container Host Service:** Based on the earlier discussion:

* *If using Azure Container Apps:* Create an Azure Container Apps Environment. You can do this in the Azure Portal by creating a Container App and specifying a new Environment, or via Azure CLI. The Environment can be left with default settings (which gives it an internal VNet managed by Azure), or you can integrate it into an existing VNet if you plan to use private endpoints for DB. Also set up a Log Analytics Workspace if prompted (Container Apps use this for logging).
* *If using Azure App Service:* Create an App Service Plan (for Linux containers) in your desired tier (start with a B1 or S1 for testing, then consider production tier for go-live). Then create a Web App for Containers. If using multi-container (Docker Compose), you’ll need to configure using Azure CLI or ARM template deployment with the compose file. In the Azure Portal, you can also configure a web app for multi-container by uploading a docker-compose.yml under the "Container Settings". Ensure the App Service plan has enough resources for two containers.
* *If using AKS:* Create an AKS cluster (ensure the node VM size is sufficient for running multiple containers). You may also create an Azure Container Registry and enable AKS to pull from it (using Azure AD integration or by secret).

At this stage, you have the compute infrastructure ready but not yet running your app.

### 2. Provision Azure Managed Services (PostgreSQL and Blob Storage)

**a. Create Azure Database for PostgreSQL:** In Azure Portal, create an Azure Database for PostgreSQL **Flexible Server**. Choose the same region as your other resources for optimal latency. Select the compute and storage (e.g., Burstable B4ms or General Purpose tier depending on expected load). Set up admin username and password. If you want a quick start, enable public access and the option “Allow Azure services…” to avoid network connectivity issues initially. (You can lock this down later or switch to private access.) Note the server name (which will be something like `<name>.postgres.database.azure.com`). After creation, in the Azure Portal you can find the Connection Strings and the **SSL certificate** if needed (for verifying the server certificate in your app; often not needed if using sslmode=require). Consider configuring the backup retention (default 7 days, can increase) and high availability (you can enable zone-redundant HA if uptime is critical).

**b. Create Azure Storage Account (for Blob):** In the Azure Portal, create a Storage Account (General Purpose v2). Again, use the same region and resource group. Once created, inside the storage account, create a **Container** (in Azure Blob terminology) – for example, `handreceipt-data`. Set the access level to private (since the app will fetch files, you likely don’t want it public). Generate an Access Key or connection string from the Storage Account’s Security settings. This will be used by the application to put/get blobs. (If you plan to use a more secure method later, you can skip retrieving the key now.)

**c. Migrate Data (if needed, at this stage):** You can start migrating your database and files before switching the app over:

* **Postgres data:** Use `pg_dump` on Lightsail as described earlier, and `psql` or `pg_restore` to import into Azure. The Azure PG server might require you to create the target database first (you can do that through the Azure Portal or with `createdb` command using the admin credentials). Also create roles/users on Azure PG that your application will use (or use the admin account for simplicity in testing, though it's better practice to create a specific DB user).
* **MinIO files:** Use AzCopy or manual download/upload to move files from MinIO to the Azure Blob container. For AzCopy, ensure MinIO is accessible. If it’s not publicly accessible, you might run AzCopy on the Lightsail instance itself (since it can reach MinIO on localhost). You’d give AzCopy the MinIO endpoint (which might be `http://127.0.0.1:9000/bucketname` if running locally – note AzCopy expects an URL format like S3’s). Alternatively, you could copy files to an AWS S3 bucket then use AzCopy from that bucket to Azure (as an intermediary step). If data volume is small, simply download via MinIO UI and use Azure Portal’s upload.

**d. Set up Azure File Share (for ImmuDB persistence):** Create an Azure **File Share** in the storage account (under “File Shares” blade). For example, name it `immudb-share` and initially you can leave a small quota. You’ll mount this in the container service in the next steps.

### 3. Reconfigure Application for Azure Services

Before deploying the containers, update configurations to point to Azure resources:

* **Environment Variables:** Prepare a new set of environment variables or configuration file for Azure. For example:

  * `DB_HOST` = `<your-postgres-server>.postgres.database.azure.com`
  * `DB_USER` = the username (e.g., `myuser@servername` – Azure PostgreSQL requires the user format to include the server name)
  * `DB_PASSWORD` = the password you set
  * `DB_NAME` = the database name
  * `DB_PORT` = 5432 (usually same)
  * `DB_SSLMODE` = `require` (if your app needs an explicit flag for SSL)
  * `MINIO_ENABLED` = false (if your code has a toggle) – Instead, configure Azure Blob: perhaps new vars like `AZURE_STORAGE_ACCOUNT` and `AZURE_STORAGE_KEY`, or if the app code can read MinIO config and you modify it to understand Azure, you might reuse fields (for example, set `MINIO_ENDPOINT` to the Azure Blob endpoint and use the key as "secret"). However, likely you will change code to use Azure SDK, in which case you might just point to a connection string.
  * `BLOB_CONTAINER` = `<your container name>` (e.g., `handreceipt-data`)
  * `IMMUDB_ADDRESS` = hostname for immudb (this might become something like `http://immudb:3322` if on the same network, or an internal DNS). If using Container Apps with internal comms, you might use the container app’s name. If using App Service compose, use the compose service name.
  * `IMMUDB_USER` / `IMMUDB_PASSWORD` = if needed, credentials for immudb.
  * Other service URLs or credentials (e.g., if you had any AWS-specific ones, replace them if needed).
  * **Secrets:** Do **not** store sensitive values (DB password, storage key, etc.) in plaintext in your code repository. Plan to use Azure’s secret management. For example, use **Azure Key Vault** to store these secrets and then have the app fetch them, or use the platform’s secret management features. (See step 5 below for handling secrets.)

* **Application Code Changes:** Modify the sections of your code that initialize MinIO/S3 client to instead initialize Azure Blob access. This may involve using Azure’s Go SDK for Blob (if your backend is Go, you can use the official Azure SDK for Go/Storage). If the code that interacts with MinIO is abstracted, implement an Azure backend for it. Test this locally if possible (you can use a connection string to Azure Blob and try a simple put/get). Similarly, double-check that your PostgreSQL connection code can handle Azure’s connection (especially the SSL part).

* **Remove Nginx (if applicable):** If you plan to rely on Azure’s managed ingress (which is recommended), you won’t need to run Nginx in a container for TLS. For Azure Container Apps and App Service, you can terminate SSL at the Azure service. Both allow you to configure a custom domain and upload or generate an SSL certificate. For example, App Service can issue a free certificate for your custom domain. Container Apps currently allows you to bring a certificate (from Key Vault or upload) and assign it to a custom domain. Therefore, your Docker Compose will no longer need the Nginx service. The Go application can listen on port 8080 (or any port) and Azure will route HTTP(S) traffic to it directly. If there were any specific Nginx configurations (like static file serving or specific headers), you might need to replicate those either in Azure (App Service has settings for some common headers) or adjust your app to handle static files (or use Azure Blob for static file hosting if that applies).

### 4. Deploy Containers to Azure Services

Now it’s time to deploy the application and ImmuDB containers on Azure:

**a. Deploy using Azure Container Apps (if chosen):**

* Publish your container images to the Azure Container Registry (if you haven’t already). Ensure you have the image tags updated (e.g., `myregistry.azurecr.io/handreceipt-backend:latest` and maybe `myregistry.azurecr.io/immudb:latest` if you retagged the immudb image).
* Create a Container App for the **backend API**. In the Azure Portal, set the image to your app’s image (configure the registry credentials if needed). Enable ingress for this container with HTTP(s) if you want it to be publicly accessible (you can start with a default Azure-generated hostname, and later add your custom domain). Set the ingress target port to the port your app listens on (8080). Add the environment variables for your app (DB host, etc.). For sensitive ones (DB password, storage key), Container Apps allows you to create a secret (which is stored securely) and then reference it as an env var. Do that for anything sensitive. If using managed identity for Blob, you would instead configure the identity and not need storage key in env.
* Create a Container App for **ImmuDB**. Use the ImmuDB image. You might not need to enable public ingress for ImmuDB (it can be internal-only, accessible only within the Container App Environment). Azure Container Apps has a concept of **internal** ingress (no public IP) – you can use this so that only the backend app can talk to ImmuDB. Set ImmuDB’s container port (likely 3322 for gRPC, and possibly 8080 if it exposes REST, depending on how your app uses it). Mount the Azure File Share volume to this container. In Container Apps, you’d have defined the storage in the environment and then specify the mount path (for example, mount `/immudbdata` to the Azure File share). Set any required env vars for ImmuDB (like `IMMUDB_ADMIN_PASSWORD`, etc., or point it to use the mounted volume for data if needed).
* The Container Apps environment ensures that the two container apps can resolve each other by name. Typically, Azure will assign an internal DNS name like `immudb.<env>.internal` or similar, or you can use the container app name with the suffix. Check Container Apps docs for the exact DNS naming within an environment. You will use that in your app’s config for IMMUDB address.
* Verify deployment: Once both are up, you can open the logs (via Log Analytics or using `az containerapp logs` command) to see if the app connected to the database, etc. At first deployment, it might fail until the database connection is allowed – be ready to adjust the firewall if needed (see step 5 about networking).

**b. Deploy using Azure App Service (if chosen):**

* If using a single container (just the backend) and perhaps running ImmuDB elsewhere: you could deploy just the backend container to App Service and perhaps run ImmuDB in Container Apps or an Azure VM. But assuming you want both in one place, you’ll use multi-container.
* Prepare a docker-compose.yml that defines your app and immudb services similar to your Lightsail one (minus MinIO and minus Nginx). For example:

  ```yaml
  version: '3'
  services:
    app:
      image: myregistry.azurecr.io/handreceipt-backend:latest
      ports:
        - 8080:8080
      env_file: .env   # (you might not include this, instead specify in App Service settings)
    immudb:
      image: myregistry.azurecr.io/immudb:latest
      volumes:
        - immudbdata:/data
  volumes:
    immudbdata:
  ```

  Note: In App Service, volume mounting a named volume requires configuration in Azure. In the portal, you can configure an Azure Storage mount to the `immudbdata` volume (backed by an Azure File Share). Alternatively, you might bake the use of Azure Files into the compose by using an Azure-specific driver. The easier approach: in Azure Portal -> your Web App -> Configuration -> Path Mappings, add a storage mapping for `immudbdata` to the Azure File share (it will ask for storage account name, share name, access key).
* Deploy this compose to Azure App Service. You can do this by Azure CLI: `az webapp create --resource-group <rg> --plan <appserviceplan> --name <appName> --multicontainer-config-type compose --multicontainer-config-file docker-compose.yml --registry-password <ACR-password> ...` (with relevant parameters). Alternatively, in Portal under "Container Settings", choose Docker Compose and upload your file.
* Configure the application settings (environment variables) in the App Service Configuration section. App Service allows you to define app settings which override those in the container. Populate DB connection info, etc., as settings. For secrets, you can leverage **Key Vault references**: App Service can directly pull a secret from Azure Key Vault into an environment variable if you set the value as `@Microsoft.KeyVault(SecretUri=https://...)` and give the App Service identity access to Key Vault. This is a secure way to keep secrets out of the compose file.
* Once deployed, App Service will pull the images from ACR, start the containers, and wire up the configured settings. Verify in the App Service logs or streaming console that the app is running and connected.

**c. Deploy using AKS (if chosen):**

* Push images to ACR (or Docker Hub).
* Create Kubernetes manifests (Deployments, Services, PersistentVolumeClaims) for the app and ImmuDB. You can use tools like Kompose to convert your docker-compose to k8s YAML, then adjust for Azure specifics (e.g., use `azureFile` storage class for the PVC to mount the Azure File share for immudb data, or use `azureDisk` if you prefer a managed disk).
* Create a Secret in Kubernetes for any sensitive config (DB password, etc.) and mount or env-inject it into pods.
* Deploy the resources to AKS using kubectl. Set up an Ingress Controller for the app’s HTTP endpoint (Azure Application Gateway Ingress or Nginx Ingress with a LoadBalancer service). Obtain a TLS cert (could use Let’s Encrypt via cert-manager, or upload a cert to Application Gateway).
* This route is the most involved. Validate pods are running (`kubectl get pods`) and troubleshoot as needed.

### 5. Networking, DNS, and Access Configuration

At this point, your application should be running in Azure, but you need to ensure it’s accessible and secure:

* **PostgreSQL connectivity:** If you had left the DB open to “Azure services”, the app should be able to connect. If not, now is the time to set up either the firewall rule or VNet integration. For example, for Container Apps without VNet: find out the outbound IP range of your Container Apps Environment (there’s an Azure Resource Manager property or you can use Azure Portal diagnostic to see outbound IPs) and add those in the PostgreSQL server firewall. For App Service: the outbound IP addresses are listed in the app’s Properties blade; add them. A more maintainable solution is to allow all Azure services or move to using private VNet integration (which would involve creating a VNet, integrating the App Service or Container Environment into it, and switching the DB to private access).
* **Blob Storage access:** If using access keys, the app should work already. If you want to tighten security, you could use a **Shared Access Signature (SAS)** with limited permissions and expiry for the app to use. Or if using Managed Identity, configure the Identity and test that the app can retrieve blobs without stored keys.
* **DNS and TLS (Custom Domain):** Currently, your Azure-hosted app might be reachable at a system domain (e.g., `<app>.azurecontainerapps.io` or `<app>.azurewebsites.net`). To cut over from Lightsail, you’ll want your custom domain (e.g., `yourdomain.com`) to point to the Azure app. In Lightsail, you likely pointed the domain to the instance’s static IP and ran certbot on Nginx. In Azure:

  * For **App Service**: Go to Custom Domains, add your domain (you’ll need to create a CNAME or A record as instructed to verify domain ownership). Once added, you can use the **App Service Managed Certificate** (free SSL cert) or upload a certificate. The managed cert is convenient (it auto-renews annually). Bind the certificate to the domain. Azure will then serve your app on `https://yourdomain.com`. No Nginx needed.
  * For **Container Apps**: Container Apps supports custom domains. You’d similarly validate the domain with a CNAME or TXT record to the Azure-provided URL. For SSL, you need to provide a certificate. You can obtain a certificate (using Azure Key Vault to do an ACME challenge via Azure DNS, or use certbot externally and upload). Azure is improving this process (they announced managed certs for Container Apps in preview). For now, you might manually get a cert. Once configured, Container Apps will handle the TLS termination.
  * For **AKS**: If using Nginx ingress, you might reuse certbot in a Pod or use cert-manager to automate Let’s Encrypt certificates. If using Azure’s Application Gateway, you could upload the cert to a Key Vault and let the gateway use it.
  * Update your DNS records (with your domain provider) to point to the Azure app’s endpoint. This might be a CNAME to an azurewebsites.net address (for App Service) or to the containerapps.io address (for Container Apps), or an A record to a static IP if using AKS with a LoadBalancer. Do this during a low-traffic period or put up a maintenance notice, as switching DNS will route users to the new deployment.
* **Testing:** Once DNS is switched, test the application thoroughly in Azure: log in, perform all key functions (file upload/download to ensure Blob works, transactions to ensure ImmuDB works, etc.). Also monitor the application logs and Azure metrics (CPU, memory) to catch any performance issues.

### 6. Secure Configuration of Environment Variables and Secrets

Now that things are running, double-check that no sensitive configuration is exposed:

* **Azure Key Vault for Secrets:** It’s recommended to use Azure Key Vault to store secrets like database passwords, storage keys, etc., and not have them directly in your app settings. Azure Container Apps and App Service can both integrate with Key Vault. For instance, you can give your app’s managed identity access to Key Vault and then use references in your configuration. In our setup, after things are working, you would: store the DB password and any other secret in an Azure Key Vault (in the same region ideally) as secrets. Then update the Container App’s environment variables to use Key Vault references (supported via the Azure CLI or ARM template) or update App Service settings to use the `@Microsoft.KeyVault(...` syntax as shown earlier. This way the actual secret values are not sitting in the app config in plaintext – the platform will fetch them securely from Key Vault at runtime. According to Azure’s best practices, **Azure Key Vault** provides a secure storage for keys and secrets and can be used in concert with containerized apps for improved security.
* **Rotate and Review:** Use this opportunity to rotate any default or old credentials (for example, if you had a default MinIO password, it's now irrelevant; make sure the Azure Storage key is kept safe, etc.). Also, configure Azure **Application Insights** or container logs to monitor for any errors that might indicate misconfigured secrets.

### 7. Decommission Lightsail (Post-Migration)

Once the Azure environment is confirmed to be running smoothly with all functionality, you can plan to shut down the Lightsail instance. Before doing so, take one final backup of any data on Lightsail (database dump, any files) as a safety archive. Then update any remaining references (for example, if there are scheduled jobs or external services pointing to the old IP, repoint them to the new Azure endpoints). Finally, you can terminate the Lightsail instance to stop incurring AWS costs.

Throughout the migration, ensure you have backed up data and have a rollback plan (for example, if Azure deployment runs into an issue, you can quickly re-point DNS back to Lightsail temporarily). However, following the above steps methodically will allow you to transition with minimal downtime.

## Best Practices and Pitfalls to Consider

Moving from Lightsail to Azure introduces new capabilities but also new considerations. Keep these best practices and tips in mind:

* **Use Managed Services to the Fullest:** Offload as much as possible to Azure’s managed services. For example, let Azure Database for PostgreSQL handle backups and point-in-time-restore. Use Azure Blob lifecycle management for your files (you can configure rules to move older blobs to cooler storage tiers for cost savings). This reduces your ops burden.

* **Monitoring and Logging:** Set up Azure Monitor and Application Insights for observability. Container Apps can send logs to Log Analytics – configure log retention and alerts for errors or high CPU/memory. App Service has Application Insights integration; enable it to get detailed performance metrics and request traces. This will help you catch any issues early after migration.

* **Performance Tuning:** Azure Database for PostgreSQL might have different performance characteristics than a local container. Monitor the query performance; consider using the Azure DB Query Performance Insight to identify slow queries. You can scale up the DB if needed or adjust the vCores. Similarly, Azure Storage has different throughput limits (depending on account type and tier); if you serve a lot of large files, consider using a Content Delivery Network (Azure CDN) in front of Blob storage for caching.

* **Security:** Take advantage of Azure’s security features. Aside from Key Vault for secrets, use **Managed Identity** for your app to access other Azure resources without embedding keys. For example, instead of storing the storage key, you can grant the app’s identity access to Blob and use Azure SDK with DefaultAzureCredential. Also ensure your PostgreSQL is not left open – ideally restrict it as much as possible (by IP or move it to private access). Azure has a **Security Center** that will flag any configuration deemed insecure.

* **Cost Management:** Keep an eye on costs in Azure. Lightsail is a fixed-cost service, whereas Azure usage can scale with what you provision. Use Azure Cost Management to set budgets. For instance, Azure Container Apps charges based on vCPU/memory and usage – it can scale to zero if no traffic (which can save cost for low usage periods). Ensure you configure scale settings appropriately. Azure Database for PostgreSQL has a cost whether idle or not – choose a size that fits your usage (you can scale down at nights manually, or use the burstable SKU which is cheaper but can handle spikes). Azure Blob is pay-per-use (storage and egress), so monitor if you are serving very large files to external users (egress bandwidth costs might appear).

* **Pitfall – Case Sensitivity in Blob:** One difference from S3: Azure Blob storage is case-sensitive in container and blob names (actually S3 is too for keys). But just ensure any code assumptions hold true. Also, Blob storage doesn’t have a directory hierarchy truly (just use blob paths with `/` in names). This should not affect you much if you treat it like S3.

* **Pitfall – SSL Enforcement on DB:** As mentioned, many encounter connection failures initially because Azure PG by default requires SSL. Ensure your DB client in the container is using SSL. You can disable the requirement in Azure, but it’s better to use it. This often means adding an option in connection string or enabling an SSL mode in a config file.

* **DNS Propagation:** When you switch the domain to point to Azure, note that DNS changes might take some time to propagate. During that time, some users might still hit the Lightsail instance. To minimize issues, you could shorten the DNS TTL a day before, or put the Lightsail site in maintenance mode once you initiate the cutover so users are nudged to the new site.

* **Backup Strategy on Azure:** Set up a backup strategy for new environment: e.g., enable Azure PostgreSQL automatic backups (and maybe perform logical backups periodically too), consider backing up critical blobs (or enable soft delete for blobs so that deletions can be recovered), and for ImmuDB, since it’s on a file share, you might schedule a periodic backup of its data file or use Azure Backup to back up the file share.

* **Testing and Staging:** It’s wise to have a staging setup on Azure before cutting over production. You can deploy the entire stack in a separate resource group (perhaps using smaller sizes to save cost), seed it with some sample data, and run integration tests. This can uncover any issues in configuration or code (for example, issues with Azure Blob SDK usage, permissions, etc.) before you affect real users.

* **Leverage Azure Documentation:** Azure has extensive documentation and examples for all these services. For instance, there are official guides on setting up Container Apps with internal services, using Key Vault for secrets, copying data from AWS to Azure, etc. Refer to these docs for specifics – for example, Azure’s guide on copying S3 data to Blob with AzCopy, or the architecture guide on choosing container services, have details that might be useful during migration.

By thoughtfully using Azure services and following best practices, you can achieve a more scalable and maintainable architecture than the single Lightsail instance, with Azure handling much of the heavy lifting of database management, storage durability, and infrastructure management. Good luck with your migration, and take it step by step. Azure’s platform will provide robust support for your Docker-based application once the transition is complete.

**Sources:**

* Azure Container Apps and other container hosting options
* Azure Database for PostgreSQL features
* Azure Blob Storage overview
* Using AzCopy to migrate S3 (MinIO) data to Azure Blob
* Azure Container Apps internal networking and secret management
* Injecting Key Vault secrets into app configurations
