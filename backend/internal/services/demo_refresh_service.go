package services

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"
)

// DemoRefreshService handles periodic refresh of demo user data
type DemoRefreshService struct {
	db     *sql.DB
	ticker *time.Ticker
	done   chan bool
}

// NewDemoRefreshService creates a new demo refresh service
func NewDemoRefreshService(db *sql.DB) *DemoRefreshService {
	return &DemoRefreshService{
		db:   db,
		done: make(chan bool),
	}
}

// Start begins the periodic refresh of demo data
func (s *DemoRefreshService) Start(interval time.Duration) {
	log.Printf("Starting demo refresh service with interval: %v", interval)
	
	// Create ticker for periodic refresh
	s.ticker = time.NewTicker(interval)
	
	// Run initial refresh
	if err := s.RefreshDemoData(context.Background()); err != nil {
		log.Printf("Initial demo refresh failed: %v", err)
	}
	
	// Start background goroutine for periodic refresh
	go func() {
		for {
			select {
			case <-s.ticker.C:
				if err := s.RefreshDemoData(context.Background()); err != nil {
					log.Printf("Demo refresh failed: %v", err)
				}
			case <-s.done:
				return
			}
		}
	}()
}

// Stop halts the periodic refresh
func (s *DemoRefreshService) Stop() {
	if s.ticker != nil {
		s.ticker.Stop()
	}
	close(s.done)
	log.Println("Demo refresh service stopped")
}

// RefreshDemoData resets the demo user account to its original state
func (s *DemoRefreshService) RefreshDemoData(ctx context.Context) error {
	log.Println("Refreshing demo user data...")
	
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()
	
	// Get demo user ID
	var demoUserID int64
	err = tx.QueryRowContext(ctx, "SELECT id FROM users WHERE email = $1", "john.smith@example.mil").Scan(&demoUserID)
	if err != nil {
		if err == sql.ErrNoRows {
			log.Println("Demo user not found, skipping refresh")
			return nil
		}
		return fmt.Errorf("failed to get demo user ID: %w", err)
	}
	
	// 1. Reset user connections
	_, err = tx.ExecContext(ctx, `
		DELETE FROM user_connections 
		WHERE user_id = $1 OR connected_user_id = $1
	`, demoUserID)
	if err != nil {
		return fmt.Errorf("failed to reset connections: %w", err)
	}
	
	// Re-create original connections
	_, err = tx.ExecContext(ctx, `
		INSERT INTO user_connections (user_id, connected_user_id, connection_status, created_at, updated_at)
		SELECT 
			CASE 
				WHEN u.email IN ('michael.johnson@example.mil', 'robert.brown@example.mil') 
				THEN u.id 
				ELSE $1
			END,
			CASE 
				WHEN u.email IN ('michael.johnson@example.mil', 'robert.brown@example.mil') 
				THEN $1
				ELSE u.id
			END,
			'accepted',
			NOW() - INTERVAL '14 days',
			NOW()
		FROM users u
		WHERE u.email IN ('michael.johnson@example.mil', 'robert.brown@example.mil')
		
		UNION ALL
		
		SELECT 
			u.id,
			$1,
			'pending',
			NOW() - INTERVAL '3 days',
			NOW()
		FROM users u
		WHERE u.email = 'jennifer.davis@example.mil'
		ON CONFLICT DO NOTHING
	`, demoUserID)
	if err != nil {
		return fmt.Errorf("failed to recreate connections: %w", err)
	}
	
	// 2. Reset documents to unread
	_, err = tx.ExecContext(ctx, `
		UPDATE documents 
		SET status = 'unread', 
			read_at = NULL,
			updated_at = NOW()
		WHERE recipient_user_id = $1
		  AND type = 'transfer_form'
		  AND sender_user_id = (SELECT id FROM users WHERE email = 'michael.johnson@example.mil')
	`, demoUserID)
	if err != nil {
		return fmt.Errorf("failed to reset documents: %w", err)
	}
	
	// 3. Reset property statuses
	_, err = tx.ExecContext(ctx, `
		UPDATE properties p
		SET 
			current_status = CASE serial_number
				WHEN 'MC-1001' THEN 'active'
				WHEN 'NVG-2025' THEN 'inactive'
				WHEN 'RAD-4590' THEN 'maintenance'
				WHEN 'HV-7731' THEN 'maintenance'
				WHEN 'TK-8420' THEN 'lost'
				WHEN 'PX-1145' THEN 'inactive'
				ELSE current_status
			END,
			condition = CASE serial_number
				WHEN 'MC-1001' THEN 'serviceable'
				WHEN 'NVG-2025' THEN 'unserviceable'
				WHEN 'RAD-4590' THEN 'needs_repair'
				WHEN 'HV-7731' THEN 'needs_repair'
				WHEN 'TK-8420' THEN 'unserviceable'
				WHEN 'PX-1145' THEN 'needs_repair'
				ELSE condition
			END,
			updated_at = NOW()
		WHERE assigned_to_user_id = $1
		  AND serial_number IN ('MC-1001', 'NVG-2025', 'RAD-4590', 'HV-7731', 'TK-8420', 'PX-1145')
	`, demoUserID)
	if err != nil {
		return fmt.Errorf("failed to reset properties: %w", err)
	}
	
	// 4. Clean recent transfers
	_, err = tx.ExecContext(ctx, `
		DELETE FROM transfers
		WHERE (from_user_id = $1 OR to_user_id = $1)
		  AND created_at > NOW() - INTERVAL '1 day'
	`, demoUserID)
	if err != nil {
		return fmt.Errorf("failed to clean transfers: %w", err)
	}
	
	// 5. Reset transfer offers
	_, err = tx.ExecContext(ctx, `
		UPDATE transfer_offers 
		SET offer_status = 'active',
			accepted_by_user_id = NULL,
			accepted_at = NULL
		WHERE id IN (
			SELECT tof.id 
			FROM transfer_offers tof
			JOIN transfer_offer_recipients tor ON tof.id = tor.transfer_offer_id
			WHERE tor.recipient_user_id = $1
		)
	`, demoUserID)
	if err != nil {
		return fmt.Errorf("failed to reset transfer offers: %w", err)
	}
	
	// 6. Clean recent activities
	_, err = tx.ExecContext(ctx, `
		DELETE FROM activities
		WHERE user_id = $1
		  AND "timestamp" > NOW() - INTERVAL '1 day'
	`, demoUserID)
	if err != nil {
		return fmt.Errorf("failed to clean activities: %w", err)
	}
	
	// Commit transaction
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}
	
	log.Printf("Demo user data refreshed successfully for user ID: %d", demoUserID)
	return nil
}