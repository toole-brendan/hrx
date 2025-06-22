import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useProperties } from './useProperty';
import { useTransfers } from './useTransfers';
import { useDocuments } from './useDocuments';

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
}

export const useDashboardStats = () => {
  // Fetch data from multiple endpoints
  const { data: propertiesData, isLoading: propertiesLoading } = useProperties();
  const properties = Array.isArray(propertiesData) ? propertiesData : [];
  
  const { data: transfers = [], isLoading: transfersLoading } = useTransfers();
  
  const { data: documentsData, isLoading: documentsLoading } = useDocuments('inbox', 'unread');
  
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
    
    // Connection statistics - will be fetched separately in Dashboard
    const totalConnections = 0;
    const pendingConnectionRequests = 0;
    
    // Document statistics
    const unreadDocuments = documentsData?.unread_count || 0;
    const totalDocuments = documentsData?.documents?.length || 0;
    
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
    };
  }, [properties, transfers, documentsData]);
  
  // Overall loading state
  const isLoading = propertiesLoading || transfersLoading || documentsLoading;
  
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