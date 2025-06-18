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
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Separator } from "@/components/ui/separator";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { useToast } from "@/hooks/use-toast";
import { 
  Save, 
  LogOut, 
  Moon, 
  Sun, 
  RefreshCw, 
  Shield, 
  Bell, 
  QrCode, 
  Database, 
  Smartphone, 
  UserCircle, 
  Settings as SettingsIcon,
  Zap,
  Activity,
  Clock,
  Cloud,
  Loader2
} from "lucide-react";

// iOS Components
import { 
  CleanCard, 
  ElegantSectionHeader
} from "@/components/ios";

// Form schema for profile
const profileFormSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  email: z.string().email("Please enter a valid email address"),
  phone: z.string().min(10, "Please enter a valid phone number"),
  rank: z.string().optional(),
  unit: z.string().optional(),
});

// Form schema for security settings
const securityFormSchema = z.object({
  requirePinForSensitive: z.boolean().default(true),
  showItemDetails: z.boolean().default(true),
  autoLogout: z.string().default("30"),
  pinTimeout: z.string().default("5"),
});

// Form schema for QR settings
const qrFormSchema = z.object({
  defaultPrintSize: z.string().default("medium"),
  autoRegenerate: z.boolean().default(false),
  includeName: z.boolean().default(true),
  includeSerialNumber: z.boolean().default(true),
  scanConfirmation: z.boolean().default(true),
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
type ProfileFormValues = z.infer<typeof profileFormSchema>;
type SecurityFormValues = z.infer<typeof securityFormSchema>;
type QRFormValues = z.infer<typeof qrFormSchema>;
type NotificationFormValues = z.infer<typeof notificationFormSchema>;
type SyncFormValues = z.infer<typeof syncFormSchema>;

const Settings: React.FC = () => {
  const { user, logout } = useAuth();
  const { theme, toggleTheme } = useApp();
  const { toast } = useToast();
  const [isSyncing, setIsSyncing] = useState<boolean>(false);
  
  // Profile form
  const profileForm = useForm<ProfileFormValues>({
    resolver: zodResolver(profileFormSchema),
    defaultValues: {
      name: user?.name || "",
      email: "john.doe@military.gov",
      phone: "555-123-4567",
      rank: user?.rank || "",
      unit: "",
    },
  });

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

  // QR settings form
  const qrForm = useForm<QRFormValues>({
    resolver: zodResolver(qrFormSchema),
    defaultValues: {
      defaultPrintSize: "medium",
      autoRegenerate: false,
      includeName: true,
      includeSerialNumber: true,
      scanConfirmation: true,
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
  const onProfileSubmit = (data: ProfileFormValues) => {
    toast({
      title: "Profile Updated",
      description: "Your profile information has been updated",
    });
  };

  const onSecuritySubmit = (data: SecurityFormValues) => {
    toast({
      title: "Security Settings Updated",
      description: "Your security preferences have been saved",
    });
  };

  const onQRSubmit = (data: QRFormValues) => {
    toast({
      title: "QR Code Settings Updated",
      description: "Your QR code preferences have been saved",
    });
  };

  const onNotificationSubmit = (data: NotificationFormValues) => {
    toast({
      title: "Notification Settings Updated",
      description: "Your notification preferences have been saved",
    });
  };

  const onSyncSubmit = (data: SyncFormValues) => {
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
      return date.toLocaleString();
    } catch (e) {
      return "Unknown";
    }
  };

  return (
    <div className="min-h-screen bg-app-background">
      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Header */}
        <div className="mb-8">
          <ElegantSectionHeader 
            title="CONFIGURATION" 
            className="mb-4"
          />
          
          <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
            <div>
              <h1 className="text-3xl font-light tracking-tight text-primary-text">
                Account Settings
              </h1>
              <p className="text-secondary-text mt-1">
                Manage your account settings and preferences
              </p>
            </div>
          </div>
        </div>
        
        <CleanCard padding="none" className="mb-6">
          <Tabs defaultValue="profile" className="w-full">
            <div className="border-b border-ios-border">
              <TabsList className="grid grid-cols-5 w-full bg-transparent">
                <TabsTrigger 
                  value="profile" 
                  className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none flex items-center gap-2"
                >
                  <UserCircle className="h-4 w-4" />
                  <span className="hidden sm:inline">PROFILE</span>
                </TabsTrigger>
                <TabsTrigger 
                  value="security" 
                  className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none flex items-center gap-2"
                >
                  <Shield className="h-4 w-4" />
                  <span className="hidden sm:inline">SECURITY</span>
                </TabsTrigger>
                <TabsTrigger 
                  value="qr-codes" 
                  className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none flex items-center gap-2"
                >
                  <QrCode className="h-4 w-4" />
                  <span className="hidden sm:inline">QR CODES</span>
                </TabsTrigger>
                <TabsTrigger 
                  value="notifications" 
                  className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none flex items-center gap-2"
                >
                  <Bell className="h-4 w-4" />
                  <span className="hidden sm:inline">ALERTS</span>
                </TabsTrigger>
                <TabsTrigger 
                  value="sync" 
                  className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none flex items-center gap-2"
                >
                  <Cloud className="h-4 w-4" />
                  <span className="hidden sm:inline">SYNC</span>
                </TabsTrigger>
              </TabsList>
            </div>
            
            {/* Profile Settings */}
            <TabsContent value="profile" className="p-6">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <CleanCard>
                  <div className="mb-6">
                    <ElegantSectionHeader title="PERSONAL INFORMATION" size="sm" />
                    <p className="text-secondary-text mt-1">User Details</p>
                  </div>
                  
                  <Form {...profileForm}>
                    <form onSubmit={profileForm.handleSubmit(onProfileSubmit)} className="space-y-6">
                      <FormField
                        control={profileForm.control}
                        name="name"
                        render={({ field }) => (
                          <FormItem>
                            <FormLabel className="text-tertiary-text text-xs uppercase tracking-wide font-medium">Full Name</FormLabel>
                            <FormControl>
                              <Input 
                                {...field} 
                                readOnly 
                                className="border-0 border-b border-ios-border rounded-none px-0 py-2 text-base text-primary-text bg-transparent focus:border-primary-text focus:border-b-2 transition-all duration-200 focus-visible:ring-0 focus-visible:ring-offset-0 bg-gray-50"
                              />
                            </FormControl>
                            <FormDescription className="text-xs text-quaternary-text">
                              Contact admin to update name
                            </FormDescription>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={profileForm.control}
                        name="rank"
                        render={({ field }) => (
                          <FormItem>
                            <FormLabel className="text-tertiary-text text-xs uppercase tracking-wide font-medium">Rank</FormLabel>
                            <FormControl>
                              <Input 
                                {...field} 
                                readOnly 
                                className="border-0 border-b border-ios-border rounded-none px-0 py-2 text-base text-primary-text bg-transparent focus:border-primary-text focus:border-b-2 transition-all duration-200 focus-visible:ring-0 focus-visible:ring-offset-0 bg-gray-50"
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={profileForm.control}
                        name="unit"
                        render={({ field }) => (
                          <FormItem>
                            <FormLabel className="text-tertiary-text text-xs uppercase tracking-wide font-medium">Unit</FormLabel>
                            <FormControl>
                              <Input 
                                {...field} 
                                readOnly 
                                className="border-0 border-b border-ios-border rounded-none px-0 py-2 text-base text-primary-text bg-transparent focus:border-primary-text focus:border-b-2 transition-all duration-200 focus-visible:ring-0 focus-visible:ring-offset-0 bg-gray-50"
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={profileForm.control}
                        name="email"
                        render={({ field }) => (
                          <FormItem>
                            <FormLabel className="text-tertiary-text text-xs uppercase tracking-wide font-medium">Email</FormLabel>
                            <FormControl>
                              <Input 
                                {...field} 
                                className="border-0 border-b border-ios-border rounded-none px-0 py-2 text-base text-primary-text placeholder:text-quaternary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                              />
                            </FormControl>
                            <FormMessage />
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={profileForm.control}
                        name="phone"
                        render={({ field }) => (
                          <FormItem>
                            <FormLabel className="text-tertiary-text text-xs uppercase tracking-wide font-medium">Phone</FormLabel>
                            <FormControl>
                              <Input 
                                {...field} 
                                className="border-0 border-b border-ios-border rounded-none px-0 py-2 text-base text-primary-text placeholder:text-quaternary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                              />
                            </FormControl>
                            <FormMessage />
                          </FormItem>
                        )}
                      />
                      
                      <Button 
                        type="submit" 
                        className="bg-primary-text hover:bg-black/90 text-white font-medium px-6 py-3 rounded-none w-full flex items-center justify-center gap-2"
                      >
                        <Save className="h-4 w-4" />
                        Save Changes
                      </Button>
                    </form>
                  </Form>
                </CleanCard>

                <div className="flex flex-col gap-6">
                  <CleanCard>
                    <div className="mb-6">
                      <ElegantSectionHeader title="DISPLAY" size="sm" />
                      <p className="text-secondary-text mt-1">Appearance Settings</p>
                    </div>
                    
                    <div className="space-y-6">
                      <div className="flex items-center justify-between">
                        <div>
                          <h4 className="text-sm font-medium text-primary-text">Theme</h4>
                          <p className="text-xs text-secondary-text">Toggle between light and dark mode</p>
                        </div>
                        <Button 
                          variant="outline" 
                          size="icon" 
                          onClick={toggleTheme}
                          aria-label={theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode'}
                          className="rounded-none border-ios-border h-8 w-8"
                        >
                          {theme === 'light' ? (
                            <Moon className="h-4 w-4" />
                          ) : (
                            <Sun className="h-4 w-4" />
                          )}
                        </Button>
                      </div>
                      
                      <div className="flex items-center justify-between">
                        <div>
                          <h4 className="text-sm font-medium text-primary-text">Device ID</h4>
                          <p className="text-xs text-secondary-text font-mono">DVC-{user?.id || "000000"}</p>
                        </div>
                        <Button 
                          variant="outline" 
                          size="sm" 
                          onClick={() => {
                            toast({
                              title: "Device Reset",
                              description: "Device ID has been regenerated",
                            });
                          }}
                          className="flex items-center gap-1 rounded-none border-ios-border text-xs"
                        >
                          <RefreshCw className="h-3 w-3" />
                          Reset
                        </Button>
                      </div>
                    </div>
                  </CleanCard>

                  <CleanCard>
                    <div className="mb-6">
                      <ElegantSectionHeader title="ACCOUNT" size="sm" />
                      <p className="text-secondary-text mt-1">System Actions</p>
                    </div>
                    
                    <div className="space-y-4">
                      <Button 
                        variant="outline" 
                        className="w-full flex items-center justify-center gap-2 rounded-none border-ios-border text-primary-text hover:bg-gray-50"
                        onClick={() => {
                          toast({
                            title: "Account Preferences Reset",
                            description: "Your settings have been restored to defaults",
                          });
                        }}
                      >
                        <SettingsIcon className="h-4 w-4" />
                        Reset Preferences
                      </Button>
                      
                      <div className="pt-4 border-t border-ios-border">
                        <Button 
                          variant="destructive" 
                          className="w-full flex items-center justify-center gap-2 bg-ios-destructive hover:bg-destructive-dim rounded-none"
                          onClick={logout}
                        >
                          <LogOut className="h-4 w-4" />
                          Sign Out
                        </Button>
                      </div>
                    </div>
                  </CleanCard>
                </div>
              </div>
            </TabsContent>
            
            {/* Security Settings - keeping existing structure but with CleanCard */}
            <TabsContent value="security" className="p-6">
              <CleanCard>
                <div className="mb-6">
                  <ElegantSectionHeader title="ACCESS CONTROL" size="sm" />
                  <p className="text-secondary-text mt-1">Security Settings</p>
                </div>
                
                <Form {...securityForm}>
                  <form onSubmit={securityForm.handleSubmit(onSecuritySubmit)} className="space-y-6">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <FormField
                        control={securityForm.control}
                        name="requirePinForSensitive"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Require PIN for Sensitive Items
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Additional security for classified equipment
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={securityForm.control}
                        name="showItemDetails"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Show Item Details
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Display technical specifications in lists
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                    </div>
                    
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                      <FormField
                        control={securityForm.control}
                        name="autoLogout"
                        render={({ field }) => (
                          <FormItem>
                            <FormLabel className="text-tertiary-text text-xs uppercase tracking-wide font-medium">Auto Logout (minutes)</FormLabel>
                            <Select onValueChange={field.onChange} defaultValue={field.value}>
                              <FormControl>
                                <SelectTrigger className="border-0 border-b border-ios-border rounded-none px-0 py-2 text-base text-primary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus:ring-0 focus:ring-offset-0 h-auto">
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
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={securityForm.control}
                        name="pinTimeout"
                        render={({ field }) => (
                          <FormItem>
                            <FormLabel className="text-tertiary-text text-xs uppercase tracking-wide font-medium">PIN Timeout (minutes)</FormLabel>
                            <Select onValueChange={field.onChange} defaultValue={field.value}>
                              <FormControl>
                                <SelectTrigger className="border-0 border-b border-ios-border rounded-none px-0 py-2 text-base text-primary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus:ring-0 focus:ring-offset-0 h-auto">
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
                          </FormItem>
                        )}
                      />
                    </div>
                    
                    <Button 
                      type="submit" 
                      className="bg-primary-text hover:bg-black/90 text-white font-medium px-6 py-3 rounded-none flex items-center gap-2"
                    >
                      <Save className="h-4 w-4" />
                      Save Security Settings
                    </Button>
                  </form>
                </Form>
              </CleanCard>
            </TabsContent>
            
            {/* Additional tabs can be implemented similarly - keeping existing functionality but with iOS styling */}
            <TabsContent value="qr-codes" className="p-6">
              <CleanCard>
                <div className="mb-6">
                  <ElegantSectionHeader title="QR CODE CONFIGURATION" size="sm" />
                  <p className="text-secondary-text mt-1">QR Code generation and scanning preferences</p>
                </div>
                
                <Form {...qrForm}>
                  <form onSubmit={qrForm.handleSubmit(onQRSubmit)} className="space-y-6">
                    <FormField
                      control={qrForm.control}
                      name="defaultPrintSize"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-tertiary-text text-xs uppercase tracking-wide font-medium">Default Print Size</FormLabel>
                          <Select onValueChange={field.onChange} defaultValue={field.value}>
                            <FormControl>
                              <SelectTrigger className="border-0 border-b border-ios-border rounded-none px-0 py-2 text-base text-primary-text focus:border-primary-text focus:border-b-2 transition-all duration-200 bg-transparent focus:ring-0 focus:ring-offset-0 h-auto">
                                <SelectValue placeholder="Select size" />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              <SelectItem value="small">Small (1" × 1")</SelectItem>
                              <SelectItem value="medium">Medium (2" × 2")</SelectItem>
                              <SelectItem value="large">Large (3" × 3")</SelectItem>
                            </SelectContent>
                          </Select>
                        </FormItem>
                      )}
                    />
                    
                    <div className="space-y-4">
                      <FormField
                        control={qrForm.control}
                        name="autoRegenerate"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Auto-regenerate QR codes
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Automatically create new codes after transfers
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={qrForm.control}
                        name="includeName"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Include item name
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Display item name on QR label
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={qrForm.control}
                        name="includeSerialNumber"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Include serial number
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Display serial number on QR label
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={qrForm.control}
                        name="scanConfirmation"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Require scan confirmation
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Show confirmation dialog after scanning
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                    </div>
                    
                    <Button 
                      type="submit" 
                      className="bg-primary-text hover:bg-black/90 text-white font-medium px-6 py-3 rounded-none flex items-center gap-2"
                    >
                      <Save className="h-4 w-4" />
                      Save QR Settings
                    </Button>
                  </form>
                </Form>
              </CleanCard>
            </TabsContent>
            
            <TabsContent value="notifications" className="p-6">
              <CleanCard>
                <div className="mb-6">
                  <ElegantSectionHeader title="NOTIFICATION PREFERENCES" size="sm" />
                  <p className="text-secondary-text mt-1">Manage alerts and notifications</p>
                </div>
                
                <Form {...notificationForm}>
                  <form onSubmit={notificationForm.handleSubmit(onNotificationSubmit)} className="space-y-6">
                    <FormField
                      control={notificationForm.control}
                      name="enableNotifications"
                      render={({ field }) => (
                        <FormItem className="flex flex-row items-center justify-between space-y-0">
                          <div className="space-y-0.5">
                            <FormLabel className="text-sm font-medium text-primary-text">
                              Enable notifications
                            </FormLabel>
                            <FormDescription className="text-xs text-secondary-text">
                              Receive alerts for important events
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                    
                    <div className="h-px bg-ios-divider" />
                    
                    <div className="space-y-4">
                      <h4 className="text-xs uppercase tracking-wide text-tertiary-text font-medium">
                        NOTIFICATION TYPES
                      </h4>
                      
                      <FormField
                        control={notificationForm.control}
                        name="transferRequests"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Transfer requests
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                New incoming and outgoing transfers
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                                disabled={!notificationForm.watch('enableNotifications')}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={notificationForm.control}
                        name="statusUpdates"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Status updates
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Equipment status changes
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                                disabled={!notificationForm.watch('enableNotifications')}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={notificationForm.control}
                        name="systemAlerts"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                System alerts
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Important system messages
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                                disabled={!notificationForm.watch('enableNotifications')}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={notificationForm.control}
                        name="dailyDigest"
                        render={({ field }) => (
                          <FormItem className="flex flex-row items-center justify-between space-y-0">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-primary-text">
                                Daily digest
                              </FormLabel>
                              <FormDescription className="text-xs text-secondary-text">
                                Summary email sent daily at 0600
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                                disabled={!notificationForm.watch('enableNotifications')}
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                    </div>
                    
                    <Button 
                      type="submit" 
                      className="bg-primary-text hover:bg-black/90 text-white font-medium px-6 py-3 rounded-none flex items-center gap-2"
                    >
                      <Save className="h-4 w-4" />
                      Save Notification Settings
                    </Button>
                  </form>
                </Form>
              </CleanCard>
            </TabsContent>
            
            <TabsContent value="sync" className="p-6">
              <CleanCard>
                <div className="mb-6">
                  <ElegantSectionHeader title="SYNCHRONIZATION" size="sm" />
                  <p className="text-secondary-text mt-1">Data synchronization preferences</p>
                </div>
                
                <div className="space-y-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-sm font-medium text-primary-text">Manual Sync</h4>
                      <p className="text-xs text-secondary-text">Synchronize your data now</p>
                    </div>
                    <Button 
                      onClick={handleManualSync}
                      disabled={isSyncing}
                      className="bg-ios-accent hover:bg-accent-hover text-white rounded-none flex items-center gap-2"
                    >
                      {isSyncing ? (
                        <Loader2 className="h-4 w-4 animate-spin" />
                      ) : (
                        <RefreshCw className="h-4 w-4" />
                      )}
                      {isSyncing ? 'Syncing...' : 'Sync Now'}
                    </Button>
                  </div>
                  
                  <div className="text-xs text-secondary-text">
                    Last synced: {formatLastSynced(syncForm.watch('lastSynced'))}
                  </div>
                </div>
              </CleanCard>
            </TabsContent>
          </Tabs>
        </CleanCard>
      </div>
    </div>
  );
};

export default Settings;
