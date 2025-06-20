import React from 'react';
interface NotificationPanelProps {
    isOpen: boolean;
    onClose: () => void;
}
declare const NotificationPanel: React.FC<NotificationPanelProps>;
export default NotificationPanel;
