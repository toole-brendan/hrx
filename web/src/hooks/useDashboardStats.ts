import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useProperties } from './useProperty';
import { useTransfers } from './useTransfers';
import { useDocuments } from './useDocuments';
import { getConnections } from '@/services/connectionService';

// Helper function to calculate time ago
function getTimeAgo(date: Date): string {
  const seconds = Math.floor((new Date().getTime() - date.getTime()) / 1000);
  
  let interval = Math.floor(seconds / 31536000);
  if (interval > 1) return `${interval} years ago`;
  if (interval === 1) return '1 year ago';
  
  interval = Math.floor(seconds / 2592000);
  if (interval > 1) return `${interval} months ago`;
  if (interval === 1) return '1 month ago';
  
  interval = Math.floor(seconds / 86400);
  if (interval > 1) return `${interval} days ago`;
  if (interval === 1) return '1 day ago';
  
  interval = Math.floor(seconds / 3600);
  if (interval > 1) return `${interval} hours ago`;
  if (interval === 1) return '1 hour ago';
  
  interval = Math.floor(seconds / 60);
  if (interval > 1) return `${interval} minutes ago`;
  if (interval === 1) return '1 minute ago';
  
  return 'Just now';
}

export interface DashboardStats {
  totalProperties: number;
  operationalCount: number;
  deadlineMaintenanceCount: number;
  deadlineSupplyCount: number;
  lostCount: number;
  nonOperationalCount: number;
  damagedCount: number;
  inRepairCount: number;
  pendingTransfers: number;
  completedTransfersToday: number;
  totalConnections: number;
  pendingConnectionRequests: number;
  unreadDocuments: number;
  totalDocuments: number;
  recentActivities: Array<{
    id: string;
    description: string;
    timeAgo: string;
    type: string;
  }>;
}

export const useDashboardStats = () => {
  // Fetch data from multiple endpoints
  const { data: propertiesData, isLoading: propertiesLoading } = useProperties();
  const properties = Array.isArray(propertiesData) ? propertiesData : [];
  
  const { data: transfers = [], isLoading: transfersLoading } = useTransfers();
  
  const { data: documentsData, isLoading: documentsLoading } = useDocuments('inbox', 'unread');
  
  const { data: connections = [], isLoading: connectionsLoading } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
  });
  
  // Calculate statistics
  const stats = useMemo<DashboardStats>(() => {
    // Property statistics
    const totalProperties = properties.length;
    const operationalCount = properties.filter(p => p.status === 'Operational').length;
    const deadlineMaintenanceCount = properties.filter(p => p.status === 'Deadline - Maintenance').length;
    const deadlineSupplyCount = properties.filter(p => p.status === 'Deadline - Supply').length;
    const lostCount = properties.filter(p => p.status === 'Lost').length;
    const nonOperationalCount = properties.filter(p => p.status === 'Non-Operational').length;
    const damagedCount = properties.filter(p => p.status === 'Damaged').length;
    const inRepairCount = properties.filter(p => p.status === 'In Repair').length;
    
    // Transfer statistics
    const pendingTransfers = transfers.filter(t => t.status === 'pending').length;
    const today = new Date().toDateString();
    const completedTransfersToday = transfers.filter(t => 
      t.status === 'approved' && 
      t.approvedDate && 
      new Date(t.approvedDate).toDateString() === today
    ).length;
    
    // Connection statistics
    const totalConnections = connections.filter(c => c.connectionStatus === 'accepted').length;
    const pendingConnectionRequests = connections.filter(c => c.connectionStatus === 'pending').length;
    
    // Document statistics
    const unreadDocuments = documentsData?.unread_count || 0;
    const totalDocuments = documentsData?.documents?.length || 0;
    
    // Recent activities from transfers
    const recentActivities = transfers
      .slice(0, 10) // Get most recent 10
      .map(transfer => {
        const timeAgo = getTimeAgo(new Date(transfer.date));
        let description = '';
        let type = '';
        
        if (transfer.status === 'pending') {
          description = `Transfer request: ${transfer.name} from ${transfer.from} to ${transfer.to}`;
          type = 'transfer-pending';
        } else if (transfer.status === 'approved') {
          description = `Transfer approved: ${transfer.name} to ${transfer.to}`;
          type = 'transfer-approved';
        } else if (transfer.status === 'rejected') {
          description = `Transfer rejected: ${transfer.name}`;
          type = 'transfer-rejected';
        }
        
        return {
          id: transfer.id,
          description,
          timeAgo,
          type
        };
      })
      .filter(activity => activity.description); // Filter out any empty activities
    
    return {
      totalProperties,
      operationalCount,
      deadlineMaintenanceCount,
      deadlineSupplyCount,
      lostCount,
      nonOperationalCount,
      damagedCount,
      inRepairCount,
      pendingTransfers,
      completedTransfersToday,
      totalConnections,
      pendingConnectionRequests,
      unreadDocuments,
      totalDocuments,
      recentActivities,
    };
  }, [properties, transfers, documentsData, connections]);
  
  // Overall loading state
  const isLoading = propertiesLoading || transfersLoading || documentsLoading || connectionsLoading;
  
  return {
    data: stats,
    isLoading,
  };
};

// Hook for readiness percentage calculation
export const useReadinessPercentage = (stats: DashboardStats) => {
  return useMemo(() => {
    if (stats.totalProperties === 0) return 100;
    
    const operationalAndInRepair = stats.operationalCount + stats.inRepairCount;
    const percentage = Math.round((operationalAndInRepair / stats.totalProperties) * 100);
    
    return percentage;
  }, [stats]);
};