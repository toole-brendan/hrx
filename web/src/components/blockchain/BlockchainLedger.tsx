import React, { useEffect, useState } from 'react';
import { format } from 'date-fns';
import { 
  Lock, 
  ShieldCheck, 
  ArrowRightLeft, 
  AlertTriangle, 
  RefreshCw,
  Link as ChainLink,
  CheckCircle
} from 'lucide-react';
import { 
  getBlockchainRecords, 
  BlockchainRecord, 
  isBlockchainEnabled 
} from '@/lib/blockchain';
import { SensitiveItem } from '@/lib/sensitiveItemsData';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip';
import { cn } from '@/lib/utils';

interface BlockchainLedgerProps {
  item: SensitiveItem;
  className?: string;
}

const BlockchainLedger: React.FC<BlockchainLedgerProps> = ({ item, className }) => {
  const [records, setRecords] = useState<BlockchainRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Generate initial mock records if none exist
  useEffect(() => {
    try {
      setLoading(true);
      const blockchainRecords = getBlockchainRecords(item.serialNumber);
      setRecords(blockchainRecords);
      setLoading(false);
    } catch (err) {
      console.error('Error fetching blockchain records:', err);
      setError('Failed to fetch blockchain records');
      setLoading(false);
    }
  }, [item.serialNumber]);

  // Check if this item is blockchain-enabled
  const isBcEnabled = isBlockchainEnabled(item);
  
  if (!isBcEnabled) {
    return null;
  }

  // Refresh blockchain records
  const handleRefresh = () => {
    setLoading(true);
    try {
      const blockchainRecords = getBlockchainRecords(item.serialNumber);
      setRecords(blockchainRecords);
      setError(null);
    } catch (err) {
      setError('Failed to refresh blockchain records');
    }
    setLoading(false);
  };

  // Get icon for event type
  const getEventIcon = (eventType: BlockchainRecord['eventType']) => {
    switch (eventType) {
      case 'transfer':
        return <ArrowRightLeft className="w-4 h-4 text-blue-500" />;
      case 'verification':
        return <ShieldCheck className="w-4 h-4 text-green-600" />;
      case 'status_change':
        return <RefreshCw className="w-4 h-4 text-yellow-500" />;
      case 'check_in':
        return <CheckCircle className="w-4 h-4 text-green-500" />;
      case 'check_out':
        return <ArrowRightLeft className="w-4 h-4 text-orange-500" />;
      default:
        return <ChainLink className="w-4 h-4 text-gray-500" />;
    }
  };

  // Format the event description based on type
  const getEventDescription = (record: BlockchainRecord) => {
    const { eventType, eventData } = record;
    
    switch (eventType) {
      case 'transfer':
        return `Transferred from ${eventData.from} to ${eventData.to}`;
      case 'verification':
        return `Verified by ${record.verifiedBy || 'System'}`;
      case 'status_change':
        return `Status changed from ${eventData.previousStatus} to ${eventData.newStatus}`;
      case 'check_in':
        return `Checked in by ${record.verifiedBy || 'System'}`;
      case 'check_out':
        return `Checked out to ${eventData.assignedTo}`;
      default:
        // In TypeScript, this shouldn't be a 'never' type because we have a default case
        // But let's handle it explicitly to avoid errors
        const eventTypeString = String(eventType).replace(/_/g, ' ');
        return `${eventTypeString} event recorded`;
    }
  };

  return (
    <div className={cn("mt-6 pt-4 border-t border-dashed", className)}>
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center">
          <Lock className="w-4 h-4 mr-2 text-blue-600" />
          <h4 className="font-semibold text-base">Immutable Ledger (Hyperledger Fabric)</h4>
        </div>
        
        <Tooltip>
          <TooltipTrigger asChild>
            <Button variant="ghost" size="icon" onClick={handleRefresh} className="h-8 w-8">
              <RefreshCw className="h-4 w-4" />
            </Button>
          </TooltipTrigger>
          <TooltipContent>Refresh blockchain records</TooltipContent>
        </Tooltip>
      </div>
      
      <p className="text-xs text-muted-foreground mb-4">
        This item is tracked on DoD GovCloud using Hyperledger Fabric for enhanced auditability and chain of custody.
      </p>
      
      {loading ? (
        <div className="space-y-2">
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-12 w-full" />
          <Skeleton className="h-12 w-full" />
        </div>
      ) : error ? (
        <div className="flex items-center p-4 bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-300 rounded-md">
          <AlertTriangle className="w-4 h-4 mr-2" />
          <p className="text-sm">{error}</p>
        </div>
      ) : records.length > 0 ? (
        <ul className="space-y-3 text-sm">
          {records.map((record, index) => (
            <li key={index} className="flex items-start space-x-3 border-b border-gray-100 dark:border-gray-800 pb-3 last:border-0">
              <div className="flex-shrink-0 mt-0.5">
                {getEventIcon(record.eventType)}
              </div>
              <div className="flex-grow">
                <p className="font-medium">{getEventDescription(record)}</p>
                <p className="text-xs text-muted-foreground">
                  {format(new Date(record.timestamp), 'PPp')}
                </p>
                <div className="flex items-center mt-1">
                  <ChainLink className="w-3 h-3 text-blue-600 mr-1" />
                  <p className="text-xs text-blue-700 font-mono" title="Blockchain Transaction ID">
                    Tx: {record.txId}
                  </p>
                </div>
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <div className="text-center py-6 border border-dashed rounded-md">
          <ChainLink className="mx-auto h-8 w-8 text-gray-400 mb-2" />
          <p className="text-sm text-muted-foreground">No blockchain records available yet.</p>
          <p className="text-xs text-muted-foreground mt-1">
            Transactions will be recorded when this item is transferred, verified, or has status changes.
          </p>
        </div>
      )}
    </div>
  );
};

export default BlockchainLedger; 