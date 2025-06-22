import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useApp } from "@/contexts/AppContext";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue
} from "@/components/ui/select";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Separator } from "@/components/ui/separator";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { useToast } from "@/hooks/use-toast";
import {
  Shield,
  Bell,
  Cloud,
  Save,
  RefreshCw,
  Loader2,
  Lock,
  ShieldCheck,
  AlertTriangle,
  Wifi,
  WifiOff,
  CheckCircle2,
  Clock,
  Smartphone,
  LogOut,
} from "lucide-react";
import { cn } from "@/lib/utils";

// iOS Components
import {
  CleanCard,
  ElegantSectionHeader
} from "@/components/ios";

// Form schema for security settings
const securityFormSchema = z.object({
  requirePinForSensitive: z.boolean().default(true),
  showItemDetails: z.boolean().default(true),
  autoLogout: z.string().default("30"),
  pinTimeout: z.string().default("5"),
});


// Form schema for notification settings
const notificationFormSchema = z.object({
  enableNotifications: z.boolean().default(true),
  transferRequests: z.boolean().default(true),
  statusUpdates: z.boolean().default(true),
  systemAlerts: z.boolean().default(true),
  dailyDigest: z.boolean().default(false),
});

// Form schema for sync settings
const syncFormSchema = z.object({
  autoSync: z.boolean().default(true),
  syncInterval: z.string().default("15"),
  syncOnWifiOnly: z.boolean().default(false),
  lastSynced: z.string().optional(),
});

// Define types from schemas
type SecurityFormValues = z.infer<typeof securityFormSchema>;
type NotificationFormValues = z.infer<typeof notificationFormSchema>;
type SyncFormValues = z.infer<typeof syncFormSchema>;

// Enhanced Tab Button Component with better styling
interface TabButtonProps {
  title: string;
  icon?: React.ReactNode;
  isSelected: boolean;
  onClick: () => void;
  description?: string;
}

const TabButton: React.FC<TabButtonProps> = ({ title, icon, isSelected, onClick, description }) => (
  <button
    onClick={onClick}
    className={cn(
      "relative p-6 transition-all duration-300 flex flex-col items-center gap-3 rounded-xl",
      isSelected 
        ? "bg-white shadow-xl border-2 border-ios-accent/30 scale-[1.02]" 
        : "bg-white shadow-lg hover:shadow-xl border border-ios-border hover:border-ios-accent/20"
    )}
  >
    <div className={cn(
      "p-3 rounded-full transition-all duration-300",
      isSelected ? "bg-ios-accent text-white shadow-md" : "bg-ios-tertiary-background text-ios-secondary-text group-hover:shadow-sm"
    )}>
      {icon}
    </div>
    <div className="text-center">
      <span className={cn(
        "text-sm font-semibold block transition-colors duration-300 uppercase tracking-wider",
        isSelected ? "text-ios-primary-text" : "text-ios-secondary-text",
        "font-mono"
      )}>
        {title}
      </span>
      {description && (
        <span className="text-xs text-ios-tertiary-text mt-1 block">
          {description}
        </span>
      )}
    </div>
  </button>
);

// Enhanced form section component
const FormSection: React.FC<{ 
  title: string; 
  description?: string; 
  icon?: React.ReactNode;
  children: React.ReactNode 
}> = ({ title, description, icon, children }) => (
  <div className="mb-8">
    <div className="flex items-center gap-3 mb-4">
      {icon && (
        <div className="p-2 bg-ios-accent/10 rounded-lg">
          {icon}
        </div>
      )}
      <div>
        <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono">{title}</h3>
        {description && (
          <p className="text-sm text-ios-secondary-text mt-0.5">{description}</p>
        )}
      </div>
    </div>
    <div className="space-y-4">
      {children}
    </div>
  </div>
);

// Enhanced toggle component
const SettingToggle: React.FC<{
  title: string;
  description?: string;
  checked: boolean;
  onCheckedChange: (checked: boolean) => void;
  disabled?: boolean;
  icon?: React.ReactNode;
}> = ({ title, description, checked, onCheckedChange, disabled, icon }) => (
  <div className={cn(
    "flex items-center justify-between p-4 rounded-lg transition-all duration-200",
    "hover:bg-ios-tertiary-background/30 border border-transparent",
    checked && "border-ios-accent/20 bg-ios-accent/5"
  )}>
    <div className="flex items-center gap-3 flex-1">
      {icon && (
        <div className={cn(
          "p-2 rounded-lg transition-colors duration-200",
          checked ? "bg-ios-accent/10 text-ios-accent" : "bg-ios-tertiary-background"
        )}>
          {icon}
        </div>
      )}
      <div className="space-y-0.5">
        <div className="text-sm font-medium text-ios-primary-text">
          {title}
        </div>
        {description && (
          <div className="text-xs text-ios-secondary-text">
            {description}
          </div>
        )}
      </div>
    </div>
    <Switch
      checked={checked}
      onCheckedChange={onCheckedChange}
      disabled={disabled}
      className="data-[state=checked]:bg-ios-accent"
    />
  </div>
);

const Settings: React.FC = () => {
  const { user, logout } = useAuth();
  const { toast } = useToast();
  const [isSyncing, setIsSyncing] = useState<boolean>(false);
  const [selectedTab, setSelectedTab] = useState<string>('security');
  const [isSaving, setIsSaving] = useState<boolean>(false);
  
  // Security form
  const securityForm = useForm<SecurityFormValues>({
    resolver: zodResolver(securityFormSchema),
    defaultValues: {
      requirePinForSensitive: true,
      showItemDetails: true,
      autoLogout: "30",
      pinTimeout: "5",
    },
  });
  
  
  // Notification settings form
  const notificationForm = useForm<NotificationFormValues>({
    resolver: zodResolver(notificationFormSchema),
    defaultValues: {
      enableNotifications: true,
      transferRequests: true,
      statusUpdates: true,
      systemAlerts: true,
      dailyDigest: false,
    },
  });
  
  // Sync settings form
  const syncForm = useForm<SyncFormValues>({
    resolver: zodResolver(syncFormSchema),
    defaultValues: {
      autoSync: true,
      syncInterval: "15",
      syncOnWifiOnly: false,
      lastSynced: new Date().toISOString(),
    },
  });
  
  // Form submission handlers
  const onSecuritySubmit = async (data: SecurityFormValues) => {
    setIsSaving(true);
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000));
    setIsSaving(false);
    toast({
      title: "Security Settings Updated",
      description: "Your security preferences have been saved",
    });
  };
  
  
  const onNotificationSubmit = async (data: NotificationFormValues) => {
    setIsSaving(true);
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000));
    setIsSaving(false);
    toast({
      title: "Notification Settings Updated",
      description: "Your notification preferences have been saved",
    });
  };
  
  const onSyncSubmit = async (data: SyncFormValues) => {
    setIsSaving(true);
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000));
    setIsSaving(false);
    toast({
      title: "Sync Settings Updated",
      description: "Your synchronization preferences have been saved",
    });
  };
  
  // Handle manual sync
  const handleManualSync = () => {
    setIsSyncing(true);
    // Simulate sync process
    setTimeout(() => {
      setIsSyncing(false);
      toast({
        title: "Sync Complete",
        description: "Your data has been successfully synchronized",
      });
      // Update last synced time
      syncForm.setValue('lastSynced', new Date().toISOString());
    }, 2000);
  };
  
  // Format the last synced date
  const formatLastSynced = (dateString?: string) => {
    if (!dateString) return "Never";
    try {
      const date = new Date(dateString);
      const now = new Date();
      const diffInMinutes = Math.floor((now.getTime() - date.getTime()) / 60000);
      
      if (diffInMinutes < 1) return "Just now";
      if (diffInMinutes < 60) return `${diffInMinutes} minutes ago`;
      if (diffInMinutes < 1440) return `${Math.floor(diffInMinutes / 60)} hours ago`;
      return date.toLocaleDateString();
    } catch (e) {
      return "Unknown";
    }
  };
  
  return (
    <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
      <div className="max-w-5xl mx-auto px-6 py-8">
        {/* Enhanced Header */}
        <div className="mb-12">
          <div className="flex items-center justify-between mb-2">
            <h1 className="text-4xl font-bold text-ios-primary-text">
              Settings
            </h1>
            <Button
              variant="ghost"
              size="sm"
              onClick={logout}
              className="bg-red-500 text-white hover:bg-red-600 font-mono uppercase tracking-wider text-xs font-bold px-4 py-2 rounded-lg transition-all duration-200 border-0"
            >
              <LogOut className="h-4 w-4 mr-2 text-white" />
              Sign Out
            </Button>
          </div>
          <p className="text-ios-secondary-text">
            Manage your security, notifications, and sync preferences
          </p>
        </div>
        
        {/* Enhanced Tab selector - Cards directly on background */}
        <div className="mb-8">
          <div className="grid grid-cols-3 gap-4">
            <TabButton
              title="Security"
              description="Access & Protection"
              icon={<Shield className="h-5 w-5" />}
              isSelected={selectedTab === 'security'}
              onClick={() => setSelectedTab('security')}
            />
            <TabButton
              title="Notifications"
              description="Alerts & Updates"
              icon={<Bell className="h-5 w-5" />}
              isSelected={selectedTab === 'notifications'}
              onClick={() => setSelectedTab('notifications')}
            />
            <TabButton
              title="Sync"
              description="Data & Backup"
              icon={<Cloud className="h-5 w-5" />}
              isSelected={selectedTab === 'sync'}
              onClick={() => setSelectedTab('sync')}
            />
          </div>
        </div>
        
        {/* Main content with animation */}
        <div className="space-y-6">
          {selectedTab === 'security' && (
            <div className="animate-in fade-in-50 duration-300">
              <CleanCard className="p-6 shadow-lg hover:shadow-xl transition-shadow duration-300">
                <Form {...securityForm}>
                  <form onSubmit={securityForm.handleSubmit(onSecuritySubmit)} className="space-y-6">
                    <FormSection 
                      title="Access Control" 
                      description="Manage how you access sensitive information"
                      icon={<Lock className="h-5 w-5 text-ios-accent" />}
                    >
                      <FormField
                        control={securityForm.control}
                        name="requirePinForSensitive"
                        render={({ field }) => (
                          <SettingToggle
                            title="Require PIN for Sensitive Items"
                            description="Additional security layer for classified equipment"
                            checked={field.value}
                            onCheckedChange={field.onChange}
                            icon={<ShieldCheck className="h-4 w-4" />}
                          />
                        )}
                      />
                      
                      <FormField
                        control={securityForm.control}
                        name="showItemDetails"
                        render={({ field }) => (
                          <SettingToggle
                            title="Show Item Details"
                            description="Display technical specifications in item lists"
                            checked={field.value}
                            onCheckedChange={field.onChange}
                            icon={<AlertTriangle className="h-4 w-4" />}
                          />
                        )}
                      />
                    </FormSection>
                    
                    <Separator className="bg-ios-divider" />
                    
                    <FormSection 
                      title="Session Management" 
                      description="Control automatic logout and PIN timeouts"
                      icon={<Clock className="h-5 w-5 text-ios-accent" />}
                    >
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <FormField
                          control={securityForm.control}
                          name="autoLogout"
                          render={({ field }) => (
                            <FormItem>
                              <FormLabel className="text-xs font-medium text-ios-primary-text uppercase tracking-wider font-mono">
                                AUTO LOGOUT TIMER
                              </FormLabel>
                              <Select onValueChange={field.onChange} defaultValue={field.value}>
                                <FormControl>
                                  <SelectTrigger className="bg-ios-tertiary-background border-ios-border">
                                    <SelectValue placeholder="Select timeout" />
                                  </SelectTrigger>
                                </FormControl>
                                <SelectContent>
                                  <SelectItem value="15">15 minutes</SelectItem>
                                  <SelectItem value="30">30 minutes</SelectItem>
                                  <SelectItem value="60">1 hour</SelectItem>
                                  <SelectItem value="120">2 hours</SelectItem>
                                  <SelectItem value="0">Never</SelectItem>
                                </SelectContent>
                              </Select>
                              <FormDescription className="text-xs">
                                Automatically log out after inactivity
                              </FormDescription>
                            </FormItem>
                          )}
                        />
                        
                        <FormField
                          control={securityForm.control}
                          name="pinTimeout"
                          render={({ field }) => (
                            <FormItem>
                              <FormLabel className="text-xs font-medium text-ios-primary-text uppercase tracking-wider font-mono">
                                PIN RE-ENTRY TIMER
                              </FormLabel>
                              <Select onValueChange={field.onChange} defaultValue={field.value}>
                                <FormControl>
                                  <SelectTrigger className="bg-ios-tertiary-background border-ios-border">
                                    <SelectValue placeholder="Select PIN timeout" />
                                  </SelectTrigger>
                                </FormControl>
                                <SelectContent>
                                  <SelectItem value="1">1 minute</SelectItem>
                                  <SelectItem value="5">5 minutes</SelectItem>
                                  <SelectItem value="10">10 minutes</SelectItem>
                                  <SelectItem value="30">30 minutes</SelectItem>
                                </SelectContent>
                              </Select>
                              <FormDescription className="text-xs">
                                Re-enter PIN after this duration
                              </FormDescription>
                            </FormItem>
                          )}
                        />
                      </div>
                    </FormSection>
                    
                    <div className="flex justify-end pt-4">
                      <Button 
                        type="submit"
                        disabled={isSaving}
                        className="bg-blue-500 hover:bg-blue-600 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 border-0"
                      >
                        {isSaving ? (
                          <>
                            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                            Saving...
                          </>
                        ) : (
                          <>
                            <Save className="h-4 w-4 mr-2" />
                            Save Changes
                          </>
                        )}
                      </Button>
                    </div>
                  </form>
                </Form>
              </CleanCard>
            </div>
          )}
          
          {selectedTab === 'notifications' && (
            <div className="animate-in fade-in-50 duration-300">
              <CleanCard className="p-6 shadow-lg hover:shadow-xl transition-shadow duration-300">
                <Form {...notificationForm}>
                  <form onSubmit={notificationForm.handleSubmit(onNotificationSubmit)} className="space-y-6">
                    <FormSection 
                      title="Notification Preferences" 
                      description="Choose what updates you want to receive"
                      icon={<Bell className="h-5 w-5 text-ios-accent" />}
                    >
                      <FormField
                        control={notificationForm.control}
                        name="enableNotifications"
                        render={({ field }) => (
                          <div className="mb-6">
                            <SettingToggle
                              title="Enable All Notifications"
                              description="Master switch for all notification types"
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              icon={<Bell className="h-4 w-4" />}
                            />
                          </div>
                        )}
                      />
                      
                      <div className={cn(
                        "space-y-3 transition-opacity duration-200",
                        !notificationForm.watch('enableNotifications') && "opacity-50"
                      )}>
                        <FormField
                          control={notificationForm.control}
                          name="transferRequests"
                          render={({ field }) => (
                            <SettingToggle
                              title="Transfer Requests"
                              description="New incoming and outgoing transfer notifications"
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              disabled={!notificationForm.watch('enableNotifications')}
                              icon={<Smartphone className="h-4 w-4" />}
                            />
                          )}
                        />
                        
                        <FormField
                          control={notificationForm.control}
                          name="statusUpdates"
                          render={({ field }) => (
                            <SettingToggle
                              title="Status Updates"
                              description="Equipment status change notifications"
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              disabled={!notificationForm.watch('enableNotifications')}
                              icon={<CheckCircle2 className="h-4 w-4" />}
                            />
                          )}
                        />
                        
                        <FormField
                          control={notificationForm.control}
                          name="systemAlerts"
                          render={({ field }) => (
                            <SettingToggle
                              title="System Alerts"
                              description="Important system messages and updates"
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              disabled={!notificationForm.watch('enableNotifications')}
                              icon={<AlertTriangle className="h-4 w-4" />}
                            />
                          )}
                        />
                        
                        <FormField
                          control={notificationForm.control}
                          name="dailyDigest"
                          render={({ field }) => (
                            <SettingToggle
                              title="Daily Digest"
                              description="Summary email delivered daily at 0600 hours"
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              disabled={!notificationForm.watch('enableNotifications')}
                              icon={<Clock className="h-4 w-4" />}
                            />
                          )}
                        />
                      </div>
                    </FormSection>
                    
                    <div className="flex justify-end pt-4">
                      <Button 
                        type="submit"
                        disabled={isSaving}
                        className="bg-blue-500 hover:bg-blue-600 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 border-0"
                      >
                        {isSaving ? (
                          <>
                            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                            Saving...
                          </>
                        ) : (
                          <>
                            <Save className="h-4 w-4 mr-2" />
                            Save Changes
                          </>
                        )}
                      </Button>
                    </div>
                  </form>
                </Form>
              </CleanCard>
            </div>
          )}
          
          {selectedTab === 'sync' && (
            <div className="animate-in fade-in-50 duration-300">
              <CleanCard className="p-6 shadow-lg hover:shadow-xl transition-shadow duration-300">
                <Form {...syncForm}>
                  <form onSubmit={syncForm.handleSubmit(onSyncSubmit)} className="space-y-6">
                    {/* Sync Status Card */}
                    <div className="bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 rounded-lg p-4 border border-ios-accent/20 shadow-md">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <div className="p-3 bg-white rounded-lg shadow-md">
                            <Cloud className="h-6 w-6 text-ios-accent" />
                          </div>
                          <div>
                            <h4 className="text-xs font-semibold text-ios-primary-text uppercase tracking-wider font-mono">
                              SYNC STATUS
                            </h4>
                            <p className="text-xs text-ios-secondary-text mt-0.5 font-mono">
                              Last synced: {formatLastSynced(syncForm.watch('lastSynced'))}
                            </p>
                          </div>
                        </div>
                        <Button
                          type="button"
                          onClick={handleManualSync}
                          disabled={isSyncing}
                          className="bg-white hover:bg-ios-tertiary-background text-ios-accent border border-ios-accent/20 rounded-lg px-4 py-2 font-medium shadow-sm transition-all duration-200"
                        >
                          {isSyncing ? (
                            <>
                              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                              Syncing...
                            </>
                          ) : (
                            <>
                              <RefreshCw className="h-4 w-4 mr-2" />
                              Sync Now
                            </>
                          )}
                        </Button>
                      </div>
                    </div>
                    
                    <FormSection 
                      title="Automatic Sync" 
                      description="Configure automatic data synchronization"
                      icon={<RefreshCw className="h-5 w-5 text-ios-accent" />}
                    >
                      <FormField
                        control={syncForm.control}
                        name="autoSync"
                        render={({ field }) => (
                          <SettingToggle
                            title="Enable Auto Sync"
                            description="Automatically sync data in the background"
                            checked={field.value}
                            onCheckedChange={field.onChange}
                            icon={<RefreshCw className="h-4 w-4" />}
                          />
                        )}
                      />
                      
                      <div className={cn(
                        "space-y-4 transition-opacity duration-200",
                        !syncForm.watch('autoSync') && "opacity-50"
                      )}>
                        <FormField
                          control={syncForm.control}
                          name="syncInterval"
                          render={({ field }) => (
                            <FormItem>
                              <FormLabel className="text-xs font-medium text-ios-primary-text uppercase tracking-wider font-mono">
                                SYNC FREQUENCY
                              </FormLabel>
                              <Select 
                                onValueChange={field.onChange} 
                                defaultValue={field.value}
                                disabled={!syncForm.watch('autoSync')}
                              >
                                <FormControl>
                                  <SelectTrigger className="bg-ios-tertiary-background border-ios-border">
                                    <SelectValue placeholder="Select sync interval" />
                                  </SelectTrigger>
                                </FormControl>
                                <SelectContent>
                                  <SelectItem value="5">Every 5 minutes</SelectItem>
                                  <SelectItem value="15">Every 15 minutes</SelectItem>
                                  <SelectItem value="30">Every 30 minutes</SelectItem>
                                  <SelectItem value="60">Every hour</SelectItem>
                                  <SelectItem value="360">Every 6 hours</SelectItem>
                                </SelectContent>
                              </Select>
                              <FormDescription className="text-xs">
                                How often to check for updates
                              </FormDescription>
                            </FormItem>
                          )}
                        />
                        
                        <FormField
                          control={syncForm.control}
                          name="syncOnWifiOnly"
                          render={({ field }) => (
                            <SettingToggle
                              title="Wi-Fi Only"
                              description="Only sync when connected to Wi-Fi networks"
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              disabled={!syncForm.watch('autoSync')}
                              icon={field.value ? <Wifi className="h-4 w-4" /> : <WifiOff className="h-4 w-4" />}
                            />
                          )}
                        />
                      </div>
                    </FormSection>
                    
                    <div className="flex justify-end pt-4">
                      <Button 
                        type="submit"
                        disabled={isSaving}
                        className="bg-blue-500 hover:bg-blue-600 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 border-0"
                      >
                        {isSaving ? (
                          <>
                            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                            Saving...
                          </>
                        ) : (
                          <>
                            <Save className="h-4 w-4 mr-2" />
                            Save Changes
                          </>
                        )}
                      </Button>
                    </div>
                  </form>
                </Form>
              </CleanCard>
            </div>
          )}
        </div>
        
        {/* Bottom padding for mobile navigation */}
        <div className="h-24"></div>
      </div>
    </div>
  );
};

export default Settings;