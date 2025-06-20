import React, { ReactNode } from 'react';
export interface Notification {
    id: string;
    type: 'info' | 'warning' | 'critical' | 'success' | string;
    title: string;
    message: string;
    relatedEntityType?: string;
    relatedEntityId?: string;
    timestamp: number;
    read: boolean;
    action?: {
        label: string;
        path: string;
    };
}
interface NotificationContextType {
    notifications: Notification[];
    unreadCount: number;
    addNotification: (notificationData: Omit<Notification, 'id' | 'timestamp' | 'read'>) => void;
    markAsRead: (id: string) => void;
    markAllAsRead: () => void;
    clearAllNotifications: () => void;
}
interface NotificationProviderProps {
    children: ReactNode;
}
export declare const NotificationProvider: React.FC<NotificationProviderProps>;
export declare const useNotifications: () => NotificationContextType;
export {};
