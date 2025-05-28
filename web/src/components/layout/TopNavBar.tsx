import React from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useApp } from '@/contexts/AppContext';
import { useIsMobile } from '@/hooks/use-mobile';
import { cn } from '@/lib/utils';
import { Bell, Menu, QrCode, Search, User } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Input } from '@/components/ui/input';
import { Link } from "wouter";

interface TopNavBarProps {
  toggleMobileMenu: () => void;
  openScanner: () => void;
  openNotifications: () => void;
}

const TopNavBar: React.FC<TopNavBarProps> = ({
  toggleMobileMenu,
  openScanner,
  openNotifications
}) => {
  const { user } = useAuth();
  const { theme, toggleTheme } = useApp();
  const isMobile = useIsMobile();

  const userInitials = user?.name
    ? user.name
        .split(' ')
        .map(n => n[0])
        .join('')
        .toUpperCase()
    : 'U';

  return (
    <header className={cn(
      "w-full h-[var(--header-height)] border-b bg-background z-10",
      "px-4 md:px-6 py-2",
      "flex items-center justify-between"
    )}>
      {/* Left section: Mobile menu toggle + search */}
      <div className="flex items-center space-x-4">
        {/* Mobile menu button - only visible on mobile */}
        <Button 
          variant="ghost" 
          size="icon" 
          className="md:hidden"
          onClick={toggleMobileMenu}
        >
          <Menu className="h-5 w-5" />
        </Button>
        
        {/* Search bar - hidden on smallest screens */}
        <div className="hidden sm:flex items-center relative w-64 lg:w-80">
          <Search className="absolute left-2.5 h-4 w-4 text-muted-foreground" />
          <Input 
            type="search" 
            placeholder="Search..." 
            className="pl-8 bg-background border-input"
          />
        </div>
      </div>
      
      {/* Right section: Actions */}
      <div className="flex items-center space-x-2">
        {/* QR Scanner button */}
        <Button
          variant="ghost"
          size="icon"
          onClick={openScanner}
          className="relative text-muted-foreground hover:text-foreground"
        >
          <QrCode className="h-5 w-5" />
        </Button>
        
        {/* Notifications button */}
        <Button
          variant="ghost"
          size="icon"
          onClick={openNotifications}
          className="relative text-muted-foreground hover:text-foreground"
        >
          <Bell className="h-5 w-5" />
          <span className="absolute h-2 w-2 rounded-full bg-red-500 top-1.5 right-1.5"></span>
        </Button>
        
        {/* User avatar - hidden on mobile as it's in the bottom nav */}
        <Button
          variant="ghost"
          size="icon"
          className="hidden md:flex"
        >
          <Avatar className="h-8 w-8">
            <AvatarImage src="" alt={user?.name || 'User'} />
            <AvatarFallback>{userInitials}</AvatarFallback>
          </Avatar>
        </Button>
      </div>
    </header>
  );
};

export default TopNavBar;