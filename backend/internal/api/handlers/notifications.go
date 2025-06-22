package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/toole-brendan/handreceipt-go/internal/domain"
)

// NotificationHandlers handles notification-related endpoints
type NotificationHandlers struct {
	notificationService domain.NotificationService
}

// NewNotificationHandlers creates a new notification handlers instance
func NewNotificationHandlers(notificationService domain.NotificationService) *NotificationHandlers {
	return &NotificationHandlers{
		notificationService: notificationService,
	}
}

// GetNotifications returns a list of notifications for the authenticated user
func (h *NotificationHandlers) GetNotifications(c *gin.Context) {
	userID := c.GetInt("userID")
	
	// Get query parameters
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	unreadOnly := c.Query("unread_only") == "true"

	notifications, err := h.notificationService.GetUserNotifications(userID, limit, offset, unreadOnly)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch notifications"})
		return
	}

	c.JSON(http.StatusOK, notifications)
}

// GetUnreadCount returns the count of unread notifications
func (h *NotificationHandlers) GetUnreadCount(c *gin.Context) {
	userID := c.GetInt("userID")

	count, err := h.notificationService.GetUnreadCount(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get unread count"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"count": count})
}

// MarkAsRead marks a notification as read
func (h *NotificationHandlers) MarkAsRead(c *gin.Context) {
	userID := c.GetInt("userID")
	notificationID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	err = h.notificationService.MarkAsRead(userID, notificationID)
	if err != nil {
		if err.Error() == "notification not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark notification as read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notification marked as read"})
}

// MarkAllAsRead marks all notifications as read for the user
func (h *NotificationHandlers) MarkAllAsRead(c *gin.Context) {
	userID := c.GetInt("userID")

	err := h.notificationService.MarkAllAsRead(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark all notifications as read"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "All notifications marked as read"})
}

// DeleteNotification deletes a notification
func (h *NotificationHandlers) DeleteNotification(c *gin.Context) {
	userID := c.GetInt("userID")
	notificationID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid notification ID"})
		return
	}

	err = h.notificationService.DeleteNotification(userID, notificationID)
	if err != nil {
		if err.Error() == "notification not found" {
			c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete notification"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Notification deleted"})
}

// ClearOldNotifications clears notifications older than specified days
func (h *NotificationHandlers) ClearOldNotifications(c *gin.Context) {
	userID := c.GetInt("userID")
	days, _ := strconv.Atoi(c.DefaultQuery("days", "30"))

	deletedCount, err := h.notificationService.ClearOldNotifications(userID, days)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clear old notifications"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Old notifications cleared",
		"deleted": deletedCount,
	})
}