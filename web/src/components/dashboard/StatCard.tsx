import React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import { ArrowUp, ArrowDown, Minus } from 'lucide-react';
import { cn } from '@/lib/utils';

interface StatCardProps {
  title: string;
  value: string | number;
  icon?: React.ReactNode;
  change?: {
    value: number;
    label: string;
    direction: 'up' | 'down' | 'neutral';
  };
  className?: string;
}

export function StatCard({ title, value, icon, change, className }: StatCardProps) {
  return (
    <div className={cn(
      "border border-border bg-card overflow-hidden",
      className
    )}>
      <div className="p-4 relative">
        {/* Category Label */}
        <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">{title}</div>
        
        {/* Main Value */}
        <div className="text-3xl font-light mb-2">{value}</div>
        
        {/* Change indicator */}
        {change && (
          <div className="flex items-center text-xs">
            <div className={cn(
              "flex items-center mr-2",
              change.direction === 'up' ? 'text-green-600 dark:text-green-400' : 
              change.direction === 'down' ? 'text-red-600 dark:text-red-400' : 
              'text-muted-foreground'
            )}>
              {change.direction === 'up' ? (
                <ArrowUp className="h-3 w-3 mr-1" />
              ) : change.direction === 'down' ? (
                <ArrowDown className="h-3 w-3 mr-1" />
              ) : (
                <Minus className="h-3 w-3 mr-1" />
              )}
              {change.value}%
            </div>
            <div className="text-muted-foreground">
              {change.label}
            </div>
          </div>
        )}
        
        {/* Icon in the right corner */}
        {icon && (
          <div className="absolute top-4 right-4 text-muted-foreground">
            {icon}
          </div>
        )}
      </div>
    </div>
  );
}