import { Notification } from "@/types";
import { useToast } from "@/hooks/use-toast";

interface NotificationItemProps {
  notification: Notification;
}

const NotificationItem: React.FC<NotificationItemProps> = ({ notification }) => {
  const { toast } = useToast();

  const getIconStyles = () => {
    switch (notification.type) {
      case "transfer-request":
        return {
          bgColor: "bg-amber-100",
          iconColor: "text-[#FFC107]",
          icon: "exchange-alt"
        };
      case "transfer-approved":
        return {
          bgColor: "bg-green-100",
          iconColor: "text-[#28A745]",
          icon: "check"
        };
      case "system-alert":
        return {
          bgColor: "bg-blue-100",
          iconColor: "text-blue-600",
          icon: "info"
        };
      default:
        return {
          bgColor: "bg-gray-100",
          iconColor: "text-gray-500",
          icon: "bell"
        };
    }
  };

  const { bgColor, iconColor, icon } = getIconStyles();

  const handleAccept = () => {
    toast({
      title: "Transfer Accepted",
      description: "You have accepted the transfer request",
    });
  };

  const handleReject = () => {
    toast({
      title: "Transfer Rejected",
      description: "You have rejected the transfer request",
    });
  };

  return (
    <div className="p-4 hover:bg-gray-50">
      <div className="flex">
        <div className="mr-4 flex-shrink-0">
          <div className={`h-10 w-10 rounded-full ${bgColor} flex items-center justify-center`}>
            <i className={`fas fa-${icon} ${iconColor}`}></i>
          </div>
        </div>
        <div>
          <p className="font-medium">{notification.title}</p>
          <p className="text-sm text-gray-600">{notification.message}</p>
          <p className="text-xs text-gray-500 mt-1">{notification.timeAgo}</p>
          
          {notification.type === "transfer-request" && (
            <div className="mt-2 flex space-x-2">
              <button 
                className="px-3 py-1.5 bg-[#28A745] text-white text-sm rounded-md hover:bg-opacity-90"
                onClick={handleAccept}
              >
                Accept
              </button>
              <button 
                className="px-3 py-1.5 bg-[#DC3545] text-white text-sm rounded-md hover:bg-opacity-90"
                onClick={handleReject}
              >
                Reject
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default NotificationItem;
