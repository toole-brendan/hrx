import { EventEmitter } from 'events';

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

class WebSocketService extends EventEmitter {
  private ws: WebSocket | null = null;
  private reconnectInterval: number = 5000;
  private reconnectAttempts: number = 0;
  private maxReconnectAttempts: number = 10;
  private isConnected: boolean = false;
  private shouldReconnect: boolean = true;
  private pingInterval: NodeJS.Timeout | null = null;

  constructor() {
    super();
  }

  connect(token?: string): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      console.log('WebSocket already connected');
      return;
    }

    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;
    const wsUrl = `${protocol}//${host}/api/ws`;

    try {
      this.ws = new WebSocket(wsUrl);

      this.ws.onopen = () => {
        console.log('WebSocket connected');
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
          this.handleMessage(message);
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error);
        }
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        this.emit('error', error);
      };

      this.ws.onclose = (event) => {
        console.log('WebSocket disconnected:', event.code, event.reason);
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

    // Log for debugging
    console.log('WebSocket message received:', message);
  }

  private startPing(): void {
    this.stopPing(); // Clear any existing interval
    this.pingInterval = setInterval(() => {
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