import { useEffect, useState, useCallback } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import webSocketService, { WebSocketEvent, WebSocketEventType } from '@/services/websocket';
import { toast } from '@/hooks/use-toast';

interface UseWebSocketOptions {
  onTransferUpdate?: (data: any) => void;
  onTransferCreated?: (data: any) => void;
  onPropertyUpdate?: (data: any) => void;
  onConnectionRequest?: (data: any) => void;
  onConnectionAccepted?: (data: any) => void;
  onDocumentReceived?: (data: any) => void;
  onNotification?: (data: any) => void;
}

export function useWebSocket(options: UseWebSocketOptions = {}) {
  const { user } = useAuth();
  const [isConnected, setIsConnected] = useState(false);
  const [lastMessage, setLastMessage] = useState<WebSocketEvent | null>(null);

  useEffect(() => {
    if (!user) {
      return;
    }

    // Connect to WebSocket
    webSocketService.connect();

    // Set up event listeners
    const handleConnected = () => {
      setIsConnected(true);
      console.log('WebSocket connected in hook');
    };

    const handleDisconnected = () => {
      setIsConnected(false);
      console.log('WebSocket disconnected in hook');
    };

    const handleMessage = (message: WebSocketEvent) => {
      setLastMessage(message);
    };

    const handleTransferUpdate = (data: any) => {
      options.onTransferUpdate?.(data);
      
      // Show toast notification if the current user is involved
      if (data.toUserId === user.id || data.fromUserId === user.id) {
        toast({
          title: 'Transfer Updated',
          description: `Transfer of ${data.itemName} (${data.serialNumber}) is now ${data.status}`,
        });
      }
    };

    const handleTransferCreated = (data: any) => {
      options.onTransferCreated?.(data);
      
      // Show toast notification if the current user is the recipient
      if (data.toUserId === user.id) {
        toast({
          title: 'New Transfer Request',
          description: `You have a new transfer request for ${data.itemName} (${data.serialNumber})`,
        });
      }
    };

    const handlePropertyUpdate = (data: any) => {
      options.onPropertyUpdate?.(data);
    };

    const handleConnectionRequest = (data: any) => {
      options.onConnectionRequest?.(data);
      
      // Show toast notification
      toast({
        title: 'New Connection Request',
        description: `${data.fromUserName} wants to connect with you`,
      });
    };

    const handleConnectionAccepted = (data: any) => {
      options.onConnectionAccepted?.(data);
      
      // Show toast notification
      toast({
        title: 'Connection Accepted',
        description: `${data.fromUserName} accepted your connection request`,
      });
    };

    const handleDocumentReceived = (data: any) => {
      options.onDocumentReceived?.(data);
      
      // Show toast notification
      toast({
        title: 'New Document',
        description: `You received a new ${data.documentType}: ${data.title}`,
      });
    };

    const handleNotification = (data: any) => {
      options.onNotification?.(data);
    };

    // Subscribe to events
    webSocketService.on('connected', handleConnected);
    webSocketService.on('disconnected', handleDisconnected);
    webSocketService.on('message', handleMessage);
    webSocketService.on('transfer:update', handleTransferUpdate);
    webSocketService.on('transfer:created', handleTransferCreated);
    webSocketService.on('property:update', handlePropertyUpdate);
    webSocketService.on('connection:request', handleConnectionRequest);
    webSocketService.on('connection:accepted', handleConnectionAccepted);
    webSocketService.on('document:received', handleDocumentReceived);
    webSocketService.on('notification:general', handleNotification);

    // Cleanup
    return () => {
      webSocketService.off('connected', handleConnected);
      webSocketService.off('disconnected', handleDisconnected);
      webSocketService.off('message', handleMessage);
      webSocketService.off('transfer:update', handleTransferUpdate);
      webSocketService.off('transfer:created', handleTransferCreated);
      webSocketService.off('property:update', handlePropertyUpdate);
      webSocketService.off('connection:request', handleConnectionRequest);
      webSocketService.off('connection:accepted', handleConnectionAccepted);
      webSocketService.off('document:received', handleDocumentReceived);
      webSocketService.off('notification:general', handleNotification);
    };
  }, [user, options]);

  const sendMessage = useCallback((data: any) => {
    webSocketService.send(data);
  }, []);

  const reconnect = useCallback(() => {
    webSocketService.reconnect();
  }, []);

  return {
    isConnected,
    lastMessage,
    sendMessage,
    reconnect,
  };
}