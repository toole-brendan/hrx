import React, { createContext, useContext, useState, ReactNode, useEffect, useCallback } from "react";
import { User } from "@shared/schema";

// Define a type for the authedFetch function
type AuthedFetch = <T = any>(input: RequestInfo | URL, init?: RequestInit) => Promise<{ data: T, response: Response }>;

interface AuthContextType {
  user: User | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  authedFetch: AuthedFetch; // Add the new function type
}

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

  // --- New authedFetch function --- (Defined before useEffect that might use it)
  const authedFetch = useCallback(async <T = any>(
    input: RequestInfo | URL,
    init?: RequestInit
  ): Promise<{ data: T, response: Response }> => {
    // Basic wrapper - assumes cookies handle auth. Add headers/tokens if needed.
    const response = await fetch(input, {
      ...init,
      headers: {
        // Ensure Content-Type is only added if there's a body, or default GET
        ...(init?.body ? { 'Content-Type': 'application/json' } : {}),
        ...(init?.headers),
      },
      // credentials: 'include', // Might be needed depending on CORS/cookie setup
    });

    if (!response.ok) {
      let errorPayload: any = { message: `HTTP error! status: ${response.status}` };
      try {
          // Try to parse JSON error body from backend
          errorPayload = await response.json();
      } catch (e) {
          // Ignore if response is not JSON, use text as fallback
          try {
            errorPayload.message = await response.text();
          } catch (textErr) {
             // Ignore if reading text also fails
          }
      }
      // You might want more sophisticated error handling here
      // e.g., check for 401/403 and trigger logout or refresh token flow
      if (response.status === 401 || response.status === 403) {
        // Example: Could trigger logout
        // console.warn("Authentication error, logging out...");
        // logout(); // Be careful of infinite loops if checkAuthStatus calls this
      }
      console.error('API Error Payload:', errorPayload);
      throw new Error(errorPayload.message || `Request failed with status ${response.status}`);
    }

    // Handle cases where response might be empty (e.g., 204 No Content)
    const text = await response.text();
    let data: T;
    try {
      // Use null for empty responses, parse otherwise
      data = text ? JSON.parse(text) : null as T;
    } catch (e) {
       console.error("Failed to parse JSON response:", text);
       throw new Error("Invalid JSON response from server.");
    }

    return { data, response };
  }, []); // useCallback ensures function identity doesn't change unnecessarily

  // --- Existing useEffect for checkAuthStatus ---
  useEffect(() => {
    const checkAuthStatus = async () => {
      setIsLoading(true);
      try {
        // Now we *can* use authedFetch here if desired
        const { data } = await authedFetch<{ user: User }>('/api/auth/me');
        setUser(data.user);
        setIsAuthenticated(true);
      } catch (error) {
        // Handle specific error cases if needed, e.g., 401 means not logged in
        console.warn("Check auth status failed (likely not logged in):", error);
        setUser(null);
        setIsAuthenticated(false);
      } finally {
        setIsLoading(false);
      }
    };

    checkAuthStatus();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [authedFetch]); // Include authedFetch in dependency array now

  // --- Existing login function ---
  const login = async (username: string, password: string) => {
    setIsLoading(true); // Indicate loading during login
    try {
      // Use authedFetch for consistency (though login might not need auth itself)
      // Or stick to raw fetch if login endpoint doesn't expect/use auth cookies initially
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password }),
      });

      if (response.ok) {
        const data = await response.json();
        setUser(data.user);
        setIsAuthenticated(true);
      } else {
        let errorData: any = { message: 'Login failed' };
        try {
          errorData = await response.json();
        } catch (e) { /* Ignore if error response isn't JSON */ }
        throw new Error(errorData.message || 'Login failed');
      }
    } catch (error) {
      console.error("Login error:", error);
      setUser(null); // Ensure user is null on login failure
      setIsAuthenticated(false);
      throw error; // Re-throw for the component to handle
    } finally {
      setIsLoading(false);
    }
  };

  // --- Existing logout function ---
  const logout = async () => {
    setIsLoading(true);
    try {
      // Use authedFetch for consistency, although it might just be POST without body/auth needed
      await authedFetch('/api/auth/logout', { method: 'POST' });
    } catch (error) {
      console.error("Logout error:", error);
      // Even if logout API fails, clear state locally
    } finally {
      setUser(null);
      setIsAuthenticated(false);
      setIsLoading(false);
      // Optionally redirect to login page here
    }
  };

  return (
    <AuthContext.Provider value={{ user, isAuthenticated, isLoading, login, logout, authedFetch }}>
      {children}
    </AuthContext.Provider>
  );
}; 