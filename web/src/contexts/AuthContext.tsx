import React, { createContext, useContext, useState, ReactNode, useEffect, useCallback } from "react";
import { User } from "../types";
import tokenService from "../services/tokenService";

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
  
  // Store refresh token in state
  const [refreshToken, setRefreshToken] = useState<string | null>(null);

  // Token refresh handler
  useEffect(() => {
    const handleTokenRefresh = async () => {
      if (!refreshToken) {
        console.error('No refresh token available');
        // Clear auth state
        tokenService.clearTokens();
        setUser(null);
        setIsAuthenticated(false);
        return;
      }

      try {
        const response = await fetch(`${API_BASE_URL}/auth/refresh`, {
          method: 'POST',
          credentials: 'include', // Still use cookie for refresh token
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ refresh_token: refreshToken }),
        });

        if (response.ok) {
          const data = await response.json();
          
          // Calculate expires in seconds from ExpiresAt timestamp (backend returns capital E)
          let expiresIn = 3600; // default 1 hour
          if (data.ExpiresAt || data.expires_at) {
            const expiresAt = new Date(data.ExpiresAt || data.expires_at);
            const now = new Date();
            expiresIn = Math.floor((expiresAt.getTime() - now.getTime()) / 1000);
          }
          
          tokenService.setAccessToken(data.AccessToken || data.accessToken || data.access_token, expiresIn);
          
          // Update refresh token if provided (backend returns capital R)
          if (data.RefreshToken || data.refreshToken || data.refresh_token) {
            setRefreshToken(data.RefreshToken || data.refreshToken || data.refresh_token);
          }
          
          window.dispatchEvent(new Event('token-refreshed'));
        } else {
          // Refresh failed, clear auth state
          tokenService.clearTokens();
          setRefreshToken(null);
          setUser(null);
          setIsAuthenticated(false);
        }
      } catch (error) {
        console.error('Token refresh failed:', error);
        // Clear auth state on error
        tokenService.clearTokens();
        setRefreshToken(null);
        setUser(null);
        setIsAuthenticated(false);
      }
    };

    window.addEventListener('token-refresh-needed', handleTokenRefresh);
    return () => {
      window.removeEventListener('token-refresh-needed', handleTokenRefresh);
    };
  }, [refreshToken]);
  
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
    // Handle URL construction properly
    let url: string;
    const inputStr = input.toString();
    
    if (inputStr.startsWith('http://') || inputStr.startsWith('https://')) {
      // Already a full URL
      url = inputStr;
    } else if (inputStr.startsWith('/api/')) {
      // Already has /api prefix, just prepend the base domain
      const baseWithoutApi = API_BASE_URL.replace(/\/api$/, '');
      url = `${baseWithoutApi}${inputStr}`;
    } else if (inputStr.startsWith('/')) {
      // Relative path without /api, prepend full API_BASE_URL
      url = `${API_BASE_URL}${inputStr}`;
    } else {
      // Relative path without leading slash
      url = `${API_BASE_URL}/${inputStr}`;
    }
    
    console.log('[AuthContext.authedFetch] Making request:', {
      url,
      method: init?.method || 'GET',
      hasBody: !!init?.body,
      credentials: 'include',
      hasAuthToken: !!tokenService.getAccessToken(),
      timestamp: new Date().toISOString(),
      authState: { isAuthenticated, user: user?.email }
    });
    
    const response = await fetch(url, {
      ...init,
      headers: {
        ...tokenService.getAuthHeaders(),
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
    
    // Handle 401 - try refresh
    if (response.status === 401) {
      console.log('[AuthContext.authedFetch] Got 401, attempting token refresh...');
      try {
        await new Promise<void>((resolve) => {
          const handler = () => {
            window.removeEventListener('token-refreshed', handler);
            resolve();
          };
          window.addEventListener('token-refreshed', handler);
          window.dispatchEvent(new Event('token-refresh-needed'));
          
          // Timeout after 5 seconds
          setTimeout(() => {
            window.removeEventListener('token-refreshed', handler);
            resolve();
          }, 5000);
        });

        // Retry request with new token
        console.log('[AuthContext.authedFetch] Retrying request after token refresh...');
        const retryResponse = await fetch(url, {
          ...init,
          headers: {
            ...tokenService.getAuthHeaders(),
            ...(init?.body ? { 'Content-Type': 'application/json' } : {}),
            ...(init?.headers),
          },
          credentials: 'include',
        });

        if (!retryResponse.ok) {
          throw new Error(`HTTP error! status: ${retryResponse.status}`);
        }

        const text = await retryResponse.text();
        const data = text ? JSON.parse(text) : null;
        return { data, response: retryResponse };
      } catch (refreshError) {
        console.error('[AuthContext.authedFetch] Token refresh failed:', refreshError);
      }
    }
    
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
  }, [isAuthenticated, user]);
  
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
      
      // Check if we have a stored token
      const token = tokenService.getAccessToken();
      if (!token) {
        console.log('[AuthContext.checkAuthStatus] No token found, user not authenticated');
        setUser(null);
        setIsAuthenticated(false);
        setIsLoading(false);
        return;
      }
      
      // Check real auth status using direct fetch (not authedFetch to avoid circular dependency)
      try {
        console.log('[AuthContext.checkAuthStatus] Checking /auth/me endpoint...');
        const response = await fetch(`${API_BASE_URL}/auth/me`, {
          method: 'GET',
          headers: {
            ...tokenService.getAuthHeaders(),
            'Content-Type': 'application/json'
          },
          credentials: 'include'
        });
        
        if (!response.ok) {
          if (response.status === 401) {
            // Token is invalid, clear it
            console.log('[AuthContext.checkAuthStatus] Token invalid, clearing...');
            tokenService.clearTokens();
            setRefreshToken(null);
          }
          throw new Error(`Auth check failed: ${response.status}`);
        }
        
        const data = await response.json();
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
          timestamp: new Date().toISOString()
        });
        
        setUser(null);
        setIsAuthenticated(false);
      } finally {
        console.log('[AuthContext.checkAuthStatus] Auth check complete:', {
          isAuthenticated: user !== null,
          hasUser: !!user,
          timestamp: new Date().toISOString()
        });
        setIsLoading(false);
      }
    };
    
    checkAuthStatus();
  }, []); // Only run on mount
  
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
        setCookieHeader: response.headers.get('set-cookie'),
        timestamp: new Date().toISOString()
      });
      
      if (response.ok) {
        const data = await response.json();
        console.log('[AuthContext] Login response:', data);
        
        // Store access token (backend returns with capital A)
        if (data.AccessToken || data.accessToken || data.access_token) {
          // Calculate expires in seconds from ExpiresAt timestamp
          let expiresIn = 3600; // default 1 hour
          if (data.ExpiresAt || data.expires_at) {
            const expiresAt = new Date(data.ExpiresAt || data.expires_at);
            const now = new Date();
            expiresIn = Math.floor((expiresAt.getTime() - now.getTime()) / 1000);
          }
          
          tokenService.setAccessToken(
            data.AccessToken || data.accessToken || data.access_token, 
            expiresIn
          );
        }
        
        // Store refresh token (backend returns with capital R)
        if (data.RefreshToken || data.refreshToken || data.refresh_token) {
          setRefreshToken(data.RefreshToken || data.refreshToken || data.refresh_token);
        }
        
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
          hasToken: !!tokenService.getAccessToken(),
          timestamp: new Date().toISOString()
        });
        
        // Emit auth complete event
        window.dispatchEvent(new CustomEvent('auth-state-changed', { 
          detail: { isAuthenticated: true, user: mappedUser } 
        }));
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
    
    // Clear tokens
    tokenService.clearTokens();
    setRefreshToken(null);
    
    setUser(null);
    setIsAuthenticated(false);
    setIsLoading(false);
    
    // Emit auth state change event
    window.dispatchEvent(new CustomEvent('auth-state-changed', { 
      detail: { isAuthenticated: false, user: null } 
    }));
  };
  
  // Debug log current auth state
  useEffect(() => {
    console.log('[AuthContext] Current auth state:', {
      isAuthenticated,
      hasUser: !!user,
      userEmail: user?.email,
      isLoading,
      timestamp: new Date().toISOString()
    });
  }, [isAuthenticated, user, isLoading]);

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