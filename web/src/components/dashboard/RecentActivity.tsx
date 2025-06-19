import { Clock } from "lucide-react";
import { useLocation } from "wouter";
import { ActivityLogItem } from "@/components/dashboard/ActivityLogItem";
import { CleanCard } from "@/components/ios";

interface Activity {
  id: string;
  description: string;
  timeAgo: string;
  type: string;
}

interface RecentActivityProps {
  activities?: Activity[];
}

const RecentActivity: React.FC<RecentActivityProps> = ({ activities = [] }) => {
  const [, navigate] = useLocation();
  const recentActivities = activities.slice(0, 5); // Show 5 most recent activities like iOS
  
  if (activities.length === 0) {
    return (
      <CleanCard className="flex flex-col items-center justify-center py-12 px-8">
        <Clock className="h-12 w-12 text-tertiary-text mb-8 stroke-[1.5]" />
        <h3 className="text-lg font-semibold text-primary-text mb-3">
          No Recent Activity
        </h3>
        <p className="text-sm text-secondary-text text-center">
          Transfer activity will appear here
        </p>
      </CleanCard>
    );
  }
  
  return (
    <CleanCard padding="none">
      <div className="space-y-0">
        {recentActivities.map((activity, index) => (
          <div key={activity.id}>
            <ActivityLogItem
              id={activity.id}
              title={activity.description}
              timestamp={activity.timeAgo}
              verified={activity.type === 'transfer-approved' || activity.type === 'inventory-updated'}
            />
            {index < recentActivities.length - 1 && (
              <div className="border-t border-ios-divider ml-14" />
            )}
          </div>
        ))}
      </div>
    </CleanCard>
  );
};

export default RecentActivity;
