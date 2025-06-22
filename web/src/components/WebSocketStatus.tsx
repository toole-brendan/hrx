import React from 'react';
import { useWebSocketContext } from '@/contexts/WebSocketContext';
import { Wifi, WifiOff } from 'lucide-react';
import { cn } from '@/lib/utils';

export function WebSocketStatus() {
  const { isConnected } = useWebSocketContext();

  return (
    <div className="flex items-center gap-2">
      <div className={cn(
        "flex items-center gap-1.5 px-2 py-1 rounded-md text-xs font-medium",
        isConnected 
          ? "bg-green-100 text-green-700 dark:bg-green-900/20 dark:text-green-400"
          : "bg-red-100 text-red-700 dark:bg-red-900/20 dark:text-red-400"
      )}>
        {isConnected ? (
          <>
            <Wifi className="h-3 w-3" />
            <span>Connected</span>
          </>
        ) : (
          <>
            <WifiOff className="h-3 w-3" />
            <span>Disconnected</span>
          </>
        )}
      </div>
    </div>
  );
}