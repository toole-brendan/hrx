import React, { useState, useEffect, useMemo } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { StandardPageLayout } from '@/components/layout/StandardPageLayout';
import { useAuth } from '@/contexts/AuthContext';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Input } from "@/components/ui/input";
import {
  Loader2,
  AlertCircle,
  CheckCircle,
  RefreshCw,
  TableIcon as TableIconLucide, // Alias to avoid naming conflict
} from 'lucide-react';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  ColumnDef,
  flexRender,
  getCoreRowModel,
  getFilteredRowModel,
  getPaginationRowModel,
  useReactTable,
  SortingState,
  getSortedRowModel,
  ColumnFiltersState,
  getFacetedRowModel,
  getFacetedUniqueValues,
  PaginationState,
} from "@tanstack/react-table";
import { format } from 'date-fns'; // For formatting timestamps

// --- Ledger Status Indicator --- //
type VerificationStatus = 'idle' | 'loading' | 'verified' | 'failed' | 'error';
interface DbVerificationResult {
  is_verified: boolean;
  // Add other potential fields from the backend response if needed
}

const LedgerStatusIndicator: React.FC = () => {
  const [status, setStatus] = useState<VerificationStatus>('idle');
  const [error, setError] = useState<string | null>(null);
  const { authedFetch } = useAuth();

  const fetchVerificationStatus = async () => {
    setStatus('loading');
    setError(null);
    try {
      const { data } = await authedFetch<DbVerificationResult>('/api/verification/database');
      if (data && typeof data.is_verified === 'boolean') {
        setStatus(data.is_verified ? 'verified' : 'failed');
      } else {
        console.error("Invalid verification response format:", data);
        setError('Received invalid response format from server.');
        setStatus('error');
      }
    } catch (err: any) {
      console.error("Failed to fetch ledger verification status:", err);
      setError(err.message || 'An unknown error occurred.');
      setStatus('error');
    }
  };

  useEffect(() => {
    fetchVerificationStatus();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const renderStatus = () => {
    switch (status) {
      case 'loading':
        return (
          <Alert variant="default" className="flex items-center">
            <Loader2 className="h-5 w-5 mr-2 animate-spin" />
            <AlertDescription>Checking ledger database integrity...</AlertDescription>
          </Alert>
        );
      case 'verified':
        return (
          <Alert variant="default" className="flex items-center border-green-500 dark:border-green-700">
            <CheckCircle className="h-5 w-5 mr-2 text-green-600 dark:text-green-500" />
            <AlertDescription className="text-green-700 dark:text-green-400">Ledger database integrity verified successfully.</AlertDescription>
          </Alert>
        );
      case 'failed':
        return (
          <Alert variant="destructive" className="flex items-center">
            <AlertCircle className="h-5 w-5 mr-2" />
            <AlertDescription>Ledger database integrity verification failed. Potential tampering detected.</AlertDescription>
          </Alert>
        );
      case 'error':
        return (
          <Alert variant="destructive">
            <AlertCircle className="h-5 w-5" />
            <AlertTitle>Error</AlertTitle>
            <AlertDescription>{error || 'Failed to retrieve verification status.'}</AlertDescription>
          </Alert>
        );
      case 'idle':
      default:
        return null;
    }
  };

  return (
    <div className="space-y-4">
      {renderStatus()}
      <Button
        onClick={fetchVerificationStatus}
        disabled={status === 'loading'}
        variant="outline"
        size="sm"
      >
        <RefreshCw className={`h-4 w-4 mr-2 ${status === 'loading' ? 'animate-spin' : ''}`} />
        Re-check Status
      </Button>
    </div>
  );
};

// --- Ledger History Explorer --- //

// Define the expected structure for general ledger events
// NOTE: This is a hypothetical structure. The backend endpoint /api/ledger/history needs to be implemented to return this.
interface GeneralLedgerEvent {
  eventId: string; // Assuming a unique ID for each event
  eventType: string; // e.g., 'TRANSFER_REQUEST', 'TRANSFER_APPROVE', 'ITEM_VERIFY', 'STATUS_CHANGE'
  timestamp: string; // ISO date string
  userId?: number; // User initiating the event (if applicable)
  itemId?: number; // Property/Item ID related to the event
  details: Record<string, any>; // Flexible object for event-specific details (e.g., { fromUserId: 1, toUserId: 2 }, { newStatus: 'Operational' })
  // Optional Azure Ledger metadata
  ledgerTransactionId?: number;
  ledgerSequenceNumber?: number;
}

// Define columns for the GeneralLedgerEvent table
const columns: ColumnDef<GeneralLedgerEvent>[] = [
  {
    accessorKey: "timestamp",
    header: "Timestamp",
    cell: ({ row }) => {
      try {
        const date = new Date(row.getValue("timestamp"));
        return format(date, "yyyy-MM-dd HH:mm:ss");
      } catch (e) {
        return "Invalid Date";
      }
    },
  },
  {
    accessorKey: "eventType",
    header: "Event Type",
  },
  {
    accessorKey: "eventId",
    header: "Event ID",
    cell: ({ row }) => <span className="font-mono text-xs">{row.getValue("eventId")}</span>,
  },
  {
    accessorKey: "userId",
    header: "User ID",
  },
  {
    accessorKey: "itemId",
    header: "Item ID",
  },
  {
    accessorKey: "details",
    header: "Details",
    cell: ({ row }) => (
      <pre className="text-xs bg-muted p-1 rounded overflow-x-auto">
        {JSON.stringify(row.getValue("details"), null, 2)}
      </pre>
    ),
  },
];

const LedgerHistoryExplorer: React.FC = () => {
  const [data, setData] = useState<GeneralLedgerEvent[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const { authedFetch } = useAuth();

  // State for table features
  const [globalFilter, setGlobalFilter] = useState('');
  const [pagination, setPagination] = useState<PaginationState>({
    pageIndex: 0,
    pageSize: 10, // Default page size
  });

  useEffect(() => {
    const fetchData = async () => {
      setIsLoading(true);
      setError(null);
      try {
        // ***** IMPORTANT *****
        // This endpoint `/api/ledger/history` needs to be implemented on the backend
        // to return data matching the `GeneralLedgerEvent` interface.
        // Currently, this will likely fail or return unexpected data.
        // *********************
        const { data: fetchedData } = await authedFetch<GeneralLedgerEvent[]>('/api/ledger/history');
        setData(fetchedData || []);
      } catch (err: any) {
        console.error("Failed to fetch general ledger history:", err);
        setError(`Failed to load history: ${err.message || 'Unknown error'}. Backend endpoint /api/ledger/history might be missing.`);
        setData([]);
      } finally {
        setIsLoading(false);
      }
    };
    fetchData();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const table = useReactTable({
    data,
    columns,
    state: {
      pagination,
      globalFilter,
      // sorting, // Add if implementing sorting
      // columnFilters, // Add if implementing column filters
    },
    onPaginationChange: setPagination,
    onGlobalFilterChange: setGlobalFilter,
    getCoreRowModel: getCoreRowModel(),
    getFilteredRowModel: getFilteredRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    // getSortedRowModel: getSortedRowModel(), // Add if implementing sorting
    // getFacetedRowModel: getFacetedRowModel(), // Add if implementing faceted filters
    // getFacetedUniqueValues: getFacetedUniqueValues(), // Add if implementing faceted filters
    // debugTable: true, // Uncomment for debugging
    // debugHeaders: true,
    // debugColumns: true,
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center p-6">
        <Loader2 className="h-6 w-6 mr-2 animate-spin" />
        <span>Loading ledger history...</span>
      </div>
    );
  }

  // Keep error display even if table is technically usable with empty data
  // if (error) { ... }

  return (
    <div className="space-y-4">
      {/* Filtering Input */}
      <div className="flex items-center py-4">
        <Input
          placeholder="Filter all columns..."
          value={globalFilter ?? ''}
          onChange={(event) => setGlobalFilter(event.target.value)}
          className="max-w-sm"
        />
      </div>

      {/* Error Display (if any) */}
      {error && (
        <Alert variant="destructive">
          <AlertCircle className="h-5 w-5" />
          <AlertTitle>Error Loading History</AlertTitle>
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Table */}
      <div className="border rounded-md">
        <Table>
          <TableHeader>
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => (
                  <TableHead key={header.id}>
                    {header.isPlaceholder
                      ? null
                      : flexRender(
                          header.column.columnDef.header,
                          header.getContext()
                        )}
                  </TableHead>
                ))}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            {table.getRowModel().rows?.length ? (
              table.getRowModel().rows.map((row) => (
                <TableRow
                  key={row.id}
                  data-state={row.getIsSelected() && "selected"}
                >
                  {row.getVisibleCells().map((cell) => (
                    <TableCell key={cell.id}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-24 text-center">
                  {isLoading ? "Loading..." : (error ? "Error loading data." : "No ledger history found.")}
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </div>

      {/* Pagination Controls */}
      <div className="flex items-center justify-end space-x-2 py-4">
         <span className="text-sm text-muted-foreground">
            Page{" "}
            {table.getState().pagination.pageIndex + 1} of{" "}
            {table.getPageCount()}
          </span>
        <Button
          variant="outline"
          size="sm"
          onClick={() => table.previousPage()}
          disabled={!table.getCanPreviousPage()}
        >
          Previous
        </Button>
        <Button
          variant="outline"
          size="sm"
          onClick={() => table.nextPage()}
          disabled={!table.getCanNextPage()}
        >
          Next
        </Button>
         {/* Optional: Page size selector */}
         {/* <Select onValueChange={(value) => table.setPageSize(Number(value))} defaultValue={table.getState().pagination.pageSize.toString()}> ... </Select> */}
      </div>
    </div>
  );
};

// --- Main Page Component --- //
const LedgerVerificationPage: React.FC = () => {
  return (
    <StandardPageLayout title="Ledger Verification">
      <div className="space-y-6">
        <Card>
          <CardHeader>
            <CardTitle>Overall Ledger Status</CardTitle>
          </CardHeader>
          <CardContent>
            <LedgerStatusIndicator />
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Ledger History</CardTitle>
            {/* TODO: Add controls for selecting history type (general vs correction) */}
          </CardHeader>
          <CardContent>
            <LedgerHistoryExplorer />
          </CardContent>
        </Card>

        {/* TODO: Add section for initiating database-wide verification? */}
      </div>
    </StandardPageLayout>
  );
};

export default LedgerVerificationPage; 