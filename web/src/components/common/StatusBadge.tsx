import React from 'react';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

interface StatusBadgeProps {
  status: "pending" | "approved" | "rejected" | "active" | "transferred";
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  children?: React.ReactNode; // Allow children to override default label
}

const StatusBadge: React.FC<StatusBadgeProps> = ({ status, className, size = 'md', children }) => {
  const statusConfig = {
    pending: { label: 'Pending', classes: 'bg-yellow-100 text-yellow-800' },
    approved: { label: 'Approved', classes: 'bg-green-100 text-green-800' },
    rejected: { label: 'Rejected', classes: 'bg-red-100 text-red-800' },
    active: { label: 'Active', classes: 'bg-blue-100 text-blue-800' },
    transferred: { label: 'Transferred', classes: 'bg-purple-100 text-purple-800' }
  };
  
  const config = statusConfig[status];
  
  const sizeClasses = {
    sm: 'text-xs px-2 py-0.5',
    md: 'text-sm px-2.5 py-0.5',
    lg: 'text-base px-3 py-1'
  };
  
  return (
    <Badge
      variant="outline"
      className={cn(config.classes, sizeClasses[size], className)}
    >
      {children || config.label}
    </Badge>
  );
};

export default StatusBadge;