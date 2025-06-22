package notification

import (
	"encoding/json"
	"time"
)

// EventType represents the type of event being broadcast
type EventType string

const (
	EventTypeTransferUpdate     EventType = "transfer:update"
	EventTypeTransferCreated    EventType = "transfer:created"
	EventTypePropertyUpdate     EventType = "property:update"
	EventTypeConnectionRequest  EventType = "connection:request"
	EventTypeConnectionAccepted EventType = "connection:accepted"
	EventTypeDocumentReceived   EventType = "document:received"
	EventTypeNotification       EventType = "notification:general"
)

// Event represents a WebSocket event to be broadcast
type Event struct {
	Type      EventType              `json:"type"`
	Data      interface{}            `json:"data"`
	Timestamp time.Time              `json:"timestamp"`
	UserID    int                    `json:"userId,omitempty"`
}

// ToJSON converts the event to JSON bytes
func (e Event) ToJSON() []byte {
	data, _ := json.Marshal(e)
	return data
}

// TransferUpdateData represents data for transfer update events
type TransferUpdateData struct {
	TransferID   int    `json:"transferId"`
	FromUserID   int    `json:"fromUserId"`
	ToUserID     int    `json:"toUserId"`
	Status       string `json:"status"`
	SerialNumber string `json:"serialNumber"`
	ItemName     string `json:"itemName"`
}

// PropertyUpdateData represents data for property update events
type PropertyUpdateData struct {
	PropertyID   int    `json:"propertyId"`
	OwnerID      int    `json:"ownerId"`
	SerialNumber string `json:"serialNumber"`
	Status       string `json:"status"`
	Action       string `json:"action"` // created, updated, deleted
}

// ConnectionRequestData represents data for connection request events
type ConnectionRequestData struct {
	ConnectionID int    `json:"connectionId"`
	FromUserID   int    `json:"fromUserId"`
	FromUserName string `json:"fromUserName"`
	TargetUserID int    `json:"targetUserId"`
	Status       string `json:"status"`
}

// DocumentReceivedData represents data for document received events
type DocumentReceivedData struct {
	DocumentID   int    `json:"documentId"`
	RecipientID  int    `json:"recipientId"`
	SenderID     int    `json:"senderId"`
	DocumentType string `json:"documentType"`
	Title        string `json:"title"`
}