import React, { createContext, useState, useContext, useEffect, ReactNode, useCallback } from 'react';
import { v4 as uuidv4 } from 'uuid';
import { notificationService } from '../services/notificationService';
import { useWebSocket } from '../hooks/useWebSocket';
import { useQueryClient } from '@tanstack/react-query';

// 1. Define the Notification Type (Based on plan)
export interface Notification {
  id: string | number; // Support both string (local) and number (backend) IDs
  type: 'info' | 'warning' | 'critical' | 'success' | 'transfer_update' | 'transfer_created' | 'property_update' | 'connection_request' | 'connection_accepted' | 'document_received' | 'general' | string;
  title: string;
  message: string;
  relatedEntityType?: string; // e.g., 'Property', 'TransferRequest'
  relatedEntityId?: string | number; // ID for linking
  timestamp: number;
  read: boolean;
  priority?: 'low' | 'normal' | 'high' | 'urgent';
  data?: any; // Additional data from backend
  action?: {
    label: string;
    path: string; // React Router path (adjust if using wouter links differently)
  };
}

// 2. Define the Context Type
interface NotificationContextType {
  notifications: Notification[];
  unreadCount: number;
  loading: boolean;
  addNotification: (notificationData: Omit<Notification, 'id' | 'timestamp' | 'read'>) => void;
  markAsRead: (id: string | number) => void;
  markAllAsRead: () => void;
  clearAllNotifications: () => void;
  deleteNotification: (id: string | number) => void;
  refreshNotifications: () => Promise<void>;
}

// 3. Create the Context
const NotificationContext = createContext<NotificationContextType | undefined>(undefined);

// 4. Create the Provider Component
interface NotificationProviderProps {
  children: ReactNode;
}

const LOCAL_STORAGE_KEY = 'handreceipt_notifications';

export const NotificationProvider: React.FC<NotificationProviderProps> = ({ children }) => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(false);
  const [isInitialized, setIsInitialized] = useState(false);
  const queryClient = useQueryClient();
  const { isConnected } = useWebSocket();

  // Load notifications from backend on initial render
  useEffect(() => {
    const loadNotifications = async () => {
      if (isInitialized) return;
      
      setLoading(true);
      try {
        // First, try to load from backend
        const backendNotifications = await notificationService.getNotifications({ limit: 50 });
        const formattedNotifications = backendNotifications.map(n => ({
          ...n,
          id: n.id.toString(),
          timestamp: new Date(n.createdAt).getTime(),
          relatedEntityId: n.data?.propertyId || n.data?.transferId || n.data?.documentId,
          relatedEntityType: n.type.includes('transfer') ? 'Transfer' : 
                           n.type.includes('property') ? 'Property' : 
                           n.type.includes('document') ? 'Document' : undefined,
        }));
        setNotifications(formattedNotifications);
        setIsInitialized(true);
      } catch (error) {
        console.error("Failed to load notifications from backend:", error);
        // Fall back to localStorage
        try {
          const storedNotifications = localStorage.getItem(LOCAL_STORAGE_KEY);
          if (storedNotifications) {
            setNotifications(JSON.parse(storedNotifications));
          }
        } catch (localError) {
          console.error("Failed to load notifications from localStorage:", localError);
          localStorage.removeItem(LOCAL_STORAGE_KEY);
        }
      } finally {
        setLoading(false);
      }
    };

    loadNotifications();
  }, [isInitialized]);

  // Save notifications to localStorage whenever they change
  useEffect(() => {
    try {
      localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(notifications));
    } catch (error) {
      console.error("Failed to save notifications to localStorage:", error);
      // Consider implications: might lose notifications if storage is full
    }
  }, [notifications]);

  const addNotification = useCallback((notificationData: Omit<Notification, 'id' | 'timestamp' | 'read'>) => {
    const newNotification: Notification = {
      ...notificationData,
      id: uuidv4(),
      timestamp: Date.now(),
      read: false,
    };

    // Add to the beginning of the list
    setNotifications(prevNotifications => [newNotification, ...prevNotifications]);
  }, []);

  const markAsRead = useCallback(async (id: string | number) => {
    // Update local state immediately
    setNotifications(prevNotifications =>
      prevNotifications.map(n => (n.id === id || n.id === id.toString() ? { ...n, read: true } : n))
    );

    // Update backend if it's a numeric ID (backend notification)
    if (typeof id === 'number' || !isNaN(Number(id))) {
      try {
        await notificationService.markAsRead(Number(id));
      } catch (error) {
        console.error('Failed to mark notification as read on backend:', error);
        // Optionally revert the local change
      }
    }
  }, []);

  const markAllAsRead = useCallback(async () => {
    // Update local state immediately
    setNotifications(prevNotifications =>
      prevNotifications.map(n => ({ ...n, read: true }))
    );

    // Update backend
    try {
      await notificationService.markAllAsRead();
    } catch (error) {
      console.error('Failed to mark all notifications as read on backend:', error);
    }
  }, []);

  const clearAllNotifications = useCallback(async () => {
    setNotifications([]);
    localStorage.removeItem(LOCAL_STORAGE_KEY);
    
    // Clear old notifications from backend (older than 0 days = all)
    try {
      await notificationService.clearOldNotifications(0);
    } catch (error) {
      console.error('Failed to clear notifications on backend:', error);
    }
  }, []);

  const deleteNotification = useCallback(async (id: string | number) => {
    // Remove from local state
    setNotifications(prevNotifications => 
      prevNotifications.filter(n => n.id !== id && n.id !== id.toString())
    );

    // Delete from backend if it's a numeric ID
    if (typeof id === 'number' || !isNaN(Number(id))) {
      try {
        await notificationService.deleteNotification(Number(id));
      } catch (error) {
        console.error('Failed to delete notification on backend:', error);
      }
    }
  }, []);

  const refreshNotifications = useCallback(async () => {
    setLoading(true);
    try {
      const backendNotifications = await notificationService.getNotifications({ limit: 50 });
      const formattedNotifications = backendNotifications.map(n => ({
        ...n,
        id: n.id.toString(),
        timestamp: new Date(n.createdAt).getTime(),
        relatedEntityId: n.data?.propertyId || n.data?.transferId || n.data?.documentId,
        relatedEntityType: n.type.includes('transfer') ? 'Transfer' : 
                         n.type.includes('property') ? 'Property' : 
                         n.type.includes('document') ? 'Document' : undefined,
      }));
      setNotifications(formattedNotifications);
    } catch (error) {
      console.error('Failed to refresh notifications:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  const unreadCount = notifications.filter(n => !n.read).length;

  // Listen for WebSocket notifications
  useEffect(() => {
    if (!isConnected) return;

    const handleWebSocketNotification = (event: CustomEvent) => {
      console.log('WebSocket notification received:', event.detail);
      
      const detail = event.detail;
      
      // Add the notification locally
      const wsNotification: Notification = {
        id: uuidv4(), // Generate local ID for now
        type: detail.type || 'info',
        title: detail.title || 'New Notification',
        message: detail.message || '',
        timestamp: Date.now(),
        read: false,
        priority: detail.priority || 'normal',
        data: detail.data,
        relatedEntityId: detail.data?.propertyId || detail.data?.transferId || detail.data?.documentId,
        relatedEntityType: detail.type?.includes('transfer') ? 'Transfer' : 
                         detail.type?.includes('property') ? 'Property' : 
                         detail.type?.includes('document') ? 'Document' : undefined,
      };
      
      addNotification(wsNotification);
      
      // Invalidate relevant queries based on notification type
      if (detail.type?.includes('transfer')) {
        queryClient.invalidateQueries({ queryKey: ['transfers'] });
      } else if (detail.type?.includes('property')) {
        queryClient.invalidateQueries({ queryKey: ['properties'] });
      } else if (detail.type?.includes('document')) {
        queryClient.invalidateQueries({ queryKey: ['documents'] });
      } else if (detail.type?.includes('connection')) {
        queryClient.invalidateQueries({ queryKey: ['connections'] });
      }
    };

    // Subscribe to WebSocket events
    window.addEventListener('ws:notification', handleWebSocketNotification);

    return () => {
      window.removeEventListener('ws:notification', handleWebSocketNotification);
    };
  }, [isConnected, addNotification, queryClient]);

  const value = {
    notifications,
    unreadCount,
    loading,
    addNotification,
    markAsRead,
    markAllAsRead,
    clearAllNotifications,
    deleteNotification,
    refreshNotifications,
  };

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  );
};

// 5. Create a Hook for easy consumption
export const useNotifications = (): NotificationContextType => {
  const context = useContext(NotificationContext);
  if (context === undefined) {
    throw new Error('useNotifications must be used within a NotificationProvider');
  }
  return context;
}; 