import { X } from "lucide-react";
import Sidebar from "./Sidebar";
import { useApp } from "@/contexts/AppContext";
import { useLocation } from "wouter";
import { Link } from "wouter";

interface MobileMenuProps {
  isOpen: boolean;
  onClose: () => void;
    openNotificationPanel?: () => void;
}

const MobileMenu: React.FC<MobileMenuProps> = ({ 
  isOpen, 
  onClose,
  openNotificationPanel
}) => {
  if (!isOpen) return null;
  
  return (
    <div className="fixed inset-0 z-50 md:hidden">
      {/* Backdrop */}
      <div 
        className="fixed inset-0 bg-black/50 transition-opacity" 
        onClick={onClose}
      />
      
      {/* Slide-out panel */}
      <div className="fixed inset-y-0 left-0 max-w-xs w-full bg-[#FAFAFA] shadow-xl flex flex-col h-full overflow-y-auto">
        <Sidebar 
          isMobile={true} 
          closeMobileMenu={onClose} 
          openNotificationPanel={openNotificationPanel}
        />
      </div>
    </div>
  );
};

export default MobileMenu;