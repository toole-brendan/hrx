import React from 'react';
import { Badge } from "@/components/ui/badge";

// Status badge component
interface MaintenanceStatusBadgeProps {
  status: string;
  size?: 'default' | 'sm' | 'lg';
}

export const MaintenanceStatusBadge: React.FC<MaintenanceStatusBadgeProps> = ({ status, size = 'default' }) => {
  let badgeClass = "";
  let statusLabel = "";

  switch (status) {
    case 'scheduled':
      badgeClass = "uppercase bg-amber-100/70 dark:bg-transparent text-amber-700 dark:text-amber-400 border border-amber-600 dark:border-amber-500 text-[10px] tracking-wider px-2 rounded-none";
      statusLabel = "SCHEDULED";
      break;
    case 'in-progress':
      badgeClass = "uppercase bg-blue-100/70 dark:bg-transparent text-blue-700 dark:text-blue-400 border border-blue-600 dark:border-blue-500 text-[10px] tracking-wider px-2 rounded-none";
      statusLabel = "IN PROGRESS";
      break;
    case 'completed':
      badgeClass = "uppercase bg-green-100/70 dark:bg-transparent text-green-700 dark:text-green-400 border border-green-600 dark:border-green-500 text-[10px] tracking-wider px-2 rounded-none";
      statusLabel = "COMPLETED";
      break;
    case 'cancelled':
      badgeClass = "uppercase bg-gray-100/70 dark:bg-transparent text-gray-700 dark:text-gray-400 border border-gray-600 dark:border-gray-500 text-[10px] tracking-wider px-2 rounded-none";
      statusLabel = "CANCELLED";
      break;
    default:
      badgeClass = "uppercase bg-gray-100/70 dark:bg-transparent text-gray-700 dark:text-gray-400 border border-gray-600 dark:border-gray-500 text-[10px] tracking-wider px-2 rounded-none";
      statusLabel = status.toUpperCase();
  }

  // Add size-specific classes
  if (size === 'lg') {
    badgeClass = badgeClass.replace("text-[10px]", "text-xs");
  } else if (size === 'sm') {
    // Keep existing size
  }

  return <Badge className={badgeClass}>{statusLabel}</Badge>;
};

// Priority badge component
interface MaintenancePriorityBadgeProps {
  priority: string;
  size?: 'default' | 'sm' | 'lg';
}

export const MaintenancePriorityBadge: React.FC<MaintenancePriorityBadgeProps> = ({ priority, size = 'default' }) => {
  let badgeClass = "";
  let priorityLabel = "";

  switch (priority) {
    case 'low':
      badgeClass = "uppercase bg-gray-100/70 dark:bg-transparent text-gray-700 dark:text-gray-400 border border-gray-600 dark:border-gray-500 text-[10px] tracking-wider px-2 rounded-none";
      priorityLabel = "LOW";
      break;
    case 'medium':
      badgeClass = "uppercase bg-blue-100/70 dark:bg-transparent text-blue-700 dark:text-blue-400 border border-blue-600 dark:border-blue-500 text-[10px] tracking-wider px-2 rounded-none";
      priorityLabel = "MEDIUM";
      break;
    case 'high':
      badgeClass = "uppercase bg-amber-100/70 dark:bg-transparent text-amber-700 dark:text-amber-400 border border-amber-600 dark:border-amber-500 text-[10px] tracking-wider px-2 rounded-none";
      priorityLabel = "HIGH";
      break;
    case 'critical':
      badgeClass = "uppercase bg-red-100/70 dark:bg-transparent text-red-700 dark:text-red-400 border border-red-600 dark:border-red-500 text-[10px] tracking-wider px-2 rounded-none";
      priorityLabel = "CRITICAL";
      break;
    default:
      badgeClass = "uppercase bg-gray-100/70 dark:bg-transparent text-gray-700 dark:text-gray-400 border border-gray-600 dark:border-gray-500 text-[10px] tracking-wider px-2 rounded-none";
      priorityLabel = priority.toUpperCase();
  }

  // Add size-specific classes
  if (size === 'lg') {
    badgeClass = badgeClass.replace("text-[10px]", "text-xs");
    priorityLabel = priority.toUpperCase();
  } else if (size === 'sm') {
    // Keep existing size
    priorityLabel = priority.toUpperCase();
  }

  return <Badge className={badgeClass} variant="outline">{priorityLabel}</Badge>;
};
