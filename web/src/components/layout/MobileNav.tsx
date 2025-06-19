import { useLocation } from"wouter";
import { Link } from"wouter";
import { LayoutDashboard, Package, Send, Wrench
} from"lucide-react";
import { cn } from"@/lib/utils";
import { useApp } from"@/contexts/AppContext";
import { Button } from"@/components/ui/button"; interface MobileNavProps { // QR Scanner functionality removed
} const MobileNav: React.FC<MobileNavProps> = () => { const [location] = useLocation(); const { theme } = useApp(); const isActive = (path: string) => { return location === path; }; return ( <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 flex justify-around p-3 z-10"> <Link href="/"> <div className={`flex flex-col items-center justify-center ${isActive('/') ? 'text-purple-600' : 'text-gray-500'}`}> <LayoutDashboard className="h-5 w-5" /> <span className="text-xs uppercase tracking-wider font-light mt-1">Dashboard</span> </div> </Link> <Link href="/transfers"> <div className={`flex flex-col items-center justify-center ${isActive('/transfers') ? 'text-purple-600' : 'text-gray-500'}`}> <Send className="h-5 w-5" /> <span className="text-xs uppercase tracking-wider font-light mt-1">Transfers</span> </div> </Link> <Link href="/maintenance"> <div className={`flex flex-col items-center justify-center ${isActive('/maintenance') ? 'text-purple-600' : 'text-gray-500'}`}> <Wrench className="h-5 w-5" /> <span className="text-xs uppercase tracking-wider font-light mt-1">Maintenance</span> </div> </Link> </nav> );
}; export default MobileNav;