package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-contrib/sessions"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
	"github.com/toole-brendan/handreceipt-go/internal/services/notification"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		// Configure this based on your CORS requirements
		return true
	},
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
}

type WebSocketHandler struct {
	hub *notification.Hub
}

func NewWebSocketHandler(hub *notification.Hub) *WebSocketHandler {
	return &WebSocketHandler{
		hub: hub,
	}
}

func (h *WebSocketHandler) HandleWebSocket(c *gin.Context) {
	// Authenticate the user from the session
	session := sessions.Default(c)
	userIDInterface := session.Get("userID")
	if userIDInterface == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized"})
		return
	}

	// Convert userID to int
	var userID int
	switch v := userIDInterface.(type) {
	case int:
		userID = v
	case uint:
		userID = int(v)
	case float64:
		userID = int(v)
	default:
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid user ID type"})
		return
	}

	// Upgrade the connection
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	// Create client and register with hub
	client := &notification.Client{
		UserID: userID,
		Conn:   conn,
		Send:   make(chan []byte, 256),
		Hub:    h.hub,
	}

	h.hub.Register <- client

	// Start goroutines for reading and writing
	go client.WritePump()
	go client.ReadPump()
}

// Client connection manager
type ConnectionManager struct {
	clients    map[int]*notification.Client
	register   chan *notification.Client
	unregister chan *notification.Client
	broadcast  chan notification.Event
	mu         sync.RWMutex
}

func NewConnectionManager() *ConnectionManager {
	return &ConnectionManager{
		clients:    make(map[int]*notification.Client),
		register:   make(chan *notification.Client),
		unregister: make(chan *notification.Client),
		broadcast:  make(chan notification.Event),
	}
}

func (cm *ConnectionManager) Run() {
	for {
		select {
		case client := <-cm.register:
			cm.mu.Lock()
			cm.clients[client.UserID] = client
			cm.mu.Unlock()
			log.Printf("Client %d connected", client.UserID)

		case client := <-cm.unregister:
			cm.mu.Lock()
			if _, ok := cm.clients[client.UserID]; ok {
				delete(cm.clients, client.UserID)
				close(client.Send)
				cm.mu.Unlock()
				log.Printf("Client %d disconnected", client.UserID)
			} else {
				cm.mu.Unlock()
			}

		case event := <-cm.broadcast:
			cm.mu.RLock()
			for userID, client := range cm.clients {
				// Send event to relevant users based on event type
				if cm.shouldSendEvent(userID, event) {
					select {
					case client.Send <- event.ToJSON():
					default:
						// Client's send channel is full, close it
						cm.mu.RUnlock()
						cm.mu.Lock()
						delete(cm.clients, userID)
						close(client.Send)
						cm.mu.Unlock()
						cm.mu.RLock()
					}
				}
			}
			cm.mu.RUnlock()
		}
	}
}

func (cm *ConnectionManager) shouldSendEvent(userID int, event notification.Event) bool {
	// Implement logic to determine if a user should receive this event
	switch event.Type {
	case notification.EventTypeTransferUpdate:
		// Send transfer updates to sender and receiver
		data := event.Data.(map[string]interface{})
		fromUserID, _ := data["fromUserID"].(int)
		toUserID, _ := data["toUserID"].(int)
		return userID == fromUserID || userID == toUserID
	
	case notification.EventTypePropertyUpdate:
		// Send property updates to the owner
		data := event.Data.(map[string]interface{})
		ownerID, _ := data["ownerID"].(int)
		return userID == ownerID
	
	case notification.EventTypeConnectionRequest:
		// Send connection requests to the target user
		data := event.Data.(map[string]interface{})
		targetUserID, _ := data["targetUserID"].(int)
		return userID == targetUserID
	
	case notification.EventTypeDocumentReceived:
		// Send document notifications to the recipient
		data := event.Data.(map[string]interface{})
		recipientID, _ := data["recipientID"].(int)
		return userID == recipientID
	
	default:
		return false
	}
}

// SendEventToUser sends an event to a specific user if they're connected
func (cm *ConnectionManager) SendEventToUser(userID int, event notification.Event) {
	cm.mu.RLock()
	client, ok := cm.clients[userID]
	cm.mu.RUnlock()
	
	if ok {
		select {
		case client.Send <- event.ToJSON():
		default:
			// Channel is full, log and continue
			log.Printf("Failed to send event to user %d: channel full", userID)
		}
	}
}

// GetConnectedUsers returns a list of currently connected user IDs
func (cm *ConnectionManager) GetConnectedUsers() []int {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	
	users := make([]int, 0, len(cm.clients))
	for userID := range cm.clients {
		users = append(users, userID)
	}
	return users
}