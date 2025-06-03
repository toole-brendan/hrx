package storage

import (
	"context"
	"fmt"
	"io"
	"log"
	"strings"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/blob"
	"github.com/Azure/azure-sdk-for-go/sdk/storage/azblob/sas"
)

// AzureBlobService provides object storage functionality using Azure Blob Storage
type AzureBlobService struct {
	client        *azblob.Client
	containerName string
	accountName   string
}

// NewAzureBlobService creates a new Azure Blob Storage service instance
func NewAzureBlobService(connectionString, containerName string) (*AzureBlobService, error) {
	// Parse connection string to get account name
	accountName, err := parseAccountNameFromConnectionString(connectionString)
	if err != nil {
		return nil, fmt.Errorf("failed to parse account name from connection string: %w", err)
	}

	// Initialize Azure Blob client
	client, err := azblob.NewClientFromConnectionString(connectionString, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize Azure Blob client: %w", err)
	}

	service := &AzureBlobService{
		client:        client,
		containerName: containerName,
		accountName:   accountName,
	}

	// Ensure container exists
	if err := service.ensureContainerExists(); err != nil {
		return nil, fmt.Errorf("failed to ensure container exists: %w", err)
	}

	log.Printf("Azure Blob Storage service initialized with container: %s", containerName)
	return service, nil
}

// parseAccountNameFromConnectionString extracts the account name from the connection string
func parseAccountNameFromConnectionString(connectionString string) (string, error) {
	parts := strings.Split(connectionString, ";")
	for _, part := range parts {
		if strings.HasPrefix(part, "AccountName=") {
			return strings.TrimPrefix(part, "AccountName="), nil
		}
	}
	return "", fmt.Errorf("account name not found in connection string")
}

// ensureContainerExists creates the container if it doesn't exist
func (s *AzureBlobService) ensureContainerExists() error {
	ctx := context.Background()

	// Try to get container properties to check if it exists
	_, err := s.client.ServiceClient().NewContainerClient(s.containerName).GetProperties(ctx, nil)
	if err != nil {
		// Container doesn't exist, create it
		_, err = s.client.ServiceClient().NewContainerClient(s.containerName).Create(ctx, nil)
		if err != nil {
			return fmt.Errorf("failed to create container: %w", err)
		}
		log.Printf("Created Azure Blob container: %s", s.containerName)
	}

	return nil
}

// UploadFile uploads a file to Azure Blob Storage
func (s *AzureBlobService) UploadFile(ctx context.Context, objectName string, reader io.Reader, objectSize int64, contentType string) error {
	// Get blob client
	blobClient := s.client.ServiceClient().NewContainerClient(s.containerName).NewBlockBlobClient(objectName)

	// Upload options
	uploadOptions := &azblob.UploadStreamOptions{
		HTTPHeaders: &blob.HTTPHeaders{
			BlobContentType: &contentType,
		},
	}

	// Upload the blob using UploadStream from block blob client
	_, err := blobClient.UploadStream(ctx, reader, uploadOptions)
	if err != nil {
		return fmt.Errorf("failed to upload file %s: %w", objectName, err)
	}

	log.Printf("Successfully uploaded file: %s", objectName)
	return nil
}

// DownloadFile downloads a file from Azure Blob Storage
func (s *AzureBlobService) DownloadFile(ctx context.Context, objectName string) (io.ReadCloser, error) {
	// Get blob client
	blobClient := s.client.ServiceClient().NewContainerClient(s.containerName).NewBlobClient(objectName)

	// Download the blob
	response, err := blobClient.DownloadStream(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to download file %s: %w", objectName, err)
	}

	return response.Body, nil
}

// DeleteFile deletes a file from Azure Blob Storage
func (s *AzureBlobService) DeleteFile(ctx context.Context, objectName string) error {
	// Get blob client
	blobClient := s.client.ServiceClient().NewContainerClient(s.containerName).NewBlobClient(objectName)

	// Delete the blob
	_, err := blobClient.Delete(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to delete file %s: %w", objectName, err)
	}

	log.Printf("Successfully deleted file: %s", objectName)
	return nil
}

// GetPresignedURL generates a SAS URL for temporary access to a blob
func (s *AzureBlobService) GetPresignedURL(ctx context.Context, objectName string, expiry time.Duration) (string, error) {
	// Get blob client
	blobClient := s.client.ServiceClient().NewContainerClient(s.containerName).NewBlobClient(objectName)

	// Create SAS permissions
	permissions := sas.BlobPermissions{
		Read: true,
	}

	// Set expiry time
	expiryTime := time.Now().Add(expiry)

	// Generate SAS URL
	sasURL, err := blobClient.GetSASURL(permissions, expiryTime, nil)
	if err != nil {
		return "", fmt.Errorf("failed to generate SAS URL for %s: %w", objectName, err)
	}

	return sasURL, nil
}

// ListFiles lists all files in the container with a given prefix
func (s *AzureBlobService) ListFiles(ctx context.Context, prefix string) ([]string, error) {
	var files []string

	// Get container client
	containerClient := s.client.ServiceClient().NewContainerClient(s.containerName)

	// List blobs with prefix
	pager := containerClient.NewListBlobsFlatPager(&azblob.ListBlobsFlatOptions{
		Prefix: &prefix,
	})

	for pager.More() {
		page, err := pager.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("error listing blobs: %w", err)
		}

		for _, blob := range page.Segment.BlobItems {
			if blob.Name != nil {
				files = append(files, *blob.Name)
			}
		}
	}

	return files, nil
}

// GetFileInfo gets information about a file
func (s *AzureBlobService) GetFileInfo(ctx context.Context, objectName string) (BlobInfo, error) {
	// Get blob client
	blobClient := s.client.ServiceClient().NewContainerClient(s.containerName).NewBlobClient(objectName)

	// Get blob properties
	properties, err := blobClient.GetProperties(ctx, nil)
	if err != nil {
		return BlobInfo{}, fmt.Errorf("failed to get file info for %s: %w", objectName, err)
	}

	// Convert to our BlobInfo struct
	info := BlobInfo{
		Name:         objectName,
		Size:         *properties.ContentLength,
		LastModified: *properties.LastModified,
		ContentType:  getStringValue(properties.ContentType),
		ETag:         getStringValue((*string)(properties.ETag)),
	}

	return info, nil
}

// BlobInfo represents information about a blob
type BlobInfo struct {
	Name         string
	Size         int64
	LastModified time.Time
	ContentType  string
	ETag         string
}

// getStringValue safely gets string value from pointer
func getStringValue(ptr *string) string {
	if ptr == nil {
		return ""
	}
	return *ptr
}

// GetBlobURL returns the full URL to a blob
func (s *AzureBlobService) GetBlobURL(objectName string) string {
	return fmt.Sprintf("https://%s.blob.core.windows.net/%s/%s", s.accountName, s.containerName, objectName)
}

// CopyBlob copies a blob from one location to another within the same container
func (s *AzureBlobService) CopyBlob(ctx context.Context, sourceObjectName, destObjectName string) error {
	// Get source and destination blob clients
	containerClient := s.client.ServiceClient().NewContainerClient(s.containerName)
	sourceBlobClient := containerClient.NewBlobClient(sourceObjectName)
	destBlobClient := containerClient.NewBlobClient(destObjectName)

	// Get source blob URL
	sourceURL := sourceBlobClient.URL()

	// Start copy operation
	_, err := destBlobClient.StartCopyFromURL(ctx, sourceURL, nil)
	if err != nil {
		return fmt.Errorf("failed to copy blob from %s to %s: %w", sourceObjectName, destObjectName, err)
	}

	log.Printf("Successfully copied blob from %s to %s", sourceObjectName, destObjectName)
	return nil
}

// SetBlobMetadata sets metadata for a blob
func (s *AzureBlobService) SetBlobMetadata(ctx context.Context, objectName string, metadata map[string]string) error {
	// Get blob client
	blobClient := s.client.ServiceClient().NewContainerClient(s.containerName).NewBlobClient(objectName)

	// Convert metadata to map[string]*string as required by Azure SDK
	azureMetadata := make(map[string]*string)
	for key, value := range metadata {
		v := value // Create a copy to avoid pointer issues
		azureMetadata[key] = &v
	}

	// Set metadata
	_, err := blobClient.SetMetadata(ctx, azureMetadata, nil)
	if err != nil {
		return fmt.Errorf("failed to set metadata for %s: %w", objectName, err)
	}

	return nil
}

// GetBlobMetadata gets metadata for a blob
func (s *AzureBlobService) GetBlobMetadata(ctx context.Context, objectName string) (map[string]string, error) {
	// Get blob client
	blobClient := s.client.ServiceClient().NewContainerClient(s.containerName).NewBlobClient(objectName)

	// Get properties (which includes metadata)
	properties, err := blobClient.GetProperties(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to get metadata for %s: %w", objectName, err)
	}

	// Convert metadata
	metadata := make(map[string]string)
	for key, value := range properties.Metadata {
		if value != nil {
			metadata[key] = *value
		}
	}

	return metadata, nil
}
