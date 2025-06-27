import { createContext, useContext, ReactNode, useState, useEffect } from 'react';

interface AppContextType {
  sidebarCollapsed: boolean;
  toggleSidebar: () => void;
}

// Default values
export const AppContext = createContext<AppContextType>({
  sidebarCollapsed: false,
  toggleSidebar: () => {},
});

export const useApp = () => useContext(AppContext);

export const AppProvider = ({ children }: { children: ReactNode }) => {
  // Initialize sidebar state from localStorage or default to expanded
  const [sidebarCollapsed, setSidebarCollapsed] = useState<boolean>(() => {
    try {
      const savedState = localStorage.getItem('sidebarCollapsed');
      return savedState === 'true';
    } catch (error) {
      console.warn('[AppContext] Failed to read from localStorage:', error);
      return false;
    }
  });
  
  // Save sidebar state to localStorage
  useEffect(() => {
    try {
      localStorage.setItem('sidebarCollapsed', sidebarCollapsed.toString());
    } catch (error) {
      console.warn('[AppContext] Failed to write to localStorage:', error);
    }
  }, [sidebarCollapsed]);
  
  // Toggle sidebar function
  const toggleSidebar = () => {
    setSidebarCollapsed((prev) => !prev);
  };
  
  return (
    <AppContext.Provider
      value={{
        sidebarCollapsed,
        toggleSidebar
      }}
    >
      {children}
    </AppContext.Provider>
  );
}; 