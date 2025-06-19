import { activities } from "@/lib/mockData";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ListChecks } from "lucide-react";
import { useLocation } from "wouter";
import { ActivityLogItem } from "@/components/dashboard/ActivityLogItem";

const RecentActivity: React.FC = () => {
  const [, navigate] = useLocation();
  const recentActivities = activities.slice(0, 4); // Only show 4 most recent activities

  return (
    <Card className="overflow-hidden border-gray-200 dark:border-border shadow-none bg-white dark:bg-card">
      <div className="p-4 flex justify-between items-baseline bg-gray-900 dark:bg-black">
        <div>
          <div className="uppercase text-xs tracking-wider font-medium text-gray-400 dark:text-muted-foreground mb-1">
            ACTIVITY LOG
          </div>
          <div className="text-lg font-normal text-white dark:text-white">
            Recent blockchain activity
          </div>
        </div>
        
        <Button 
          variant="ghost" 
          className="text-xs uppercase tracking-wider text-gray-400 dark:text-blue-400 hover:bg-transparent hover:text-white dark:hover:text-blue-300"
          onClick={() => navigate("/audit-log")}
        >
          VIEW ALL
        </Button>
      </div>
      
      <CardContent className="p-0 bg-white dark:bg-card">
        {recentActivities.length === 0 ? (
          <div className="px-4 pb-4 text-center text-muted-foreground flex flex-col items-center">
            <ListChecks className="h-12 w-12 mb-2 text-muted-foreground/50" />
            <p>No activity recorded yet</p>
          </div>
        ) : (
          <div className="divide-y divide-gray-200 dark:divide-border px-4 pb-2">
            {recentActivities.map((activity) => (
              <ActivityLogItem 
                key={activity.id}
                id={activity.id}
                title={activity.description}
                timestamp={activity.timeAgo}
                verified={activity.type === 'transfer-approved' || activity.type === 'inventory-updated'}
              />
            ))}
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default RecentActivity;
