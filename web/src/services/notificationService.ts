import { transformKeys } from '../utils/transformKeys';

interface BackendNotification {
  id: number;
  user_id: number;
  type: string;
  title: string;
  message: string;
  data?: any;
  read: boolean;
  read_at?: string;
  priority: string;
  expires_at?: string;
  created_at: string;
  updated_at: string;
}

interface Notification {
  id: number;
  userId: number;
  type: string;
  title: string;
  message: string;
  data?: any;
  read: boolean;
  readAt?: string;
  priority: string;
  expiresAt?: string;
  createdAt: string;
  updatedAt: string;
}

interface NotificationListParams {
  limit?: number;
  offset?: number;
  unreadOnly?: boolean;
}

class NotificationService {
  private baseUrl = '/api/notifications';

  async getNotifications(params?: NotificationListParams): Promise<Notification[]> {
    const queryParams = new URLSearchParams();
    if (params?.limit) queryParams.append('limit', params.limit.toString());
    if (params?.offset) queryParams.append('offset', params.offset.toString());
    if (params?.unreadOnly) queryParams.append('unread_only', 'true');

    const response = await fetch(`${this.baseUrl}?${queryParams.toString()}`, {
      credentials: 'include',
    });

    if (!response.ok) {
      throw new Error('Failed to fetch notifications');
    }

    const notifications: BackendNotification[] = await response.json();
    return notifications.map(n => transformKeys(n, 'snakeToCamel') as Notification);
  }

  async getUnreadCount(): Promise<number> {
    const response = await fetch(`${this.baseUrl}/unread-count`, {
      credentials: 'include',
    });

    if (!response.ok) {
      throw new Error('Failed to fetch unread count');
    }

    const data = await response.json();
    return data.count;
  }

  async markAsRead(notificationId: number): Promise<void> {
    const response = await fetch(`${this.baseUrl}/${notificationId}/read`, {
      method: 'PATCH',
      credentials: 'include',
    });

    if (!response.ok) {
      throw new Error('Failed to mark notification as read');
    }
  }

  async markAllAsRead(): Promise<void> {
    const response = await fetch(`${this.baseUrl}/mark-all-read`, {
      method: 'POST',
      credentials: 'include',
    });

    if (!response.ok) {
      throw new Error('Failed to mark all notifications as read');
    }
  }

  async deleteNotification(notificationId: number): Promise<void> {
    const response = await fetch(`${this.baseUrl}/${notificationId}`, {
      method: 'DELETE',
      credentials: 'include',
    });

    if (!response.ok) {
      throw new Error('Failed to delete notification');
    }
  }

  async clearOldNotifications(days: number = 30): Promise<{ deleted: number }> {
    const response = await fetch(`${this.baseUrl}/clear-old?days=${days}`, {
      method: 'DELETE',
      credentials: 'include',
    });

    if (!response.ok) {
      throw new Error('Failed to clear old notifications');
    }

    return response.json();
  }
}

export const notificationService = new NotificationService();