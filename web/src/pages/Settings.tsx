import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useApp } from "@/contexts/AppContext";
import { 
  Card, 
  CardContent, 
  CardHeader, 
  CardTitle, 
  CardDescription,
  CardFooter
} from "@/components/ui/card";
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
import { PageWrapper } from "@/components/ui/page-wrapper";
import { PageHeader } from "@/components/ui/page-header";

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
    <PageWrapper withPadding={true}>
      {/* Header section with 8VC style formatting */}
      <div className="pt-16 pb-10">
        {/* Category label - Small all-caps category label */}
        <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
          CONFIGURATION
        </div>
        
        {/* Main title - following 8VC typography */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">Settings</h1>
            <p className="text-sm text-muted-foreground">Manage your account settings and preferences</p>
          </div>
        </div>
      </div>
      
      <Tabs defaultValue="profile" className="w-full">
        <TabsList className="grid grid-cols-5 mb-6 rounded-none bg-gray-50 dark:bg-white/5 h-10">
          <TabsTrigger value="profile" className="uppercase tracking-wider text-xs font-medium rounded-none flex items-center gap-2">
            <UserCircle className="h-4 w-4" />
            <span className="hidden sm:inline">PROFILE</span>
          </TabsTrigger>
          <TabsTrigger value="security" className="uppercase tracking-wider text-xs font-medium rounded-none flex items-center gap-2">
            <Shield className="h-4 w-4" />
            <span className="hidden sm:inline">SECURITY</span>
          </TabsTrigger>
          <TabsTrigger value="qr-codes" className="uppercase tracking-wider text-xs font-medium rounded-none flex items-center gap-2">
            <QrCode className="h-4 w-4" />
            <span className="hidden sm:inline">QR CODES</span>
          </TabsTrigger>
          <TabsTrigger value="notifications" className="uppercase tracking-wider text-xs font-medium rounded-none flex items-center gap-2">
            <Bell className="h-4 w-4" />
            <span className="hidden sm:inline">ALERTS</span>
          </TabsTrigger>
          <TabsTrigger value="sync" className="uppercase tracking-wider text-xs font-medium rounded-none flex items-center gap-2">
            <Cloud className="h-4 w-4" />
            <span className="hidden sm:inline">SYNC</span>
          </TabsTrigger>
        </TabsList>
        
        {/* Profile Settings */}
        <TabsContent value="profile">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
              <div className="p-4 flex justify-between items-baseline">
                <div>
                  <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                    PERSONAL INFORMATION
                  </div>
                  <div className="text-lg font-normal text-gray-900 dark:text-white">
                    User Details
                  </div>
                </div>
              </div>
              <CardContent className="p-4">
                <Form {...profileForm}>
                  <form onSubmit={profileForm.handleSubmit(onProfileSubmit)} className="space-y-4">
                    <FormField
                      control={profileForm.control}
                      name="name"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Full Name</FormLabel>
                          <FormControl>
                            <Input {...field} readOnly className="bg-gray-50 dark:bg-gray-800/50 border-gray-200 dark:border-white/10 rounded-none" />
                          </FormControl>
                          <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
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
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Rank</FormLabel>
                          <FormControl>
                            <Input {...field} readOnly className="bg-gray-50 dark:bg-gray-800/50 border-gray-200 dark:border-white/10 rounded-none" />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                    
                    <FormField
                      control={profileForm.control}
                      name="unit"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Unit</FormLabel>
                          <FormControl>
                            <Input {...field} readOnly className="bg-gray-50 dark:bg-gray-800/50 border-gray-200 dark:border-white/10 rounded-none" />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                    
                    <FormField
                      control={profileForm.control}
                      name="email"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Email</FormLabel>
                          <FormControl>
                            <Input {...field} className="border-gray-200 dark:border-white/10 rounded-none" />
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
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Phone</FormLabel>
                          <FormControl>
                            <Input {...field} className="border-gray-200 dark:border-white/10 rounded-none" />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    
                    <Button 
                      type="submit" 
                      className="rounded-none uppercase tracking-wider text-xs font-medium bg-primary hover:bg-primary-600 flex items-center gap-1"
                    >
                      <Save className="h-4 w-4" />
                      <span>SAVE CHANGES</span>
                    </Button>
                  </form>
                </Form>
              </CardContent>
            </Card>

            <div className="flex flex-col gap-6">
              <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
                <div className="p-4 flex justify-between items-baseline">
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                      DISPLAY
                    </div>
                    <div className="text-lg font-normal text-gray-900 dark:text-white">
                      Appearance Settings
                    </div>
                  </div>
                </div>
                <CardContent className="p-4 space-y-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">Theme</h4>
                      <p className="text-xs text-gray-500 dark:text-gray-400">Toggle between light and dark mode</p>
                    </div>
                    <Button 
                      variant="outline" 
                      size="icon" 
                      onClick={toggleTheme}
                      aria-label={theme === 'light' ? 'Switch to dark mode' : 'Switch to light mode'}
                      className="rounded-none border-gray-200 dark:border-white/10 h-8 w-8"
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
                      <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">Device ID</h4>
                      <p className="text-xs text-gray-500 dark:text-gray-400 font-mono">DVC-{user?.id || "000000"}</p>
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
                      className="flex items-center gap-1 rounded-none border-gray-200 dark:border-white/10 uppercase tracking-wider text-xs"
                    >
                      <RefreshCw className="h-3 w-3" />
                      <span>RESET</span>
                    </Button>
                  </div>
                </CardContent>
              </Card>

              <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
                <div className="p-4 flex justify-between items-baseline">
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                      ACCOUNT
                    </div>
                    <div className="text-lg font-normal text-gray-900 dark:text-white">
                      System Actions
                    </div>
                  </div>
                </div>
                <CardContent className="p-4 space-y-4">
                  <Button 
                    variant="outline" 
                    className="w-full flex items-center justify-center gap-1 rounded-none border-gray-200 dark:border-white/10 uppercase tracking-wider text-xs"
                    onClick={() => {
                      toast({
                        title: "Account Preferences Reset",
                        description: "Your settings have been restored to defaults",
                      });
                    }}
                  >
                    <SettingsIcon className="h-4 w-4" />
                    <span>RESET PREFERENCES</span>
                  </Button>
                </CardContent>
                <div className="p-4 border-t border-gray-200 dark:border-white/10">
                  <Button 
                    variant="destructive" 
                    className="w-full flex items-center justify-center gap-1 bg-red-600 hover:bg-red-700 rounded-none uppercase tracking-wider text-xs"
                    onClick={logout}
                  >
                    <LogOut className="h-4 w-4" />
                    <span>SIGN OUT</span>
                  </Button>
                </div>
              </Card>
            </div>
          </div>
        </TabsContent>
        
        {/* Security Settings */}
        <TabsContent value="security">
          <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
            <div className="p-4 flex justify-between items-baseline">
              <div>
                <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                  ACCESS CONTROL
                </div>
                <div className="text-lg font-normal text-gray-900 dark:text-white">
                  Security Settings
                </div>
              </div>
            </div>
            <CardContent className="p-4">
              <Form {...securityForm}>
                <form onSubmit={securityForm.handleSubmit(onSecuritySubmit)} className="space-y-6">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <FormField
                      control={securityForm.control}
                      name="requirePinForSensitive"
                      render={({ field }) => (
                        <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                          <div className="space-y-0.5">
                            <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">PIN for Sensitive Items</FormLabel>
                            <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                              Require PIN verification for sensitive item access
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              className="data-[state=checked]:bg-primary"
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                    
                    <FormField
                      control={securityForm.control}
                      name="showItemDetails"
                      render={({ field }) => (
                        <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                          <div className="space-y-0.5">
                            <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Show Item Details</FormLabel>
                            <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                              Display sensitive item details in listings
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              className="data-[state=checked]:bg-primary"
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                  </div>
                  
                  <div className="horizontal-divider"></div>
                  
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    TIMEOUT SETTINGS
                  </div>
                  
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <FormField
                      control={securityForm.control}
                      name="autoLogout"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Auto Logout (minutes)</FormLabel>
                          <Select
                            onValueChange={field.onChange}
                            defaultValue={field.value}
                          >
                            <FormControl>
                              <SelectTrigger className="rounded-none border-gray-200 dark:border-white/10">
                                <SelectValue placeholder="Select timeout" />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              <SelectItem value="5">5 minutes</SelectItem>
                              <SelectItem value="15">15 minutes</SelectItem>
                              <SelectItem value="30">30 minutes</SelectItem>
                              <SelectItem value="60">1 hour</SelectItem>
                              <SelectItem value="never">Never</SelectItem>
                            </SelectContent>
                          </Select>
                          <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                            Automatically log out after period of inactivity
                          </FormDescription>
                        </FormItem>
                      )}
                    />
                    
                    <FormField
                      control={securityForm.control}
                      name="pinTimeout"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">PIN Verification Timeout</FormLabel>
                          <Select
                            onValueChange={field.onChange}
                            defaultValue={field.value}
                          >
                            <FormControl>
                              <SelectTrigger className="rounded-none border-gray-200 dark:border-white/10">
                                <SelectValue placeholder="Select timeout" />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              <SelectItem value="1">1 minute</SelectItem>
                              <SelectItem value="5">5 minutes</SelectItem>
                              <SelectItem value="15">15 minutes</SelectItem>
                              <SelectItem value="30">30 minutes</SelectItem>
                              <SelectItem value="0">Every time</SelectItem>
                            </SelectContent>
                          </Select>
                          <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                            How often to require PIN re-entry for sensitive items
                          </FormDescription>
                        </FormItem>
                      )}
                    />
                  </div>
                  
                  <div className="horizontal-divider"></div>
                  
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    ADVANCED OPTIONS
                  </div>
                  
                  <Accordion type="single" collapsible className="w-full border-none">
                    <AccordionItem value="advanced" className="border-none">
                      <AccordionTrigger className="text-sm font-medium text-gray-700 dark:text-gray-300 py-2 hover:no-underline">
                        Advanced Security Options
                      </AccordionTrigger>
                      <AccordionContent>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
                          <div className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                            <div>
                              <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">Biometric Authentication</h4>
                              <p className="text-xs text-gray-500 dark:text-gray-400">Use fingerprint or face ID when available</p>
                            </div>
                            <Switch disabled className="data-[state=checked]:bg-primary" />
                          </div>
                          
                          <div className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                            <div>
                              <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">Secure Boot</h4>
                              <p className="text-xs text-gray-500 dark:text-gray-400">Verify app integrity on startup</p>
                            </div>
                            <Switch defaultChecked={true} className="data-[state=checked]:bg-primary" />
                          </div>
                        </div>
                        
                        <div className="pt-4">
                          <Button
                            variant="outline"
                            size="sm"
                            className="rounded-none border-gray-200 dark:border-white/10 text-xs uppercase tracking-wider"
                            onClick={() => {
                              toast({
                                title: "Security Log Cleared",
                                description: "Your login history has been cleared",
                              });
                            }}
                          >
                            Clear Security Log
                          </Button>
                        </div>
                      </AccordionContent>
                    </AccordionItem>
                  </Accordion>
                  
                  <div className="pt-4 flex justify-end">
                    <Button 
                      type="submit" 
                      className="rounded-none uppercase tracking-wider text-xs font-medium bg-primary hover:bg-primary-600 flex items-center gap-1"
                    >
                      <Shield className="h-4 w-4" />
                      <span>SAVE SECURITY SETTINGS</span>
                    </Button>
                  </div>
                </form>
              </Form>
            </CardContent>
          </Card>
        </TabsContent>
        
        {/* QR Code Settings */}
        <TabsContent value="qr-codes">
          <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
            <div className="p-4 flex justify-between items-baseline">
              <div>
                <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                  QR MANAGEMENT
                </div>
                <div className="text-lg font-normal text-gray-900 dark:text-white">
                  QR Code Settings
                </div>
              </div>
            </div>
            <CardContent className="p-4">
              <Form {...qrForm}>
                <form onSubmit={qrForm.handleSubmit(onQRSubmit)} className="space-y-6">
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    PRINT SETTINGS
                  </div>
                  
                  <FormField
                    control={qrForm.control}
                    name="defaultPrintSize"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Default QR Code Size</FormLabel>
                        <Select
                          onValueChange={field.onChange}
                          defaultValue={field.value}
                        >
                          <FormControl>
                            <SelectTrigger className="rounded-none border-gray-200 dark:border-white/10">
                              <SelectValue placeholder="Select size" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            <SelectItem value="small">Small (1.5" x 1.5")</SelectItem>
                            <SelectItem value="medium">Medium (2" x 2")</SelectItem>
                            <SelectItem value="large">Large (3" x 3")</SelectItem>
                            <SelectItem value="xlarge">Extra Large (4" x 4")</SelectItem>
                          </SelectContent>
                        </Select>
                        <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                          Standard size for printing QR codes
                        </FormDescription>
                      </FormItem>
                    )}
                  />
                  
                  <div className="horizontal-divider"></div>
                  
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    QR CODE CONTENT
                  </div>
                  
                  <FormField
                    control={qrForm.control}
                    name="autoRegenerate"
                    render={({ field }) => (
                      <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                        <div className="space-y-0.5">
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Auto-Regenerate Damaged QR Codes</FormLabel>
                          <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                            Automatically generate replacement QR codes when damage is reported
                          </FormDescription>
                        </div>
                        <FormControl>
                          <Switch
                            checked={field.value}
                            onCheckedChange={field.onChange}
                            className="data-[state=checked]:bg-primary"
                          />
                        </FormControl>
                      </FormItem>
                    )}
                  />
                  
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                    <FormField
                      control={qrForm.control}
                      name="includeName"
                      render={({ field }) => (
                        <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                          <div className="space-y-0.5">
                            <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Include Item Name</FormLabel>
                            <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                              Print item name on QR code label
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              className="data-[state=checked]:bg-primary"
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                    
                    <FormField
                      control={qrForm.control}
                      name="includeSerialNumber"
                      render={({ field }) => (
                        <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                          <div className="space-y-0.5">
                            <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Include Serial Number</FormLabel>
                            <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                              Print item name on QR code label
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              className="data-[state=checked]:bg-primary"
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                  </div>
                  
                  <FormField
                    control={qrForm.control}
                    name="scanConfirmation"
                    render={({ field }) => (
                      <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none mt-4">
                        <div className="space-y-0.5">
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Scan Confirmation</FormLabel>
                          <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                            Require confirmation after scanning before processing
                          </FormDescription>
                        </div>
                        <FormControl>
                          <Switch
                            checked={field.value}
                            onCheckedChange={field.onChange}
                            className="data-[state=checked]:bg-primary"
                          />
                        </FormControl>
                      </FormItem>
                    )}
                  />
                  
                  <div className="horizontal-divider"></div>
                  
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    SECURITY INFORMATION
                  </div>
                  
                  <div className="border border-gray-200 dark:border-white/10 p-4 rounded-none">
                    <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">QR Code Format</h3>
                    <p className="text-xs text-gray-500 dark:text-gray-400 mb-4">
                      HandReceipt uses a secure, blockchain-verified format for all QR codes
                    </p>
                    
                    <div className="grid grid-cols-2 gap-2 text-xs">
                      <div className="font-medium text-gray-700 dark:text-gray-300">Error Correction:</div>
                      <div className="text-gray-500 dark:text-gray-400">High (Level H)</div>
                      
                      <div className="font-medium text-gray-700 dark:text-gray-300">Encryption:</div>
                      <div className="text-gray-500 dark:text-gray-400">AES-256</div>
                      
                      <div className="font-medium text-gray-700 dark:text-gray-300">Verification:</div>
                      <div className="text-gray-500 dark:text-gray-400">SHA-256 hash</div>
                    </div>
                  </div>
                  
                  <div className="pt-4 flex justify-end">
                    <Button 
                      type="submit" 
                      className="rounded-none uppercase tracking-wider text-xs font-medium bg-primary hover:bg-primary-600 flex items-center gap-1"
                    >
                      <QrCode className="h-4 w-4" />
                      <span>SAVE QR SETTINGS</span>
                    </Button>
                  </div>
                </form>
              </Form>
            </CardContent>
          </Card>
        </TabsContent>
        
        {/* Notification Settings */}
        <TabsContent value="notifications">
          <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
            <div className="p-4 flex justify-between items-baseline">
              <div>
                <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                  ALERTS
                </div>
                <div className="text-lg font-normal text-gray-900 dark:text-white">
                  Notification Settings
                </div>
              </div>
            </div>
            <CardContent className="p-4">
              <Form {...notificationForm}>
                <form onSubmit={notificationForm.handleSubmit(onNotificationSubmit)} className="space-y-6">
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    NOTIFICATION CONTROLS
                  </div>
                
                  <FormField
                    control={notificationForm.control}
                    name="enableNotifications"
                    render={({ field }) => (
                      <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                        <div className="space-y-0.5">
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Enable Notifications</FormLabel>
                          <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                            Master toggle for all notification types
                          </FormDescription>
                        </div>
                        <FormControl>
                          <Switch
                            checked={field.value}
                            onCheckedChange={field.onChange}
                            className="data-[state=checked]:bg-primary"
                          />
                        </FormControl>
                      </FormItem>
                    )}
                  />
                  
                  <div className="horizontal-divider"></div>
                  
                  <div className={notificationForm.watch("enableNotifications") ? "" : "opacity-50 pointer-events-none"}>
                    <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                      NOTIFICATION TYPES
                    </div>
                    
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <FormField
                        control={notificationForm.control}
                        name="transferRequests"
                        render={({ field }) => (
                          <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Transfer Requests</FormLabel>
                              <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                                Notifications for incoming and outgoing transfers
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                                disabled={!notificationForm.watch("enableNotifications")}
                                className="data-[state=checked]:bg-primary"
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={notificationForm.control}
                        name="statusUpdates"
                        render={({ field }) => (
                          <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Status Updates</FormLabel>
                              <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                                Notifications for inventory status changes
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                                disabled={!notificationForm.watch("enableNotifications")}
                                className="data-[state=checked]:bg-primary"
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={notificationForm.control}
                        name="systemAlerts"
                        render={({ field }) => (
                          <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">System Alerts</FormLabel>
                              <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                                Notifications for sensitive item verifications
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                                disabled={!notificationForm.watch("enableNotifications")}
                                className="data-[state=checked]:bg-primary"
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                      
                      <FormField
                        control={notificationForm.control}
                        name="dailyDigest"
                        render={({ field }) => (
                          <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                            <div className="space-y-0.5">
                              <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Daily Digest</FormLabel>
                              <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                                Daily summary of all activity and pending actions
                              </FormDescription>
                            </div>
                            <FormControl>
                              <Switch
                                checked={field.value}
                                onCheckedChange={field.onChange}
                                disabled={!notificationForm.watch("enableNotifications")}
                                className="data-[state=checked]:bg-primary"
                              />
                            </FormControl>
                          </FormItem>
                        )}
                      />
                    </div>
                  </div>
                  
                  <div className="pt-4 flex justify-end">
                    <Button 
                      type="submit" 
                      className="rounded-none uppercase tracking-wider text-xs font-medium bg-primary hover:bg-primary-600 flex items-center gap-1"
                      disabled={!notificationForm.watch("enableNotifications")}
                    >
                      <Bell className="h-4 w-4" />
                      <span>SAVE NOTIFICATION SETTINGS</span>
                    </Button>
                  </div>
                </form>
              </Form>
            </CardContent>
          </Card>
        </TabsContent>
        
        {/* Sync Settings */}
        <TabsContent value="sync">
          <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
            <div className="p-4 flex justify-between items-baseline">
              <div>
                <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                  BLOCKCHAIN
                </div>
                <div className="text-lg font-normal text-gray-900 dark:text-white">
                  Data Synchronization
                </div>
              </div>
            </div>
            <CardContent className="p-4">
              <Form {...syncForm}>
                <form onSubmit={syncForm.handleSubmit(onSyncSubmit)} className="space-y-6">
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    SYNC STATUS
                  </div>
                
                  <div className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none bg-muted/5">
                    <div className="space-y-0.5">
                      <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300">Blockchain Status</h3>
                      <p className="text-xs text-gray-500 dark:text-gray-400">
                        Last synchronized: {formatLastSynced(syncForm.watch("lastSynced"))}
                      </p>
                    </div>
                    <Button 
                      variant="outline" 
                      size="sm" 
                      className="rounded-none border-gray-200 dark:border-white/10 text-xs uppercase tracking-wider flex items-center gap-1"
                      onClick={handleManualSync}
                      disabled={isSyncing}
                    >
                      {isSyncing ? (
                        <>
                          <Loader2 className="h-4 w-4 animate-spin" />
                          <span>SYNCING...</span>
                        </>
                      ) : (
                        <>
                          <Cloud className="h-4 w-4" />
                          <span>SYNC NOW</span>
                        </>
                      )}
                    </Button>
                  </div>
                  
                  <div className="horizontal-divider"></div>
                  
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    SYNC SETTINGS
                  </div>
                  
                  <FormField
                    control={syncForm.control}
                    name="autoSync"
                    render={({ field }) => (
                      <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                        <div className="space-y-0.5">
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Auto-Synchronization</FormLabel>
                          <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                            Automatically sync data with blockchain ledger
                          </FormDescription>
                        </div>
                        <FormControl>
                          <Switch
                            checked={field.value}
                            onCheckedChange={field.onChange}
                            className="data-[state=checked]:bg-primary"
                          />
                        </FormControl>
                      </FormItem>
                    )}
                  />
                  
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                    <FormField
                      control={syncForm.control}
                      name="syncInterval"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Sync Interval (minutes)</FormLabel>
                          <Select
                            onValueChange={field.onChange}
                            defaultValue={field.value}
                            disabled={!syncForm.watch("autoSync")}
                          >
                            <FormControl>
                              <SelectTrigger className="rounded-none border-gray-200 dark:border-white/10">
                                <SelectValue placeholder="Select interval" />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent>
                              <SelectItem value="5">5 minutes</SelectItem>
                              <SelectItem value="15">15 minutes</SelectItem>
                              <SelectItem value="30">30 minutes</SelectItem>
                              <SelectItem value="60">1 hour</SelectItem>
                              <SelectItem value="360">6 hours</SelectItem>
                            </SelectContent>
                          </Select>
                          <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                            How often to synchronize with the blockchain
                          </FormDescription>
                        </FormItem>
                      )}
                    />
                    
                    <FormField
                      control={syncForm.control}
                      name="syncOnWifiOnly"
                      render={({ field }) => (
                        <FormItem className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none h-full">
                          <div className="space-y-0.5">
                            <FormLabel className="text-sm font-medium text-gray-700 dark:text-gray-300">Sync on Wi-Fi Only</FormLabel>
                            <FormDescription className="text-xs text-gray-500 dark:text-gray-400">
                              Only perform automatic sync when connected to Wi-Fi
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                              disabled={!syncForm.watch("autoSync")}
                              className="data-[state=checked]:bg-primary"
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                  </div>
                  
                  <div className="horizontal-divider"></div>
                  
                  <div className="uppercase text-xs tracking-wider font-medium mb-4 text-gray-500 dark:text-gray-400">
                    ADVANCED OPTIONS
                  </div>
                
                  <Accordion type="single" collapsible className="w-full border-none">
                    <AccordionItem value="advanced" className="border-none">
                      <AccordionTrigger className="text-sm font-medium text-gray-700 dark:text-gray-300 py-2 hover:no-underline">
                        Advanced Sync Options
                      </AccordionTrigger>
                      <AccordionContent>
                        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
                          <div className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                            <div>
                              <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">Offline Mode</h4>
                              <p className="text-xs text-gray-500 dark:text-gray-400">Allow operation without blockchain connectivity</p>
                            </div>
                            <Switch defaultChecked={true} className="data-[state=checked]:bg-primary" />
                          </div>
                          
                          <div className="flex items-center justify-between border border-gray-200 dark:border-white/10 p-4 rounded-none">
                            <div>
                              <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300">Background Sync</h4>
                              <p className="text-xs text-gray-500 dark:text-gray-400">Sync when app is not in use</p>
                            </div>
                            <Switch defaultChecked={false} className="data-[state=checked]:bg-primary" />
                          </div>
                        </div>
                        
                        <div className="pt-4">
                          <Button
                            variant="outline"
                            size="sm"
                            className="rounded-none border-gray-200 dark:border-white/10 text-xs uppercase tracking-wider"
                            onClick={() => {
                              toast({
                                title: "Sync Cache Cleared",
                                description: "Your local cache has been cleared",
                              });
                            }}
                          >
                            Clear Sync Cache
                          </Button>
                        </div>
                      </AccordionContent>
                    </AccordionItem>
                  </Accordion>
                  
                  <div className="pt-4 flex justify-end">
                    <Button 
                      type="submit" 
                      className="rounded-none uppercase tracking-wider text-xs font-medium bg-primary hover:bg-primary-600 flex items-center gap-1"
                    >
                      <Database className="h-4 w-4" />
                      <span>SAVE SYNC SETTINGS</span>
                    </Button>
                  </div>
                </form>
              </Form>
            </CardContent>
          </Card>
          
          <Card className="mt-6 overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
            <div className="p-4 flex justify-between items-baseline">
              <div>
                <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                  ANALYTICS
                </div>
                <div className="text-lg font-normal text-gray-900 dark:text-white">
                  Performance Metrics
                </div>
              </div>
            </div>
            <CardContent className="p-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 border border-gray-200 dark:border-white/10 rounded-none">
                  <div className="flex items-center gap-2 mb-2">
                    <Activity className="h-4 w-4 text-primary" />
                    <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300">System Performance</h3>
                  </div>
                  <p className="text-2xl font-light text-gray-900 dark:text-white">98.7%</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Uptime last 30 days</p>
                </div>
                
                <div className="p-4 border border-gray-200 dark:border-white/10 rounded-none">
                  <div className="flex items-center gap-2 mb-2">
                    <Zap className="h-4 w-4 text-primary" />
                    <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300">Sync Speed</h3>
                  </div>
                  <p className="text-2xl font-light text-gray-900 dark:text-white">1.2s</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">Average sync time</p>
                </div>
                
                <div className="p-4 border border-gray-200 dark:border-white/10 rounded-none">
                  <div className="flex items-center gap-2 mb-2">
                    <Clock className="h-4 w-4 text-primary" />
                    <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300">Last Full Sync</h3>
                  </div>
                  <p className="text-2xl font-light text-gray-900 dark:text-white">36m</p>
                  <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">36 minutes ago</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </PageWrapper>
  );
};

export default Settings;
