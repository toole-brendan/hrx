import React from 'react';
import { ArrowLeftRight } from 'lucide-react';

interface ActivityLogItemProps {
  id: string;
  title: string;
  description?: string;
  timestamp: string;
  verified?: boolean;
}

export function ActivityLogItem({ 
  id, 
  title, 
  description, 
  timestamp, 
  verified = true 
}: ActivityLogItemProps) {
  return (
    <div className="p-4">
      <div className="flex items-center gap-4">
        <div className="w-10 h-10 bg-tertiary-background rounded-full flex items-center justify-center flex-shrink-0">
          <ArrowLeftRight className="h-4 w-4 text-secondary-text stroke-[1.5]" />
        </div>
        <div className="flex-1 min-w-0">
          <div className="font-medium text-primary-text text-sm">
            {title}
          </div>
          {description && (
            <div className="text-xs text-secondary-text mt-1">
              {description}
            </div>
          )}
        </div>
        <div className="text-xs text-tertiary-text whitespace-nowrap">
          {timestamp}
        </div>
      </div>
    </div>
  );
}