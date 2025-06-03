package storage

import (
	"context"
	"io"
	"time"
)

// StorageService defines the interface for object storage operations
type StorageService interface {
	// UploadFile uploads a file to storage
	UploadFile(ctx context.Context, objectName string, reader io.Reader, objectSize int64, contentType string) error

	// DownloadFile downloads a file from storage
	DownloadFile(ctx context.Context, objectName string) (io.ReadCloser, error)

	// DeleteFile deletes a file from storage
	DeleteFile(ctx context.Context, objectName string) error

	// GetPresignedURL generates a presigned URL for temporary access
	GetPresignedURL(ctx context.Context, objectName string, expiry time.Duration) (string, error)

	// ListFiles lists all files with a given prefix
	ListFiles(ctx context.Context, prefix string) ([]string, error)
}

// FileInfo represents basic file information
type FileInfo struct {
	Name         string
	Size         int64
	LastModified time.Time
	ContentType  string
	ETag         string
}
