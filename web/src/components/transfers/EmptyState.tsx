import React from 'react';
import { Button } from '@/components/ui/button';
import { History, Inbox, ExternalLink, Plus } from 'lucide-react';

interface EmptyStateProps {
  activeView: 'incoming' | 'outgoing' | 'history';
  searchTerm: string;
  filterStatus: 'all' | 'pending' | 'approved' | 'rejected';
  onInitiateTransfer: () => void;
}

const EmptyState: React.FC<EmptyStateProps> = ({
  activeView,
  searchTerm,
  filterStatus,
  onInitiateTransfer,
}) => {
  let title = '';
  let description = '';
  let icon: React.ReactNode = <History className="h-8 w-8 text-muted-foreground" />;
  let showInitiateButton = false;

  const baseDesc = searchTerm || filterStatus !== 'all'
    ? "Try adjusting your search or filter criteria."
    : "";

  if (activeView === 'incoming') {
    title = 'No Incoming Transfers';
    description = `You have no ${filterStatus !== 'all' ? filterStatus + ' ' : ''}incoming transfers${searchTerm ? ' matching your search' : ''}. ${baseDesc}`.trim();
    icon = <Inbox className="h-8 w-8 text-muted-foreground" />;
  } else if (activeView === 'outgoing') {
    title = 'No Outgoing Transfers';
    description = `You have no ${filterStatus !== 'all' ? filterStatus + ' ' : ''}outgoing transfers${searchTerm ? ' matching your search' : ''}. ${baseDesc}`.trim();
    icon = <ExternalLink className="h-8 w-8 text-muted-foreground" />;
    showInitiateButton = !searchTerm && filterStatus === 'all'; // Show button only if no filters active
  } else { // history
    title = 'No Transfer History';
    description = `No transfer history found${searchTerm ? ' matching your search' : ''}${filterStatus !== 'all' ? ' with status ' + filterStatus : ''}. ${baseDesc}`.trim();
  }

  return (
    <div className="py-16 text-center flex flex-col items-center justify-center min-h-[300px]">
      <div className="inline-flex h-16 w-16 items-center justify-center rounded-full bg-muted mb-4">
        {icon}
      </div>
      <h3 className="text-lg font-semibold mb-2">{title}</h3>
      <p className="text-sm text-muted-foreground max-w-sm mx-auto">
        {description}
      </p>
      {showInitiateButton && (
        <Button
          variant="blue" // Use blue variant as per style guide
          className="mt-6"
          onClick={onInitiateTransfer}
        >
          <Plus className="h-4 w-4 mr-2" />
          Initiate New Transfer
        </Button>
      )}
    </div>
  );
};

export default EmptyState; 