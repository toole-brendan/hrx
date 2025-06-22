import React, { useMemo, useState, useEffect, useRef } from 'react';
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
import { useDashboardStats, useReadinessPercentage } from '@/hooks/useDashboardStats';

// iOS Components
import { CleanCard, ElegantSectionHeader, StatusBadge } from '@/components/ios';
import { Skeleton } from '@/components/ui/skeleton';

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
  badge?: {
    text: string;
    variant: 'success' | 'warning' | 'error' | 'info';
  };
  isUrgent?: boolean;
}

const QuickActionCard: React.FC<QuickActionCardProps> = ({ 
  title, 
  value, 
  icon, 
  description,
  trend,
  onClick,
  color = 'accent',
  badge,
  isUrgent
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
      className="group w-full"
    >
      <div className={cn(
        "bg-gradient-to-br from-white to-ios-secondary-background/70 rounded-xl p-6 border shadow-lg hover:shadow-xl hover:scale-[1.02] transition-all duration-300 transform-gpu relative overflow-hidden",
        isUrgent ? "border-orange-500/50 hover:border-orange-500" : "border-ios-border hover:border-ios-accent/30"
      )}>
        {/* Subtle background pattern */}
        <div className="absolute inset-0 opacity-5">
          <div className="absolute inset-0 bg-gradient-to-br from-transparent via-ios-accent/10 to-transparent" />
        </div>
        <div className="flex flex-col h-full relative z-10">
          <div className="flex items-start justify-between mb-3">
            <div className="relative">
              <div className={cn(
                "p-3 rounded-lg transition-all duration-300 group-hover:scale-110",
                colorClasses[color]
              )}>
                {icon}
              </div>
              {isUrgent && (
                <div className="absolute -top-1 -right-1 h-3 w-3 bg-orange-500 rounded-full animate-pulse" />
              )}
            </div>
            {badge ? (
              <span className={cn(
                "px-2 py-1 text-xs font-medium rounded-full",
                badge.variant === 'success' && "bg-green-100 text-green-700",
                badge.variant === 'warning' && "bg-orange-100 text-orange-700",
                badge.variant === 'error' && "bg-red-100 text-red-700",
                badge.variant === 'info' && "bg-blue-100 text-blue-700"
              )}>
                {badge.text}
              </span>
            ) : trend !== undefined && (
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
            <div className="text-center">
              <h3 className="text-sm font-semibold text-ios-secondary-text uppercase tracking-wider mb-1">
                {title}
              </h3>
              {value !== undefined && (
                <div className="text-3xl font-bold text-ios-primary-text font-mono">
                  {typeof value === 'number' ? (
                    <span className="tabular-nums">{value.toLocaleString()}</span>
                  ) : (
                    value
                  )}
                </div>
              )}
            </div>
            
            {description && (
              <p className="text-sm text-ios-secondary-text mt-3 line-clamp-2 leading-relaxed text-center">
                {description}
              </p>
            )}
          </div>
          
          <div className="mt-auto pt-3 flex items-center justify-center">
            <div className="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
              <span className="text-xs font-medium text-ios-accent">View Details</span>
              <ArrowRight className="h-4 w-4 text-ios-accent" />
            </div>
          </div>
        </div>
      </div>
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

const StatCard: React.FC<StatCardProps> = ({ title, value, icon, trend, subtitle }) => {
  // Loading state for stat cards
  const [isLoading, setIsLoading] = useState(true);
  
  useEffect(() => {
    // Simulate loading delay
    const timer = setTimeout(() => setIsLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);
  
  return (
  <div className="group bg-gradient-to-br from-white to-ios-secondary-background/70 rounded-xl p-6 border border-ios-border shadow-lg hover:shadow-xl hover:scale-[1.02] transition-all duration-300 transform-gpu">
    <div className="flex items-start justify-between mb-4">
      <div className="p-3 bg-ios-accent/10 rounded-lg transition-all duration-300 group-hover:scale-110 group-hover:bg-ios-accent/20">
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
      {isLoading ? (
        <>
          <Skeleton className="h-10 w-24 mb-2 bg-ios-tertiary-background" />
          <Skeleton className="h-4 w-32 bg-ios-tertiary-background" />
          {subtitle && <Skeleton className="h-3 w-20 mt-1 bg-ios-tertiary-background" />}
        </>
      ) : (
        <>
          <div className="text-3xl font-bold text-ios-primary-text mb-1 font-mono">
            {typeof value === 'number' ? value.toLocaleString() : value}
          </div>
          <h3 className="text-sm font-medium text-ios-secondary-text">{title}</h3>
          {subtitle && (
            <p className="text-xs text-ios-tertiary-text mt-1">{subtitle}</p>
          )}
        </>
      )}
    </div>
  </div>
  );
};

export default function Dashboard() {
  const { user } = useAuth();
  const [, navigate] = useLocation();
  const { unreadCount } = useNotifications();
  const [showNotifications, setShowNotifications] = useState(false);
  
  // Fetch dashboard statistics
  const { data: stats, isLoading: statsLoading } = useDashboardStats();
  const readinessPercentage = useReadinessPercentage(stats);
  
  // Fetch connections data separately (already included in stats)
  const { data: connections = [] } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
  });
  
  // Calculate dynamic readiness stats
  const readinessStats = useMemo(() => {
    if (!stats) return {
      operational: { count: 0, percentage: 0 },
      maintenance: { count: 0, percentage: 0 },
      nonOperational: { count: 0, percentage: 0 },
      other: { count: 0, percentage: 0 },
    };
    
    const total = stats.totalProperties || 1; // Avoid division by zero
    return {
      operational: { 
        count: stats.operationalCount, 
        percentage: Math.round((stats.operationalCount / total) * 100) 
      },
      maintenance: { 
        count: stats.deadlineMaintenanceCount + stats.inRepairCount, 
        percentage: Math.round(((stats.deadlineMaintenanceCount + stats.inRepairCount) / total) * 100) 
      },
      nonOperational: { 
        count: stats.nonOperationalCount + stats.damagedCount, 
        percentage: Math.round(((stats.nonOperationalCount + stats.damagedCount) / total) * 100) 
      },
      other: { 
        count: stats.lostCount + stats.deadlineSupplyCount, 
        percentage: Math.round(((stats.lostCount + stats.deadlineSupplyCount) / total) * 100) 
      },
    };
  }, [stats]);
  
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
  
  // ResizeObserver for responsive behavior
  const containerRef = useRef<HTMLDivElement>(null);
  const [containerWidth, setContainerWidth] = useState(0);
  
  useEffect(() => {
    if (!containerRef.current) return;
    
    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        setContainerWidth(entry.contentRect.width);
      }
    });
    
    resizeObserver.observe(containerRef.current);
    return () => resizeObserver.disconnect();
  }, []);
  
  return (
    <div ref={containerRef} className="min-h-screen bg-gradient-to-br from-ios-background via-ios-tertiary-background/30 to-ios-background relative overflow-hidden">
      {/* Decorative gradient orbs */}
      <div className="absolute top-0 left-0 w-96 h-96 bg-gradient-to-br from-blue-500/10 to-indigo-500/10 rounded-full blur-3xl" />
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-gradient-to-br from-purple-500/10 to-pink-500/10 rounded-full blur-3xl" />
      
      <div className="max-w-7xl mx-auto px-6 py-8 space-y-8 relative z-10">
        {/* Enhanced Header section */}
        <div className="space-y-8">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-xl shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-110 transform-gpu">
                <Shield className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700">
                  Dashboard
                </h1>
                <p className="text-sm font-medium text-ios-secondary-text mt-1">
                  {getWelcomeMessage()}, {getUserTitle()}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setShowNotifications(true)}
                className="relative p-2.5 hover:bg-ios-tertiary-background/80 rounded-lg transition-all duration-300 hover:scale-110 active:scale-95 transform-gpu"
              >
                <Bell className="h-5 w-5 text-ios-secondary-text" />
                {unreadCount > 0 && (
                  <span className="absolute top-1 right-1 h-2 w-2 bg-ios-destructive rounded-full animate-pulse" />
                )}
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => navigate('/search')}
                className="p-2.5 hover:bg-ios-tertiary-background/80 rounded-lg transition-all duration-300 hover:scale-110 active:scale-95 transform-gpu"
              >
                <Search className="h-5 w-5 text-ios-secondary-text" />
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => navigate('/profile')}
                className="p-2.5 hover:bg-ios-tertiary-background/80 rounded-lg transition-all duration-300 hover:scale-110 active:scale-95 transform-gpu"
              >
                <UserCircle className="h-5 w-5 text-ios-secondary-text" />
              </Button>
            </div>
          </div>
          
          {/* Key Metrics Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
            <StatCard
              title="Total Properties"
              value={stats?.totalProperties || 0}
              icon={<Package className="h-5 w-5 text-ios-accent" />}
              trend={{ value: 12, label: "vs last month" }}
            />
            <StatCard
              title="Pending Transfers"
              value={stats?.pendingTransfers || 0}
              icon={<Activity className="h-5 w-5 text-orange-500" />}
              subtitle="Requires action"
            />
            <StatCard
              title="Connected Users"
              value={stats?.totalConnections || 0}
              icon={<Users className="h-5 w-5 text-blue-500" />}
              trend={{ value: 5, label: "new this week" }}
            />
            <StatCard
              title="Documents"
              value={stats?.unreadDocuments || 0}
              icon={<FileText className="h-5 w-5 text-purple-500" />}
              subtitle="In your inbox"
            />
          </div>
        </div>
        
        {/* Quick Actions Section */}
        <div className="space-y-6">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-ios-accent/10 rounded-lg">
              <Zap className="h-5 w-5 text-ios-accent" />
            </div>
            <h2 className="text-sm font-black text-ios-primary-text uppercase tracking-widest font-mono">
              QUICK ACTIONS
            </h2>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <QuickActionCard
              title="Property Book"
              value={stats?.totalProperties || 0}
              icon={<Package className="h-5 w-5" />}
              description="View and manage all assigned equipment"
              onClick={() => navigate('/property-book')}
              color="accent"
              badge={(stats?.totalProperties || 0) > 0 ? { text: "Active", variant: "success" } : undefined}
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
              value={stats?.unreadDocuments || 0}
              icon={<Inbox className="h-5 w-5" />}
              description="View receipts, forms, and reports"
              onClick={() => navigate('/documents')}
              color="purple"
              badge={(stats?.unreadDocuments || 0) > 0 ? { text: `${stats?.unreadDocuments || 0} New`, variant: "warning" } : undefined}
              isUrgent={(stats?.unreadDocuments || 0) > 5}
            />
          </div>
        </div>
        
        {/* Network Section */}
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-blue-500/10 rounded-lg">
                <Users className="h-5 w-5 text-blue-500" />
              </div>
              <div>
                <h2 className="text-sm font-black text-ios-primary-text uppercase tracking-widest font-mono">
                  NETWORK
                </h2>
                <p className="text-xs font-medium text-ios-secondary-text mt-0.5">Connected users and transfer partners</p>
              </div>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => navigate('/network')}
              className="text-xs font-semibold text-ios-accent hover:text-ios-accent/80 hover:bg-transparent px-3 py-1 uppercase tracking-wider font-mono transition-all duration-300 hover:scale-105 active:scale-95"
            >
              View All
              <ArrowRight className="h-3 w-3 ml-1" />
            </Button>
          </div>
          
          <CleanCard className="p-6 bg-gradient-to-br from-white to-ios-secondary-background/50 shadow-lg hover:shadow-xl transition-all duration-300">
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
              <div className="text-center">
                {connections === undefined ? (
                  <>
                    <Skeleton className="h-9 w-16 mb-1 mx-auto bg-ios-tertiary-background" />
                    <Skeleton className="h-3 w-20 mx-auto bg-ios-tertiary-background" />
                  </>
                ) : (
                  <>
                    <div className="text-3xl font-bold text-ios-primary-text mb-1 font-mono">
                      {stats?.totalConnections || 0}
                    </div>
                    <div className="text-xs text-ios-secondary-text uppercase tracking-wider">Connected</div>
                  </>
                )}
              </div>
              <div className="text-center">
                {connections === undefined ? (
                  <>
                    <Skeleton className="h-9 w-16 mb-1 mx-auto bg-ios-tertiary-background" />
                    <Skeleton className="h-3 w-20 mx-auto bg-ios-tertiary-background" />
                  </>
                ) : (
                  <>
                    <div className="text-3xl font-bold text-orange-500 mb-1 font-mono">
                      {stats?.pendingConnectionRequests || 0}
                    </div>
                    <div className="text-xs text-ios-secondary-text uppercase tracking-wider">Pending</div>
                  </>
                )}
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-ios-primary-text mb-1 font-mono">
                  0
                </div>
                <div className="text-xs text-ios-secondary-text uppercase tracking-wider">Recent</div>
              </div>
              <div className="text-center">
                <div className="text-3xl font-bold text-ios-primary-text mb-1 font-mono">
                  0
                </div>
                <div className="text-xs text-ios-secondary-text uppercase tracking-wider">Blocked</div>
              </div>
            </div>
          </CleanCard>
        </div>
        
        {/* Recent Activity Section */}
        <div className="space-y-6">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-green-500/10 rounded-lg">
                <Activity className="h-5 w-5 text-green-500" />
              </div>
              <div>
                <h2 className="text-sm font-black text-ios-primary-text uppercase tracking-widest font-mono">
                  RECENT ACTIVITY
                </h2>
                <p className="text-xs font-medium text-ios-secondary-text mt-0.5">Latest transfers and updates</p>
              </div>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => navigate('/transfers')}
              className="text-xs font-semibold text-ios-accent hover:text-ios-accent/80 hover:bg-transparent px-3 py-1 uppercase tracking-wider font-mono transition-all duration-300 hover:scale-105 active:scale-95"
            >
              See All
              <ArrowRight className="h-3 w-3 ml-1" />
            </Button>
          </div>
          <CleanCard className="p-0 bg-gradient-to-br from-white to-ios-secondary-background/50 shadow-lg hover:shadow-xl transition-all duration-300 overflow-hidden">
            <RecentActivity activities={[]} />
          </CleanCard>
        </div>
        
        {/* Property Status Section */}
        <div className="space-y-6">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-orange-500/10 rounded-lg">
              <BarChart3 className="h-5 w-5 text-orange-500" />
            </div>
            <div>
              <h2 className="text-sm font-black text-ios-primary-text uppercase tracking-widest font-mono">
                PROPERTY STATUS
              </h2>
              <p className="text-xs font-medium text-ios-secondary-text mt-0.5">Equipment operational readiness</p>
            </div>
          </div>
          
          <CleanCard className="p-6 bg-gradient-to-br from-white to-ios-secondary-background/50 shadow-lg hover:shadow-xl transition-all duration-300">
            <div className="space-y-6">
              <div className="flex items-center justify-between group p-3 rounded-lg hover:bg-ios-tertiary-background/50 transition-all duration-300 -mx-3">
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
                  <span className="text-sm font-bold text-ios-primary-text font-mono">
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
              
              <div className="flex items-center justify-between group p-3 rounded-lg hover:bg-ios-tertiary-background/50 transition-all duration-300 -mx-3">
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
                  <span className="text-sm font-bold text-ios-primary-text font-mono">
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
              
              <div className="flex items-center justify-between group p-3 rounded-lg hover:bg-ios-tertiary-background/50 transition-all duration-300 -mx-3">
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
                  <span className="text-sm font-bold text-ios-primary-text font-mono">
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