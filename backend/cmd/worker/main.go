package main

import (
	"context"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/robfig/cron/v3"
	"github.com/sirupsen/logrus"
	"github.com/toole-brendan/handreceipt-go/internal/config"
	"github.com/toole-brendan/handreceipt-go/internal/services/nsn"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func main() {
	// Initialize logger
	logger := logrus.New()
	logger.SetFormatter(&logrus.JSONFormatter{})
	logger.SetLevel(logrus.InfoLevel)

	logger.Info("Starting HandReceipt background worker")

	// Load configuration
	cfg, err := config.LoadConfig("./configs")
	if err != nil {
		logger.WithError(err).Fatal("Failed to load configuration")
	}

	// Initialize database connection
	db, err := initDatabase(cfg.Database, logger)
	if err != nil {
		logger.WithError(err).Fatal("Failed to initialize database")
	}

	// Audit operations removed - using PostgreSQL ledger instead

	// Initialize NSN service
	nsnService := nsn.NewNSNService(&cfg.NSN, db, logger)

	// Create cron scheduler
	c := cron.New(cron.WithLogger(cron.VerbosePrintfLogger(logger)))

	// Schedule NSN data refresh - daily at 2 AM
	_, err = c.AddFunc("0 2 * * *", func() {
		logger.Info("Starting scheduled NSN data refresh")
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
		defer cancel()

		if err := nsnService.RefreshCachedNSNData(ctx); err != nil {
			logger.WithError(err).Error("NSN data refresh failed")
		} else {
			logger.Info("NSN data refresh completed successfully")
		}
	})
	if err != nil {
		logger.WithError(err).Error("Failed to schedule NSN data refresh")
	}

	// Audit log compression removed - using PostgreSQL ledger instead

	// Schedule database maintenance - daily at 1 AM
	_, err = c.AddFunc("0 1 * * *", func() {
		logger.Info("Starting scheduled database maintenance")
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
		defer cancel()

		if err := performDatabaseMaintenance(ctx, db, logger); err != nil {
			logger.WithError(err).Error("Database maintenance failed")
		} else {
			logger.Info("Database maintenance completed successfully")
		}
	})
	if err != nil {
		logger.WithError(err).Error("Failed to schedule database maintenance")
	}

	// Schedule cache cleanup - every 6 hours
	_, err = c.AddFunc("0 */6 * * *", func() {
		logger.Info("Starting scheduled cache cleanup")
		nsnService.ClearCache()
		logger.Info("Cache cleanup completed")
	})
	if err != nil {
		logger.WithError(err).Error("Failed to schedule cache cleanup")
	}

	// Schedule health checks - every 5 minutes
	_, err = c.AddFunc("*/5 * * * *", func() {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		if err := performHealthChecks(ctx, db, logger); err != nil {
			logger.WithError(err).Warn("Health check failed")
		}
	})
	if err != nil {
		logger.WithError(err).Error("Failed to schedule health checks")
	}

	// Start the cron scheduler
	c.Start()
	logger.Info("Background worker started successfully")

	// Wait for interrupt signal to gracefully shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down background worker...")

	// Stop the cron scheduler
	ctx := c.Stop()
	<-ctx.Done()

	logger.Info("Background worker stopped")
}

func initDatabase(cfg config.DatabaseConfig, logger *logrus.Logger) (*gorm.DB, error) {
	dsn := cfg.GetDSN()

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: nil, // Disable GORM's default logger
	})
	if err != nil {
		return nil, err
	}

	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}

	// Configure connection pool
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetConnMaxLifetime(cfg.ConnMaxLifetime)

	// Test the connection
	if err := sqlDB.Ping(); err != nil {
		return nil, err
	}

	logger.Info("Database connection established")
	return db, nil
}


func performDatabaseMaintenance(ctx context.Context, db *gorm.DB, logger *logrus.Logger) error {
	// Analyze tables for better query performance
	tables := []string{"users", "equipment", "hand_receipts", "maintenance_records", "audit_logs", "nsn_data"}

	for _, table := range tables {
		if err := db.WithContext(ctx).Exec("ANALYZE " + table).Error; err != nil {
			logger.WithError(err).WithField("table", table).Warn("Failed to analyze table")
		}
	}

	// Clean up old sessions (older than 30 days)
	cutoff := time.Now().AddDate(0, 0, -30)
	if err := db.WithContext(ctx).Where("expires_at < ?", cutoff).Delete(&struct {
		TableName struct{} `gorm:"table:sessions"`
	}{}).Error; err != nil {
		logger.WithError(err).Warn("Failed to clean up old sessions")
	}

	// Clean up revoked refresh tokens (older than 7 days)
	cutoff = time.Now().AddDate(0, 0, -7)
	if err := db.WithContext(ctx).Where("is_revoked = true AND updated_at < ?", cutoff).Delete(&struct {
		TableName struct{} `gorm:"table:refresh_tokens"`
	}{}).Error; err != nil {
		logger.WithError(err).Warn("Failed to clean up revoked refresh tokens")
	}

	// Update statistics
	if err := db.WithContext(ctx).Exec("VACUUM ANALYZE").Error; err != nil {
		logger.WithError(err).Warn("Failed to vacuum analyze database")
	}

	return nil
}

func performHealthChecks(ctx context.Context, db *gorm.DB, logger *logrus.Logger) error {
	// Check database connectivity
	sqlDB, err := db.DB()
	if err != nil {
		return err
	}

	if err := sqlDB.PingContext(ctx); err != nil {
		logger.WithError(err).Error("Database health check failed")
		return err
	}

	// Log successful health check
	logger.Debug("Health checks passed")
	return nil
}
