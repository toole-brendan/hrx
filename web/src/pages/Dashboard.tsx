import React, { useState, useEffect, useMemo } from 'react';
import { useLocation } from 'wouter';
import { useAuth } from '@/contexts/AuthContext';
import { 
  Calendar,
  Clock,
  AlertTriangle,
  Shield,
  RefreshCw,
  ChevronRight,
  ArrowRight,
  ArrowRightLeft,
  BarChart3,
  Users,
  CheckCircle,
  Clock8,
  Database,
  Send,
  Fingerprint,
  Search,
  Filter,
  Plus,
  Activity as ActivityIcon,
  Package,
  FileText,
  ScanLine,
  User
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { useQuery } from '@tanstack/react-query';
import { getConnections } from '@/services/connectionService';

// iOS Components
import { CleanCard, ElegantSectionHeader, StatusBadge } from '@/components/ios';

// Dashboard components
import MyProperties from '@/components/dashboard/MyProperties';
import PendingTransfers from '@/components/dashboard/PendingTransfers';
import QuickActions from '@/components/dashboard/QuickActions';
import RecentActivity from '@/components/dashboard/RecentActivity';
import { StatCard } from '@/components/dashboard/StatCard';
import { TransferItem } from '@/components/dashboard/TransferItem';
import { ActivityLogItem } from '@/components/dashboard/ActivityLogItem';

// Mock data imports
import { sensitiveItems, sensitiveItemsStats } from '@/lib/sensitiveItemsData';
import { activities, notifications, transfers, inventory } from '@/lib/mockData';
import { maintenanceStats, maintenanceItems } from '@/lib/maintenanceData';
import { useNotifications } from "@/contexts/NotificationContext";
import { parseISO, isBefore, isAfter, addDays, startOfDay } from 'date-fns';
import { 
  Property as PropertyType, 
  Transfer, 
  Activity, 
  Notification 
} from "@/types"; // Import Property from @/types

export default function Dashboard() {
  const { user } = useAuth();
  const [, navigate] = useLocation();

  const { addNotification } = useNotifications();
  const [maintenanceCheckDone, setMaintenanceCheckDone] = useState(false);

  // Fetch connections data
  const { data: connections = [] } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
  });

  // Alert counts
  const pendingTransfersCount = transfers.filter(t => t.status === 'pending').length;
  const pendingMaintenanceCount = maintenanceStats.scheduled;
  const sensitiveItemVerifications = sensitiveItemsStats.pendingVerification;
  
  // Calculate verification percentage - Check if totalItems > 0
  const verificationPercentage = sensitiveItemsStats.totalItems > 0 
    ? Math.round((sensitiveItemsStats.verifiedToday / sensitiveItemsStats.totalItems) * 100)
    : 0;

  // Calculate network stats
  const connectedUsersCount = connections.filter(c => c.connectionStatus === 'accepted').length;
  const pendingConnectionsCount = connections.filter(c => c.connectionStatus === 'pending').length;

  // Calculate dynamic readiness stats from inventory
  const readinessStats = useMemo(() => {
    const total = inventory.length;
    if (total === 0) {
      return {
        operational: { count: 0, percentage: 0 },
        maintenance: { count: 0, percentage: 0 },
        nonOperational: { count: 0, percentage: 0 },
        other: { count: 0, percentage: 0 },
      };
    }

    let operationalCount = 0;
    let maintenanceCount = 0;
    let nonOperationalCount = 0;
    let otherCount = 0;

    inventory.forEach((item: PropertyType) => {
      // Match the actual Property status type definition
      switch (item.status) { 
        case 'Operational':
          operationalCount++;
          break;
        case 'Deadline - Maintenance':
        case 'In Repair':
          maintenanceCount++;
          break;
        case 'Non-Operational':
        case 'Damaged':
          nonOperationalCount++;
          break;
        case 'Deadline - Supply':
        case 'Lost':
        default:
          otherCount++; 
          break;
      }
    });

    // Calculate percentages
    const operationalPercentage = Math.round((operationalCount / total) * 100);
    const maintenancePercentage = Math.round((maintenanceCount / total) * 100);
    const nonOperationalPercentage = Math.round((nonOperationalCount / total) * 100);
    const otherPercentage = 100 - operationalPercentage - maintenancePercentage - nonOperationalPercentage;

    return {
      operational: { count: operationalCount, percentage: operationalPercentage },
      maintenance: { count: maintenanceCount, percentage: maintenancePercentage },
      nonOperational: { count: nonOperationalCount, percentage: nonOperationalPercentage },
      other: { count: otherCount, percentage: otherPercentage >= 0 ? otherPercentage : 0 },
    };
  }, [inventory]);

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

  // Effect to check for upcoming maintenance and trigger notifications
  useEffect(() => {
    if (!maintenanceCheckDone) {
      const today = startOfDay(new Date());
      const sevenDaysFromNow = addDays(today, 7);
      let notificationsAdded = 0;

      maintenanceItems.forEach(item => {
        if (item.scheduledDate && (item.status === 'scheduled' || item.status === 'in-progress')) {
          try {
            const scheduled = startOfDay(parseISO(item.scheduledDate));
            
            // Check if scheduled date is after or equal to today AND before 7 days from now
            if (isAfter(scheduled, addDays(today, -1)) && isBefore(scheduled, sevenDaysFromNow)) {
              addNotification({
                type: 'warning',
                title: `Upcoming Maintenance Due: ${item.itemName}`,
                message: `Maintenance scheduled for ${item.scheduledDate}. Serial: ${item.serialNumber}`,
                relatedEntityType: 'MaintenanceItem',
                relatedEntityId: item.id,
                action: {
                  label: 'View Maintenance',
                  path: `/maintenance/${item.id}`
                }
              });
              notificationsAdded++;
            }
          } catch (error) {
            console.error(`Error parsing scheduledDate '${item.scheduledDate}' for item ${item.id}:`, error);
          }
        }
      });
      
      if (notificationsAdded > 0) {
         console.log(`Added ${notificationsAdded} upcoming maintenance notifications.`);
      }

      setMaintenanceCheckDone(true);
    }
  }, [addNotification, maintenanceCheckDone]);

  return (
    <div className="min-h-screen" style={{ backgroundColor: '#FAFAFA' }}>
      <div className="max-w-4xl mx-auto px-6 py-8">
        {/* Header section with iOS styling */}
        <div className="mb-10">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-6">
            <h1 className="text-base text-secondary-text" style={{ fontFamily: '"SF Mono", Monaco, monospace' }}>
              HandReceipt
            </h1>
            
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
                <User className="h-6 w-6 text-primary-text" />
              </Button>
            </div>
          </div>
          
          {/* Divider */}
          <div className="border-b border-ios-divider mb-6" />
          
          {/* Welcome message */}
          <div className="mb-8">
            <h1 className="text-4xl font-light text-primary-text leading-tight" style={{ fontFamily: 'Georgia, serif' }}>
              {getWelcomeMessage()}
            </h1>
          </div>
        </div>
        
        {/* Overview Section - iOS style */}
        <div className="mb-10">
          <ElegantSectionHeader 
            title="Overview"
            className="mb-6"
            size="lg"
          />
          
          <div className="space-y-4">
            {/* First row: Total Properties and Import DA-2062 */}
            <div className="grid grid-cols-2 gap-4">
              <Button
                variant="ghost"
                onClick={() => navigate('/property')}
                className="h-20 p-0 hover:bg-transparent hover:opacity-90 active:opacity-70"
              >
                <CleanCard className="w-full h-full hover:shadow-md transition-shadow">
                  <div className="flex flex-col items-center justify-center h-full space-y-3">
                    <div className="text-2xl font-mono font-light text-primary-text">
                      {String(inventory.length).padStart(4, '0')}
                    </div>
                    <div className="text-xs uppercase tracking-wide text-secondary-text text-center">
                      Total Properties
                    </div>
                  </div>
                </CleanCard>
              </Button>

              <Button
                variant="ghost"
                onClick={() => navigate('/da2062')}
                className="h-20 p-0 hover:bg-transparent hover:opacity-90 active:opacity-70"
              >
                <CleanCard className="w-full h-full hover:shadow-md transition-shadow">
                  <div className="flex flex-col items-center justify-center h-full space-y-3">
                    <ScanLine className="h-6 w-6 text-primary-text" />
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
                    <FileText className="h-6 w-6 text-primary-text" />
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
          <ElegantSectionHeader 
            title="Network"
            subtitle="Connected users"
            className="mb-6"
            size="lg"
          />
          
          <div className="grid grid-cols-2 gap-4">
            <Button
              variant="ghost"
              onClick={() => navigate('/connections')}
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
              onClick={() => navigate('/connections')}
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
          <ElegantSectionHeader 
            title="Recent Activity"
            className="mb-6"
            size="lg"
          />
          
          <RecentActivity />
        </div>

        {/* Property Status Section */}
        <div className="mb-10">
          <ElegantSectionHeader 
            title="Property Status"
            subtitle="Operational readiness"
            className="mb-6"
            size="lg"
          />
          
          <CleanCard className="p-6" style={{ backgroundColor: 'white' }}>
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