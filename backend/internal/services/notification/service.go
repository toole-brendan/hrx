package notification

import (
	"time"
)

// Service provides methods for sending notifications through WebSocket
type Service struct {
	hub *Hub
}

// NewService creates a new notification service
func NewService(hub *Hub) *Service {
	return &Service{
		hub: hub,
	}
}

// NotifyTransferUpdate sends a transfer update notification
func (s *Service) NotifyTransferUpdate(transferID, fromUserID, toUserID int, status, serialNumber, itemName string) {
	event := Event{
		Type: EventTypeTransferUpdate,
		Data: TransferUpdateData{
			TransferID:   transferID,
			FromUserID:   fromUserID,
			ToUserID:     toUserID,
			Status:       status,
			SerialNumber: serialNumber,
			ItemName:     itemName,
		},
		Timestamp: time.Now(),
	}
	s.hub.BroadcastEvent(event)
}

// NotifyTransferCreated sends a new transfer notification
func (s *Service) NotifyTransferCreated(transferID, fromUserID, toUserID int, serialNumber, itemName string) {
	event := Event{
		Type: EventTypeTransferCreated,
		Data: TransferUpdateData{
			TransferID:   transferID,
			FromUserID:   fromUserID,
			ToUserID:     toUserID,
			Status:       "pending",
			SerialNumber: serialNumber,
			ItemName:     itemName,
		},
		Timestamp: time.Now(),
	}
	s.hub.BroadcastEvent(event)
}

// NotifyPropertyUpdate sends a property update notification
func (s *Service) NotifyPropertyUpdate(propertyID, ownerID int, serialNumber, status, action string) {
	event := Event{
		Type: EventTypePropertyUpdate,
		Data: PropertyUpdateData{
			PropertyID:   propertyID,
			OwnerID:      ownerID,
			SerialNumber: serialNumber,
			Status:       status,
			Action:       action,
		},
		Timestamp: time.Now(),
	}
	s.hub.BroadcastEvent(event)
}

// NotifyConnectionRequest sends a connection request notification
func (s *Service) NotifyConnectionRequest(connectionID, fromUserID int, fromUserName string, targetUserID int) {
	event := Event{
		Type: EventTypeConnectionRequest,
		Data: ConnectionRequestData{
			ConnectionID: connectionID,
			FromUserID:   fromUserID,
			FromUserName: fromUserName,
			TargetUserID: targetUserID,
			Status:       "pending",
		},
		Timestamp: time.Now(),
	}
	s.hub.BroadcastEvent(event)
}

// NotifyConnectionAccepted sends a connection accepted notification
func (s *Service) NotifyConnectionAccepted(connectionID, fromUserID int, fromUserName string, targetUserID int) {
	event := Event{
		Type: EventTypeConnectionAccepted,
		Data: ConnectionRequestData{
			ConnectionID: connectionID,
			FromUserID:   fromUserID,
			FromUserName: fromUserName,
			TargetUserID: targetUserID,
			Status:       "accepted",
		},
		Timestamp: time.Now(),
	}
	s.hub.BroadcastEvent(event)
}

// NotifyDocumentReceived sends a document received notification
func (s *Service) NotifyDocumentReceived(documentID, recipientID, senderID int, documentType, title string) {
	event := Event{
		Type: EventTypeDocumentReceived,
		Data: DocumentReceivedData{
			DocumentID:   documentID,
			RecipientID:  recipientID,
			SenderID:     senderID,
			DocumentType: documentType,
			Title:        title,
		},
		Timestamp: time.Now(),
	}
	s.hub.BroadcastEvent(event)
}

// SendGeneralNotification sends a general notification to a specific user
func (s *Service) SendGeneralNotification(userID int, message string, data interface{}) {
	event := Event{
		Type:      EventTypeNotification,
		Data:      data,
		Timestamp: time.Now(),
		UserID:    userID,
	}
	s.hub.SendToUser(userID, event)
}

// IsUserOnline checks if a user is currently connected
func (s *Service) IsUserOnline(userID int) bool {
	return s.hub.IsUserConnected(userID)
}

// GetOnlineUsers returns a list of online user IDs
func (s *Service) GetOnlineUsers() []int {
	return s.hub.GetConnectedUsers()
}