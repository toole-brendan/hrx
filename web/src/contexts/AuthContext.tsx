import React, { createContext, useContext, useState, ReactNode, useEffect, useCallback } from "react";
import { User } from "../types";

// Define a type for the authedFetch function
type AuthedFetch = <T = any>(input: RequestInfo | URL, init?: RequestInit) => Promise<{ data: T, response: Response }>;

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  authedFetch: AuthedFetch;
}

// API Base URL - Azure Container Apps backend
const API_BASE_URL = 'https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io'; // Azure Production API URL

// Provide a default stub that throws an error if used before initialization
const defaultAuthedFetch: AuthedFetch = async () => {
  throw new Error('AuthContext not initialized - authedFetch called too early.');
};

const AuthContext = createContext<AuthContextType>({
  user: null,
  isAuthenticated: false,
  isLoading: true,
  login: async () => {},
  logout: async () => {},
  authedFetch: defaultAuthedFetch,
});

export const useAuth = () => useContext(AuthContext);

export const AuthProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(true);

  // --- New authedFetch function ---
  const authedFetch = useCallback(async <T = any>(
    input: RequestInfo | URL,
    init?: RequestInit
  ): Promise<{ data: T, response: Response }> => {
    // Production mode - use real fetch
    // Convert relative URLs to absolute URLs using API_BASE_URL
    const url = input.toString().startsWith('/') 
      ? `${API_BASE_URL}${input}` 
      : input.toString();
      
    const response = await fetch(url, {
      ...init,
      headers: {
        ...(init?.body ? { 'Content-Type': 'application/json' } : {}),
        ...(init?.headers),
      },
      credentials: 'include',
    });

    if (!response.ok) {
      let errorPayload: any = { message: `HTTP error! status: ${response.status}` };
      try {
          errorPayload = await response.json();
      } catch (e) {
          try {
            errorPayload.message = await response.text();
          } catch (textErr) {}
      }
      
      if (response.status !== 401) {
        console.error('API Error Payload:', errorPayload);
      }
      
      // Check for both 'error' and 'message' fields from backend
      const errorMessage = errorPayload.error || errorPayload.message || `Request failed with status ${response.status}`;
      throw new Error(errorMessage);
    }

    const text = await response.text();
    let data: T;
    try {
      data = text ? JSON.parse(text) : null as T;
    } catch (e) {
       console.error("Failed to parse JSON response:", text);
       throw new Error("Invalid JSON response from server.");
    }

    return { data, response };
  }, []);

  // --- Check auth status on mount ---
  useEffect(() => {
    const checkAuthStatus = async () => {
      setIsLoading(true);
      
      // Check real auth status
      try {
        const { data } = await authedFetch<{ user: User }>('/api/auth/me');
        setUser(data.user);
        setIsAuthenticated(true);
      } catch (error: any) {
        if (!error.message?.includes('401')) {
          console.warn("Check auth status failed:", error);
        }
        setUser(null);
        setIsAuthenticated(false);
      } finally {
        setIsLoading(false);
      }
    };

    checkAuthStatus();
  }, [authedFetch]);

  // --- Login function ---
  const login = async (email: string, password: string) => {
    setIsLoading(true);
    
    // Real login
    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
        credentials: 'include',
      });

      if (response.ok) {
        const data = await response.json();
        setUser(data.user);
        setIsAuthenticated(true);
      } else {
        let errorData: any = { message: 'Login failed' };
        try {
          errorData = await response.json();
        } catch (e) {}
        // Check for both 'error' and 'message' fields from backend
        const errorMessage = errorData.error || errorData.message || 'Login failed';
        throw new Error(errorMessage);
      }
    } catch (error) {
      console.error("Login error:", error);
      setUser(null);
      setIsAuthenticated(false);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  // --- Logout function ---
  const logout = async () => {
    setIsLoading(true);
    
    try {
      await authedFetch('/api/auth/logout', { method: 'POST' });
    } catch (error) {
      console.error("Logout error:", error);
    }
    
    setUser(null);
    setIsAuthenticated(false);
    setIsLoading(false);
  };

  return (
    <AuthContext.Provider value={{ user, isAuthenticated, isLoading, login, logout, authedFetch }}>
      {children}
    </AuthContext.Provider>
  );
}; 