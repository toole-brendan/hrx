import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import Sidebar from "./Sidebar";
import MobileMenu from "./MobileMenu";
import MobileNav from "./MobileNav";
import QRScannerModal from "@/components/shared/QRScannerModal";
import NotificationPanel from "@/components/modals/NotificationPanel";
import { useApp } from "@/contexts/AppContext";
import { cn } from "@/lib/utils";
import { useIsMobile } from "@/hooks/use-mobile";
import { Menu } from "lucide-react";

interface AppShellProps {
  children: React.ReactNode;
}

const AppShell: React.FC<AppShellProps> = ({ children }) => {
  const { isAuthenticated } = useAuth();
  const { sidebarCollapsed, toggleSidebar, toggleTheme, theme } = useApp();
  const isMobile = useIsMobile();
  
  // State for mobile menu, scanner, and notifications
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [scannerOpen, setScannerOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  
  // Handlers for opening/closing various panels
  const openScanner = () => setScannerOpen(true);
  const openNotifications = () => setNotificationsOpen(true);
  const toggleMobileMenu = () => setMobileMenuOpen(!mobileMenuOpen);
  
  const handleLogoClick = () => {
    // Navigate to the dashboard page
    window.location.href = '/';
  };
  
  if (!isAuthenticated) {
    // Render a simpler layout for unauthenticated pages (login)
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
        <main className="flex-1">
          {children}
        </main>
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-background overflow-hidden">
      {/* Sidebar - hidden on mobile */}
      <div className="hidden md:block">
        <Sidebar 
          openQRScanner={openScanner} 
          toggleTheme={toggleTheme}
          toggleSidebar={toggleSidebar}
          openNotificationPanel={openNotifications}
        />
      </div>
      
      {/* Mobile menu */}
      <MobileMenu 
        isOpen={mobileMenuOpen} 
        onClose={() => setMobileMenuOpen(false)} 
        openQRScanner={openScanner}
        openNotificationPanel={openNotifications}
      />
      
      {/* Mobile header - visible only on mobile */}
      <div className="md:hidden bg-white dark:bg-black p-4 border-b border-gray-200 dark:border-white/10 fixed top-0 left-0 right-0 z-10">
        <div className="flex items-center justify-between">
          <div 
            className="flex items-center cursor-pointer hover:opacity-90 transition-opacity"
            onClick={handleLogoClick}
          >
            <div className="border border-gray-800/70 dark:border-gray-100/70 px-4 py-1.5">
              <h1 className="text-lg font-light tracking-widest text-gray-800 dark:text-gray-100 m-0 font-['Georgia']">HandReceipt</h1>
            </div>
          </div>
          <button 
            className="text-gray-800 dark:text-white hover:text-purple-600 dark:hover:text-purple-400 p-2 transition-colors focus:outline-none"
            onClick={toggleMobileMenu}
            aria-label="Open menu"
          >
            <Menu className="h-6 w-6" />
          </button>
        </div>
      </div>
      
      {/* Main content area with proper sidebar offset and mobile header padding */}
      <div className={cn(
        sidebarCollapsed ? "main-content sidebar-collapsed" : "main-content",
        "flex flex-col"
      )}>
        {/* Main content area with responsive viewport scaling */}
        <main className={cn(
          "flex-1 overflow-y-auto transition-all duration-300 ease-in-out",
          "pt-0 md:pt-0",
          "md:pb-0 pb-20", // Add bottom padding on mobile for the nav bar
          "md:mt-0 mt-16" // Add top margin on mobile for the header
        )}>
          {children}
        </main>
      </div>
      
      {/* Mobile Navigation Footer */}
      <MobileNav openQRScanner={openScanner} />
      
      {/* QR Scanner Modal */}
      <QRScannerModal
        isOpen={scannerOpen}
        onClose={() => setScannerOpen(false)}
      />
      
      {/* Notification Panel */}
      <NotificationPanel
        isOpen={notificationsOpen}
        onClose={() => setNotificationsOpen(false)}
      />
    </div>
  );
};

export default AppShell;