import React from 'react';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { 
  Bell, 
  Check, 
  ChevronRight, 
  Trash2, 
  ArrowLeftRight,
  Info,
  CheckCircle2,
  AlertTriangle,
  AlertCircle,
  Inbox,
  Clock
} from 'lucide-react';
import { useNotifications, Notification } from '@/contexts/NotificationContext';
import { formatDistanceToNow } from 'date-fns';
import { cn } from '@/lib/utils';

interface NotificationPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

const NotificationPanel: React.FC<NotificationPanelProps> = ({ isOpen, onClose }) => {
  const { notifications, markAllAsRead, clearAllNotifications, markAsRead } = useNotifications();
  
  const transferNotifications = notifications.filter(n => 
    n.type === 'transfer-request' || 
    n.type === 'transfer-approved' || 
    n.type === 'transfer-rejected'
  );
  const systemNotifications = notifications.filter(n => 
    !transferNotifications.some(tn => tn.id === n.id)
  );
  
  const unreadCount = notifications.filter(n => !n.read).length;
  
  return (
    <Sheet open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="w-full max-w-md sm:max-w-lg overflow-hidden flex flex-col p-0 gap-0">
        {/* Enhanced Header */}
        <div className="bg-gradient-to-b from-white to-ios-tertiary-background/30 border-b border-ios-border">
          <SheetHeader className="p-6 pb-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-ios-accent/10 rounded-lg">
                  <Bell className="h-5 w-5 text-ios-accent" />
                </div>
                <div>
                  <SheetTitle className="text-lg font-semibold">Notifications</SheetTitle>
                  {unreadCount > 0 && (
                    <p className="text-xs text-ios-secondary-text mt-0.5">
                      {unreadCount} unread {unreadCount === 1 ? 'notification' : 'notifications'}
                    </p>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-xs hover:bg-ios-tertiary-background font-mono font-semibold uppercase tracking-wider"
                  onClick={markAllAsRead}
                  disabled={notifications.every(n => n.read)}
                >
                  <Check className="h-3.5 w-3.5 mr-1" />
                  Mark All Read
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 text-ios-destructive hover:bg-ios-destructive/10 hover:text-ios-destructive"
                  onClick={clearAllNotifications}
                  disabled={notifications.length === 0}
                  title="Clear all notifications"
                >
                  <Trash2 className="h-4 w-4" />
                </Button>
              </div>
            </div>
          </SheetHeader>
        </div>
        
        {/* Enhanced Tabs */}
        <div className="flex-grow overflow-hidden flex flex-col">
          <Tabs defaultValue="all" className="flex flex-col h-full">
            <div className="px-6 pt-2 bg-ios-tertiary-background/30">
              <TabsList className="grid grid-cols-3 bg-ios-tertiary-background/50 p-1 rounded-lg">
                <TabsTrigger 
                  value="all" 
                  className="data-[state=active]:bg-white data-[state=active]:shadow-sm rounded-md transition-all duration-200 font-mono font-semibold uppercase text-xs tracking-wider"
                >
                  All ({notifications.length})
                </TabsTrigger>
                <TabsTrigger 
                  value="transfers"
                  className="data-[state=active]:bg-white data-[state=active]:shadow-sm rounded-md transition-all duration-200 font-mono font-semibold uppercase text-xs tracking-wider"
                >
                  Transfers ({transferNotifications.length})
                </TabsTrigger>
                <TabsTrigger 
                  value="system"
                  className="data-[state=active]:bg-white data-[state=active]:shadow-sm rounded-md transition-all duration-200 font-mono font-semibold uppercase text-xs tracking-wider"
                >
                  System ({systemNotifications.length})
                </TabsTrigger>
              </TabsList>
            </div>
            
            <div className="flex-grow overflow-y-auto">
              <TabsContent value="all" className="p-6 pt-4 space-y-3 m-0">
                {notifications.length === 0 ? (
                  <EmptyState />
                ) : (
                  notifications.map(notification => (
                    <NotificationItem
                      key={notification.id}
                      notification={notification}
                      onMarkRead={() => markAsRead(notification.id)}
                    />
                  ))
                )}
              </TabsContent>
              
              <TabsContent value="transfers" className="p-6 pt-4 space-y-3 m-0">
                {transferNotifications.length === 0 ? (
                  <EmptyState type="transfers" />
                ) : (
                  transferNotifications.map(notification => (
                    <NotificationItem
                      key={notification.id}
                      notification={notification}
                      onMarkRead={() => markAsRead(notification.id)}
                    />
                  ))
                )}
              </TabsContent>
              
              <TabsContent value="system" className="p-6 pt-4 space-y-3 m-0">
                {systemNotifications.length === 0 ? (
                  <EmptyState type="system" />
                ) : (
                  systemNotifications.map(notification => (
                    <NotificationItem
                      key={notification.id}
                      notification={notification}
                      onMarkRead={() => markAsRead(notification.id)}
                    />
                  ))
                )}
              </TabsContent>
            </div>
          </Tabs>
        </div>
      </SheetContent>
    </Sheet>
  );
};

const NotificationItem = ({ 
  notification, 
  onMarkRead 
}: { 
  notification: Notification, 
  onMarkRead: () => void 
}) => {
  const handleClick = () => {
    if (!notification.read) {
      onMarkRead();
    }
    if (notification.action?.path) {
      window.location.href = notification.action.path;
    }
  };
  
  const getIcon = (type: string) => {
    switch (type) {
      case 'transfer-request':
      case 'transfer-approved':
      case 'transfer-rejected':
        return {
          icon: <ArrowLeftRight className="h-4 w-4" />,
          bg: type === 'transfer-approved' ? 'bg-green-500/10' : 
              type === 'transfer-rejected' ? 'bg-red-500/10' : 'bg-blue-500/10',
          color: type === 'transfer-approved' ? 'text-green-500' : 
                 type === 'transfer-rejected' ? 'text-red-500' : 'text-blue-500'
        };
      case 'info':
        return {
          icon: <Info className="h-4 w-4" />,
          bg: 'bg-blue-500/10',
          color: 'text-blue-500'
        };
      case 'success':
        return {
          icon: <CheckCircle2 className="h-4 w-4" />,
          bg: 'bg-green-500/10',
          color: 'text-green-500'
        };
      case 'warning':
        return {
          icon: <AlertTriangle className="h-4 w-4" />,
          bg: 'bg-yellow-500/10',
          color: 'text-yellow-500'
        };
      case 'critical':
        return {
          icon: <AlertCircle className="h-4 w-4" />,
          bg: 'bg-red-500/10',
          color: 'text-red-500'
        };
      default:
        return {
          icon: <Bell className="h-4 w-4" />,
          bg: 'bg-ios-tertiary-background',
          color: 'text-ios-secondary-text'
        };
    }
  };
  
  const iconConfig = getIcon(notification.type);
  
  return (
    <div
      className={cn(
        "p-4 rounded-lg border cursor-pointer transition-all duration-200 group",
        notification.read 
          ? "border-ios-border bg-transparent hover:bg-ios-tertiary-background/30" 
          : "border-ios-accent/20 bg-ios-accent/5 hover:bg-ios-accent/10 shadow-sm"
      )}
      onClick={handleClick}
    >
      <div className="flex items-start gap-3">
        <div className={cn(
          "p-2.5 rounded-lg transition-all duration-200",
          iconConfig.bg,
          "group-hover:scale-110"
        )}>
          <div className={cn("flex items-center justify-center", iconConfig.color)}>
            {iconConfig.icon}
          </div>
        </div>
        
        <div className="flex-1 min-w-0">
          <div className="flex items-start justify-between gap-2">
            <h4 className={cn(
              "font-medium text-sm",
              !notification.read && "text-ios-primary-text"
            )}>
              {notification.title}
            </h4>
            <span className="text-xs text-ios-tertiary-text flex-shrink-0 flex items-center gap-1 font-mono">
              <Clock className="h-3 w-3" />
              {formatDistanceToNow(new Date(notification.timestamp), { addSuffix: true })}
            </span>
          </div>
          
          <p className={cn(
            "text-sm mt-1 line-clamp-2",
            notification.read ? "text-ios-tertiary-text" : "text-ios-secondary-text"
          )}>
            {notification.message}
          </p>
          
          {notification.action && (
            <div className="flex items-center mt-3">
              <Button
                variant="link"
                size="sm"
                className="text-xs h-auto p-0 text-ios-accent hover:text-ios-accent/80 font-medium transition-colors"
              >
                {notification.action.label}
                <ChevronRight className="h-3 w-3 ml-1 transition-transform duration-200 group-hover:translate-x-0.5" />
              </Button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

const EmptyState = ({ type = 'all' }: { type?: string }) => {
  const getEmptyMessage = () => {
    switch (type) {
      case 'transfers':
        return {
          title: "No transfer notifications",
          description: "Transfer updates will appear here",
          icon: <ArrowLeftRight className="h-6 w-6 text-ios-tertiary-text" />
        };
      case 'system':
        return {
          title: "No system notifications",
          description: "System alerts will appear here",
          icon: <Info className="h-6 w-6 text-ios-tertiary-text" />
        };
      default:
        return {
          title: "No notifications",
          description: "You're all caught up!",
          icon: <Inbox className="h-6 w-6 text-ios-tertiary-text" />
        };
    }
  };
  
  const emptyConfig = getEmptyMessage();
  
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center">
      <div className="p-4 rounded-full bg-ios-tertiary-background mb-4">
        {emptyConfig.icon}
      </div>
      <h3 className="font-medium text-ios-primary-text mb-1 font-mono uppercase tracking-wider text-sm">
        {emptyConfig.title}
      </h3>
      <p className="text-sm text-ios-tertiary-text">
        {emptyConfig.description}
      </p>
    </div>
  );
};

export default NotificationPanel;