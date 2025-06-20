interface SidebarProps {
    isMobile?: boolean;
    closeMobileMenu?: () => void;
    toggleSidebar?: () => void;
    openNotificationPanel?: () => void;
}
declare const Sidebar: ({ isMobile, closeMobileMenu, toggleSidebar: toggleSidebarProp, openNotificationPanel, }: SidebarProps) => import("react").JSX.Element;
export default Sidebar;
