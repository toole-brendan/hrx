import { Transfer } from '@/types';
export declare const transferKeys: {
    all: readonly ["transfers"];
    lists: () => readonly ["transfers", "list"];
    list: (filters?: {
        status?: string;
        direction?: string;
    }) => readonly ["transfers", "list", {
        status?: string;
        direction?: string;
    } | undefined];
    details: () => readonly ["transfers", "detail"];
    detail: (id: string) => readonly ["transfers", "detail", string];
};
export declare function useTransfers(filters?: {
    status?: string;
    direction?: string;
}): import("@tanstack/react-query").UseQueryResult<Transfer[], Error>;
export declare function useTransfer(id: string): import("@tanstack/react-query").UseQueryResult<Transfer, Error>;
export declare function useCreateTransfer(): import("@tanstack/react-query").UseMutationResult<Transfer, any, {
    propertyId: number;
    toUserId: number;
    includeComponents?: boolean;
    notes?: string;
}, unknown>;
export declare function useUpdateTransferStatus(): import("@tanstack/react-query").UseMutationResult<Transfer, any, {
    id: string;
    status: "approved" | "rejected";
    notes?: string;
}, unknown>;
export declare function usePendingTransfersCount(): number;
export declare function useAutoRefreshTransfers(): (() => void) | undefined;
