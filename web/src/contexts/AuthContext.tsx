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

// Development mode flag - set this to true for local development
const IS_DEVELOPMENT = false; // Change to false for production

// API Base URL - Azure Container Apps backend
const API_BASE_URL = 'https://handreceipt-backend.bravestone-851f654c.eastus2.azurecontainerapps.io'; // Azure Production API URL

// Mock user for development
const DEV_USER: User = {
  id: "RODMC01",
  email: "michael.rodriguez@handreceipt.com",
  name: "CPT Rodriguez", // Format as rank + last name per requirements
  firstName: "Michael",
  lastName: "Rodriguez",
  rank: "CPT", // Use standard military abbreviation
  position: "Company Commander",
  unit: "Bravo Company, 2-87 Infantry Battalion",
  yearsOfService: 6,
  commandTime: "3 months",
  responsibility: "Primary Hand Receipt Holder for company-level property",
  valueManaged: "$4.2M Equipment Value",
  upcomingEvents: [
    { title: "NTC Rotation Prep", date: "Ongoing" },
    { title: "Equipment Reset", date: "In Progress" },
    { title: "Command Maintenance", date: "Next Week" }
  ],
  equipmentSummary: {
    vehicles: 72,
    weapons: 143,
    communications: 95,
    opticalSystems: 63,
    sensitiveItems: 210
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
  const authedFetch = useCallback(async <T = any>(
    input: RequestInfo | URL,
    init?: RequestInit
  ): Promise<{ data: T, response: Response }> => {
    // In development mode, mock successful responses
    if (IS_DEVELOPMENT) {
      console.log(`[DEV MODE] Mocking fetch for: ${input}`);
      
      // Create a mock response based on the URL
      let mockData: any = {};
      const url = input.toString();
      
      // Mock different endpoints
      if (url.includes('/api/auth/me')) {
        mockData = { user: DEV_USER };
      } else if (url.includes('/api/inventory')) {
        mockData = { items: [] };
      } else if (url.includes('/api/transfers')) {
        mockData = { transfers: [] };
      } else if (url.includes('/api/activities')) {
        mockData = { activities: [] };
      } else {
        mockData = { success: true };
      }
      
      // Create a mock Response object
      const mockResponse = new Response(JSON.stringify(mockData), {
        status: 200,
        statusText: 'OK',
        headers: new Headers({
          'Content-Type': 'application/json'
        })
      });
      
      return { data: mockData as T, response: mockResponse };
    }
    
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
      
      // In development mode, automatically authenticate
      if (IS_DEVELOPMENT) {
        console.log("[DEV MODE] Auto-authenticating with mock user");
        setUser(DEV_USER);
        setIsAuthenticated(true);
        setIsLoading(false);
        return;
      }
      
      // Production mode - check real auth
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
    
    // In development mode, fake successful login
    if (IS_DEVELOPMENT) {
      console.log(`[DEV MODE] Mock login for user: ${email}`);
      setUser(DEV_USER);
      setIsAuthenticated(true);
      setIsLoading(false);
      return;
    }
    
    // Production mode - real login
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
    
    if (!IS_DEVELOPMENT) {
      try {
        await authedFetch('/api/auth/logout', { method: 'POST' });
      } catch (error) {
        console.error("Logout error:", error);
      }
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