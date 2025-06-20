interface MobileMenuProps {
    isOpen: boolean;
    onClose: () => void;
    openNotificationPanel?: () => void;
}
declare const MobileMenu: React.FC<MobileMenuProps>;
export default MobileMenu;
