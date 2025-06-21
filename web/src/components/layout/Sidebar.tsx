// web/src/components/layout/Sidebar.tsx

import React, { useContext, useEffect, useRef, useState } from "react";
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
  PanelLeftClose,
  PanelLeftOpen,
} from "lucide-react";
import { useUnreadDocumentCount } from "@/hooks/useDocuments";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

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
  const [location, navigate] = useLocation();
  const { user } = useAuth();
  const { sidebarCollapsed, toggleSidebar: contextToggleSidebar } = useApp();
  const { unreadCount } = useNotifications();
  const { data: unreadDocumentCount = 0 } = useUnreadDocumentCount();
  const sidebarRef = useRef<HTMLElement>(null);
  const [isResizing, setIsResizing] = useState(false);
  const [sidebarWidth, setSidebarWidth] = useState(250);
  const [showTooltip, setShowTooltip] = useState<string | null>(null);

  // Use ResizeObserver for responsive behavior
  useEffect(() => {
    if (!sidebarRef.current || isMobile) return;

    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const width = entry.contentRect.width;
        // Only auto-collapse if window is being resized and sidebar is not manually collapsed
        if (width < 100 && !sidebarCollapsed && window.innerWidth < 1024) {
          contextToggleSidebar();
        }
      }
    });

    resizeObserver.observe(sidebarRef.current);
    return () => resizeObserver.disconnect();
  }, [sidebarCollapsed, contextToggleSidebar, isMobile]);

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

  // Handle profile click
  const handleProfileClick = () => {
    navigate('/profile');
    if (isMobile && closeMobileMenu) {
      closeMobileMenu();
    }
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
      <nav className="flex-1 flex flex-col bg-gradient-to-b from-gray-50 to-gray-100 shadow-inner">
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
        
        {/* Gradient divider */}
        <div className="px-4 py-2">
          <div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent"></div>
        </div>
        
        {/* User Profile section with improved styling */}
        <div 
          className="flex items-center min-h-[70px] px-4 py-3 cursor-pointer transition-all duration-200 hover:bg-white/50 group"
          onClick={handleProfileClick}
        >
          {!sidebarCollapsed ? (
            <div className="flex items-center w-full">
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-400 to-blue-500 flex items-center justify-center text-white text-sm font-semibold mr-3 shadow-md group-hover:shadow-lg transition-shadow duration-200">
                {getUserInitials()}
              </div>
              <div className="flex-1">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-0.5">
                  {user?.rank}
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {user?.lastName}{user?.firstName ? `, ${user?.firstName}` : ''}
                </p>
              </div>
            </div>
          ) : (
            <div className="flex justify-center w-full">
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-400 to-blue-500 flex items-center justify-center text-white text-sm font-semibold shadow-md group-hover:shadow-lg transition-shadow duration-200">
                {getUserInitials()}
              </div>
            </div>
          )}
        </div>
        
        {/* Gradient divider */}
        <div className="px-4 py-2">
          <div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent"></div>
        </div>
        
        {/* Main navigation section */}
        <div className="flex-1 space-y-1 py-2 px-3">
          {/* Main navigation items */}
          {navItems.map((item) => 
            item.onClick ? (
              <div 
                key={item.path}
                onClick={() => handleLinkClick(item.onClick)}
                className={cn(
                  "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                  isActive(item.path) 
                    ? "bg-blue-500 text-white shadow-md" 
                    : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                )}
              >
                {isActive(item.path) && (
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
                )}
                <div className={cn(
                  "transition-transform duration-200",
                  !isActive(item.path) && "group-hover:scale-110"
                )}>
                  {React.cloneElement(item.icon as React.ReactElement, {
                    className: cn(
                      "h-5 w-5 mr-3",
                      isActive(item.path) ? "text-white" : "text-gray-600"
                    ),
                    strokeWidth: 2
                  })}
                </div>
                <span className="font-medium">{item.label}</span>
                {item.notificationCount && (
                  <span className={cn(
                    "ml-auto inline-flex items-center justify-center h-5 min-w-[20px] px-1 text-xs font-bold rounded-full",
                    isActive(item.path) 
                      ? "bg-white/20 text-white" 
                      : "bg-blue-500 text-white animate-pulse"
                  )}>
                    {item.notificationCount}
                  </span>
                )}
              </div>
            ) : (
              <Link key={item.path} href={item.path}>
                <div 
                  onClick={() => handleLinkClick()}
                  className={cn(
                    "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                    isActive(item.path) 
                      ? "bg-blue-500 text-white shadow-md" 
                      : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                  )}
                >
                  {isActive(item.path) && (
                    <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
                  )}
                  <div className={cn(
                    "transition-transform duration-200",
                    !isActive(item.path) && "group-hover:scale-110"
                  )}>
                    {React.cloneElement(item.icon as React.ReactElement, {
                      className: cn(
                        "h-5 w-5 mr-3",
                        isActive(item.path) ? "text-white" : "text-gray-600"
                      ),
                      strokeWidth: 2
                    })}
                  </div>
                  <span className="font-medium">{item.label}</span>
                  {item.notificationCount && (
                    <span className={cn(
                      "ml-auto inline-flex items-center justify-center h-5 min-w-[20px] px-1 text-xs font-bold rounded-full",
                      isActive(item.path) 
                        ? "bg-white/20 text-white" 
                        : "bg-blue-500 text-white animate-pulse"
                    )}>
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
          {/* Gradient divider */}
          <div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent"></div>
          
          {/* Mobile version - Notification Item */}
          <div 
            className={cn(
              "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
              "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
            )}
            onClick={handleNotificationClick}
          >
            <Bell className="h-5 w-5 mr-3 text-gray-600 transition-transform duration-200 group-hover:scale-110" strokeWidth={2} />
            <span className="font-medium">Notifications</span>
            {unreadCount > 0 && (
              <span className="ml-auto inline-flex items-center justify-center h-5 min-w-[20px] px-1 text-xs font-bold bg-red-500 text-white rounded-full animate-pulse">
                {unreadCount}
              </span>
            )}
          </div>
          
          {/* Settings link */}
          <Link href="/settings">
            <div 
              onClick={() => handleLinkClick()}
              className={cn(
                "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                isActive("/settings") 
                  ? "bg-blue-500 text-white shadow-md" 
                  : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
              )}
            >
              {isActive("/settings") && (
                <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
              )}
              <Settings className={cn(
                "h-5 w-5 mr-3 transition-transform duration-200",
                isActive("/settings") ? "text-white" : "text-gray-600 group-hover:scale-110"
              )} strokeWidth={2} />
              <span className="font-medium">{settingsAction.label}</span>
            </div>
          </Link>
          
          {/* Profile link */}
          <Link href="/profile">
            <div
              className={cn(
                "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                isActive("/profile") 
                  ? "bg-blue-500 text-white shadow-md" 
                  : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
              )}
              onClick={() => handleLinkClick()}
            >
              {isActive("/profile") && (
                <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
              )}
              <UserCircle className={cn(
                "h-5 w-5 mr-3 transition-transform duration-200",
                isActive("/profile") ? "text-white" : "text-gray-600 group-hover:scale-110"
              )} strokeWidth={2} />
              <span className="font-medium">Profile</span>
            </div>
          </Link>
        </div>
      </nav>
    );
  }

  return (
    <TooltipProvider>
      <aside 
        ref={sidebarRef}
        className={cn(
          "sidebar hidden md:flex flex-col bg-gradient-to-b from-gray-50 to-gray-100 shadow-xl backdrop-blur-md transition-all duration-300",
          sidebarCollapsed ? 'collapsed' : ''
        )}
        style={{ 
          borderRight: `1px solid #E0E0E0`,
          width: sidebarCollapsed ? '70px' : '250px'
        }}
      >
        {/* Header - Logo */}
        <div className={cn("flex items-center justify-center", sidebarCollapsed ? "p-4 h-16" : "p-6")}>
          {!sidebarCollapsed ? (
            <div 
              className="cursor-pointer hover:opacity-90 transition-opacity"
              onClick={handleLogoClick}
            >
              <img 
                src="/hr_logo.png" 
                alt="HandReceipt"
                className="h-8 w-auto"
              />
            </div>
          ) : (
            <Tooltip>
              <TooltipTrigger asChild>
                <div 
                  className="cursor-pointer hover:opacity-90 transition-opacity"
                  onClick={handleLogoClick}
                >
                  <Home className="h-6 w-6 text-gray-600" strokeWidth={2} />
                </div>
              </TooltipTrigger>
              <TooltipContent side="right" className="animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95">
                <p>Dashboard</p>
              </TooltipContent>
            </Tooltip>
          )}
        </div>
        
        {/* Gradient divider */}
        <div className="px-3">
          <div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent"></div>
        </div>
        
        {/* User Profile section with improved styling */}
        <div 
          className="flex items-center min-h-[70px] px-4 py-3 cursor-pointer transition-all duration-200 hover:bg-white/50 group"
          onClick={handleProfileClick}
        >
          {!sidebarCollapsed ? (
            <div className="flex items-center w-full">
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-400 to-blue-500 flex items-center justify-center text-white text-sm font-semibold mr-3 shadow-md group-hover:shadow-lg transition-shadow duration-200">
                {getUserInitials()}
              </div>
              <div className="flex-1">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-0.5">
                  {user?.rank}
                </p>
                <p className="text-sm font-medium text-gray-900">
                  {user?.lastName}{user?.firstName ? `, ${user?.firstName}` : ''}
                </p>
              </div>
            </div>
          ) : (
            <Tooltip>
              <TooltipTrigger asChild>
                <div className="flex justify-center w-full">
                  <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-400 to-blue-500 flex items-center justify-center text-white text-sm font-semibold shadow-md group-hover:shadow-lg transition-shadow duration-200">
                    {getUserInitials()}
                  </div>
                </div>
              </TooltipTrigger>
              <TooltipContent side="right" className="animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95">
                <p>{user?.rank} {user?.lastName}{user?.firstName ? `, ${user?.firstName}` : ''}</p>
              </TooltipContent>
            </Tooltip>
          )}
        </div>
        
        {/* Gradient divider */}
        <div className="px-3">
          <div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent"></div>
        </div>
        
        <div className="flex flex-col flex-1">
          {/* Main navigation items section */}
          <nav className={cn("flex-1 px-3 pt-4 pb-4 space-y-1 overflow-y-auto", sidebarCollapsed ? 'collapsed' : '')}>
            {navItems.map((item) => {
              const NavContent = (
                <div
                  className={cn(
                    "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                    isActive(item.path) 
                      ? "bg-blue-500 text-white shadow-md" 
                      : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                  )}
                  onClick={() => item.onClick ? handleLinkClick(item.onClick) : undefined}
                >
                  {isActive(item.path) && (
                    <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
                  )}
                  <div className={cn(
                    "transition-transform duration-200",
                    !isActive(item.path) && "group-hover:scale-110"
                  )}>
                    {React.cloneElement(item.icon as React.ReactElement, {
                      className: cn(
                        "h-5 w-5",
                        !sidebarCollapsed && "mr-3",
                        isActive(item.path) ? "text-white" : "text-gray-600"
                      ),
                      strokeWidth: 2
                    })}
                  </div>
                  {!sidebarCollapsed && <span className="font-medium text-nav-item">{item.label}</span>}
                  {item.notificationCount && !sidebarCollapsed && (
                    <span className={cn(
                      "ml-auto inline-flex items-center justify-center h-5 min-w-[20px] px-1 text-xs font-bold rounded-full",
                      isActive(item.path) 
                        ? "bg-white/20 text-white" 
                        : "bg-blue-500 text-white animate-pulse"
                    )}>
                      {item.notificationCount}
                    </span>
                  )}
                  {item.notificationCount && sidebarCollapsed && (
                    <span className="absolute -top-1 -right-1 inline-flex items-center justify-center h-4 w-4 text-xs font-bold bg-red-500 text-white rounded-full animate-pulse">
                      {item.notificationCount > 9 ? '9+' : item.notificationCount}
                    </span>
                  )}
                </div>
              );

              if (sidebarCollapsed) {
                return (
                  <Tooltip key={item.path}>
                    <TooltipTrigger asChild>
                      {item.onClick ? (
                        NavContent
                      ) : (
                        <Link href={item.path}>
                          {NavContent}
                        </Link>
                      )}
                    </TooltipTrigger>
                    <TooltipContent side="right" className="animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95">
                      <p>{item.label}</p>
                    </TooltipContent>
                  </Tooltip>
                );
              }

              return item.onClick ? (
                <div key={item.path}>
                  {NavContent}
                </div>
              ) : (
                <Link key={item.path} href={item.path}>
                  {NavContent}
                </Link>
              );
            })}
          </nav>
          
          {/* Bottom action links section */}
          <div className={cn("mt-auto px-3 pt-2 pb-4", sidebarCollapsed ? 'text-center' : '')}>
            {/* Gradient divider */}
            <div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent mb-3"></div>
            
            {/* Navigation items group - styled as regular sidebar items */}
            <div className="space-y-1 mb-3">
              {/* Desktop version - Notification Item */}
              {sidebarCollapsed ? (
                <Tooltip>
                  <TooltipTrigger asChild>
                    <div 
                      className={cn(
                        "relative flex items-center justify-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                        "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                      )}
                      onClick={handleNotificationClick}
                    >
                      <Bell className="h-5 w-5 text-gray-600 transition-transform duration-200 group-hover:scale-110" strokeWidth={2} />
                      {unreadCount > 0 && (
                        <span className="absolute -top-1 -right-1 inline-flex items-center justify-center h-4 w-4 text-xs font-bold bg-red-500 text-white rounded-full animate-pulse">
                          {unreadCount > 9 ? '9+' : unreadCount}
                        </span>
                      )}
                    </div>
                  </TooltipTrigger>
                  <TooltipContent side="right" className="animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95">
                    <p>Notifications</p>
                  </TooltipContent>
                </Tooltip>
              ) : (
                <div 
                  className={cn(
                    "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                    "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                  )}
                  onClick={handleNotificationClick}
                >
                  <Bell className="h-5 w-5 mr-3 text-gray-600 transition-transform duration-200 group-hover:scale-110" strokeWidth={2} />
                  <span className="font-medium text-nav-item">Notifications</span>
                  {unreadCount > 0 && (
                    <span className="ml-auto inline-flex items-center justify-center h-5 min-w-[20px] px-1 text-xs font-bold bg-red-500 text-white rounded-full animate-pulse">
                      {unreadCount}
                    </span>
                  )}
                </div>
              )}
              
              {/* Settings link */}
              {sidebarCollapsed ? (
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Link href="/settings">
                      <div
                        className={cn(
                          "relative flex items-center justify-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                          isActive("/settings") 
                            ? "bg-blue-500 text-white shadow-md" 
                            : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                        )}
                        onClick={() => handleLinkClick()}
                      >
                        {isActive("/settings") && (
                          <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
                        )}
                        <Settings className={cn(
                          "h-5 w-5 transition-transform duration-200",
                          isActive("/settings") ? "text-white" : "text-gray-600 group-hover:scale-110"
                        )} strokeWidth={2} />
                      </div>
                    </Link>
                  </TooltipTrigger>
                  <TooltipContent side="right" className="animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95">
                    <p>Settings</p>
                  </TooltipContent>
                </Tooltip>
              ) : (
                <Link href="/settings">
                  <div
                    className={cn(
                      "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                      isActive("/settings") 
                        ? "bg-blue-500 text-white shadow-md" 
                        : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                    )}
                    onClick={() => handleLinkClick()}
                  >
                    {isActive("/settings") && (
                      <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
                    )}
                    <Settings className={cn(
                      "h-5 w-5 mr-3 transition-transform duration-200",
                      isActive("/settings") ? "text-white" : "text-gray-600 group-hover:scale-110"
                    )} strokeWidth={2} />
                    <span className="font-medium text-nav-item">{settingsAction.label}</span>
                  </div>
                </Link>
              )}
              
              {/* Profile link */}
              {sidebarCollapsed ? (
                <Tooltip>
                  <TooltipTrigger asChild>
                    <Link href="/profile">
                      <div
                        className={cn(
                          "relative flex items-center justify-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                          isActive("/profile") 
                            ? "bg-blue-500 text-white shadow-md" 
                            : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                        )}
                        onClick={() => handleLinkClick()}
                      >
                        {isActive("/profile") && (
                          <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
                        )}
                        <UserCircle className={cn(
                          "h-5 w-5 transition-transform duration-200",
                          isActive("/profile") ? "text-white" : "text-gray-600 group-hover:scale-110"
                        )} strokeWidth={2} />
                      </div>
                    </Link>
                  </TooltipTrigger>
                  <TooltipContent side="right" className="animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95">
                    <p>Profile</p>
                  </TooltipContent>
                </Tooltip>
              ) : (
                <Link href="/profile">
                  <div
                    className={cn(
                      "relative flex items-center px-3 py-2.5 rounded-lg cursor-pointer transition-all duration-200 group",
                      isActive("/profile") 
                        ? "bg-blue-500 text-white shadow-md" 
                        : "text-gray-700 hover:bg-white/60 hover:scale-[1.02]"
                    )}
                    onClick={() => handleLinkClick()}
                  >
                    {isActive("/profile") && (
                      <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-blue-600 rounded-r-full -ml-3" />
                    )}
                    <UserCircle className={cn(
                      "h-5 w-5 mr-3 transition-transform duration-200",
                      isActive("/profile") ? "text-white" : "text-gray-600 group-hover:scale-110"
                    )} strokeWidth={2} />
                    <span className="font-medium text-nav-item">Profile</span>
                  </div>
                </Link>
              )}
            </div>
            
            {/* Gradient divider */}
            <div className="h-px bg-gradient-to-r from-transparent via-gray-300 to-transparent mb-3"></div>
            
            {/* Sidebar collapse button */}
            <div className={cn(
              "flex items-center",
              sidebarCollapsed ? "justify-center" : "justify-end px-2"
            )}>
              {!sidebarCollapsed ? (
                <button 
                  onClick={toggleSidebar}
                  className="p-2.5 rounded-lg hover:bg-white/60 transition-all duration-200 group hover:scale-105"
                  title="Collapse sidebar"
                >
                  <PanelLeftClose className="h-5 w-5 text-gray-600 group-hover:text-gray-900" strokeWidth={2} />
                </button>
              ) : (
                <Tooltip>
                  <TooltipTrigger asChild>
                    <button 
                      onClick={toggleSidebar}
                      className="p-2.5 rounded-lg hover:bg-white/60 transition-all duration-200 group hover:scale-105"
                      title="Expand sidebar"
                    >
                      <PanelLeftOpen className="h-5 w-5 text-gray-600 group-hover:text-gray-900" strokeWidth={2} />
                    </button>
                  </TooltipTrigger>
                  <TooltipContent side="right" className="animate-in fade-in-0 zoom-in-95 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95">
                    <p>Expand sidebar</p>
                  </TooltipContent>
                </Tooltip>
              )}
            </div>
          </div>
        </div>
      </aside>
    </TooltipProvider>
  );
};

export default Sidebar;