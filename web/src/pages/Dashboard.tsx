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
  QrCode,
  Send,
  FileText,
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
import { PageWrapper } from '@/components/ui/page-wrapper';
import { PageHeader } from '@/components/ui/page-header';
import { Separator } from '@/components/ui/separator';
import QRScannerModal from '@/components/shared/QRScannerModal';

// Dashboard components
import MyInventory from '@/components/dashboard/MyInventory';
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
  InventoryItem as InventoryItemType, 
  Transfer, 
  Activity, 
  Notification 
} from "@/types"; // Import InventoryItem from @/types

export default function Dashboard() {
  const { user } = useAuth();
  const [, navigate] = useLocation();
  const [showQRScannerModal, setShowQRScannerModal] = useState(false);
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

    inventory.forEach((item: InventoryItemType) => {
      // Keep case statements lowercase, assuming type definition matches mock data
      switch (item.status) { 
        case 'operational':
        case 'ntc-prepped':
          operationalCount++;
          break;
        case 'maintenance':
        case 'awaiting-parts':
        case 'bn-level-maint': 
        case 'needs-reset': 
          maintenanceCount++;
          break;
        case 'non-operational':
        case 'damaged':
        case 'deadline': // Assuming deadline means non-operational
          nonOperationalCount++;
          break;
        case 'scheduled-for-turn-in':
        case 'limited-use':
        case 'active': // Map legacy 'active' to 'other' or 'operational' if preferred
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

  // Page actions
  const actions = (
    <div className="flex items-center gap-2">
      <Button 
        size="sm" 
        variant="blue"
        onClick={() => setShowQRScannerModal(true)}
        className="h-9 px-3 flex items-center gap-1.5"
      >
        <QrCode className="h-4 w-4" />
        <span className="hidden sm:inline text-xs uppercase tracking-wider">Scan QR Code</span>
      </Button>
      
      <Button 
        size="sm" 
        variant="blue"
        onClick={() => navigate('/transfers')}
        className="h-9 px-3 flex items-center gap-1.5"
      >
        <Send className="h-4 w-4" />
        <span className="hidden sm:inline text-xs uppercase tracking-wider">New Transfer</span>
      </Button>
      
      <Button 
        size="sm" 
        variant="blue"
        onClick={() => navigate('/reports')}
        className="h-9 px-3 flex items-center gap-1.5"
      >
        <FileText className="h-4 w-4" />
        <span className="hidden sm:inline text-xs uppercase tracking-wider">Reports</span>
      </Button>
    </div>
  );

  return (
    <PageWrapper withPadding={true}>
      {/* Header section with styling formatting */}
      <div className="pt-16 pb-10">
        {/* Category label - Small all-caps category label */}
        <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
          DASHBOARD
        </div>
        
        {/* Main title - following typography */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">Welcome, CPT Rodriguez</h1>
          </div>
          {actions}
        </div>
      </div>
      
      {/* Summary Stats - Metric cards with styling */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard 
          title="Total Inventory"
          value={inventory.length}
          icon={<Package size={20} className="text-blue-600 dark:text-blue-400" />}
        />

        <StatCard 
          title="Pending Transfers"
          value={pendingTransfersCount}
          icon={<ArrowRightLeft size={20} className="text-primary" />}
        />

        <StatCard 
          title="Sensitive Items Verified"
          value={`${sensitiveItemsStats.verifiedToday}/${sensitiveItemsStats.totalItems}`}
          icon={<Shield size={20} className="text-green-600 dark:text-green-400" />}
        />

        <StatCard 
          title="Items Needing Maintenance"
          value={maintenanceStats.scheduled + maintenanceStats.inProgress}
          icon={<AlertTriangle size={20} className="text-amber-600 dark:text-amber-400" />}
        />
      </div>

      {/* Quick Actions with styled header */}
      <div className="mb-8">
        <div className="text-xs uppercase tracking-wider font-medium mb-4 text-muted-foreground">
          QUICK ACTIONS
        </div>
        <QuickActions openScanner={() => setShowQRScannerModal(true)} />
      </div>

      {/* Main Content Grid with split layout */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          {/* Pending Transfers */}
          <PendingTransfers />
          
          {/* Inventory Items */}
          <div className="mb-6">
            <MyInventory />
          </div>
          
          {/* Stats Tabs */}
          <Card className="mb-6 overflow-hidden border-border shadow-none bg-card">
            <div className="p-4 flex justify-between items-baseline border-b border-border">
              <div>
                <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                  EQUIPMENT STATUS
                </div>
                <div className="text-lg font-normal">
                  Readiness and verification
                </div>
              </div>
            </div>
            
            <CardContent className="p-0">
              <Tabs defaultValue="overview" className="w-full">
                <div className="px-4 pt-4 pb-2">
                  <TabsList className="grid grid-cols-3 w-full h-10 border rounded-none">
                    <TabsTrigger value="overview" className="text-xs uppercase tracking-wider rounded-none">OVERVIEW</TabsTrigger>
                    <TabsTrigger value="readiness" className="text-xs uppercase tracking-wider rounded-none">READINESS</TabsTrigger>
                    <TabsTrigger value="verification" className="text-xs uppercase tracking-wider rounded-none">VERIFICATION</TabsTrigger>
                  </TabsList>
                </div>
                
                <div className="p-4">
                  <TabsContent value="overview" className="m-0 mt-2">
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                      <div className="p-4 border border-border bg-muted/80 dark:bg-zinc-900 shadow-sm">
                        <h4 className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground mb-2">PENDING ACTIONS</h4>
                        <div className="text-2xl font-light tracking-tight">{pendingTransfersCount + (maintenanceStats.scheduled + maintenanceStats.inProgress) + sensitiveItemsStats.pendingVerification}</div>
                        <p className="text-xs tracking-wide text-muted-foreground mt-1">Across all categories</p>
                      </div>
                      <div className="p-4 border border-border bg-muted/80 dark:bg-zinc-900 shadow-sm">
                        <h4 className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground mb-2">TRANSFER RATE</h4>
                        <div className="text-2xl font-light tracking-tight">8.5/day</div>
                        <p className="text-xs tracking-wide text-muted-foreground mt-1">Last 7 days average</p>
                      </div>
                      <div className="p-4 border border-border bg-muted/80 dark:bg-zinc-900 shadow-sm">
                        <h4 className="text-[10px] uppercase tracking-wider font-medium text-muted-foreground mb-2">QR SCANS</h4>
                        <div className="text-2xl font-light tracking-tight">32</div>
                        <p className="text-xs tracking-wide text-muted-foreground mt-1">Last 24 hours</p>
                      </div>
                    </div>
                  </TabsContent>
                  
                  <TabsContent value="readiness" className="m-0 mt-4">
                    <div className="space-y-5">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <div className="w-8 h-8 rounded-none bg-green-100/70 dark:bg-green-900/20 flex items-center justify-center">
                            <CheckCircle className="h-4 w-4 text-green-600 dark:text-green-400" />
                          </div>
                          <span className="text-sm tracking-wide">Operational / Ready</span>
                        </div>
                        <div className="flex items-center">
                          <span className="text-sm font-medium mr-3 min-w-[3rem] text-right">{readinessStats.operational.percentage}%</span>
                          <Progress value={readinessStats.operational.percentage} className="w-40 h-2 rounded-none bg-muted/30 [&>div]:bg-green-600 dark:[&>div]:bg-green-500" />
                        </div>
                      </div>
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <div className="w-8 h-8 rounded-none bg-amber-100/70 dark:bg-amber-900/20 flex items-center justify-center">
                            <Clock8 className="h-4 w-4 text-amber-600 dark:text-amber-400" />
                          </div>
                          <span className="text-sm tracking-wide">In Maintenance / Reset</span>
                        </div>
                        <div className="flex items-center">
                          <span className="text-sm font-medium mr-3 min-w-[3rem] text-right">{readinessStats.maintenance.percentage}%</span>
                          <Progress value={readinessStats.maintenance.percentage} className="w-40 h-2 rounded-none bg-muted/30 [&>div]:bg-amber-600 dark:[&>div]:bg-amber-500" />
                        </div>
                      </div>
                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-3">
                          <div className="w-8 h-8 rounded-none bg-red-100/70 dark:bg-red-900/20 flex items-center justify-center">
                            <AlertTriangle className="h-4 w-4 text-red-600 dark:text-red-400" />
                          </div>
                          <span className="text-sm tracking-wide">Non-operational</span>
                        </div>
                        <div className="flex items-center">
                          <span className="text-sm font-medium mr-3 min-w-[3rem] text-right">{readinessStats.nonOperational.percentage}%</span>
                          <Progress value={readinessStats.nonOperational.percentage} className="w-40 h-2 rounded-none bg-muted/30 [&>div]:bg-red-600 dark:[&>div]:bg-red-500" />
                        </div>
                      </div>
                      {/* Optionally display 'Other' if needed */}
                      {readinessStats.other.count > 0 && (
                        <div className="flex items-center justify-between">
                          <div className="flex items-center space-x-3">
                            <div className="w-8 h-8 rounded-none bg-gray-100/70 dark:bg-gray-900/20 flex items-center justify-center">
                              <Package className="h-4 w-4 text-gray-600 dark:text-gray-400" /> 
                            </div>
                            <span className="text-sm tracking-wide">Other Status</span>
                          </div>
                          <div className="flex items-center">
                            <span className="text-sm font-medium mr-3 min-w-[3rem] text-right">{readinessStats.other.percentage}%</span>
                            <Progress value={readinessStats.other.percentage} className="w-40 h-2 rounded-none bg-muted/30 [&>div]:bg-gray-600 dark:[&>div]:bg-gray-500" />
                          </div>
                        </div>
                      )}
                    </div>
                  </TabsContent>
                  
                  <TabsContent value="verification" className="m-0 mt-2">
                    <div className="space-y-4">
                      <div className="flex justify-between items-center p-3 border border-border bg-muted/80 dark:bg-zinc-900 mb-2">
                        <div className="flex items-center">
                          <div className="w-8 h-8 rounded-none bg-muted/30 flex items-center justify-center mr-3">
                            <Calendar className="h-4 w-4 text-primary" />
                          </div>
                          <div>
                            <span className="tracking-wide text-sm font-medium block">Today - Morning Check</span>
                            <span className="text-xs text-muted-foreground">Daily accountability check</span>
                          </div>
                        </div>
                        <div className="flex items-center space-x-4">
                          <div className="flex items-center">
                            <Clock className="h-4 w-4 mr-2 text-amber-600 dark:text-amber-400" />
                            <span className="font-medium text-sm">0600</span>
                          </div>
                          <Badge variant="outline" className="bg-green-100/70 dark:bg-transparent text-green-700 dark:text-green-400 border border-green-600 dark:border-green-500 uppercase text-[10px] tracking-wider font-medium rounded-none">
                            Completed
                          </Badge>
                        </div>
                      </div>
                      <div className="flex justify-between items-center p-3 border border-border bg-muted/80 dark:bg-zinc-900 mb-2">
                        <div className="flex items-center">
                          <div className="w-8 h-8 rounded-none bg-muted/30 flex items-center justify-center mr-3">
                            <Calendar className="h-4 w-4 text-primary" />
                          </div>
                          <div>
                            <span className="tracking-wide text-sm font-medium block">Today - Evening Check</span>
                            <span className="text-xs text-muted-foreground">Daily accountability check</span>
                          </div>
                        </div>
                        <div className="flex items-center space-x-4">
                          <div className="flex items-center">
                            <Clock className="h-4 w-4 mr-2 text-amber-600 dark:text-amber-400" />
                            <span className="font-medium text-sm">1800</span>
                          </div>
                          <Badge variant="outline" className="bg-yellow-100/70 dark:bg-transparent text-yellow-700 dark:text-yellow-400 border border-yellow-600 dark:border-yellow-500 uppercase text-[10px] tracking-wider font-medium rounded-none">
                            Pending
                          </Badge>
                        </div>
                      </div>
                      <div className="flex justify-between items-center p-3 border border-border bg-muted/80 dark:bg-zinc-900 mb-2">
                        <div className="flex items-center">
                          <div className="w-8 h-8 rounded-none bg-muted/30 flex items-center justify-center mr-3">
                            <Calendar className="h-4 w-4 text-primary" />
                          </div>
                          <div>
                            <span className="tracking-wide text-sm font-medium block">Tomorrow - Morning Check</span>
                            <span className="text-xs text-muted-foreground">Daily accountability check</span>
                          </div>
                        </div>
                        <div className="flex items-center space-x-4">
                          <div className="flex items-center">
                            <Clock className="h-4 w-4 mr-2 text-amber-600 dark:text-amber-400" />
                            <span className="font-medium text-sm">0600</span>
                          </div>
                          <Badge variant="outline" className="bg-blue-100/70 dark:bg-transparent text-blue-700 dark:text-blue-400 border border-blue-600 dark:border-blue-500 uppercase text-[10px] tracking-wider font-medium rounded-none">
                            Scheduled
                          </Badge>
                        </div>
                      </div>
                    </div>
                  </TabsContent>
                </div>
              </Tabs>
            </CardContent>
            <div className="px-4 py-3 border-t border-border flex justify-end">
              <Button 
                variant="ghost" 
                className="text-xs uppercase tracking-wider text-blue-600 dark:text-blue-400 hover:bg-transparent hover:text-blue-800 dark:hover:text-blue-300"
                onClick={() => navigate("/reports")}
              >
                VIEW ALL REPORTS
                <ArrowRight className="h-3 w-3 ml-1" />
              </Button>
            </div>
          </Card>
        </div>
        
        {/* Right Column - Recent Activity & Notifications */}
        <div className="space-y-6">
          {/* Activity Feed */}
          <RecentActivity />
          
          {/* QR Management Summary */}
          <Card className="overflow-hidden border-border shadow-none bg-card">
            <div className="p-4 flex justify-between items-baseline">
              <div>
                <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                  QR TRACKING
                </div>
                <div className="text-lg font-normal">
                  Barcode status
                </div>
              </div>
              
              <Button 
                variant="ghost" 
                className="text-xs uppercase tracking-wider text-blue-600 dark:text-blue-400 hover:bg-transparent hover:text-blue-800 dark:hover:text-blue-300"
                onClick={() => navigate('/qr-management')}
              >
                MANAGE ALL
              </Button>
            </div>
            
            <CardContent className="px-4 pb-4">
              <div className="space-y-3">
                <div className="flex justify-between items-center text-sm">
                  <span className="tracking-wide">Total QR Codes</span>
                  <span className="font-medium">{inventory.length}</span>
                </div>
                <Separator className="bg-border" />
                <div className="flex justify-between items-center text-sm">
                  <span className="tracking-wide">Needs Reprinting</span>
                  <Badge variant="outline" className="bg-yellow-100/70 dark:bg-transparent text-yellow-700 dark:text-yellow-400 border border-yellow-600 dark:border-yellow-500 uppercase text-[10px] tracking-wider rounded-none">2</Badge>
                </div>
                <Separator className="bg-border" />
                <div className="flex justify-between items-center text-sm">
                  <span className="tracking-wide">Recently Generated</span>
                  <Badge variant="outline" className="bg-green-100/70 dark:bg-transparent text-green-700 dark:text-green-400 border border-green-600 dark:border-green-500 uppercase text-[10px] tracking-wider rounded-none">5</Badge>
                </div>
              </div>
            </CardContent>
          </Card>
          
          {/* Notifications Preview */}
          <Card className="overflow-hidden border-border shadow-none bg-card">
            <div className="p-4 flex justify-between items-baseline">
              <div>
                <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                  TEAM ACTIVITY
                </div>
                <div className="text-lg font-normal">
                  Recent notifications
                </div>
              </div>
              
              <Button 
                variant="ghost" 
                className="text-xs uppercase tracking-wider text-blue-600 dark:text-blue-400 hover:bg-transparent hover:text-blue-800 dark:hover:text-blue-300"
                onClick={() => navigate('/audit-log')}
              >
                VIEW ALL
              </Button>
            </div>
            
            <CardContent className="p-0">
              <div className="divide-y divide-border">
                {notifications.slice(0, 3).map(notification => (
                  <div key={notification.id} className="p-4 hover:bg-muted/50 transition-colors">
                    <div className="flex items-start">
                      <div className={`h-8 w-8 flex-shrink-0 rounded-none bg-muted/50 flex items-center justify-center mr-3 ${
                        notification.type === 'transfer-request' ? 'text-amber-600 dark:text-amber-400' : 
                        notification.type === 'transfer-approved' ? 'text-green-600 dark:text-green-400' : 
                        'text-blue-600 dark:text-blue-400'
                      }`}>
                        {notification.type === 'transfer-request' ? <Send className="h-4 w-4" /> :
                         notification.type === 'transfer-approved' ? <CheckCircle className="h-4 w-4" /> :
                         <AlertTriangle className="h-4 w-4" />}
                      </div>
                      <div>
                        <h4 className="font-medium text-sm">{notification.title}</h4>
                        <p className="text-xs text-muted-foreground mt-1">{notification.message}</p>
                        <p className="text-xs text-muted-foreground/70 mt-1">{notification.timeAgo}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
      
      {/* QR Scanner Modal */}
      {showQRScannerModal && (
        <QRScannerModal 
          isOpen={showQRScannerModal} 
          onClose={() => setShowQRScannerModal(false)}
          onScan={(code) => {
            console.log("QR Code scanned:", code);
            setShowQRScannerModal(false);
          }}
        />
      )}
    </PageWrapper>
  );
}