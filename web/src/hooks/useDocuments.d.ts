import { Document, CreateMaintenanceFormRequest } from '@/services/documentService';
export declare const useDocuments: (box?: "inbox" | "sent" | "all", status?: string, type?: string) => import("@tanstack/react-query").UseQueryResult<{
    documents: Document[];
    unread_count: number;
}, Error>;
export declare const useUnreadDocumentCount: () => import("@tanstack/react-query").UseQueryResult<number, Error>;
export declare const useMarkDocumentRead: () => import("@tanstack/react-query").UseMutationResult<void, Error, number, unknown>;
export declare const useSendMaintenanceForm: () => import("@tanstack/react-query").UseMutationResult<{
    document: Document;
    message: string;
}, Error, CreateMaintenanceFormRequest, unknown>;
export declare const useDocument: (id: number) => import("@tanstack/react-query").UseQueryResult<any, Error>;
