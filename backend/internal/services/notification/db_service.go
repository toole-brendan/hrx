package notification

import (
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
)

// DBService extends the notification service with database persistence
type DBService struct {
	*Service
	db *gorm.DB
}

// NewDBService creates a new notification service with database support
func NewDBService(hub *Hub, db *gorm.DB) *DBService {
	return &DBService{
		Service: NewService(hub),
		db:      db,
	}
}

// NotifyTransferUpdate sends a real-time notification and saves to database
func (s *DBService) NotifyTransferUpdate(transfer *domain.Transfer) error {
	// Send real-time notification
	s.Service.NotifyTransferUpdate(
		int(transfer.ID),
		int(transfer.FromUserID),
		int(transfer.ToUserID),
		transfer.Status,
		transfer.Property.SerialNumber,
		transfer.Property.Name,
	)

	// Create persistent notifications
	data := map[string]interface{}{
		"transferId":   transfer.ID,
		"propertyId":   transfer.PropertyID,
		"serialNumber": transfer.Property.SerialNumber,
		"status":       transfer.Status,
	}
	dataJSON, _ := json.Marshal(data)

	// Notification for sender
	senderNotif := &domain.Notification{
		UserID:   transfer.FromUserID,
		Type:     domain.NotificationTypeTransferUpdate,
		Title:    fmt.Sprintf("Transfer %s", transfer.Status),
		Message:  fmt.Sprintf("Your transfer of %s (%s) has been %s", transfer.Property.Name, transfer.Property.SerialNumber, transfer.Status),
		Data:     dataJSON,
		Priority: domain.NotificationPriorityNormal,
	}
	if err := s.CreateNotification(senderNotif); err != nil {
		return err
	}

	// Notification for receiver
	receiverNotif := &domain.Notification{
		UserID:   transfer.ToUserID,
		Type:     domain.NotificationTypeTransferUpdate,
		Title:    fmt.Sprintf("Transfer %s", transfer.Status),
		Message:  fmt.Sprintf("Transfer of %s (%s) to you has been %s", transfer.Property.Name, transfer.Property.SerialNumber, transfer.Status),
		Data:     dataJSON,
		Priority: domain.NotificationPriorityNormal,
	}
	return s.CreateNotification(receiverNotif)
}

// NotifyTransferCreated sends a real-time notification and saves to database
func (s *DBService) NotifyTransferCreated(transfer *domain.Transfer) error {
	// Send real-time notification
	s.Service.NotifyTransferCreated(
		int(transfer.ID),
		int(transfer.FromUserID),
		int(transfer.ToUserID),
		transfer.Property.SerialNumber,
		transfer.Property.Name,
	)

	// Create persistent notification for receiver
	data := map[string]interface{}{
		"transferId":   transfer.ID,
		"propertyId":   transfer.PropertyID,
		"serialNumber": transfer.Property.SerialNumber,
		"fromUserId":   transfer.FromUserID,
	}
	dataJSON, _ := json.Marshal(data)

	notification := &domain.Notification{
		UserID:   transfer.ToUserID,
		Type:     domain.NotificationTypeTransferCreated,
		Title:    "New Transfer Request",
		Message:  fmt.Sprintf("You have a new transfer request for %s (%s)", transfer.Property.Name, transfer.Property.SerialNumber),
		Data:     dataJSON,
		Priority: domain.NotificationPriorityHigh,
	}
	return s.CreateNotification(notification)
}

// NotifyPropertyUpdate sends a real-time notification and saves to database
func (s *DBService) NotifyPropertyUpdate(property *domain.Property) error {
	if property.AssignedToUserID == nil {
		return nil // No owner to notify
	}

	// Send real-time notification
	s.Service.NotifyPropertyUpdate(
		int(property.ID),
		int(*property.AssignedToUserID),
		property.SerialNumber,
		property.CurrentStatus,
		"updated",
	)

	// Create persistent notification
	data := map[string]interface{}{
		"propertyId":   property.ID,
		"serialNumber": property.SerialNumber,
		"status":       property.CurrentStatus,
	}
	dataJSON, _ := json.Marshal(data)

	notification := &domain.Notification{
		UserID:   *property.AssignedToUserID,
		Type:     domain.NotificationTypePropertyUpdate,
		Title:    "Property Updated",
		Message:  fmt.Sprintf("Property %s (%s) has been updated", property.Name, property.SerialNumber),
		Data:     dataJSON,
		Priority: domain.NotificationPriorityNormal,
	}
	return s.CreateNotification(notification)
}

// NotifyConnectionRequest sends a real-time notification and saves to database
func (s *DBService) NotifyConnectionRequest(requesterID, targetUserID int) error {
	// Get requester details
	var requester domain.User
	if err := s.db.First(&requester, requesterID).Error; err != nil {
		return err
	}

	// Send real-time notification
	s.Service.NotifyConnectionRequest(0, requesterID, requester.Name, targetUserID)

	// Create persistent notification
	data := map[string]interface{}{
		"requesterID": requesterID,
		"requesterName": requester.Name,
	}
	dataJSON, _ := json.Marshal(data)

	notification := &domain.Notification{
		UserID:   uint(targetUserID),
		Type:     domain.NotificationTypeConnectionRequest,
		Title:    "New Connection Request",
		Message:  fmt.Sprintf("%s wants to connect with you", requester.Name),
		Data:     dataJSON,
		Priority: domain.NotificationPriorityNormal,
	}
	return s.CreateNotification(notification)
}

// NotifyConnectionAccepted sends a real-time notification and saves to database
func (s *DBService) NotifyConnectionAccepted(acceptorID, requesterID int) error {
	// Get acceptor details
	var acceptor domain.User
	if err := s.db.First(&acceptor, acceptorID).Error; err != nil {
		return err
	}

	// Send real-time notification
	s.Service.NotifyConnectionAccepted(0, acceptorID, acceptor.Name, requesterID)

	// Create persistent notification
	data := map[string]interface{}{
		"acceptorID": acceptorID,
		"acceptorName": acceptor.Name,
	}
	dataJSON, _ := json.Marshal(data)

	notification := &domain.Notification{
		UserID:   uint(requesterID),
		Type:     domain.NotificationTypeConnectionAccepted,
		Title:    "Connection Accepted",
		Message:  fmt.Sprintf("%s accepted your connection request", acceptor.Name),
		Data:     dataJSON,
		Priority: domain.NotificationPriorityNormal,
	}
	return s.CreateNotification(notification)
}

// NotifyDocumentReceived sends a real-time notification and saves to database
func (s *DBService) NotifyDocumentReceived(document *domain.Document) error {
	// Get sender details
	var sender domain.User
	if err := s.db.First(&sender, document.SenderUserID).Error; err != nil {
		return err
	}

	// Send real-time notification
	s.Service.NotifyDocumentReceived(
		int(document.ID),
		int(document.RecipientUserID),
		int(document.SenderUserID),
		document.Type,
		document.Title,
	)

	// Create persistent notification
	data := map[string]interface{}{
		"documentId": document.ID,
		"documentType": document.Type,
		"senderID": document.SenderUserID,
		"senderName": sender.Name,
	}
	dataJSON, _ := json.Marshal(data)

	notification := &domain.Notification{
		UserID:   document.RecipientUserID,
		Type:     domain.NotificationTypeDocumentReceived,
		Title:    "New Document Received",
		Message:  fmt.Sprintf("You received a %s from %s", document.Title, sender.Name),
		Data:     dataJSON,
		Priority: domain.NotificationPriorityNormal,
	}
	return s.CreateNotification(notification)
}

// SendGeneralNotification sends a general notification with persistence
func (s *DBService) SendGeneralNotification(userID int, title, message string) error {
	// Send real-time notification
	s.Service.SendGeneralNotification(userID, message, nil)

	// Create persistent notification
	notification := &domain.Notification{
		UserID:   uint(userID),
		Type:     domain.NotificationTypeGeneral,
		Title:    title,
		Message:  message,
		Priority: domain.NotificationPriorityNormal,
	}
	return s.CreateNotification(notification)
}

// CreateNotification creates a new notification in the database
func (s *DBService) CreateNotification(notification *domain.Notification) error {
	return s.db.Create(notification).Error
}

// GetUserNotifications retrieves notifications for a user
func (s *DBService) GetUserNotifications(userID int, limit, offset int, unreadOnly bool) ([]*domain.Notification, error) {
	var notifications []*domain.Notification
	query := s.db.Where("user_id = ?", userID)
	
	if unreadOnly {
		query = query.Where("read = ?", false)
	}
	
	// Exclude expired notifications
	query = query.Where("expires_at IS NULL OR expires_at > ?", time.Now())
	
	err := query.Order("created_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&notifications).Error
		
	return notifications, err
}

// GetUnreadCount returns the count of unread notifications
func (s *DBService) GetUnreadCount(userID int) (int64, error) {
	var count int64
	err := s.db.Model(&domain.Notification{}).
		Where("user_id = ? AND read = ?", userID, false).
		Where("expires_at IS NULL OR expires_at > ?", time.Now()).
		Count(&count).Error
	return count, err
}

// MarkAsRead marks a notification as read
func (s *DBService) MarkAsRead(userID, notificationID int) error {
	result := s.db.Model(&domain.Notification{}).
		Where("id = ? AND user_id = ?", notificationID, userID).
		Updates(map[string]interface{}{
			"read": true,
			"read_at": time.Now(),
		})
		
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return errors.New("notification not found")
	}
	return nil
}

// MarkAllAsRead marks all notifications as read for a user
func (s *DBService) MarkAllAsRead(userID int) error {
	return s.db.Model(&domain.Notification{}).
		Where("user_id = ? AND read = ?", userID, false).
		Updates(map[string]interface{}{
			"read": true,
			"read_at": time.Now(),
		}).Error
}

// DeleteNotification deletes a notification
func (s *DBService) DeleteNotification(userID, notificationID int) error {
	result := s.db.Where("id = ? AND user_id = ?", notificationID, userID).
		Delete(&domain.Notification{})
		
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return errors.New("notification not found")
	}
	return nil
}

// ClearOldNotifications deletes notifications older than specified days
func (s *DBService) ClearOldNotifications(userID int, days int) (int64, error) {
	cutoffDate := time.Now().AddDate(0, 0, -days)
	result := s.db.Where("user_id = ? AND created_at < ?", userID, cutoffDate).
		Delete(&domain.Notification{})
	return result.RowsAffected, result.Error
}