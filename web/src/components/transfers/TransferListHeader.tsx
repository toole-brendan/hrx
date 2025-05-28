import React from 'react';
import { ArrowUp, ArrowDown, ArrowUpDown } from 'lucide-react';

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

const TransferListHeader: React.FC<TransferListHeaderProps> = ({ sortConfig, onSort }) => (
  <div className="grid grid-cols-[100px_1.5fr_1fr_1fr_120px_140px] gap-4 border-b px-4 py-3 bg-muted/50 sticky top-0 z-10 text-xs uppercase tracking-wider text-muted-foreground font-medium">
    {(['date', 'name', 'from', 'to'] as SortField[]).map((field) => (
      <div
        key={field}
        className="flex items-center cursor-pointer hover:text-foreground transition-colors group"
        onClick={() => onSort(field)}
      >
        <span>{field === 'name' ? 'Item / SN' : field.charAt(0).toUpperCase() + field.slice(1)}</span>
        {sortConfig.field === field ? (
          sortConfig.order === 'asc' ? (
            <ArrowUp className="h-3 w-3 ml-1 text-foreground" />
          ) : (
            <ArrowDown className="h-3 w-3 ml-1 text-foreground" />
          )
        ) : (
          <ArrowUpDown className="h-3 w-3 ml-1 text-muted-foreground group-hover:text-foreground transition-colors" />
        )}
      </div>
    ))}
    <div>Status</div>
    <div className="text-right">Actions</div>
  </div>
);

export default TransferListHeader; 