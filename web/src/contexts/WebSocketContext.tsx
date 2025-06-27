import React, { createContext, useContext, useEffect, useState } from 'react';
import { useAuth } from './AuthContext';
import { useQueryClient } from '@tanstack/react-query';
import webSocketService, { WebSocketEvent } from '@/services/websocket';
import tokenService from '@/services/tokenService';

interface WebSocketContextType {
  isConnected: boolean;
  lastMessage: WebSocketEvent | null;
}

const WebSocketContext = createContext<WebSocketContextType>({
  isConnected: false,
  lastMessage: null,
});

export function useWebSocketContext() {
  return useContext(WebSocketContext);
}

interface WebSocketProviderProps {
  children: React.ReactNode;
}

export function WebSocketProvider({ children }: WebSocketProviderProps) {
  const { user, isAuthenticated } = useAuth();
  const queryClient = useQueryClient();
  const [isConnected, setIsConnected] = useState(false);
  const [lastMessage, setLastMessage] = useState<WebSocketEvent | null>(null);

  useEffect(() => {
    if (!isAuthenticated || !user) {
      webSocketService.disconnect();
      return;
    }

    // Connect to WebSocket when authenticated with JWT token
    const token = tokenService.getAccessToken();
    webSocketService.connect(token || undefined);

    const handleConnected = () => {
      setIsConnected(true);
      console.log('WebSocket connected');
    };

    const handleDisconnected = () => {
      setIsConnected(false);
      console.log('WebSocket disconnected');
    };

    const handleMessage = (message: WebSocketEvent) => {
      setLastMessage(message);
    };

    // Handle specific events to invalidate queries
    const handleTransferUpdate = (data: any) => {
      // Invalidate transfer queries to refetch latest data
      queryClient.invalidateQueries({ queryKey: ['transfers'] });
      queryClient.invalidateQueries({ queryKey: ['transfer', data.transferId] });
    };

    const handleTransferCreated = (data: any) => {
      // Invalidate transfer queries
      queryClient.invalidateQueries({ queryKey: ['transfers'] });
    };

    const handlePropertyUpdate = (data: any) => {
      // Invalidate property queries
      queryClient.invalidateQueries({ queryKey: ['properties'] });
      queryClient.invalidateQueries({ queryKey: ['property', data.propertyId] });
    };

    const handleConnectionRequest = (data: any) => {
      // Invalidate connection queries
      queryClient.invalidateQueries({ queryKey: ['connections'] });
    };

    const handleConnectionAccepted = (data: any) => {
      // Invalidate connection queries
      queryClient.invalidateQueries({ queryKey: ['connections'] });
    };

    const handleDocumentReceived = (data: any) => {
      // Invalidate document queries
      queryClient.invalidateQueries({ queryKey: ['documents'] });
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
      
      // Disconnect when component unmounts
      webSocketService.disconnect();
    };
  }, [isAuthenticated, user, queryClient]);

  return (
    <WebSocketContext.Provider value={{ isConnected, lastMessage }}>
      {children}
    </WebSocketContext.Provider>
  );
}