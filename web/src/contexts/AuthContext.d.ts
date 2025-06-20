import React, { ReactNode } from "react";
import { User } from "../types";
type AuthedFetch = <T = any>(input: RequestInfo | URL, init?: RequestInit) => Promise<{
    data: T;
    response: Response;
}>;
interface AuthContextType {
    user: User | null;
    isAuthenticated: boolean;
    isLoading: boolean;
    login: (email: string, password: string) => Promise<void>;
    logout: () => Promise<void>;
    authedFetch: AuthedFetch;
}
export declare const useAuth: () => AuthContextType;
export declare const AuthProvider: React.FC<{
    children: ReactNode;
}>;
export {};
