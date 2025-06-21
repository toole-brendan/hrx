import React, { useMemo } from 'react';
import { useLocation } from 'wouter';
import { useAuth } from '@/contexts/AuthContext';
import { 
  AlertTriangle, CheckCircle, Clock8, Search, UserCircle, Inbox, FileScan
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { useQuery } from '@tanstack/react-query';
import { getConnections } from '@/services/connectionService';

// iOS Components
import { CleanCard, ElegantSectionHeader, StatusBadge } from '@/components/ios';

// Dashboard components
import RecentActivity from '@/components/dashboard/RecentActivity';

export default function Dashboard() {
  const { user } = useAuth();
  const [, navigate] = useLocation();
  
  // Fetch connections data
  const { data: connections = [] } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
  });
  
  // Alert counts - Using real data from API or default values
  const pendingTransfersCount = 0; // TODO: Fetch from API
  const pendingMaintenanceCount = 0; // TODO: Fetch from API
  const sensitiveItemVerifications = 0; // TODO: Fetch from API
  
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
    
    const parts = ["Welcome,"];
    
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
    <div className="min-h-screen" style={{ backgroundColor: '#FAFAFA' }}>
      <div className="max-w-4xl mx-auto px-6 py-8">
        {/* Header section with iOS styling */}
        <div className="mb-10">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-6">
            <div></div>
            <div className="flex items-center space-x-5">
              <Button
                variant="ghost"
                size="sm"
                onClick={() => navigate('/search')}
                className="p-2 hover:bg-transparent"
              >
                <Search className="h-5 w-5 text-primary-text" />
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => navigate('/profile')}
                className="p-2 hover:bg-transparent"
              >
                <UserCircle className="h-6 w-6 text-primary-text" />
              </Button>
            </div>
          </div>
          
          {/* Divider */}
          <div className="border-b border-ios-divider mb-6" />
          
          {/* Welcome message */}
          <div className="mb-8">
            <h1 className="text-5xl font-bold text-primary-text leading-tight" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
              {getWelcomeMessage()}
            </h1>
          </div>
        </div>
        
        {/* Overview Section - iOS style */}
        <div className="mb-10">
          <ElegantSectionHeader title="Overview" className="mb-6" size="lg" divider={true} />
          
          <div className="space-y-4">
            {/* First row: Total Properties and Import DA-2062 */}
            <div className="grid grid-cols-2 gap-4">
              <Button
                variant="ghost"
                onClick={() => navigate('/property-book')}
                className="h-20 p-0 hover:bg-transparent hover:opacity-90 active:opacity-70"
              >
                <CleanCard className="w-full h-full hover:shadow-md transition-shadow">
                  <div className="flex flex-col items-center justify-center h-full space-y-3">
                    <div className="text-2xl font-mono font-light text-primary-text">
                      {String(0).padStart(4, '0')}
                    </div>
                    <div className="text-xs uppercase tracking-wide text-secondary-text text-center">
                      Total Properties
                    </div>
                  </div>
                </CleanCard>
              </Button>
              
              <Button
                variant="ghost"
                onClick={() => navigate('/property-book?action=import-da2062')}
                className="h-20 p-0 hover:bg-transparent hover:opacity-90 active:opacity-70"
              >
                <CleanCard className="w-full h-full hover:shadow-md transition-shadow">
                  <div className="flex flex-col items-center justify-center h-full space-y-3">
                    <FileScan className="h-6 w-6 text-primary-text" />
                    <div className="text-xs uppercase tracking-wide text-secondary-text text-center">
                      Import DA-2062
                    </div>
                  </div>
                </CleanCard>
              </Button>
            </div>
            
            {/* Second row: Documents and empty space */}
            <div className="grid grid-cols-2 gap-4">
              <Button
                variant="ghost"
                onClick={() => navigate('/documents')}
                className="h-20 p-0 hover:bg-transparent hover:opacity-90 active:opacity-70"
              >
                <CleanCard className="w-full h-full hover:shadow-md transition-shadow">
                  <div className="flex flex-col items-center justify-center h-full space-y-3">
                    <Inbox className="h-6 w-6 text-primary-text" />
                    <div className="text-xs uppercase tracking-wide text-secondary-text text-center">
                      Documents
                    </div>
                  </div>
                </CleanCard>
              </Button>
              
              {/* Empty space to maintain layout */}
              <div></div>
            </div>
          </div>
        </div>
        
        {/* Network Section - iOS style */}
        <div className="mb-10">
          <div className="flex items-baseline justify-between mb-6">
            <ElegantSectionHeader 
              title="Network" 
              subtitle="Connected users" 
              className="flex-1" 
              size="lg" 
              divider={false}
            />
            <Button
              variant="ghost"
              size="sm"
              onClick={() => navigate('/network')}
              className="text-sm font-medium text-ios-accent hover:bg-transparent px-0"
            >
              View All
            </Button>
          </div>
          <div className="border-b border-ios-divider mb-6" />
          
          <div className="grid grid-cols-2 gap-4">
            <Button
              variant="ghost"
              onClick={() => navigate('/network')}
              className="h-20 p-0 hover:bg-transparent hover:opacity-90 active:opacity-70"
            >
              <CleanCard className="w-full h-full hover:shadow-md transition-shadow">
                <div className="flex flex-col items-center justify-center h-full space-y-3">
                  <div className="text-2xl font-mono font-light text-primary-text">
                    {connectedUsersCount}
                  </div>
                  <div className="text-xs uppercase tracking-wide text-secondary-text">
                    Connected
                  </div>
                </div>
              </CleanCard>
            </Button>
            
            <Button
              variant="ghost"
              onClick={() => navigate('/network')}
              className="h-20 p-0 hover:bg-transparent hover:opacity-90 active:opacity-70"
            >
              <CleanCard className="w-full h-full hover:shadow-md transition-shadow">
                <div className="flex flex-col items-center justify-center h-full space-y-3">
                  <div className="text-2xl font-mono font-light text-primary-text">
                    {pendingConnectionsCount}
                  </div>
                  <div className="text-xs uppercase tracking-wide text-secondary-text">
                    Pending
                  </div>
                </div>
              </CleanCard>
            </Button>
          </div>
        </div>
        
        {/* Recent Activity Section */}
        <div className="mb-10">
          <div className="flex items-baseline justify-between mb-6">
            <ElegantSectionHeader 
              title="Recent Activity" 
              className="flex-1" 
              size="lg" 
              divider={false} 
            />
            <Button
              variant="ghost"
              size="sm"
              onClick={() => navigate('/transfers')}
              className="text-sm font-medium text-ios-accent hover:bg-transparent px-0"
            >
              See All
            </Button>
          </div>
          <div className="border-b border-ios-divider mb-6" />
          <RecentActivity activities={[]} />
        </div>
        
        {/* Property Status Section */}
        <div className="mb-10">
          <ElegantSectionHeader 
            title="Property Status" 
            subtitle="Operational readiness" 
            className="mb-6" 
            size="lg" 
            divider={true}
          />
          
          <CleanCard className="p-6 bg-white">
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="w-8 h-8 bg-green-50 flex items-center justify-center rounded">
                    <CheckCircle className="h-4 w-4 text-ios-success" />
                  </div>
                  <span className="text-sm text-primary-text">Operational</span>
                </div>
                <div className="flex items-center">
                  <span className="text-sm font-medium mr-3 min-w-[3rem] text-right text-primary-text">
                    {readinessStats.operational.percentage}%
                  </span>
                  <Progress 
                    value={readinessStats.operational.percentage} 
                    className="w-40 h-2 bg-gray-200 [&>div]:bg-ios-success" 
                  />
                </div>
              </div>
              
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="w-8 h-8 bg-amber-50 flex items-center justify-center rounded">
                    <Clock8 className="h-4 w-4 text-ios-warning" />
                  </div>
                  <span className="text-sm text-primary-text">In Maintenance</span>
                </div>
                <div className="flex items-center">
                  <span className="text-sm font-medium mr-3 min-w-[3rem] text-right text-primary-text">
                    {readinessStats.maintenance.percentage}%
                  </span>
                  <Progress 
                    value={readinessStats.maintenance.percentage} 
                    className="w-40 h-2 bg-gray-200 [&>div]:bg-ios-warning" 
                  />
                </div>
              </div>
              
              <div className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className="w-8 h-8 bg-red-50 flex items-center justify-center rounded">
                    <AlertTriangle className="h-4 w-4 text-ios-destructive" />
                  </div>
                  <span className="text-sm text-primary-text">Non-operational</span>
                </div>
                <div className="flex items-center">
                  <span className="text-sm font-medium mr-3 min-w-[3rem] text-right text-primary-text">
                    {readinessStats.nonOperational.percentage}%
                  </span>
                  <Progress 
                    value={readinessStats.nonOperational.percentage} 
                    className="w-40 h-2 bg-gray-200 [&>div]:bg-ios-destructive" 
                  />
                </div>
              </div>
            </div>
          </CleanCard>
        </div>
        
        {/* Bottom padding for mobile navigation */}
        <div className="h-24"></div>
      </div>
    </div>
  );
}