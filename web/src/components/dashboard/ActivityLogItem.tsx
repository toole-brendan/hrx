import React from 'react';
import { Badge } from '@/components/ui/badge';

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
    <div className="py-3">
      <div className="flex items-start">
        <div className="h-3 w-3 rounded-none bg-blue-600 dark:bg-blue-500 mt-1.5 mr-3 flex-shrink-0"></div>
        <div className="flex-1">
          <div className="flex justify-between mb-1">
            <div className="font-medium text-sm">{title}</div>
            <div className="text-xs text-muted-foreground">{timestamp}</div>
          </div>
          {description && (
            <div className="text-xs text-muted-foreground mb-1">{description}</div>
          )}
          {verified && (
            <Badge className="uppercase bg-green-100/70 dark:bg-transparent text-green-700 dark:text-green-400 border border-green-600 dark:border-green-500 text-[10px] tracking-wider px-2 mt-1 rounded-none">
              Verified on blockchain
            </Badge>
          )}
        </div>
      </div>
    </div>
  );
}