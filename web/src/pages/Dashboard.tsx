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
  Package
} from 'lucide-react';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Progress } from '@/components/ui/progress';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';

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

  // Alert counts
  const pendingTransfersCount = transfers.filter(t => t.status === 'pending').length;
  const pendingMaintenanceCount = maintenanceStats.scheduled;
  const sensitiveItemVerifications = sensitiveItemsStats.pendingVerification;
  
  // Calculate verification percentage - Check if totalItems > 0
  const verificationPercentage = sensitiveItemsStats.totalItems > 0 
    ? Math.round((sensitiveItemsStats.verifiedToday / sensitiveItemsStats.totalItems) * 100)
    : 0;

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

  // Helper function to format welcome message
  const getWelcomeMessage = () => {
    if (!user) return "Welcome";
    
    const parts = ["Welcome"];
    
    // Convert common full ranks to abbreviations
    const rankAbbreviations: Record<string, string> = {
      "Captain": "CPT",
      "Lieutenant": "LT", 
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
    <div className="min-h-screen bg-app-background">
      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Header section with iOS styling */}
        <div className="mb-10">
          <ElegantSectionHeader 
            title="DASHBOARD" 
            className="mb-4"
          />
          
          <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
            <div>
              <h1 className="text-3xl font-light tracking-tight text-primary-text">
                {getWelcomeMessage()}
              </h1>
            </div>
            <Button 
              onClick={() => navigate('/transfers')}
              className="bg-primary-text hover:bg-black/90 text-white font-medium px-6 py-3 rounded-none flex items-center gap-2"
            >
              <Send className="h-4 w-4" />
              New Transfer
            </Button>
          </div>
        </div>
        
        {/* Summary Stats - iOS style cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <CleanCard className="text-center p-6">
            <div className="flex items-center justify-center mb-3">
              <Package className="h-6 w-6 text-ios-accent" />
            </div>
            <div className="text-2xl font-light text-primary-text mb-1">
              {inventory.length}
            </div>
            <div className="text-xs uppercase tracking-wide text-tertiary-text">
              TOTAL INVENTORY
            </div>
          </CleanCard>

          <CleanCard className="text-center p-6">
            <div className="flex items-center justify-center mb-3">
              <ArrowRightLeft className="h-6 w-6 text-ios-accent" />
            </div>
            <div className="text-2xl font-light text-primary-text mb-1">
              {pendingTransfersCount}
            </div>
            <div className="text-xs uppercase tracking-wide text-tertiary-text">
              PENDING TRANSFERS
            </div>
          </CleanCard>

          <CleanCard className="text-center p-6">
            <div className="flex items-center justify-center mb-3">
              <Shield className="h-6 w-6 text-ios-success" />
            </div>
            <div className="text-2xl font-light text-primary-text mb-1">
              {sensitiveItemsStats.verifiedToday}/{sensitiveItemsStats.totalItems}
            </div>
            <div className="text-xs uppercase tracking-wide text-tertiary-text">
              SENSITIVE ITEMS VERIFIED
            </div>
          </CleanCard>

          <CleanCard className="text-center p-6">
            <div className="flex items-center justify-center mb-3">
              <AlertTriangle className="h-6 w-6 text-ios-warning" />
            </div>
            <div className="text-2xl font-light text-primary-text mb-1">
              {maintenanceStats.scheduled + maintenanceStats.inProgress}
            </div>
            <div className="text-xs uppercase tracking-wide text-tertiary-text">
              ITEMS NEEDING MAINTENANCE
            </div>
          </CleanCard>
        </div>

        {/* Quick Actions */}
        <div className="mb-8">
          <ElegantSectionHeader 
            title="QUICK ACTIONS" 
            className="mb-4"
          />
          <QuickActions />
        </div>

        {/* Main Content Grid */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-6">
            {/* Pending Transfers */}
            <PendingTransfers />
            
            {/* Inventory Items */}
            <MyProperties />
            
            {/* Equipment Status Tabs */}
            <CleanCard padding="none">
              <div className="p-6 border-b border-ios-border">
                <ElegantSectionHeader 
                  title="EQUIPMENT STATUS"
                  subtitle="Readiness and verification overview"
                />
              </div>
              
              <div className="p-6">
                <Tabs defaultValue="overview" className="w-full">
                  <TabsList className="grid grid-cols-3 w-full mb-6 bg-gray-50">
                    <TabsTrigger 
                      value="overview" 
                      className="text-xs uppercase tracking-wide font-medium data-[state=active]:bg-white data-[state=active]:text-primary-text"
                    >
                      OVERVIEW
                    </TabsTrigger>
                    <TabsTrigger 
                      value="readiness" 
                      className="text-xs uppercase tracking-wide font-medium data-[state=active]:bg-white data-[state=active]:text-primary-text"
                    >
                      READINESS
                    </TabsTrigger>
                    <TabsTrigger 
                      value="verification" 
                      className="text-xs uppercase tracking-wide font-medium data-[state=active]:bg-white data-[state=active]:text-primary-text"
                    >
                      VERIFICATION
                    </TabsTrigger>
                  </TabsList>
                  
                  <TabsContent value="overview" className="mt-0">
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                      <CleanCard padding="md" className="text-center">
                        <div className="text-xs uppercase tracking-wide text-tertiary-text mb-2">
                          PENDING ACTIONS
                        </div>
                        <div className="text-2xl font-light text-primary-text">
                          {pendingTransfersCount + (maintenanceStats.scheduled + maintenanceStats.inProgress) + sensitiveItemsStats.pendingVerification}
                        </div>
                        <div className="text-xs text-secondary-text mt-1">
                          Across all categories
                        </div>
                      </CleanCard>
                      
                      <CleanCard padding="md" className="text-center">
                        <div className="text-xs uppercase tracking-wide text-tertiary-text mb-2">
                          TRANSFER RATE
                        </div>
                        <div className="text-2xl font-light text-primary-text">
                          8.5/day
                        </div>
                        <div className="text-xs text-secondary-text mt-1">
                          Last 7 days average
                        </div>
                      </CleanCard>
                      
                      <CleanCard padding="md" className="text-center">
                        <div className="text-xs uppercase tracking-wide text-tertiary-text mb-2">
                          MAINTENANCE
                        </div>
                        <div className="text-2xl font-light text-primary-text">
                          {maintenanceStats.scheduled + maintenanceStats.inProgress}
                        </div>
                        <div className="text-xs text-secondary-text mt-1">
                          Items requiring attention
                        </div>
                      </CleanCard>
                    </div>
                  </TabsContent>
                  
                  <TabsContent value="readiness" className="mt-0">
                    <div className="space-y-6">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <div className="w-8 h-8 bg-green-50 flex items-center justify-center">
                            <CheckCircle className="h-4 w-4 text-ios-success" />
                          </div>
                          <span className="text-sm text-primary-text">Operational / Ready</span>
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
                          <div className="w-8 h-8 bg-amber-50 flex items-center justify-center">
                            <Clock8 className="h-4 w-4 text-ios-warning" />
                          </div>
                          <span className="text-sm text-primary-text">In Maintenance / Reset</span>
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
                          <div className="w-8 h-8 bg-red-50 flex items-center justify-center">
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
                  </TabsContent>
                  
                  <TabsContent value="verification" className="mt-0">
                    <div className="space-y-4">
                      <CleanCard padding="md">
                        <div className="flex justify-between items-center">
                          <div className="flex items-center">
                            <div className="w-8 h-8 bg-gray-50 flex items-center justify-center mr-3">
                              <Calendar className="h-4 w-4 text-ios-accent" />
                            </div>
                            <div>
                              <span className="text-sm font-medium text-primary-text block">Today - Morning Check</span>
                              <span className="text-xs text-secondary-text">Daily accountability check</span>
                            </div>
                          </div>
                          <div className="flex items-center space-x-4">
                            <div className="flex items-center">
                              <Clock className="h-4 w-4 mr-2 text-secondary-text" />
                              <span className="font-medium text-sm text-primary-text">0600</span>
                            </div>
                            <StatusBadge status="operational" size="sm" />
                          </div>
                        </div>
                      </CleanCard>
                      
                      <CleanCard padding="md">
                        <div className="flex justify-between items-center">
                          <div className="flex items-center">
                            <div className="w-8 h-8 bg-gray-50 flex items-center justify-center mr-3">
                              <Calendar className="h-4 w-4 text-ios-accent" />
                            </div>
                            <div>
                              <span className="text-sm font-medium text-primary-text block">Today - Evening Check</span>
                              <span className="text-xs text-secondary-text">Daily accountability check</span>
                            </div>
                          </div>
                          <div className="flex items-center space-x-4">
                            <div className="flex items-center">
                              <Clock className="h-4 w-4 mr-2 text-secondary-text" />
                              <span className="font-medium text-sm text-primary-text">1800</span>
                            </div>
                            <StatusBadge status="pending" size="sm" />
                          </div>
                        </div>
                      </CleanCard>
                    </div>
                  </TabsContent>
                </Tabs>
              </div>
            </CleanCard>
          </div>
          
          {/* Right Column - Recent Activity */}
          <div className="space-y-6">
            <RecentActivity />
            
            {/* Equipment Status Summary */}
            <CleanCard padding="none">
              <div className="p-6 border-b border-ios-border">
                <div className="flex justify-between items-center">
                  <ElegantSectionHeader 
                    title="EQUIPMENT STATUS"
                    subtitle="Current overview"
                  />
                  <Button 
                    variant="ghost" 
                    className="text-xs uppercase tracking-wide text-ios-accent hover:text-accent-hover hover:bg-transparent"
                    onClick={() => navigate('/property-book')}
                  >
                    VIEW ALL
                  </Button>
                </div>
              </div>
              
              <div className="p-6">
                <div className="space-y-4">
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-secondary-text">Total Items</span>
                    <span className="font-medium text-primary-text">{inventory.length}</span>
                  </div>
                  <div className="h-px bg-ios-divider" />
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-secondary-text">Operational</span>
                    <StatusBadge status="operational" size="sm" />
                  </div>
                  <div className="h-px bg-ios-divider" />
                  <div className="flex justify-between items-center text-sm">
                    <span className="text-secondary-text">Need Maintenance</span>
                    <StatusBadge status="maintenance" size="sm" />
                  </div>
                </div>
              </div>
            </CleanCard>
          </div>
        </div>
      </div>
    </div>
  );
}