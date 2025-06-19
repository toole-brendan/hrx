import React from 'react';
import { cn } from '@/lib/utils'; interface MinimalEmptyStateProps { title: string; description?: string; icon?: React.ReactNode; action?: React.ReactNode; className?: string;
} export const MinimalEmptyState: React.FC<MinimalEmptyStateProps> = ({ title, description, icon, action, className
}) => { return ( <div className={cn('flex flex-col items-center justify-center py-12 px-6 text-center', className)}> {icon && ( <div className="mb-4 text-quaternary-text"> {icon} </div> )} <h3 className="text-lg font-medium text-primary-text mb-2"> {title} </h3> {description && ( <p className="text-secondary-text mb-6 max-w-md"> {description} </p> )} {action && ( <div> {action} </div> )} </div> );
}; 