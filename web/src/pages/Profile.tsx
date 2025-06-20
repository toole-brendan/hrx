import React from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useNotifications } from '@/contexts/NotificationContext';
import { Link } from 'wouter';
import { 
  User, 
  Mail, 
  Star, 
  Settings, 
  Edit, 
  Inbox, 
  Info, 
  HelpCircle, 
  AlertTriangle, 
  Lock, 
  LogOut,
  ChevronRight
} from 'lucide-react';

// iOS-style components
import { 
  CleanCard, 
  ElegantSectionHeader,
  MinimalLoadingView,
  MinimalEmptyState
} from '@/components/ios';

import { useUnreadDocumentCount } from '@/hooks/useDocuments';

export default function Profile() {
  const { user, logout } = useAuth();
  const { unreadCount } = useNotifications();
  const { data: unreadDocumentCount = 0 } = useUnreadDocumentCount();

  if (!user) {
    return (
      <div className="min-h-screen bg-ios-background">
        <MinimalLoadingView text="LOADING PROFILE" />
      </div>
    );
  }

  const formatUserName = () => {
    if (user.lastName && user.firstName) {
      return `${user.lastName}, ${user.firstName}`;
    } else if (user.lastName) {
      return user.lastName;
    } else if (user.firstName) {
      return user.firstName;
    } else {
      return user.name || "No name available";
    }
  };

  const handleLogout = async () => {
    try {
      await logout();
    } catch (error) {
      console.error('Logout failed:', error);
    }
  };

  return (
    <div className="min-h-screen bg-ios-background">
      <div className="max-w-2xl mx-auto px-6 py-8">
        
        {/* Header */}
        <div className="mb-10">
          <h1 className="text-3xl font-light text-primary-text tracking-tight mb-2">
            PROFILE
          </h1>
        </div>

        <div className="space-y-8">
          
          {/* Profile Information Section */}
          <div className="space-y-6">
            <ElegantSectionHeader 
              title="USER INFORMATION" 
              className="mb-4"
            />
            
            <CleanCard className="p-0">
              <div className="space-y-0">
                <ProfileInfoRow
                  label="NAME"
                  value={formatUserName()}
                  icon={<User className="h-4 w-4" />}
                />
                
                <ProfileDivider />
                
                <ProfileInfoRow
                  label="EMAIL"
                  value={user.email || "No email"}
                  icon={<Mail className="h-4 w-4" />}
                  isMonospace
                />
                
                <ProfileDivider />
                
                <ProfileInfoRow
                  label="RANK"
                  value={user.rank || "No rank"}
                  icon={<Star className="h-4 w-4" />}
                  isMonospace
                />
              </div>
            </CleanCard>
          </div>

          {/* Quick Actions Section */}
          <div className="space-y-6">
            <ElegantSectionHeader 
              title="QUICK ACTIONS" 
              className="mb-4"
            />
            
            <CleanCard className="p-0">
              <div className="space-y-0">
                <Link href="/settings">
                  <ProfileActionRow
                    label="Settings"
                    description="App preferences"
                    icon={<Settings className="h-4 w-4" />}
                  />
                </Link>
                
                <ProfileDivider />
                
                <Link href="/profile/edit">
                  <ProfileActionRow
                    label="Edit Profile"
                    description="Update your information"
                    icon={<Edit className="h-4 w-4" />}
                  />
                </Link>
                
                <ProfileDivider />
                
                <Link href="/documents">
                  <ProfileActionRow
                    label="Documents"
                    description={unreadDocumentCount > 0 ? `${unreadDocumentCount} unread` : "View inbox"}
                    icon={<Inbox className="h-4 w-4" />}
                    badge={unreadDocumentCount > 0 ? unreadDocumentCount.toString() : undefined}
                  />
                </Link>
              </div>
            </CleanCard>
          </div>

          {/* Support Section */}
          <div className="space-y-6">
            <ElegantSectionHeader 
              title="SUPPORT" 
              className="mb-4"
            />
            
            <CleanCard className="p-0">
              <div className="space-y-0">
                <Link href="/about">
                  <ProfileActionRow
                    label="About"
                    description="Learn more about the app"
                    icon={<Info className="h-4 w-4" />}
                  />
                </Link>
                
                <ProfileDivider />
                
                <Link href="/help">
                  <ProfileActionRow
                    label="Help"
                    description="Get assistance"
                    icon={<HelpCircle className="h-4 w-4" />}
                  />
                </Link>
                
                <ProfileDivider />
                
                <Link href="/report-issue">
                  <ProfileActionRow
                    label="Report Issue"
                    description="Report a problem"
                    icon={<AlertTriangle className="h-4 w-4" />}
                  />
                </Link>
              </div>
            </CleanCard>
          </div>

          {/* Account Section */}
          <div className="space-y-6">
            <ElegantSectionHeader 
              title="ACCOUNT" 
              className="mb-4"
            />
            
            <CleanCard className="p-0">
              <div className="space-y-0">
                <Link href="/change-password">
                  <ProfileActionRow
                    label="Change Password"
                    description="Update security"
                    icon={<Lock className="h-4 w-4" />}
                  />
                </Link>
                
                <ProfileDivider />
                
                <button
                  onClick={handleLogout}
                  className="w-full text-left"
                >
                  <ProfileActionRow
                    label="Sign Out"
                    description="End session"
                    icon={<LogOut className="h-4 w-4" />}
                    isDestructive
                  />
                </button>
              </div>
            </CleanCard>
          </div>

          {/* Bottom padding */}
          <div className="h-10" />
        </div>
      </div>
    </div>
  );
}

// Supporting Components

interface ProfileInfoRowProps {
  label: string;
  value: string;
  icon: React.ReactNode;
  isMonospace?: boolean;
}

const ProfileInfoRow: React.FC<ProfileInfoRowProps> = ({ 
  label, 
  value, 
  icon, 
  isMonospace = false 
}) => (
  <div className="flex items-center gap-4 px-4 py-4">
    <div className="text-tertiary-text w-5 flex justify-center">
      {icon}
    </div>
    
    <div className="text-xs font-medium text-tertiary-text uppercase tracking-wide w-16">
      {label}
    </div>
    
    <div className={`text-primary-text ${isMonospace ? 'font-mono' : ''} flex-1`}>
      {value}
    </div>
  </div>
);

interface ProfileActionRowProps {
  label: string;
  description: string;
  icon: React.ReactNode;
  isDestructive?: boolean;
  badge?: string;
}

const ProfileActionRow: React.FC<ProfileActionRowProps> = ({ 
  label, 
  description, 
  icon, 
  isDestructive = false,
  badge 
}) => (
  <div className="flex items-center gap-4 px-4 py-4 hover:bg-ios-secondary-background/50 transition-colors cursor-pointer">
    <div className={`w-5 flex justify-center ${isDestructive ? 'text-ios-destructive' : 'text-secondary-text'}`}>
      {icon}
    </div>
    
    <div className="flex-1">
      <div className={`font-medium ${isDestructive ? 'text-ios-destructive' : 'text-primary-text'}`}>
        {label}
      </div>
      <div className="text-sm text-tertiary-text">
        {description}
      </div>
    </div>
    
    {badge && (
      <div className="bg-ios-accent text-white text-xs font-mono px-2 py-1 rounded-full">
        {badge}
      </div>
    )}
    
    <div className="text-tertiary-text">
      <ChevronRight className="h-3 w-3" />
    </div>
  </div>
);

const ProfileDivider: React.FC = () => (
  <div className="h-px bg-ios-divider ml-12" />
);