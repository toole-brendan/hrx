import { Activity } from "@/types";
import { CheckCircle, XCircle, RefreshCcw, Info } from "lucide-react";

interface ActivityItemProps {
  activity: Activity;
}

const ActivityItem: React.FC<ActivityItemProps> = ({ activity }) => {
  const getIconConfig = () => {
    switch (activity.type) {
      case "transfer-approved":
        return {
          bgColor: "bg-green-100 dark:bg-green-500/20",
          iconColor: "text-green-600 dark:text-green-500",
          icon: <CheckCircle className="h-4 w-4" />
        };
      case "transfer-rejected":
        return {
          bgColor: "bg-red-100 dark:bg-red-500/20",
          iconColor: "text-red-600 dark:text-red-500",
          icon: <XCircle className="h-4 w-4" />
        };
      case "inventory-updated":
        return {
          bgColor: "bg-blue-100 dark:bg-blue-500/20",
          iconColor: "text-blue-600 dark:text-blue-500",
          icon: <RefreshCcw className="h-4 w-4" />
        };
      default:
        return {
          bgColor: "bg-gray-100 dark:bg-gray-500/20",
          iconColor: "text-gray-600 dark:text-gray-400",
          icon: <Info className="h-4 w-4" />
        };
    }
  };

  const { bgColor, iconColor, icon } = getIconConfig();

  return (
    <div className="p-4 hover:bg-muted/10">
      <div className="flex">
        <div className="mr-4 flex-shrink-0">
          <div className={`h-8 w-8 rounded-full ${bgColor} flex items-center justify-center ${iconColor}`}>
            {icon}
          </div>
        </div>
        <div className="flex-1">
          <p className="text-sm font-medium">{activity.description}</p>
          <div className="flex items-center gap-1 mt-1">
            <p className="text-xs text-muted-foreground">{activity.user}</p>
            <span className="text-xs text-muted-foreground/60">•</span>
            <p className="text-xs text-muted-foreground/60">{activity.timeAgo}</p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ActivityItem;
