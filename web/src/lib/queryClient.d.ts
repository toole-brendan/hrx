import { QueryClient, QueryFunction } from '@tanstack/react-query';
type UnauthorizedBehavior = 'throw' | 'returnNull';
export declare const getQueryFn: <T>(options: {
    on401: UnauthorizedBehavior;
}) => QueryFunction<T>;
export declare const queryClient: QueryClient;
export {};
