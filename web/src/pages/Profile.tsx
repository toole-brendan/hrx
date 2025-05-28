import React from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { Card, CardContent, CardHeader, CardTitle, CardDescription, CardFooter } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Progress } from '@/components/ui/progress';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { 
  Shield, 
  Calendar, 
  Tag, 
  Award, 
  Truck, 
  Radio, 
  Eye, 
  AlertTriangle, 
  Star, 
  FileText, 
  ChevronRight, 
  Fingerprint, 
  UserCheck,
  Clock,
  BarChart3,
  ArrowRight
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { PageWrapper } from '@/components/ui/page-wrapper';
import { StandardPageLayout } from '@/components/layout/StandardPageLayout';

export default function Profile() {
  const { user } = useAuth();

  if (!user) {
    return (
      <PageWrapper withPadding={true}>
        <div className="pt-16 pb-10">
          <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
            PROFILE
          </div>
          <h1 className="text-3xl font-light tracking-tight mb-1">Personnel Profile</h1>
        </div>
        <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
          <CardContent className="pt-6">
            <p>Please log in to view your profile.</p>
          </CardContent>
        </Card>
      </PageWrapper>
    );
  }

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(part => part[0])
      .join('')
      .toUpperCase();
  };

  // Profile actions
  const actions = (
    <div className="flex items-center gap-2">
      <Button 
        size="sm" 
        variant="default"
        className="flex items-center gap-1 uppercase tracking-wider text-xs"
      >
        <FileText className="h-4 w-4" />
        <span className="hidden sm:inline">Export Data</span>
      </Button>
      
      <Button 
        size="sm" 
        variant="default"
        className="flex items-center gap-1 uppercase tracking-wider text-xs"
      >
        <UserCheck className="h-4 w-4" />
        <span className="hidden sm:inline">Update Profile</span>
      </Button>
    </div>
  );

  return (
    <PageWrapper withPadding={true}>
      {/* Header section with 8VC style formatting */}
      <div className="pt-16 pb-10">
        {/* Category label - Small all-caps category label */}
        <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
          PERSONNEL
        </div>
        
        {/* Main title - following 8VC typography */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">{user.name}</h1>
            <p className="text-sm text-muted-foreground">{user.position} – {user.unit}</p>
          </div>
          {actions}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Profile Card */}
        <Card className="md:col-span-1 overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
          <div className="p-4">
            <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
              PERSONNEL INFORMATION
            </div>
            <div className="text-lg font-normal text-gray-900 dark:text-white flex items-center justify-between">
              <span>Service Record</span>
              <Badge variant="outline" className="bg-green-50 text-green-800 dark:bg-green-900/20 dark:text-green-400 border-green-200 dark:border-green-900/30 uppercase text-[10px] tracking-wider font-medium rounded-none">
                {user.rank}
              </Badge>
            </div>
          </div>
          <CardContent className="p-4 pt-0">
            <div className="flex flex-col items-center space-y-4 pt-4">
              <Avatar className="h-24 w-24">
                <AvatarImage src="" alt={user.name} />
                <AvatarFallback className="text-2xl bg-primary text-white">{getInitials(user.name)}</AvatarFallback>
              </Avatar>
              <div className="text-center">
                <h3 className="text-xl font-medium">{user.name}</h3>
                <p className="text-sm text-muted-foreground">{user.position}</p>
                <p className="text-xs text-muted-foreground">{user.unit}</p>
              </div>
              
              <Separator className="bg-gray-100 dark:bg-white/10" />
              
              <div className="w-full space-y-3">
                <div className="flex justify-between items-center">
                  <span className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400 flex items-center gap-2">
                    <Shield className="h-4 w-4" /> Years of Service
                  </span>
                  <span className="font-normal">{user.yearsOfService} years</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400 flex items-center gap-2">
                    <Calendar className="h-4 w-4" /> Command Time
                  </span>
                  <span className="font-normal">{user.commandTime}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400 flex items-center gap-2">
                    <Tag className="h-4 w-4" /> ID Number
                  </span>
                  <span className="font-normal font-mono">{user.id}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400 flex items-center gap-2">
                    <Award className="h-4 w-4" /> Responsibility
                  </span>
                  <span className="font-normal">Hand Receipt Holder</span>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Main Content Area */}
        <div className="md:col-span-2 space-y-6">
          {/* Property Overview */}
          <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
            <div className="p-4">
              <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                PROPERTY MANAGEMENT
              </div>
              <div className="text-lg font-normal text-gray-900 dark:text-white flex items-center justify-between">
                <span>Equipment Overview</span>
                <span className="text-xs text-muted-foreground">Value: {user.valueManaged}</span>
              </div>
            </div>
            <CardContent className="p-0">
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-px bg-gray-100 dark:bg-white/5">
                <PropertyCard 
                  icon={<Truck className="h-5 w-5 text-blue-500" />}
                  title="Vehicles"
                  count={user.equipmentSummary?.vehicles || 0}
                />
                <PropertyCard 
                  icon={<Shield className="h-5 w-5 text-red-500" />}
                  title="Weapons"
                  count={user.equipmentSummary?.weapons || 0}
                />
                <PropertyCard 
                  icon={<Radio className="h-5 w-5 text-green-500" />}
                  title="Comms"
                  count={user.equipmentSummary?.communications || 0}
                />
                <PropertyCard 
                  icon={<Eye className="h-5 w-5 text-purple-500" />}
                  title="Optics"
                  count={user.equipmentSummary?.opticalSystems || 0}
                />
              </div>
              
              <div className="p-4 border-t border-gray-100 dark:border-white/10">
                <div className="flex justify-between mb-2 items-center">
                  <div className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400 flex items-center gap-2">
                    <Fingerprint className="h-4 w-4 text-amber-500" /> 
                    Sensitive Items Accountability
                  </div>
                  <span className="text-sm">{user.equipmentSummary?.sensitiveItems || 0} items</span>
                </div>
                <Progress value={100} className="h-2" />
                <div className="flex items-center justify-between mt-1">
                  <p className="text-xs text-muted-foreground flex items-center gap-1">
                    <Clock className="h-3 w-3" />
                    Last inventory: 6 hours ago
                  </p>
                  <Badge variant="outline" className="bg-green-50 text-green-800 dark:bg-green-900/20 dark:text-green-400 border-green-200 dark:border-green-900/30 uppercase text-[10px] tracking-wider font-medium rounded-none">
                    100% Verified
                  </Badge>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Tabs Section */}
          <Card className="overflow-hidden border-gray-200 dark:border-white/10 shadow-none bg-white dark:bg-black">
            <div className="p-4">
              <div className="uppercase text-xs tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">
                ACCOUNTABILITY
              </div>
              <div className="text-lg font-normal text-gray-900 dark:text-white">
                Calendar & Performance
              </div>
            </div>
            <CardContent className="p-0">
              <Tabs defaultValue="upcoming" className="w-full">
                <TabsList className="grid grid-cols-2 w-full rounded-none bg-gray-50 dark:bg-white/5 h-8">
                  <TabsTrigger value="upcoming" className="uppercase tracking-wider text-[10px] font-medium">UPCOMING EVENTS</TabsTrigger>
                  <TabsTrigger value="career" className="uppercase tracking-wider text-[10px] font-medium">CAREER METRICS</TabsTrigger>
                </TabsList>
                
                <div className="p-4">
                  <TabsContent value="upcoming" className="m-0">
                    <ul className="space-y-4">
                      {user.upcomingEvents?.map((event, i) => (
                        <li key={i} className="flex items-start space-x-3 pb-3 border-b border-gray-100 dark:border-white/5 last:border-0 last:pb-0">
                          <Star className="h-5 w-5 text-amber-500 mt-0.5" />
                          <div>
                            <p className="font-medium">{event.title}</p>
                            <p className="text-xs text-muted-foreground mt-0.5">Timeline: {event.date}</p>
                          </div>
                        </li>
                      ))}
                      <li className="flex items-start space-x-3 pb-3 border-b border-gray-100 dark:border-white/5 last:border-0 last:pb-0">
                        <FileText className="h-5 w-5 text-blue-500 mt-0.5" />
                        <div>
                          <p className="font-medium">Monthly Sensitive Items Inventory</p>
                          <p className="text-xs text-muted-foreground mt-0.5">Due: 15 days</p>
                        </div>
                      </li>
                      <li className="flex items-start space-x-3 pb-3 border-b border-gray-100 dark:border-white/5 last:border-0 last:pb-0">
                        <Calendar className="h-5 w-5 text-indigo-500 mt-0.5" />
                        <div>
                          <p className="font-medium">Quarterly Hand Receipt Reconciliation</p>
                          <p className="text-xs text-muted-foreground mt-0.5">Due: 37 days</p>
                        </div>
                      </li>
                    </ul>
                  </TabsContent>
                  
                  <TabsContent value="career" className="m-0">
                    <div className="space-y-4">
                      <div>
                        <div className="flex justify-between mb-1 items-center">
                          <span className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400">Property Accountability</span>
                          <span className="text-sm">98%</span>
                        </div>
                        <Progress value={98} className="h-2" />
                      </div>
                      <div>
                        <div className="flex justify-between mb-1 items-center">
                          <span className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400">Transfer Completion Rate</span>
                          <span className="text-sm">94%</span>
                        </div>
                        <Progress value={94} className="h-2" />
                      </div>
                      <div>
                        <div className="flex justify-between mb-1 items-center">
                          <span className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400">Supply Requisition Efficiency</span>
                          <span className="text-sm">87%</span>
                        </div>
                        <Progress value={87} className="h-2" />
                      </div>
                      
                      <Separator className="my-4 bg-gray-100 dark:bg-white/10" />
                      
                      <div className="grid grid-cols-2 gap-px bg-gray-100 dark:bg-white/5">
                        <div className="p-4 bg-white dark:bg-black">
                          <h4 className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">TRANSFERS COMPLETED</h4>
                          <div className="flex items-center justify-between">
                            <p className="text-2xl font-light tracking-tight">287</p>
                            <BarChart3 className="h-4 w-4 text-primary" />
                          </div>
                        </div>
                        <div className="p-4 bg-white dark:bg-black">
                          <h4 className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">EQUIPMENT STATUS</h4>
                          <div className="flex items-center justify-between">
                            <p className="text-2xl font-light tracking-tight">93%</p>
                            <BarChart3 className="h-4 w-4 text-primary" />
                          </div>
                        </div>
                      </div>
                    </div>
                  </TabsContent>
                </div>
              </Tabs>
            </CardContent>
            <div className="px-4 py-2 border-t border-gray-100 dark:border-white/5 flex justify-end">
              <Button 
                variant="ghost" 
                className="text-xs uppercase tracking-wider text-purple-600 dark:text-purple-400 hover:bg-transparent hover:text-purple-800 dark:hover:text-purple-300"
                onClick={() => {}}
              >
                VIEW FULL HISTORY
                <ArrowRight className="h-3 w-3 ml-1" />
              </Button>
            </div>
          </Card>
        </div>
      </div>
    </PageWrapper>
  );
}

// Helper component for property cards
function PropertyCard({ 
  icon, 
  title, 
  count
}: { 
  icon: React.ReactNode; 
  title: string; 
  count: number;
}) {
  return (
    <div className="p-4 bg-white dark:bg-black">
      <h4 className="text-xs uppercase tracking-wider font-medium text-gray-500 dark:text-gray-400 mb-1">{title}</h4>
      <div className="flex items-center justify-between">
        <p className="text-2xl font-light tracking-tight">{count}</p>
        {icon}
      </div>
    </div>
  );
}