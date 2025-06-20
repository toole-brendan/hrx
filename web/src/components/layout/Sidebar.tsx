// web/src/components/layout/Sidebar.tsx

import { useContext } from "react";
import { useLocation, Link } from "wouter";
import { cn } from "@/lib/utils";
import { useAuth } from "@/contexts/AuthContext";
import { useApp } from "@/contexts/AppContext";
import { useNotifications } from "@/contexts/NotificationContext";
import {
  Home,
  Package,
  ArrowLeftRight,
  ClipboardList,
  Settings,
  BarChart3,
  Menu,
  ChevronLeft,
  ChevronRight,
  Globe,
  Wifi,
  UserCircle,
  Bell,
  Inbox,
} from "lucide-react";
import { useUnreadDocumentCount } from "@/hooks/useDocuments";

interface SidebarProps {
  isMobile?: boolean;
  closeMobileMenu?: () => void;
  // QR Scanner functionality removed
  toggleSidebar?: () => void;
  openNotificationPanel?: () => void;
}

const Sidebar = ({
  isMobile = false,
  closeMobileMenu,
  toggleSidebar: toggleSidebarProp,
  openNotificationPanel,
}: SidebarProps) => {
  const [location] = useLocation();
  const { user } = useAuth();
  const { sidebarCollapsed, toggleSidebar: contextToggleSidebar } = useApp();
  const { unreadCount } = useNotifications();
  const { data: unreadDocumentCount = 0 } = useUnreadDocumentCount();

  // Use the functions from context directly if they're not passed as props
  const toggleSidebar = () => {
    if (toggleSidebarProp) {
      toggleSidebarProp();
    } else {
      contextToggleSidebar();
    }
  };

  const isActive = (path: string) => {
    const currentPath = location;
    return currentPath === path || currentPath.startsWith(path + '/');
  };

  const handleLinkClick = (onClick?: () => void) => {
    if (onClick) {
      onClick();
    }
    
    if (isMobile && closeMobileMenu) {
      closeMobileMenu();
    }
  };
  
  const handleLogoClick = () => {
    // Navigate to the dashboard page
    window.location.href = '/dashboard';
  };

  const handleNotificationClick = () => {
    if (openNotificationPanel) {
      openNotificationPanel();
    }
    if (isMobile && closeMobileMenu) {
      closeMobileMenu();
    }
  };

  // Helper function to get user initials
  const getUserInitials = () => {
    if (!user) return "?";
    
    const firstInitial = user.firstName?.charAt(0).toUpperCase() || "";
    const lastInitial = user.lastName?.charAt(0).toUpperCase() || "";
    
    return firstInitial + lastInitial || "U";
  };

  interface NavItem {
    path: string;
    icon: React.ReactNode;
    label: string;
    notificationCount?: number;
    onClick?: () => void;
  }

  // Updated nav items without QR Management
  const navItems: NavItem[] = [
    { path: "/dashboard", icon: <Home className="sidebar-item-icon" />, label: "Dashboard" },
    { path: "/property-book", icon: <Package className="sidebar-item-icon" />, label: "Property Book" },
    { 
      path: "/transfers", 
      icon: <ArrowLeftRight className="sidebar-item-icon" />, 
      label: "Transfers"
    },
    { path: "/network", icon: <Globe className="sidebar-item-icon" />, label: "Network" },
    { 
      path: "/documents", 
      icon: <Inbox className="sidebar-item-icon" />, 
      label: "Documents",
      notificationCount: unreadDocumentCount > 0 ? unreadDocumentCount : undefined
    }
  ];
  
  // Footer actions
  const settingsAction = {
    path: "/settings",
    icon: <Settings className="sidebar-item-icon" />,
    label: "Settings"
  };
  
  const profileAction = {
    path: "/profile", 
    icon: <UserCircle className="sidebar-item-icon" />,
    label: "Profile"
  };

  if (isMobile) {
    return (
      <nav 
        className="flex-1 flex flex-col" 
        style={{ 
          backgroundColor: '#FAFAFA' 
        }}
      >
        {/* Header - Logo */}
        <div className="p-6">
          <div 
            className="flex items-center justify-center cursor-pointer hover:opacity-90 transition-opacity"
            onClick={handleLogoClick}
          >
            <img 
              src="/hr_logo.png" 
              alt="HandReceipt"
              className="h-8 w-auto"
            />
          </div>
        </div>
        
        {/* Divider with same styling as Quick Action dividers */}
        <div className="px-4">
          <div className="border-t border-gray-200 mb-2"></div>
        </div>
        
        {/* User Profile section with proper vertical centering */}
        <div className="flex items-center min-h-[60px]"> {/* Fixed height container with flexbox centering */}
          {!sidebarCollapsed ? (
            <div className="flex items-center cursor-pointer px-4 w-full">
              <div className="w-8 h-8 rounded-full bg-blue-300 flex items-center justify-center text-blue-800 text-sm font-medium mr-3 shadow-sm">
                {getUserInitials()}
              </div>
              <div>
                <p className="text-sm font-medium tracking-wider text-gray-900">
                  {user?.rank} {user?.lastName}
                </p>
              </div>
            </div>
          ) : (
            <div className="flex justify-center w-full">
              <div className="w-8 h-8 rounded-full bg-blue-300 flex items-center justify-center text-blue-800 text-sm font-medium cursor-pointer shadow-sm">
                {getUserInitials()}
              </div>
            </div>
          )}
        </div>
        
        {/* Divider with same styling as Quick Action dividers */}
        <div className="px-4">
          <div className="border-t border-gray-200 mb-2"></div>
        </div>
        
        {/* Main navigation section */}
        <div className="flex-1 space-y-1 py-2 px-4">
          {/* Main navigation items */}
          {navItems.map((item) => 
            item.onClick ? (
              <div 
                key={item.path}
                onClick={() => handleLinkClick(item.onClick)}
                className={`sidebar-item ${isActive(item.path) ? "active" : ""}`}
              >
                {item.icon}
                <span>{item.label}</span>
                {item.notificationCount && (
                  <span className="ml-auto inline-flex items-center justify-center h-5 w-5 text-xs font-medium text-white bg-ios-accent rounded-full">
                    {item.notificationCount}
                  </span>
                )}
              </div>
            ) : (
              <Link key={item.path} href={item.path}>
                <div 
                  onClick={() => handleLinkClick()}
                  className={`sidebar-item ${isActive(item.path) ? "active" : ""}`}
                >
                  {item.icon}
                  <span>{item.label}</span>
                  {item.notificationCount && (
                    <span className="ml-auto inline-flex items-center justify-center h-5 w-5 text-xs font-medium text-white bg-ios-accent rounded-full">
                      {item.notificationCount}
                    </span>
                  )}
                </div>
              </Link>
            )
          )}
        </div>
        
        {/* Footer section */}
        <div className="mt-auto p-4 space-y-3">
          {/* Footer divider */}
          <div className="border-t border-gray-200 my-3"></div>
          
          {/* Mobile version - Notification Item */}
          <div 
            className="sidebar-item relative cursor-pointer"
            onClick={handleNotificationClick}
          >
            <Bell className="sidebar-item-icon" />
            <span>Notifications</span>
            {unreadCount > 0 && (
              <span className="absolute inline-flex items-center justify-center h-5 w-5 text-xs font-medium text-white bg-red-600 rounded-full top-1/2 right-1 transform -translate-y-1/2">
                {unreadCount}
              </span>
            )}
          </div>
          
          {/* Settings link */}
          <Link href="/settings">
            <div 
              onClick={() => handleLinkClick()}
              className={`sidebar-item ${isActive("/settings") ? "active" : ""}`}
            >
              {settingsAction.icon}
              <span>{settingsAction.label}</span>
            </div>
          </Link>
          
          {/* Profile link */}
          <Link href="/profile">
            <div
              className={`sidebar-item ${isActive("/profile") ? "active" : ""}`}
              onClick={() => handleLinkClick()}
            >
              <UserCircle className="sidebar-item-icon" />
              <span>Profile</span>
            </div>
          </Link>
        </div>
      </nav>
    );
  }

  return (
    <aside 
      className={`sidebar hidden md:flex flex-col ${sidebarCollapsed ? 'collapsed' : ''}`}
      style={{ 
        backgroundColor: '#FAFAFA',
        borderRight: `1px solid #E0E0E0` 
      }}
    >
      {/* Header - Logo */}
      <div className="p-6">
        {!sidebarCollapsed ? (
          <div 
            className="flex items-center justify-center cursor-pointer hover:opacity-90 transition-opacity"
            onClick={handleLogoClick}
          >
            <img 
              src="/hr_logo.png" 
              alt="HandReceipt"
              className="h-8 w-auto"
            />
          </div>
        ) : (
          <div className="flex items-center justify-center h-5">
            {/* Empty div to maintain spacing in collapsed mode */}
          </div>
        )}
      </div>
      
      {/* Divider with same styling as Quick Action dividers */}
      <div className="px-2">
        <div className="border-t border-gray-200"></div>
      </div>
      
      {/* User Profile section with proper vertical centering */}
      <div className="flex items-center min-h-[60px]"> {/* Fixed height container with flexbox centering */}
        {!sidebarCollapsed ? (
          <div className="flex items-center cursor-pointer px-4 w-full">
            <div className="w-8 h-8 rounded-full bg-blue-300 flex items-center justify-center text-blue-800 text-sm font-medium mr-3 shadow-sm">
              {getUserInitials()}
            </div>
            <div>
              <p className="text-sm font-medium tracking-wider text-gray-900">
                {user?.rank} {user?.lastName}
              </p>
            </div>
          </div>
        ) : (
          <div className="flex justify-center w-full">
            <div className="w-8 h-8 rounded-full bg-blue-300 flex items-center justify-center text-blue-800 text-sm font-medium cursor-pointer shadow-sm">
              {getUserInitials()}
            </div>
          </div>
        )}
      </div>
      
      {/* Divider with same styling as Quick Action dividers */}
      <div className="px-2">
        <div className="border-t border-gray-200 mb-2"></div>
      </div>
      
      <div className="flex flex-col flex-1">
        {/* Main navigation items section */}
        <nav className={`flex-1 px-2 pt-1 pb-4 space-y-1 overflow-y-auto ${sidebarCollapsed ? 'collapsed' : ''}`}>
          {navItems.map((item) => 
            item.onClick ? (
              <div 
                key={item.path}
                onClick={() => handleLinkClick(item.onClick)}
                className={`sidebar-item ${isActive(item.path) ? "active" : ""}`}
              >
                {item.icon}
                {!sidebarCollapsed && <span className="text-nav-item">{item.label}</span>}
                {item.notificationCount && !sidebarCollapsed && (
                  <span className="ml-auto inline-flex items-center justify-center h-5 w-5 text-xs font-medium text-white bg-ios-accent rounded-full">
                    {item.notificationCount}
                  </span>
                )}
              </div>
            ) : (
              <Link key={item.path} href={item.path}>
                <div
                  className={`sidebar-item ${isActive(item.path) ? "active" : ""}`}
                  onClick={() => handleLinkClick()}
                >
                  {item.icon}
                  {!sidebarCollapsed && <span className="text-nav-item">{item.label}</span>}
                  {item.notificationCount && !sidebarCollapsed && (
                    <span className="ml-auto inline-flex items-center justify-center h-5 w-5 text-xs font-medium text-white bg-ios-accent rounded-full">
                      {item.notificationCount}
                    </span>
                  )}
                </div>
              </Link>
            )
          )}
        </nav>
        
        {/* Bottom action links section */}
        <div className={`mt-auto px-2 pt-2 pb-4 ${sidebarCollapsed ? 'text-center' : ''}`}>
          {/* First divider */}
          <div className="border-t border-gray-200 mb-2"></div>
          
          {/* Navigation items group - styled as regular sidebar items */}
          <div className="mb-2">
            {/* Desktop version - Notification Item */}
            <div 
              className="sidebar-item relative cursor-pointer"
              onClick={handleNotificationClick}
              title="Notifications"
            >
              <Bell className="sidebar-item-icon" />
              {!sidebarCollapsed && <span className="text-nav-item">Notifications</span>}
              {unreadCount > 0 && (
                <span className={cn(
                  "absolute inline-flex items-center justify-center h-5 w-5 text-xs font-medium text-white bg-red-600 rounded-full",
                  sidebarCollapsed 
                    ? "top-0 right-0 transform translate-x-1/2 -translate-y-1/2" 
                    : "top-1/2 right-1 transform -translate-y-1/2" // Centered vertically and moved closer
                )}>
                  {unreadCount}
                </span>
              )}
            </div>
            
            {/* Settings link */}
            <Link href="/settings">
              <div
                className={`sidebar-item ${isActive("/settings") ? "active" : ""}`}
                onClick={() => handleLinkClick()}
              >
                {settingsAction.icon}
                {!sidebarCollapsed && <span className="text-nav-item">{settingsAction.label}</span>}
              </div>
            </Link>
            
            {/* Profile link */}
            <Link href="/profile">
              <div
                className={`sidebar-item ${isActive("/profile") ? "active" : ""}`}
                onClick={() => handleLinkClick()}
              >
                <UserCircle className="sidebar-item-icon" />
                {!sidebarCollapsed && <span className="text-nav-item">Profile</span>}
              </div>
            </Link>
          </div>
          
          {/* Second divider */}
          <div className="border-t border-gray-200 mb-2"></div>
          
          {/* Sidebar collapse button only */}
          {!sidebarCollapsed ? (
            <div className="flex items-center justify-end px-2">
              <button 
                onClick={toggleSidebar}
                className="p-2 rounded-md hover:bg-gray-200 transition-colors"
                title="Collapse sidebar"
              >
                <ChevronLeft className="h-5 w-5 text-gray-900" />
              </button>
            </div>
          ) : (
            <button 
              onClick={toggleSidebar}
              className="p-2 rounded-md hover:bg-gray-200 transition-colors mx-auto block"
              title="Expand sidebar"
            >
              <ChevronRight className="h-5 w-5 text-gray-900" />
            </button>
          )}
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;