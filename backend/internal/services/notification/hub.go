package notification

import (
	"log"
	"sync"
)

// Hub maintains the set of active clients and broadcasts messages to the clients
type Hub struct {
	clients    map[int]*Client
	broadcast  chan Event
	register   chan *Client
	unregister chan *Client
	mu         sync.RWMutex
}

// NewHub creates a new Hub instance
func NewHub() *Hub {
	return &Hub{
		broadcast:  make(chan Event),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		clients:    make(map[int]*Client),
	}
}

// Run starts the hub's main loop
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client.UserID] = client
			h.mu.Unlock()
			log.Printf("Client registered: UserID %d", client.UserID)

		case client := <-h.unregister:
			h.mu.Lock()
			if _, ok := h.clients[client.UserID]; ok {
				delete(h.clients, client.UserID)
				close(client.Send)
				h.mu.Unlock()
				log.Printf("Client unregistered: UserID %d", client.UserID)
			} else {
				h.mu.Unlock()
			}

		case event := <-h.broadcast:
			h.mu.RLock()
			for userID, client := range h.clients {
				if h.shouldSendEvent(userID, event) {
					select {
					case client.Send <- event.ToJSON():
					default:
						// Client's send channel is full
						close(client.Send)
						delete(h.clients, userID)
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

// shouldSendEvent determines if an event should be sent to a specific user
func (h *Hub) shouldSendEvent(userID int, event Event) bool {
	// If UserID is specified in the event, only send to that user
	if event.UserID > 0 {
		return userID == event.UserID
	}

	// Otherwise, use event type-specific logic
	switch event.Type {
	case EventTypeTransferUpdate, EventTypeTransferCreated:
		if data, ok := event.Data.(TransferUpdateData); ok {
			return userID == data.FromUserID || userID == data.ToUserID
		}
	case EventTypePropertyUpdate:
		if data, ok := event.Data.(PropertyUpdateData); ok {
			return userID == data.OwnerID
		}
	case EventTypeConnectionRequest, EventTypeConnectionAccepted:
		if data, ok := event.Data.(ConnectionRequestData); ok {
			return userID == data.TargetUserID || userID == data.FromUserID
		}
	case EventTypeDocumentReceived:
		if data, ok := event.Data.(DocumentReceivedData); ok {
			return userID == data.RecipientID
		}
	}

	return false
}

// BroadcastEvent sends an event to all relevant clients
func (h *Hub) BroadcastEvent(event Event) {
	select {
	case h.broadcast <- event:
	default:
		log.Printf("Broadcast channel full, event dropped: %v", event.Type)
	}
}

// SendToUser sends an event to a specific user
func (h *Hub) SendToUser(userID int, event Event) {
	h.mu.RLock()
	client, ok := h.clients[userID]
	h.mu.RUnlock()

	if ok {
		select {
		case client.Send <- event.ToJSON():
		default:
			log.Printf("Failed to send event to user %d: channel full", userID)
		}
	}
}

// IsUserConnected checks if a user is currently connected
func (h *Hub) IsUserConnected(userID int) bool {
	h.mu.RLock()
	_, ok := h.clients[userID]
	h.mu.RUnlock()
	return ok
}

// GetConnectedUsers returns a list of all connected user IDs
func (h *Hub) GetConnectedUsers() []int {
	h.mu.RLock()
	defer h.mu.RUnlock()

	users := make([]int, 0, len(h.clients))
	for userID := range h.clients {
		users = append(users, userID)
	}
	return users
}

// RegisterClient registers a new client with the hub
func (h *Hub) RegisterClient(client *Client) {
	h.register <- client
}

// UnregisterClient unregisters a client from the hub
func (h *Hub) UnregisterClient(client *Client) {
	h.unregister <- client
}