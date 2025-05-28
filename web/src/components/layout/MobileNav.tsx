import { useLocation } from "wouter";
import { Link } from "wouter";
import { 
  LayoutDashboard, 
  Package, 
  QrCode, 
  Send, 
  Wrench
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useApp } from "@/contexts/AppContext";
import { Button } from "@/components/ui/button";

interface MobileNavProps {
  openQRScanner?: () => void;
}

const MobileNav: React.FC<MobileNavProps> = ({ openQRScanner }) => {
  const [location] = useLocation();
  const { theme } = useApp();

  const isActive = (path: string) => {
    return location === path;
  };

  const handleQRScanClick = () => {
    if (openQRScanner) {
      openQRScanner();
    }
  };

  return (
    <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white dark:bg-black border-t border-gray-200 dark:border-white/10 flex justify-around p-3 z-10">
      <Link href="/">
        <div className={`flex flex-col items-center justify-center ${isActive('/') ? 'text-purple-600 dark:text-purple-400' : 'text-gray-500 dark:text-gray-400'}`}>
          <LayoutDashboard className="h-5 w-5" />
          <span className="text-xs uppercase tracking-wider font-light mt-1">Dashboard</span>
        </div>
      </Link>
      
      <div 
        className={`flex flex-col items-center justify-center cursor-pointer 
                   p-2 bg-purple-600 dark:bg-purple-600 rounded-full -mt-6 border-4 
                   ${theme === 'dark' ? 'border-black' : 'border-white'}`}
        onClick={handleQRScanClick}
      >
        <QrCode className="h-6 w-6 text-white" />
      </div>
      
      <Link href="/transfers">
        <div className={`flex flex-col items-center justify-center ${isActive('/transfers') ? 'text-purple-600 dark:text-purple-400' : 'text-gray-500 dark:text-gray-400'}`}>
          <Send className="h-5 w-5" />
          <span className="text-xs uppercase tracking-wider font-light mt-1">Transfers</span>
        </div>
      </Link>
      
      <Link href="/maintenance">
        <div className={`flex flex-col items-center justify-center ${isActive('/maintenance') ? 'text-purple-600 dark:text-purple-400' : 'text-gray-500 dark:text-gray-400'}`}>
          <Wrench className="h-5 w-5" />
          <span className="text-xs uppercase tracking-wider font-light mt-1">Maintenance</span>
        </div>
      </Link>
    </nav>
  );
};

export default MobileNav;