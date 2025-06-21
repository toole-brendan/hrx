import React, { useMemo, useState } from 'react';
import { useLocation } from 'wouter';
import { useAuth } from '@/contexts/AuthContext';
import { useNotifications } from '@/contexts/NotificationContext';
import { 
  AlertTriangle, 
  CheckCircle, 
  Clock8, 
  Search, 
  UserCircle, 
  Inbox, 
  FileScan,
  Package,
  Users,
  Activity,
  TrendingUp,
  Shield,
  ArrowRight,
  Bell,
  BarChart3,
  FileText,
  Zap
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { useQuery } from '@tanstack/react-query';
import { getConnections } from '@/services/connectionService';
import { cn } from '@/lib/utils';

// iOS Components
import { CleanCard, ElegantSectionHeader, StatusBadge } from '@/components/ios';

// Dashboard components
import RecentActivity from '@/components/dashboard/RecentActivity';

// Modals
import NotificationPanel from '@/components/modals/NotificationPanel';

// Enhanced Quick Action Card Component
interface QuickActionCardProps {
  title: string;
  value?: string | number;
  icon: React.ReactNode;
  description?: string;
  trend?: number;
  onClick: () => void;
  color?: 'accent' | 'blue' | 'green' | 'orange' | 'purple';
}

const QuickActionCard: React.FC<QuickActionCardProps> = ({ 
  title, 
  value, 
  icon, 
  description,
  trend,
  onClick,
  color = 'accent'
}) => {
  const colorClasses = {
    accent: 'bg-ios-accent/10 text-ios-accent border-ios-accent/20',
    blue: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
    green: 'bg-green-500/10 text-green-500 border-green-500/20',
    orange: 'bg-orange-500/10 text-orange-500 border-orange-500/20',
    purple: 'bg-purple-500/10 text-purple-500 border-purple-500/20'
  };

  return (
    <button
      onClick={onClick}
      className="group relative overflow-hidden rounded-xl transition-all duration-300 hover:scale-[1.02] active:scale-[0.98] w-full"
    >
      <CleanCard className="h-full p-5 border border-ios-border hover:border-ios-accent/30 hover:shadow-lg transition-all duration-300">
        <div className="flex flex-col h-full">
          <div className="flex items-start justify-between mb-3">
            <div className={cn(
              "p-2.5 rounded-lg transition-all duration-300 group-hover:scale-110",
              colorClasses[color]
            )}>
              {icon}
            </div>
            {trend !== undefined && (
              <div className={cn(
                "flex items-center gap-1 text-xs font-medium",
                trend > 0 ? "text-green-500" : trend < 0 ? "text-red-500" : "text-ios-tertiary-text"
              )}>
                <TrendingUp className={cn("h-3 w-3", trend < 0 && "rotate-180")} />
                {Math.abs(trend)}%
              </div>
            )}
          </div>
          
          <div className="flex-1 flex flex-col justify-between">
            <div>
              {value !== undefined && (
                <div className="text-2xl font-bold text-ios-primary-text mb-1 font-['Courier_New',_monospace]">
                  {typeof value === 'number' ? value.toLocaleString() : value}
                </div>
              )}
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                {title}
              </h3>
            </div>
            
            {description && (
              <p className="text-xs text-ios-secondary-text mt-2 line-clamp-2">
                {description}
              </p>
            )}
          </div>
          
          <div className="mt-3 flex items-center justify-end opacity-0 group-hover:opacity-100 transition-opacity duration-300">
            <ArrowRight className="h-4 w-4 text-ios-accent" />
          </div>
        </div>
      </CleanCard>
    </button>
  );
};

// Enhanced Stat Card Component
interface StatCardProps {
  title: string;
  value: string | number;
  icon: React.ReactNode;
  trend?: {
    value: number;
    label: string;
  };
  subtitle?: string;
}

const StatCard: React.FC<StatCardProps> = ({ title, value, icon, trend, subtitle }) => (
  <div className="bg-gradient-to-br from-white to-ios-secondary-background rounded-xl p-6 border border-ios-border shadow-sm hover:shadow-md transition-all duration-300">
    <div className="flex items-start justify-between mb-4">
      <div className="p-3 bg-ios-accent/10 rounded-lg">
        {icon}
      </div>
      {trend && (
        <div className="text-right">
          <div className={cn(
            "text-sm font-semibold",
            trend.value > 0 ? "text-green-500" : "text-ios-tertiary-text"
          )}>
            {trend.value > 0 && "+"}{trend.value}%
          </div>
          <div className="text-xs text-ios-tertiary-text">{trend.label}</div>
        </div>
      )}
    </div>
    <div>
      <div className="text-3xl font-bold text-ios-primary-text mb-1 font-['Courier_New',_monospace]">
        {typeof value === 'number' ? value.toLocaleString() : value}
      </div>
      <h3 className="text-sm font-medium text-ios-secondary-text">{title}</h3>
      {subtitle && (
        <p className="text-xs text-ios-tertiary-text mt-1">{subtitle}</p>
      )}
    </div>
  </div>
);

export default function Dashboard() {
  const { user } = useAuth();
  const [, navigate] = useLocation();
  const { unreadCount } = useNotifications();
  const [showNotifications, setShowNotifications] = useState(false);
  
  // Fetch connections data
  const { data: connections = [] } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
  });
  
  // Alert counts - Using real data from API or default values
  const pendingTransfersCount = 0; // TODO: Fetch from API
  const pendingMaintenanceCount = 0; // TODO: Fetch from API
  const sensitiveItemVerifications = 0; // TODO: Fetch from API
  const totalProperties = 0; // TODO: Fetch from API
  const documentsCount = 0; // TODO: Fetch from API
  
  // Calculate verification percentage
  const verificationPercentage = 0; // TODO: Calculate from API data
  
  // Calculate network stats
  const connectedUsersCount = connections.filter(c => c.connectionStatus === 'accepted').length;
  const pendingConnectionsCount = connections.filter(c => c.connectionStatus === 'pending').length;
  
  // Calculate dynamic readiness stats - TODO: Replace with API data
  const readinessStats = useMemo(() => {
    // Default values until API integration
    return {
      operational: { count: 0, percentage: 0 },
      maintenance: { count: 0, percentage: 0 },
      nonOperational: { count: 0, percentage: 0 },
      other: { count: 0, percentage: 0 },
    };
  }, []);
  
  // Helper function to format welcome message - iOS style
  const getWelcomeMessage = () => {
    if (!user) return "Welcome";
    
    const hour = new Date().getHours();
    let greeting = "Good evening";
    if (hour < 12) greeting = "Good morning";
    else if (hour < 17) greeting = "Good afternoon";
    
    return greeting;
  };
  
  const getUserTitle = () => {
    if (!user) return "";
    
    const parts = [];
    
    // Convert common full ranks to abbreviations
    const rankAbbreviations: Record<string, string> = {
      "Captain": "CPT",
      "Lieutenant": "LT",
      "First Lieutenant": "1LT",
      "Second Lieutenant": "2LT",
      "Major": "MAJ",
      "Colonel": "COL",
      "Sergeant": "SGT",
      "Private": "PVT",
      "Specialist": "SPC",
      "Corporal": "CPL",
      "Staff Sergeant": "SSG",
      "Sergeant First Class": "SFC",
      "Master Sergeant": "MSG",
      "First Sergeant": "1SG",
      "Sergeant Major": "SGM"
    };
    
    // Add rank if available (handle full rank names)
    if (user.rank) {
      const rank = rankAbbreviations[user.rank] || user.rank;
      parts.push(rank);
    }
    
    // Add last name if available
    if (user.lastName) {
      parts.push(user.lastName);
    }
    
    return parts.join(" ");
  };
  
  // TODO: Add real maintenance notification checks from API
  
  return (
    <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
      <div className="max-w-6xl mx-auto px-6 py-8">
        {/* Enhanced Header section */}
        <div className="mb-12">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-8">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-xl shadow-sm">
                <Shield className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-bold text-ios-primary-text">
                  Dashboard
                </h1>
                <p className="text-sm text-ios-secondary-text mt-1">
                  {getWelcomeMessage()}, {getUserTitle()}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setShowNotifications(true)}
                className="relative p-2.5 hover:bg-ios-tertiary-background rounded-lg transition-colors"
              >
                <Bell className="h-5 w-5 text-ios-secondary-text" />
                {unreadCount > 0 && (
                  <span className="absolute top-1 right-1 h-2 w-2 bg-ios-destructive rounded-full" />
                )}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => navigate('/search')}
                className="p-2.5 hover:bg-ios-tertiary-background rounded-lg transition-colors"
              >
                <Search className="h-5 w-5 text-ios-secondary-text" />
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => navigate('/profile')}
                className="p-2.5 hover:bg-ios-tertiary-background rounded-lg transition-colors"
              >
                <UserCircle className="h-5 w-5 text-ios-secondary-text" />
              </Button>
            </div>
          </div>
          
          {/* Key Metrics Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
            <StatCard
              title="Total Properties"
              value={totalProperties}
              icon={<Package className="h-5 w-5 text-ios-accent" />}
              trend={{ value: 12, label: "vs last month" }}
            />
            <StatCard
              title="Pending Transfers"
              value={pendingTransfersCount}
              icon={<Activity className="h-5 w-5 text-orange-500" />}
              subtitle="Requires action"
            />
            <StatCard
              title="Connected Users"
              value={connectedUsersCount}
              icon={<Users className="h-5 w-5 text-blue-500" />}
              trend={{ value: 5, label: "new this week" }}
            />
            <StatCard
              title="Documents"
              value={documentsCount}
              icon={<FileText className="h-5 w-5 text-purple-500" />}
              subtitle="In your inbox"
            />
          </div>
        </div>
        
        {/* Quick Actions Section */}
        <div className="mb-10">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-ios-accent/10 rounded-lg">
              <Zap className="h-5 w-5 text-ios-accent" />
            </div>
            <h2 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
              QUICK ACTIONS
            </h2>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <QuickActionCard
              title="Property Book"
              value={totalProperties}
              icon={<Package className="h-5 w-5" />}
              description="View and manage all assigned equipment"
              onClick={() => navigate('/property-book')}
              color="accent"
            />
            
            <QuickActionCard
              title="Import DA-2062"
              icon={<FileScan className="h-5 w-5" />}
              description="Scan and import hand receipt forms"
              onClick={() => navigate('/property-book?action=import-da2062')}
              color="blue"
            />
            
            <QuickActionCard
              title="Documents"
              value={documentsCount}
              icon={<Inbox className="h-5 w-5" />}
              description="View receipts, forms, and reports"
              onClick={() => navigate('/documents')}
              color="purple"
            />
          </div>
        </div>
        
        {/* Network Section */}
        <div className="mb-10">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-blue-500/10 rounded-lg">
                <Users className="h-5 w-5 text-blue-500" />
              </div>
              <div>
                <h2 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                  NETWORK
                </h2>
                <p className="text-xs text-ios-secondary-text mt-0.5">Connected users and transfer partners</p>
              </div>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => navigate('/network')}
              className="text-xs font-semibold text-ios-accent hover:text-ios-accent/80 hover:bg-transparent px-3 py-1 uppercase tracking-wider font-['Courier_New',_monospace] transition-colors"
            >
              View All
              <ArrowRight className="h-3 w-3 ml-1" />
            </Button>
          </div>
          
          <CleanCard className="p-6 shadow-sm">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
              <div className="text-center">
                <div className="text-3xl font-bold text-ios-primary-text mb-1 font-['Courier_New',_monospace]">
                  {connectedUsersCount}
                </div>
                <div className="text-xs text-ios-secondary-text uppercase tracking-wider">Connected</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-orange-500 mb-1 font-['Courier_New',_monospace]">
                  {pendingConnectionsCount}
                </div>
                <div className="text-xs text-ios-secondary-text uppercase tracking-wider">Pending</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-ios-primary-text mb-1 font-['Courier_New',_monospace]">
                  0
                </div>
                <div className="text-xs text-ios-secondary-text uppercase tracking-wider">Recent</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-ios-primary-text mb-1 font-['Courier_New',_monospace]">
                  0
                </div>
                <div className="text-xs text-ios-secondary-text uppercase tracking-wider">Blocked</div>
              </div>
            </div>
          </CleanCard>
        </div>
        
        {/* Recent Activity Section */}
        <div className="mb-10">
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-green-500/10 rounded-lg">
                <Activity className="h-5 w-5 text-green-500" />
              </div>
              <div>
                <h2 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                  RECENT ACTIVITY
                </h2>
                <p className="text-xs text-ios-secondary-text mt-0.5">Latest transfers and updates</p>
              </div>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => navigate('/transfers')}
              className="text-xs font-semibold text-ios-accent hover:text-ios-accent/80 hover:bg-transparent px-3 py-1 uppercase tracking-wider font-['Courier_New',_monospace] transition-colors"
            >
              See All
              <ArrowRight className="h-3 w-3 ml-1" />
            </Button>
          </div>
          <CleanCard className="p-0 shadow-sm overflow-hidden">
            <RecentActivity activities={[]} />
          </CleanCard>
        </div>
        
        {/* Property Status Section */}
        <div className="mb-10">
          <div className="flex items-center gap-3 mb-6">
            <div className="p-2 bg-orange-500/10 rounded-lg">
              <BarChart3 className="h-5 w-5 text-orange-500" />
            </div>
            <div>
              <h2 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                PROPERTY STATUS
              </h2>
              <p className="text-xs text-ios-secondary-text mt-0.5">Equipment operational readiness</p>
            </div>
          </div>
          
          <CleanCard className="p-6 shadow-sm">
            <div className="space-y-6">
              <div className="flex items-center justify-between group">
                <div className="flex items-center gap-4">
                  <div className="p-2.5 bg-green-500/10 rounded-lg transition-all duration-200 group-hover:scale-110">
                    <CheckCircle className="h-5 w-5 text-green-500" />
                  </div>
                  <div>
                    <span className="text-sm font-medium text-ios-primary-text">Operational</span>
                    <p className="text-xs text-ios-tertiary-text">{readinessStats.operational.count} items</p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-sm font-bold text-ios-primary-text font-['Courier_New',_monospace]">
                    {readinessStats.operational.percentage}%
                  </span>
                  <div className="w-32">
                    <Progress 
                      value={readinessStats.operational.percentage} 
                      className="h-2 bg-ios-tertiary-background [&>div]:bg-green-500 [&>div]:transition-all [&>div]:duration-500" 
                    />
                  </div>
                </div>
              </div>
              
              <div className="flex items-center justify-between group">
                <div className="flex items-center gap-4">
                  <div className="p-2.5 bg-orange-500/10 rounded-lg transition-all duration-200 group-hover:scale-110">
                    <Clock8 className="h-5 w-5 text-orange-500" />
                  </div>
                  <div>
                    <span className="text-sm font-medium text-ios-primary-text">In Maintenance</span>
                    <p className="text-xs text-ios-tertiary-text">{readinessStats.maintenance.count} items</p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-sm font-bold text-ios-primary-text font-['Courier_New',_monospace]">
                    {readinessStats.maintenance.percentage}%
                  </span>
                  <div className="w-32">
                    <Progress 
                      value={readinessStats.maintenance.percentage} 
                      className="h-2 bg-ios-tertiary-background [&>div]:bg-orange-500 [&>div]:transition-all [&>div]:duration-500" 
                    />
                  </div>
                </div>
              </div>
              
              <div className="flex items-center justify-between group">
                <div className="flex items-center gap-4">
                  <div className="p-2.5 bg-red-500/10 rounded-lg transition-all duration-200 group-hover:scale-110">
                    <AlertTriangle className="h-5 w-5 text-red-500" />
                  </div>
                  <div>
                    <span className="text-sm font-medium text-ios-primary-text">Non-operational</span>
                    <p className="text-xs text-ios-tertiary-text">{readinessStats.nonOperational.count} items</p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-sm font-bold text-ios-primary-text font-['Courier_New',_monospace]">
                    {readinessStats.nonOperational.percentage}%
                  </span>
                  <div className="w-32">
                    <Progress 
                      value={readinessStats.nonOperational.percentage} 
                      className="h-2 bg-ios-tertiary-background [&>div]:bg-red-500 [&>div]:transition-all [&>div]:duration-500" 
                    />
                  </div>
                </div>
              </div>
            </div>
          </CleanCard>
        </div>
        
        {/* Bottom padding for mobile navigation */}
        <div className="h-24"></div>
      </div>
      
      {/* Notification Panel */}
      <NotificationPanel 
        isOpen={showNotifications}
        onClose={() => setShowNotifications(false)}
      />
    </div>
  );
}