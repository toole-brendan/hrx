import { Property } from '@/types';
export declare const propertyKeys: {
    all: readonly ["property"];
    lists: () => readonly ["property", "list"];
    list: (filters?: {
        userId?: number;
    }) => readonly ["property", "list", {
        userId?: number;
    } | undefined];
    details: () => readonly ["property", "detail"];
    detail: (id: string) => readonly ["property", "detail", string];
    history: (serialNumber: string) => readonly ["property", "history", string];
    components: (propertyId: string) => readonly ["property", "components", string];
    availableComponents: (propertyId: string) => readonly ["property", "available-components", string];
};
export declare function useProperties(): import("@tanstack/react-query").UseQueryResult<Property[], any>;
export declare function useUserProperties(userId?: number): import("@tanstack/react-query").UseQueryResult<Property[], Error>;
export declare function useProperty(id: string): import("@tanstack/react-query").UseQueryResult<Property, Error>;
export declare function usePropertyHistory(serialNumber: string): import("@tanstack/react-query").UseQueryResult<any[], Error>;
export declare function useCreateProperty(): import("@tanstack/react-query").UseMutationResult<Property, any, {
    name: string;
    serialNumber: string;
    description?: string;
    currentStatus: string;
    propertyModelId?: number;
    assignedToUserId?: number;
    nsn?: string;
    lin?: string;
}, unknown>;
export declare function useUpdatePropertyStatus(): import("@tanstack/react-query").UseMutationResult<Property, any, {
    id: string;
    status: string;
}, unknown>;
export declare function useUpdatePropertyComponents(): import("@tanstack/react-query").UseMutationResult<Property, any, {
    id: string;
    components: any[];
}, unknown>;
export declare function useVerifyProperty(): import("@tanstack/react-query").UseMutationResult<void, any, {
    id: string;
    verificationType: string;
}, unknown>;
export declare function useProcessOfflineQueue(): import("@tanstack/react-query").UseMutationResult<{
    processed: number;
    remaining: number;
}, any, void, unknown>;
export declare function useOfflineSync(): import("@tanstack/react-query").UseMutationResult<{
    processed: number;
    remaining: number;
}, any, void, unknown>;
export declare function usePropertyComponents(propertyId: string): import("@tanstack/react-query").UseQueryResult<any[], Error>;
export declare function useAvailableComponents(propertyId: string): import("@tanstack/react-query").UseQueryResult<Property[], Error>;
export declare function useAttachComponent(): import("@tanstack/react-query").UseMutationResult<any, any, {
    propertyId: string;
    componentId: number;
    position?: string;
    notes?: string;
}, unknown>;
export declare function useDetachComponent(): import("@tanstack/react-query").UseMutationResult<void, any, {
    propertyId: string;
    componentId: number;
}, unknown>;
export declare function useUpdateComponentPosition(): import("@tanstack/react-query").UseMutationResult<void, any, {
    propertyId: string;
    componentId: number;
    position: string;
}, unknown>;
