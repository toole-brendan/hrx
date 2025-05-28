import React from 'react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { ArrowLeft, ArrowRight } from 'lucide-react';

interface TransferItemProps {
  id: string;
  name: string;
  source: string;
  destination?: string; // Optional for outbound transfers
  status: 'pending' | 'completed';
  direction: 'inbound' | 'outbound';
  onAccept?: () => void;
  onDecline?: () => void;
}

export function TransferItem({ 
  id, 
  name, 
  source, 
  destination, 
  status, 
  direction,
  onAccept,
  onDecline
}: TransferItemProps) {
  return (
    <div className="py-3 flex items-start">
      <div className="flex-1">
        <div className="flex items-center mb-1">
          {direction === 'inbound' ? (
            <ArrowRight className="h-4 w-4 text-blue-600 dark:text-blue-400 mr-2" />
          ) : (
            <ArrowLeft className="h-4 w-4 text-blue-600 dark:text-blue-400 mr-2" />
          )}
          <div className="font-medium text-sm">{name}</div>
        </div>
        <div className="text-xs text-muted-foreground ml-6">
          {direction === 'inbound' 
            ? `From: ${source}` 
            : `To: ${destination}`}
        </div>
      </div>
      
      {status === 'pending' && onAccept && onDecline ? (
        <div className="flex space-x-2">
          <Button 
            variant="outline" 
            size="sm" 
            className="h-8 bg-transparent border-blue-600 dark:border-blue-500 text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 uppercase text-xs tracking-wider rounded-none"
            onClick={onAccept}
          >
            Accept
          </Button>
          <Button 
            variant="outline" 
            size="sm" 
            className="h-8 bg-transparent border-border text-muted-foreground hover:bg-muted/50 uppercase text-xs tracking-wider rounded-none"
            onClick={onDecline}
          >
            Decline
          </Button>
        </div>
      ) : status === 'pending' ? (
        <Badge className="uppercase bg-yellow-100/70 dark:bg-transparent text-yellow-700 dark:text-yellow-400 border border-yellow-600 dark:border-yellow-500 text-[10px] tracking-wider px-2 rounded-none">
          Pending
        </Badge>
      ) : (
        <Badge className="uppercase bg-green-100/70 dark:bg-transparent text-green-700 dark:text-green-400 border border-green-600 dark:border-green-500 text-[10px] tracking-wider px-2 rounded-none">
          Completed
        </Badge>
      )}
    </div>
  );
}