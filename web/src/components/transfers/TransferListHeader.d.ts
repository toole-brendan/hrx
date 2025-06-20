import React from 'react';
type SortField = 'date' | 'name' | 'from' | 'to';
type SortOrder = 'asc' | 'desc';
interface SortConfig {
    field: SortField;
    order: SortOrder;
}
interface TransferListHeaderProps {
    sortConfig: SortConfig;
    onSort: (field: SortField) => void;
}
declare const TransferListHeader: React.FC<TransferListHeaderProps>;
export default TransferListHeader;
