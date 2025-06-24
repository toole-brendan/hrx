import React, { createContext, useContext, useState, ReactNode, useEffect, useCallback } from "react";
import { User } from "../types";

// Define a type for the authedFetch function
type AuthedFetch = <T = unknown>(input: RequestInfo | URL, init?: RequestInit) => Promise<{ data: T, response: Response }>;

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  authedFetch: AuthedFetch;
}

// API Base URL - Use environment variable or default
const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

// Development mode - bypass auth when running locally
const isDevelopment = window.location.hostname === 'localhost' && !import.meta.env.PROD;
const BYPASS_AUTH = false; // Disabled to use real authentication

// Mock user for development
const mockUser: User = {
  id: 'dev-user-123',
  email: 'dev@handreceipt.com',
  name: 'Development User',
  firstName: 'Development',
  lastName: 'User',
  rank: 'CPT',
  position: 'Developer',
  unit: 'Dev Unit',
  yearsOfService: 5,
  commandTime: '2 years',
  responsibility: 'Development',
  valueManaged: '$1,000,000',
  upcomingEvents: [],
  equipmentSummary: {
    vehicles: 10,
    weapons: 20,
    communications: 15,
    opticalSystems: 5,
    sensitiveItems: 25
  }
};

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
  const authedFetch = useCallback(async <T = unknown>(
    input: RequestInfo | URL,
    init?: RequestInit
  ): Promise<{ data: T, response: Response }> => {
    // In bypass mode, return mock responses
    if (BYPASS_AUTH) {
      console.log('[DEV MODE] Bypassing API call:', input);
      
      // Create a mock response
      const mockResponse = new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      });
      
      return {
        data: { success: true } as T,
        response: mockResponse
      };
    }
    
    // Production mode - use real fetch
    // Convert relative URLs to absolute URLs using API_BASE_URL
    const url = input.toString().startsWith('/')
      ? `${API_BASE_URL}${input}`
      : input.toString();
    
    console.log('[AuthContext.authedFetch] Making request:', {
      url,
      method: init?.method || 'GET',
      hasBody: !!init?.body,
      credentials: 'include',
      timestamp: new Date().toISOString(),
      authState: { isAuthenticated, user: user?.email }
    });
    
    const response = await fetch(url, {
      ...init,
      headers: {
        ...(init?.body ? { 'Content-Type': 'application/json' } : {}),
        ...(init?.headers),
      },
      credentials: 'include',
    });
    
    console.log('[AuthContext.authedFetch] Response received:', {
      url,
      status: response.status,
      statusText: response.statusText,
      ok: response.ok,
      timestamp: new Date().toISOString()
    });
    
    if (!response.ok) {
      let errorPayload: { message: string; details?: unknown; error?: string } = { message: `HTTP error! status: ${response.status}` };
      
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
      console.log('[AuthContext.checkAuthStatus] Starting auth check...');
      setIsLoading(true);
      
      // In bypass mode, automatically authenticate with mock user
      if (BYPASS_AUTH) {
        console.log('[DEV MODE] Auth bypassed - using mock user');
        setUser(mockUser);
        setIsAuthenticated(true);
        setIsLoading(false);
        return;
      }
      
      // Check real auth status
      try {
        console.log('[AuthContext.checkAuthStatus] Checking /auth/me endpoint...');
        const { data } = await authedFetch<{ user: any }>('/auth/me');
        console.log('[AuthContext.checkAuthStatus] User data from /auth/me:', data.user);
        
        // Map snake_case from backend to camelCase for frontend
        const mappedUser: User = {
          id: data.user.id?.toString() || '',
          email: data.user.email || '',
          name: data.user.name,
          firstName: data.user.first_name || data.user.firstName,
          lastName: data.user.last_name || data.user.lastName,
          rank: data.user.rank,
          position: data.user.position,
          unit: data.user.unit,
          phone: data.user.phone,
          yearsOfService: data.user.yearsOfService || data.user.years_of_service,
          commandTime: data.user.commandTime || data.user.command_time,
          responsibility: data.user.responsibility,
          valueManaged: data.user.valueManaged || data.user.value_managed,
          upcomingEvents: data.user.upcomingEvents || data.user.upcoming_events,
          equipmentSummary: data.user.equipmentSummary || data.user.equipment_summary
        };
        
        console.log('[AuthContext.checkAuthStatus] Setting user:', mappedUser);
        setUser(mappedUser);
        setIsAuthenticated(true);
        console.log('[AuthContext.checkAuthStatus] Auth check successful, user authenticated');
      } catch (error: unknown) {
        // 401 is expected when not authenticated - don't log as error
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        console.log('[AuthContext.checkAuthStatus] Auth check failed:', {
          error: errorMessage,
          is401: errorMessage.includes('401') || errorMessage.includes('User not authenticated'),
          timestamp: new Date().toISOString()
        });
        
        if (error instanceof Error && !error.message?.includes('401') && !error.message?.includes('User not authenticated')) {
          console.warn("Check auth status failed:", error);
        }
        setUser(null);
        setIsAuthenticated(false);
      } finally {
        console.log('[AuthContext.checkAuthStatus] Auth check complete:', {
          isAuthenticated,
          hasUser: !!user,
          timestamp: new Date().toISOString()
        });
        setIsLoading(false);
      }
    };
    
    checkAuthStatus();
  }, [authedFetch]);
  
  // --- Login function ---
  const login = async (email: string, password: string) => {
    console.log('[AuthContext.login] Login attempt started:', {
      email,
      timestamp: new Date().toISOString()
    });
    
    setIsLoading(true);
    
    // In bypass mode, simulate successful login
    if (BYPASS_AUTH) {
      console.log('[DEV MODE] Login bypassed');
      setUser(mockUser);
      setIsAuthenticated(true);
      setIsLoading(false);
      return;
    }
    
    // Real login
    try {
      console.log('[AuthContext.login] Sending login request to backend...');
      const response = await fetch(`${API_BASE_URL}/auth/login`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ email, password }),
        credentials: 'include',
      });
      
      console.log('[AuthContext.login] Login response received:', {
        status: response.status,
        ok: response.ok,
        headers: Object.fromEntries(response.headers.entries()),
        timestamp: new Date().toISOString()
      });
      
      if (response.ok) {
        const data = await response.json();
        console.log('[AuthContext] Login response user data:', data.user);
        
        // Map snake_case from backend to camelCase for frontend
        const mappedUser: User = {
          id: data.user.id?.toString() || '',
          email: data.user.email || '',
          name: data.user.name,
          firstName: data.user.first_name || data.user.firstName,
          lastName: data.user.last_name || data.user.lastName,
          rank: data.user.rank,
          position: data.user.position,
          unit: data.user.unit,
          phone: data.user.phone,
          yearsOfService: data.user.yearsOfService || data.user.years_of_service,
          commandTime: data.user.commandTime || data.user.command_time,
          responsibility: data.user.responsibility,
          valueManaged: data.user.valueManaged || data.user.value_managed,
          upcomingEvents: data.user.upcomingEvents || data.user.upcoming_events,
          equipmentSummary: data.user.equipmentSummary || data.user.equipment_summary
        };
        
        console.log('[AuthContext.login] Login successful, setting user:', mappedUser);
        setUser(mappedUser);
        setIsAuthenticated(true);
        console.log('[AuthContext.login] Auth state updated:', {
          isAuthenticated: true,
          user: mappedUser.email,
          timestamp: new Date().toISOString()
        });
      } else {
        console.log('[AuthContext.login] Login failed with non-OK response');
        let errorData: { message: string; details?: unknown; error?: string } = { message: 'Login failed' };
        
        try {
          errorData = await response.json();
        } catch (e) {
          // If we can't parse JSON, use the status text
          errorData.message = response.statusText || 'Login failed';
        }
        
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
    
    if (!BYPASS_AUTH) {
      try {
        await authedFetch('/auth/logout', { method: 'POST' });
      } catch (error: unknown) {
        console.error("Logout error:", error);
      }
    }
    
    setUser(null);
    setIsAuthenticated(false);
    setIsLoading(false);
  };
  
  return (
    <AuthContext.Provider 
      value={{ 
        user, 
        isAuthenticated, 
        isLoading, 
        login, 
        logout, 
        authedFetch 
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}; 