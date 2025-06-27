export type WebSocketEventType = 
  | 'transfer:update'
  | 'transfer:created'
  | 'property:update'
  | 'connection:request'
  | 'connection:accepted'
  | 'document:received'
  | 'notification:general';

export interface WebSocketEvent {
  type: WebSocketEventType;
  data: any;
  timestamp: string;
  userId?: number;
}

export interface TransferUpdateData {
  transferId: number;
  fromUserId: number;
  toUserId: number;
  status: string;
  serialNumber: string;
  itemName: string;
}

export interface PropertyUpdateData {
  propertyId: number;
  ownerId: number;
  serialNumber: string;
  status: string;
  action: string;
}

export interface ConnectionRequestData {
  connectionId: number;
  fromUserId: number;
  fromUserName: string;
  targetUserId: number;
  status: string;
}

export interface DocumentReceivedData {
  documentId: number;
  recipientId: number;
  senderId: number;
  documentType: string;
  title: string;
}

// Simple EventEmitter implementation for browser
class EventEmitter {
  private events: { [key: string]: Array<(...args: any[]) => void> } = {};

  on(event: string, listener: (...args: any[]) => void): void {
    if (!this.events[event]) {
      this.events[event] = [];
    }
    this.events[event].push(listener);
  }

  off(event: string, listenerToRemove: (...args: any[]) => void): void {
    if (!this.events[event]) return;
    
    this.events[event] = this.events[event].filter(
      listener => listener !== listenerToRemove
    );
  }

  emit(event: string, ...args: any[]): void {
    if (!this.events[event]) return;
    
    this.events[event].forEach(listener => {
      try {
        listener(...args);
      } catch (error) {
        console.error(`Error in event listener for ${event}:`, error);
      }
    });
  }

  removeAllListeners(event?: string): void {
    if (event) {
      delete this.events[event];
    } else {
      this.events = {};
    }
  }
}

class WebSocketService extends EventEmitter {
  private ws: WebSocket | null = null;
  private reconnectInterval: number = 5000;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 10;
  private isConnected: boolean = false;
  private shouldReconnect: boolean = true;
  private pingInterval: number | null = null;

  constructor() {
    super();
  }

  connect(token?: string): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      console.log('[WebSocket] Already connected');
      return;
    }

    // Get API URL from environment or use current host for local development
    const apiUrl = import.meta.env.VITE_API_URL || '';
    let wsUrl: string;
    
    if (apiUrl) {
      // Convert HTTP(S) URL to WebSocket URL
      const url = new URL(apiUrl);
      const protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
      wsUrl = `${protocol}//${url.host}/api/ws`;
    } else {
      // Fallback to current host for local development
      const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
      const host = window.location.host;
      wsUrl = `${protocol}//${host}/api/ws`;
    }

    // Add token as query parameter if provided
    if (token) {
      const separator = wsUrl.includes('?') ? '&' : '?';
      wsUrl = `${wsUrl}${separator}token=${encodeURIComponent(token)}`;
    }

    console.log('[WebSocket] Attempting to connect:', {
      wsUrl: wsUrl.replace(/token=[^&]+/, 'token=***'), // Hide token in logs
      timestamp: new Date().toISOString(),
      hasToken: !!token
    });

    try {
      this.ws = new WebSocket(wsUrl);

      this.ws.onopen = () => {
        console.log('[WebSocket] Connected successfully:', {
          timestamp: new Date().toISOString(),
          readyState: this.ws?.readyState
        });
        this.isConnected = true;
        this.reconnectAttempts = 0;
        this.emit('connected');

        // Start ping/pong to keep connection alive
        this.startPing();
      };

      this.ws.onmessage = (event) => {
        try {
          if (event.data === 'pong') {
            // Ignore pong responses
            return;
          }

          const message: WebSocketEvent = JSON.parse(event.data);
          console.log('[WebSocket] Message received:', {
            type: message.type,
            timestamp: new Date().toISOString()
          });
          this.handleMessage(message);
        } catch (error) {
          console.error('[WebSocket] Failed to parse message:', error);
        }
      };

      this.ws.onerror = (error) => {
        console.error('[WebSocket] Error occurred:', {
          error,
          timestamp: new Date().toISOString(),
          readyState: this.ws?.readyState
        });
        this.emit('error', error);
      };

      this.ws.onclose = (event) => {
        console.log('[WebSocket] Disconnected:', {
          code: event.code,
          reason: event.reason,
          wasClean: event.wasClean,
          timestamp: new Date().toISOString()
        });
        this.isConnected = false;
        this.stopPing();
        this.emit('disconnected');

        // Attempt to reconnect if not intentionally closed
        if (this.shouldReconnect && this.reconnectAttempts < this.maxReconnectAttempts) {
          this.reconnectAttempts++;
          console.log(`Reconnecting in ${this.reconnectInterval}ms... (attempt ${this.reconnectAttempts})`);
          setTimeout(() => this.connect(token), this.reconnectInterval);
        }
      };
    } catch (error) {
      console.error('Failed to create WebSocket connection:', error);
      this.emit('error', error);
    }
  }

  private handleMessage(message: WebSocketEvent): void {
    // Emit specific event based on message type
    this.emit(message.type, message.data);

    // Also emit a general 'message' event
    this.emit('message', message);

    // Emit a custom DOM event that NotificationContext can listen to
    // This is needed because NotificationContext uses window events
    const notificationEvent = new CustomEvent('ws:notification', {
      detail: {
        type: message.type,
        data: message.data,
        timestamp: message.timestamp,
        userId: message.userId,
        // Map WebSocket event types to notification properties
        title: this.getNotificationTitle(message.type, message.data),
        message: this.getNotificationMessage(message.type, message.data),
        priority: this.getNotificationPriority(message.type),
      }
    });
    window.dispatchEvent(notificationEvent);

    // Log for debugging
    console.log('WebSocket message received:', message);
  }

  private getNotificationTitle(type: WebSocketEventType, data: any): string {
    switch (type) {
      case 'transfer:update':
        return `Transfer ${data.status}`;
      case 'transfer:created':
        return 'New Transfer Request';
      case 'property:update':
        return 'Property Updated';
      case 'connection:request':
        return 'New Connection Request';
      case 'connection:accepted':
        return 'Connection Accepted';
      case 'document:received':
        return 'New Document Received';
      case 'notification:general':
        return data.title || 'Notification';
      default:
        return 'Notification';
    }
  }

  private getNotificationMessage(type: WebSocketEventType, data: any): string {
    switch (type) {
      case 'transfer:update':
        return `Transfer of ${data.itemName} (${data.serialNumber}) has been ${data.status}`;
      case 'transfer:created':
        return `You have a new transfer request for ${data.itemName} (${data.serialNumber})`;
      case 'property:update':
        return `Property ${data.serialNumber} has been ${data.action}`;
      case 'connection:request':
        return `${data.fromUserName} wants to connect with you`;
      case 'connection:accepted':
        return `${data.fromUserName} accepted your connection request`;
      case 'document:received':
        return `You received a ${data.documentType}: ${data.title}`;
      case 'notification:general':
        return data.message || '';
      default:
        return '';
    }
  }

  private getNotificationPriority(type: WebSocketEventType): 'low' | 'normal' | 'high' | 'urgent' {
    switch (type) {
      case 'transfer:created':
      case 'connection:request':
        return 'high';
      case 'transfer:update':
      case 'property:update':
      case 'document:received':
        return 'normal';
      default:
        return 'normal';
    }
  }

  private startPing(): void {
    this.stopPing(); // Clear any existing interval
    this.pingInterval = window.setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send('ping');
      }
    }, 30000); // Send ping every 30 seconds
  }

  private stopPing(): void {
    if (this.pingInterval) {
      clearInterval(this.pingInterval);
      this.pingInterval = null;
    }
  }

  disconnect(): void {
    this.shouldReconnect = false;
    this.stopPing();
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  reconnect(): void {
    this.shouldReconnect = true;
    this.reconnectAttempts = 0;
    this.disconnect();
    this.connect();
  }

  isConnectedStatus(): boolean {
    return this.isConnected && this.ws?.readyState === WebSocket.OPEN;
  }

  send(data: any): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    } else {
      console.warn('WebSocket is not connected. Message not sent:', data);
    }
  }
}

// Create singleton instance
const webSocketService = new WebSocketService();

export default webSocketService;