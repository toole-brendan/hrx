package storage

import (
	"context"
	"fmt"
	"io"
	"log"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// MinIOService provides object storage functionality using MinIO
type MinIOService struct {
	client     *minio.Client
	bucketName string
}

// NewMinIOService creates a new MinIO service instance
func NewMinIOService(endpoint, accessKeyID, secretAccessKey, bucketName string, useSSL bool) (*MinIOService, error) {
	// Initialize MinIO client
	minioClient, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKeyID, secretAccessKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to initialize MinIO client: %w", err)
	}

	service := &MinIOService{
		client:     minioClient,
		bucketName: bucketName,
	}

	// Ensure bucket exists
	if err := service.ensureBucketExists(); err != nil {
		return nil, fmt.Errorf("failed to ensure bucket exists: %w", err)
	}

	log.Printf("MinIO service initialized with bucket: %s", bucketName)
	return service, nil
}

// ensureBucketExists creates the bucket if it doesn't exist
func (s *MinIOService) ensureBucketExists() error {
	ctx := context.Background()

	exists, err := s.client.BucketExists(ctx, s.bucketName)
	if err != nil {
		return fmt.Errorf("failed to check if bucket exists: %w", err)
	}

	if !exists {
		err = s.client.MakeBucket(ctx, s.bucketName, minio.MakeBucketOptions{})
		if err != nil {
			return fmt.Errorf("failed to create bucket: %w", err)
		}
		log.Printf("Created MinIO bucket: %s", s.bucketName)
	}

	return nil
}

// UploadFile uploads a file to MinIO storage
func (s *MinIOService) UploadFile(ctx context.Context, objectName string, reader io.Reader, objectSize int64, contentType string) error {
	_, err := s.client.PutObject(ctx, s.bucketName, objectName, reader, objectSize, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return fmt.Errorf("failed to upload file %s: %w", objectName, err)
	}

	log.Printf("Successfully uploaded file: %s", objectName)
	return nil
}

// DownloadFile downloads a file from MinIO storage
func (s *MinIOService) DownloadFile(ctx context.Context, objectName string) (*minio.Object, error) {
	object, err := s.client.GetObject(ctx, s.bucketName, objectName, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to download file %s: %w", objectName, err)
	}

	return object, nil
}

// DeleteFile deletes a file from MinIO storage
func (s *MinIOService) DeleteFile(ctx context.Context, objectName string) error {
	err := s.client.RemoveObject(ctx, s.bucketName, objectName, minio.RemoveObjectOptions{})
	if err != nil {
		return fmt.Errorf("failed to delete file %s: %w", objectName, err)
	}

	log.Printf("Successfully deleted file: %s", objectName)
	return nil
}

// GetPresignedURL generates a presigned URL for temporary access to an object
func (s *MinIOService) GetPresignedURL(ctx context.Context, objectName string, expiry time.Duration) (string, error) {
	url, err := s.client.PresignedGetObject(ctx, s.bucketName, objectName, expiry, nil)
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned URL for %s: %w", objectName, err)
	}

	return url.String(), nil
}

// ListFiles lists all files in the bucket with a given prefix
func (s *MinIOService) ListFiles(ctx context.Context, prefix string) ([]string, error) {
	var files []string

	objectCh := s.client.ListObjects(ctx, s.bucketName, minio.ListObjectsOptions{
		Prefix:    prefix,
		Recursive: true,
	})

	for object := range objectCh {
		if object.Err != nil {
			return nil, fmt.Errorf("error listing objects: %w", object.Err)
		}
		files = append(files, object.Key)
	}

	return files, nil
}

// GetFileInfo gets information about a file
func (s *MinIOService) GetFileInfo(ctx context.Context, objectName string) (minio.ObjectInfo, error) {
	info, err := s.client.StatObject(ctx, s.bucketName, objectName, minio.StatObjectOptions{})
	if err != nil {
		return minio.ObjectInfo{}, fmt.Errorf("failed to get file info for %s: %w", objectName, err)
	}

	return info, nil
}
