import React from 'react';
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Bell, Check, ChevronRight, Trash2 } from 'lucide-react';
import { useNotifications, Notification } from '@/contexts/NotificationContext';
import { formatDistanceToNow } from 'date-fns';

interface NotificationPanelProps {
  isOpen: boolean;
  onClose: () => void;
}

const NotificationPanel: React.FC<NotificationPanelProps> = ({ isOpen, onClose }) => {
  const { 
    notifications, 
    markAllAsRead, 
    clearAllNotifications, 
    markAsRead
  } = useNotifications();

  const transferNotifications = notifications.filter(n => n.type === 'transfer-request' || n.type === 'transfer-approved' || n.type === 'transfer-rejected');
  const systemNotifications = notifications.filter(n => !transferNotifications.some(tn => tn.id === n.id));

  return (
    <Sheet open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <SheetContent className="w-full max-w-md sm:max-w-lg overflow-y-auto flex flex-col">
        <SheetHeader className="border-b pb-4 mb-4">
          <div className="flex items-center justify-between">
            <SheetTitle>Notifications</SheetTitle>
             <div className="flex items-center gap-2">
               <Button 
                 variant="ghost" 
                 size="sm"
                 className="text-xs"
                 onClick={markAllAsRead}
                 disabled={notifications.every(n => n.read)}
               >
                 <Check className="h-3.5 w-3.5 mr-1" /> Mark all as read
               </Button>
                <Button 
                 variant="outline"
                 size="icon"
                 className="h-7 w-7 text-destructive border-destructive hover:bg-destructive/10"
                 onClick={clearAllNotifications}
                 disabled={notifications.length === 0}
                 title="Clear all notifications"
               >
                 <Trash2 className="h-3.5 w-3.5" />
               </Button>
             </div>
          </div>
        </SheetHeader>
        
        <div className="flex-grow overflow-y-auto pr-2">
          <Tabs defaultValue="all" className="flex flex-col h-full">
            <TabsList className="grid grid-cols-3 mb-4 sticky top-0 bg-background z-10">
              <TabsTrigger value="all">All ({notifications.length})</TabsTrigger>
              <TabsTrigger value="transfers">Transfers ({transferNotifications.length})</TabsTrigger>
              <TabsTrigger value="system">System ({systemNotifications.length})</TabsTrigger>
            </TabsList>
            
            <TabsContent value="all" className="space-y-3 flex-grow">
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
            
            <TabsContent value="transfers" className="space-y-3 flex-grow"> 
              {transferNotifications.length === 0 ? (
                <EmptyState />
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
            
            <TabsContent value="system" className="space-y-3 flex-grow">
              {systemNotifications.length === 0 ? (
                <EmptyState />
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
          </Tabs>
        </div>
      </SheetContent>
    </Sheet>
  );
};

const NotificationItem = ({ notification, onMarkRead }: { notification: Notification, onMarkRead: () => void }) => {
  
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
        return <div className="h-8 w-8 rounded-full bg-blue-100 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 flex items-center justify-center flex-shrink-0">↔</div>;
      case 'info':
         return <div className="h-8 w-8 rounded-full bg-blue-100 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 flex items-center justify-center flex-shrink-0"><Bell className="h-4 w-4" /></div>;
      case 'success':
         return <div className="h-8 w-8 rounded-full bg-green-100 dark:bg-green-900/20 text-green-600 dark:text-green-400 flex items-center justify-center flex-shrink-0">✓</div>;
       case 'warning':
         return <div className="h-8 w-8 rounded-full bg-yellow-100 dark:bg-yellow-900/20 text-yellow-600 dark:text-yellow-400 flex items-center justify-center flex-shrink-0">!</div>;
      case 'critical':
         return <div className="h-8 w-8 rounded-full bg-red-100 dark:bg-red-900/20 text-red-600 dark:text-red-400 flex items-center justify-center flex-shrink-0">!</div>;
      default:
        return <div className="h-8 w-8 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400 flex items-center justify-center flex-shrink-0"><Bell className="h-4 w-4" /></div>;
    }
  };
  
  return (
    <div 
       className={`p-3 rounded-lg border cursor-pointer transition-colors ${notification.read ? 'border-gray-200 dark:border-gray-800 bg-transparent opacity-70 hover:bg-gray-50/50 dark:hover:bg-gray-800/30' : 'border-blue-200 dark:border-blue-800/50 bg-blue-50 dark:bg-blue-900/20 hover:bg-blue-100/70 dark:hover:bg-blue-900/30'}`}
       onClick={handleClick}
     >
      <div className="flex items-start space-x-3">
        {getIcon(notification.type)}
        <div className="flex-1 min-w-0">
          <div className="flex items-center justify-between">
            <h4 className="font-medium text-sm truncate">{notification.title}</h4>
            <span className="text-xs text-gray-500 dark:text-gray-400 flex-shrink-0 ml-2">
                {formatDistanceToNow(new Date(notification.timestamp), { addSuffix: true })}
            </span>
          </div>
          <p className="text-sm text-gray-600 dark:text-gray-300 mt-1 line-clamp-2">{notification.message}</p>
          
           {notification.action && (
            <div className="flex items-center mt-2">
              <Button variant="link" size="sm" className="text-xs h-7 px-1 text-primary">
                 {notification.action.label} <ChevronRight className="h-3 w-3 ml-1" />
              </Button>
             </div>
           )}
        </div>
      </div>
    </div>
  );
};

const EmptyState = () => {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center h-full">
      <div className="h-12 w-12 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-4">
        <Bell className="h-6 w-6 text-gray-400" />
      </div>
      <h3 className="font-medium mb-1">No notifications</h3>
      <p className="text-sm text-gray-500 dark:text-gray-400">You're all caught up!</p>
    </div>
  );
};

export default NotificationPanel;