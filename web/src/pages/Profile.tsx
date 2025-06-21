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
  ChevronRight,
  Shield,
  Building,
  Phone,
  MapPin,
  Calendar,
  Award,
  FileText,
} from 'lucide-react';
import { cn } from '@/lib/utils';

// iOS-style components
import { 
  CleanCard, 
  ElegantSectionHeader,
  MinimalLoadingView,
  MinimalEmptyState
} from '@/components/ios';

import { useUnreadDocumentCount } from '@/hooks/useDocuments';

// Enhanced section component
const ProfileSection: React.FC<{ 
  title: string; 
  icon?: React.ReactNode;
  children: React.ReactNode 
}> = ({ title, icon, children }) => (
  <div className="mb-8">
    <div className="flex items-center gap-3 mb-4">
      {icon && (
        <div className="p-2 bg-ios-accent/10 rounded-lg">
          {icon}
        </div>
      )}
      <h2 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
        {title}
      </h2>
    </div>
    <CleanCard className="p-0 shadow-sm overflow-hidden">
      {children}
    </CleanCard>
  </div>
);

export default function Profile() {
  const { user, logout } = useAuth();
  const { unreadCount } = useNotifications();
  const { data: unreadDocumentCount = 0 } = useUnreadDocumentCount();

  if (!user) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
        <div className="max-w-4xl mx-auto px-6 py-8">
          <MinimalLoadingView text="LOADING PROFILE" />
        </div>
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
    <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
      <div className="max-w-5xl mx-auto px-6 py-8">
        
        {/* Enhanced Header */}
        <div className="mb-12">
          <div className="flex items-center justify-between mb-2">
            <h1 className="text-4xl font-bold text-ios-primary-text">
              Profile
            </h1>
            <Link href="/profile/edit">
              <button className="text-ios-accent hover:text-ios-accent/80 font-['Courier_New',_monospace] font-semibold uppercase tracking-wider text-xs flex items-center gap-2 transition-colors">
                <Edit className="h-4 w-4" />
                Edit Profile
              </button>
            </Link>
          </div>
          <p className="text-ios-secondary-text">
            Your account information and preferences
          </p>
        </div>

        {/* User Info Card - Premium Style */}
        <div className="mb-8">
          <div className="bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-xl p-6 border border-ios-accent/20">
            <div className="flex items-start justify-between">
              <div className="flex items-center gap-4">
                <div className="p-4 bg-white rounded-xl shadow-sm">
                  <User className="h-8 w-8 text-ios-accent" />
                </div>
                <div>
                  <h2 className="text-xl font-semibold text-ios-primary-text font-['Courier_New',_monospace] uppercase tracking-wider">
                    {user.rank} {formatUserName()}
                  </h2>
                  <p className="text-sm text-ios-secondary-text mt-1">
                    {user.position || "Service Member"}
                  </p>
                  <div className="flex items-center gap-4 mt-3 text-xs text-ios-tertiary-text">
                    <span className="flex items-center gap-1">
                      <Building className="h-3 w-3" />
                      {user.unit || "Not specified"}
                    </span>
                    <span className="flex items-center gap-1">
                      <Mail className="h-3 w-3" />
                      {user.email}
                    </span>
                  </div>
                </div>
              </div>
              <div className="text-right">
                <p className="text-xs text-ios-tertiary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                  USER ID
                </p>
                <p className="text-sm font-mono text-ios-secondary-text">
                  #{user.id ? String(user.id).slice(0, 8).toUpperCase() : "000000"}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="space-y-6">
          
          {/* Personal Information Section */}
          <ProfileSection 
            title="PERSONAL INFORMATION" 
            icon={<User className="h-5 w-5 text-ios-accent" />}
          >
            <div className="divide-y divide-ios-divider">
              <ProfileInfoRow
                label="FULL NAME"
                value={formatUserName()}
                icon={<User className="h-4 w-4" />}
              />
              
              <ProfileInfoRow
                label="EMAIL ADDRESS"
                value={user.email || "No email"}
                icon={<Mail className="h-4 w-4" />}
              />
              
              <ProfileInfoRow
                label="RANK"
                value={user.rank || "No rank"}
                icon={<Star className="h-4 w-4" />}
              />
              
              <ProfileInfoRow
                label="UNIT"
                value={user.unit || "Not specified"}
                icon={<Building className="h-4 w-4" />}
              />
            </div>
          </ProfileSection>

          {/* Quick Actions Section */}
          <ProfileSection 
            title="QUICK ACTIONS" 
            icon={<Settings className="h-5 w-5 text-ios-accent" />}
          >
            <div className="divide-y divide-ios-divider">
              <Link href="/settings">
                <ProfileActionRow
                  label="Settings"
                  description="App preferences and configuration"
                  icon={<Settings className="h-4 w-4" />}
                  iconBg="bg-ios-accent/10"
                  iconColor="text-ios-accent"
                />
              </Link>
              
              <Link href="/documents">
                <ProfileActionRow
                  label="Documents"
                  description={unreadDocumentCount > 0 ? `${unreadDocumentCount} unread documents` : "View your inbox"}
                  icon={<Inbox className="h-4 w-4" />}
                  badge={unreadDocumentCount > 0 ? unreadDocumentCount.toString() : undefined}
                  iconBg="bg-blue-500/10"
                  iconColor="text-blue-500"
                />
              </Link>
              
              <Link href="/change-password">
                <ProfileActionRow
                  label="Security"
                  description="Change password and security settings"
                  icon={<Lock className="h-4 w-4" />}
                  iconBg="bg-green-500/10"
                  iconColor="text-green-500"
                />
              </Link>
            </div>
          </ProfileSection>

          {/* Support Section */}
          <ProfileSection 
            title="HELP & SUPPORT" 
            icon={<HelpCircle className="h-5 w-5 text-ios-accent" />}
          >
            <div className="divide-y divide-ios-divider">
              <Link href="/about">
                <ProfileActionRow
                  label="About HandReceipt"
                  description="Version info and details"
                  icon={<Info className="h-4 w-4" />}
                  iconBg="bg-purple-500/10"
                  iconColor="text-purple-500"
                />
              </Link>
              
              <Link href="/help">
                <ProfileActionRow
                  label="Help Center"
                  description="Get assistance and FAQs"
                  icon={<HelpCircle className="h-4 w-4" />}
                  iconBg="bg-orange-500/10"
                  iconColor="text-orange-500"
                />
              </Link>
              
              <Link href="/report-issue">
                <ProfileActionRow
                  label="Report an Issue"
                  description="Submit feedback or report problems"
                  icon={<AlertTriangle className="h-4 w-4" />}
                  iconBg="bg-yellow-500/10"
                  iconColor="text-yellow-500"
                />
              </Link>
            </div>
          </ProfileSection>

          {/* Account Actions */}
          <div className="pt-4">
            <button
              onClick={handleLogout}
              className="w-full bg-ios-destructive hover:bg-ios-destructive/90 text-white rounded-lg px-6 py-3 font-semibold shadow-sm transition-all duration-200 flex items-center justify-center gap-2 uppercase tracking-wider text-sm font-['Courier_New',_monospace]"
            >
              <LogOut className="h-4 w-4" />
              Sign Out
            </button>
          </div>

          {/* Bottom padding */}
          <div className="h-24" />
        </div>
      </div>
    </div>
  );
}

// Enhanced Supporting Components

interface ProfileInfoRowProps {
  label: string;
  value: string;
  icon: React.ReactNode;
}

const ProfileInfoRow: React.FC<ProfileInfoRowProps> = ({ 
  label, 
  value, 
  icon, 
}) => (
  <div className="flex items-center gap-4 px-6 py-4 hover:bg-ios-tertiary-background/30 transition-colors">
    <div className="text-ios-secondary-text w-5 flex justify-center">
      {icon}
    </div>
    
    <div className="flex-1">
      <p className="text-xs font-medium text-ios-tertiary-text uppercase tracking-wider font-['Courier_New',_monospace] mb-1">
        {label}
      </p>
      <p className="text-sm text-ios-primary-text font-medium">
        {value}
      </p>
    </div>
  </div>
);

interface ProfileActionRowProps {
  label: string;
  description: string;
  icon: React.ReactNode;
  isDestructive?: boolean;
  badge?: string;
  iconBg?: string;
  iconColor?: string;
}

const ProfileActionRow: React.FC<ProfileActionRowProps> = ({ 
  label, 
  description, 
  icon, 
  isDestructive = false,
  badge,
  iconBg = "bg-ios-tertiary-background",
  iconColor = "text-ios-secondary-text"
}) => (
  <div className="flex items-center gap-4 px-6 py-4 hover:bg-ios-tertiary-background/30 transition-all duration-200 cursor-pointer group">
    <div className={cn(
      "p-2.5 rounded-lg transition-all duration-200",
      iconBg,
      "group-hover:scale-110"
    )}>
      <div className={cn("w-5 h-5 flex items-center justify-center", iconColor)}>
        {icon}
      </div>
    </div>
    
    <div className="flex-1">
      <div className={cn(
        "font-medium text-sm",
        isDestructive ? "text-ios-destructive" : "text-ios-primary-text"
      )}>
        {label}
      </div>
      <div className="text-xs text-ios-tertiary-text mt-0.5">
        {description}
      </div>
    </div>
    
    {badge && (
      <div className="bg-ios-accent text-white text-xs font-semibold px-2.5 py-1 rounded-full font-['Courier_New',_monospace]">
        {badge}
      </div>
    )}
    
    <div className="text-ios-tertiary-text transition-transform duration-200 group-hover:translate-x-0.5">
      <ChevronRight className="h-4 w-4" />
    </div>
  </div>
);