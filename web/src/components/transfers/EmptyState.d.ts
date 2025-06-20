import React from 'react';
interface EmptyStateProps {
    activeView: 'incoming' | 'outgoing' | 'history';
    searchTerm: string;
    filterStatus: string;
    onInitiateTransfer: () => void;
}
declare const EmptyState: React.FC<EmptyStateProps>;
export default EmptyState;
