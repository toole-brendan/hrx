import React from 'react';
import { cn } from '@/lib/utils';

interface StatusBadgeProps {
  status: 'operational' | 'maintenance' | 'non-operational' | 'pending' | 'approved' | 'rejected' | 'in-transit' | 'delivered' | 'completed' | 'cancelled';
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  children?: React.ReactNode;
}

export const StatusBadge: React.FC<StatusBadgeProps> = ({
  status,
  className,
  size = 'md',
  children
}) => {
  const getStatusStyles = () => {
    switch (status) {
      case 'operational':
      case 'approved':
      case 'delivered':
      case 'completed':
        return 'bg-green-50 text-ios-success border border-green-200';
      case 'maintenance':
      case 'in-transit':
        return 'bg-amber-50 text-ios-warning border border-amber-200';
      case 'non-operational':
      case 'rejected':
      case 'cancelled':
        return 'bg-red-50 text-ios-destructive border border-red-200';
      case 'pending':
        return 'bg-blue-50 text-ios-accent border border-blue-200';
      default:
        return 'bg-gray-50 text-tertiary-text border border-gray-200';
    }
  };
  
  const getSizeStyles = () => {
    switch (size) {
      case 'sm':
        return 'px-2 py-1 text-xs';
      case 'lg':
        return 'px-4 py-2 text-sm';
      default:
        return 'px-3 py-1.5 text-xs';
    }
  };
  
  const getStatusText = () => {
    switch (status) {
      case 'operational':
        return 'OPERATIONAL';
      case 'maintenance':
        return 'MAINTENANCE';
      case 'non-operational':
        return 'NON-OPERATIONAL';
      case 'approved':
        return 'APPROVED';
      case 'pending':
        return 'PENDING';
      case 'rejected':
        return 'REJECTED';
      case 'in-transit':
        return 'IN TRANSIT';
      case 'delivered':
        return 'DELIVERED';
      case 'completed':
        return 'COMPLETED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return String(status).toUpperCase();
    }
  };
  
  return (
    <span
      className={cn(
        'inline-flex items-center rounded font-bold uppercase tracking-wider',
        getStatusStyles(),
        getSizeStyles(),
        className
      )}
    >
      {children || getStatusText()}
    </span>
  );
};