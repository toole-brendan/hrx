import React from 'react';
interface TopNavBarProps {
    toggleMobileMenu: () => void;
    openNotifications: () => void;
}
declare const TopNavBar: React.FC<TopNavBarProps>;
export default TopNavBar;
