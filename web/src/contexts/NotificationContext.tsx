import React, { createContext, useState, useContext, useEffect, ReactNode, useCallback } from 'react';
import { v4 as uuidv4 } from 'uuid';

// 1. Define the Notification Type (Based on plan)
export interface Notification {
  id: string; 
  type: 'info' | 'warning' | 'critical' | 'success' | string; // Allow custom types too
  title: string;
  message: string;
  relatedEntityType?: string; // e.g., 'InventoryItem', 'TransferRequest'
  relatedEntityId?: string; // ID for linking
  timestamp: number;
  read: boolean;
  action?: {
    label: string;
    path: string; // React Router path (adjust if using wouter links differently)
  };
}

// 2. Define the Context Type
interface NotificationContextType {
  notifications: Notification[];
  unreadCount: number;
  addNotification: (notificationData: Omit<Notification, 'id' | 'timestamp' | 'read'>) => void;
  markAsRead: (id: string) => void;
  markAllAsRead: () => void;
  clearAllNotifications: () => void;
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

  // Load notifications from localStorage on initial render
  useEffect(() => {
    try {
      const storedNotifications = localStorage.getItem(LOCAL_STORAGE_KEY);
      if (storedNotifications) {
        setNotifications(JSON.parse(storedNotifications));
      }
    } catch (error) {
      console.error("Failed to load notifications from localStorage:", error);
      localStorage.removeItem(LOCAL_STORAGE_KEY); // Clear corrupted data
    }
  }, []);

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

  const markAsRead = useCallback((id: string) => {
    setNotifications(prevNotifications =>
      prevNotifications.map(n => (n.id === id ? { ...n, read: true } : n))
    );
  }, []);

  const markAllAsRead = useCallback(() => {
    setNotifications(prevNotifications =>
      prevNotifications.map(n => ({ ...n, read: true }))
    );
  }, []);

  const clearAllNotifications = useCallback(() => {
    setNotifications([]);
  }, []);

  const unreadCount = notifications.filter(n => !n.read).length;

  const value = {
    notifications,
    unreadCount,
    addNotification,
    markAsRead,
    markAllAsRead,
    clearAllNotifications,
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