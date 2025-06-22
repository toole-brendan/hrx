import React, { useState, useMemo, useEffect, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getConnections, searchUsers, sendConnectionRequest, updateConnectionStatus, exportConnections } from '@/services/connectionService';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useToast } from '@/hooks/use-toast';
import { useAuth } from '@/contexts/AuthContext';
import { 
  Search, 
  UserPlus, 
  Users, 
  Clock, 
  CheckCircle, 
  XCircle, 
  Globe, 
  Filter, 
  ArrowRight,
  Network,
  Link2,
  UserCheck,
  UserX,
  Shield,
  Building2,
  Mail,
  Phone,
  Hash,
  Activity,
  Calendar,
  MapPin,
  ChevronDown,
  X,
  Inbox,
  Send as SendIcon,
  UserCog,
  MoreVertical,
  FileText,
  Download,
  MessageSquare,
  ArrowLeftRight,
  Eye,
  Loader2,
  Sparkles
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Checkbox } from '@/components/ui/checkbox';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { format } from 'date-fns';
import { MessageModal } from '@/components/modals/MessageModal';

// iOS Components
import { 
  CleanCard, 
  ElegantSectionHeader, 
  StatusBadge, 
  MinimalEmptyState,
  MinimalLoadingView 
} from '@/components/ios';

// Types
interface User {
  id: number;
  name: string;
  rank?: string;
  unit?: string;
  phone?: string;
  email?: string;
  dodid?: string;
}

interface UserConnection {
  id: number;
  userId: number;
  connectedUserId: number;
  connectionStatus: 'pending' | 'accepted' | 'blocked';
  connectedUser?: {
    id: number;
    name: string;
    rank: string;
    unit: string;
    phone?: string;
    email?: string;
  };
  createdAt: string;
}

enum ConnectionFilter {
  ALL = 'All',
  CONNECTED = 'Connected',
  PENDING = 'Pending'
}

type NetworkTab = 'my-network' | 'requests' | 'directory';

// Advanced search filters
interface SearchFilters {
  organization?: string;
  rank?: string;
  location?: string;
}

export const Connections: React.FC = () => {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedFilter, setSelectedFilter] = useState<ConnectionFilter>(ConnectionFilter.ALL);
  const [searchResults, setSearchResults] = useState<User[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [showUserDetails, setShowUserDetails] = useState<User | null>(null);
  const [activeTab, setActiveTab] = useState<NetworkTab>('my-network');
  const [searchFilters, setSearchFilters] = useState<SearchFilters>({});
  const [showAdvancedSearch, setShowAdvancedSearch] = useState(false);
  const [selectedConnections, setSelectedConnections] = useState<Set<number>>(new Set());
  const [recentSearches, setRecentSearches] = useState<string[]>([]);
  const containerRef = useRef<HTMLDivElement>(null);
  const [containerWidth, setContainerWidth] = useState(0);
  
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const { user } = useAuth();
  
  // Add ResizeObserver for responsive behavior
  useEffect(() => {
    if (!containerRef.current) return;
    
    const resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        setContainerWidth(entry.contentRect.width);
      }
    });
    
    resizeObserver.observe(containerRef.current);
    
    return () => {
      resizeObserver.disconnect();
    };
  }, []);

  // Fetch existing connections
  const { data: connections = [], isLoading } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
  });

  // Mutations
  const sendRequestMutation = useMutation({
    mutationFn: sendConnectionRequest,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['connections'] });
      toast({ title: 'Connection request sent successfully' });
      setSearchResults([]);
      setSearchQuery('');
    },
    onError: (error: Error) => {
      toast({ 
        title: 'Failed to send request', 
        description: error.message,
        variant: 'destructive' 
      });
    }
  });

  const updateStatusMutation = useMutation({
    mutationFn: ({ id, status }: { id: number; status: 'accepted' | 'blocked' }) => 
      updateConnectionStatus(id, status),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['connections'] });
      toast({ 
        title: variables.status === 'accepted' ? 'Connection accepted' : 'Connection blocked'
      });
    },
    onError: (error: Error) => {
      toast({ 
        title: 'Failed to update connection', 
        description: error.message,
        variant: 'destructive' 
      });
    }
  });

  // Filter connections
  const { pendingRequests, acceptedConnections, filteredConnections } = useMemo(() => {
    const currentUserId = parseInt(user?.id || '0');
    
    const pending = connections.filter(c => 
      c.connectionStatus === 'pending' && c.userId !== currentUserId
    );
    
    const accepted = connections.filter(c => 
      c.connectionStatus === 'accepted'
    );

    let filtered = connections;
    switch (selectedFilter) {
      case ConnectionFilter.CONNECTED:
        filtered = accepted;
        break;
      case ConnectionFilter.PENDING:
        filtered = pending;
        break;
      default:
        filtered = connections;
    }

    // Apply search filter
    if (searchQuery.trim()) {
      filtered = filtered.filter(connection => {
        const connectedUser = connection.connectedUser;
        if (!connectedUser) return false;
        
                 const searchTerm = searchQuery.toLowerCase();
         return (
           connectedUser.name?.toLowerCase().includes(searchTerm) ||
           connectedUser.rank?.toLowerCase().includes(searchTerm) ||
           connectedUser.unit?.toLowerCase().includes(searchTerm)
         );
      });
    }

    return { pendingRequests: pending, acceptedConnections: accepted, filteredConnections: filtered };
  }, [connections, selectedFilter, searchQuery, user?.id]);

  // Handle search users
  const handleSearchUsers = async () => {
    if (!searchQuery.trim()) return;
    
    setIsSearching(true);
    try {
      const results = await searchUsers(searchQuery);
      setSearchResults(results);
    } catch (error) {
      toast({ 
        title: 'Search failed', 
        description: 'Unable to search users',
        variant: 'destructive' 
      });
    } finally {
      setIsSearching(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearchUsers();
    }
  };

  // Helper function to get suggested connections
  const suggestedConnections = useMemo(() => {
    // In a real app, this would be based on mutual connections, same unit, etc.
    return searchResults.slice(0, 3);
  }, [searchResults]);

     if (isLoading) {
     return (
       <div className="min-h-screen bg-gradient-to-br from-ios-background via-ios-tertiary-background/30 to-ios-background relative overflow-hidden">
         <div className="absolute top-0 left-0 w-96 h-96 bg-gradient-to-br from-blue-500/10 to-indigo-500/10 rounded-full blur-3xl animate-pulse" />
         <div className="absolute bottom-0 right-0 w-96 h-96 bg-gradient-to-br from-purple-500/10 to-pink-500/10 rounded-full blur-3xl animate-pulse" />
         <div className="max-w-6xl mx-auto px-6 py-8 relative z-10">
           <div className="space-y-8">
             {/* Header Skeleton */}
             <div className="flex items-center justify-between">
               <div className="flex items-center gap-4">
                 <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-gray-200 to-gray-100 animate-pulse" />
                 <div className="space-y-2">
                   <div className="h-10 w-48 bg-gradient-to-r from-gray-200 to-gray-100 rounded-lg animate-pulse" />
                   <div className="h-4 w-64 bg-gradient-to-r from-gray-200 to-gray-100 rounded-md animate-pulse" />
                 </div>
               </div>
               <div className="h-10 w-24 bg-gradient-to-r from-gray-200 to-gray-100 rounded-lg animate-pulse" />
             </div>
             
             {/* Stats Skeleton */}
             <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
               {[...Array(4)].map((_, i) => (
                 <div key={i} className="bg-white/50 backdrop-blur-sm rounded-xl p-5 border border-ios-border/30 shadow-md">
                   <div className="flex items-center justify-between mb-3">
                     <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-gray-200 to-gray-100 animate-pulse" />
                     <div className="h-8 w-16 bg-gradient-to-r from-gray-200 to-gray-100 rounded-md animate-pulse" />
                   </div>
                   <div className="h-3 w-20 bg-gradient-to-r from-gray-200 to-gray-100 rounded animate-pulse" />
                 </div>
               ))}
             </div>
             
             {/* Tabs Skeleton */}
             <div className="bg-white/50 backdrop-blur-sm rounded-2xl p-1.5 shadow-lg border border-ios-border/30">
               <div className="grid grid-cols-3 gap-1.5">
                 {[...Array(3)].map((_, i) => (
                   <div key={i} className="h-16 bg-gradient-to-r from-gray-200 to-gray-100 rounded-xl animate-pulse" />
                 ))}
               </div>
             </div>
             
             {/* Content Skeleton */}
             <CleanCard className="py-12 shadow-lg bg-white/50 backdrop-blur-sm">
               <div className="space-y-4 px-6">
                 {[...Array(3)].map((_, i) => (
                   <div key={i} className="flex items-center gap-4 p-4 bg-gray-50/50 rounded-xl">
                     <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-gray-200 to-gray-100 animate-pulse" />
                     <div className="flex-1 space-y-2">
                       <div className="h-5 w-32 bg-gradient-to-r from-gray-200 to-gray-100 rounded animate-pulse" />
                       <div className="h-3 w-48 bg-gradient-to-r from-gray-200 to-gray-100 rounded animate-pulse" />
                     </div>
                     <div className="h-9 w-24 bg-gradient-to-r from-gray-200 to-gray-100 rounded-lg animate-pulse" />
                   </div>
                 ))}
               </div>
             </CleanCard>
           </div>
         </div>
       </div>
     );
   }

  // Handle advanced search
  const handleAdvancedSearch = async () => {
    if (!searchQuery.trim() && !Object.values(searchFilters).some(v => v)) return;
    
    // Add to recent searches
    if (searchQuery.trim() && !recentSearches.includes(searchQuery)) {
      setRecentSearches(prev => [searchQuery, ...prev.slice(0, 4)]);
    }
    
    setIsSearching(true);
    try {
      const results = await searchUsers(searchQuery);
      // In real app, would filter by searchFilters here
      setSearchResults(results);
    } catch (error) {
      toast({ 
        title: 'Search failed', 
        description: 'Unable to search users',
        variant: 'destructive' 
      });
    } finally {
      setIsSearching(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-ios-background via-ios-tertiary-background/30 to-ios-background relative overflow-hidden">
      {/* Decorative gradient orbs */}
      <div className="absolute top-0 left-0 w-96 h-96 bg-gradient-to-br from-blue-500/10 to-indigo-500/10 rounded-full blur-3xl" />
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-gradient-to-br from-purple-500/10 to-pink-500/10 rounded-full blur-3xl" />
      
      <div ref={containerRef} className="max-w-7xl mx-auto px-6 py-8 relative z-10">
        
        {/* Enhanced Header section */}
        <div className="mb-8">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-xl shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-110 transform-gpu">
                <Globe className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-black text-transparent bg-clip-text bg-gradient-to-r from-gray-900 to-gray-700">
                  Network
                </h1>
                <p className="text-sm text-ios-secondary-text mt-1 font-medium">
                  Build your trusted network for secure property transfers
                </p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <Button
                variant="ghost"
                size="sm"
                onClick={async () => {
                  try {
                    await exportConnections();
                    toast({ title: 'Connections exported successfully' });
                  } catch (error) {
                    toast({ 
                      title: 'Failed to export connections', 
                      description: error instanceof Error ? error.message : 'Unknown error',
                      variant: 'destructive' 
                    });
                  }
                }}
                className="text-sm font-medium text-ios-accent border border-ios-accent hover:bg-blue-500 hover:border-blue-500 hover:text-white px-4 py-2 uppercase transition-all duration-200 rounded-md hover:scale-105 [&:hover_svg]:text-white"
              >
                <Download className="h-4 w-4 mr-1.5" />
                Export
              </Button>
            </div>
          </div>
        </div>

        {/* Network Stats */}
        <NetworkStats connections={connections} />
        
        {/* Tab selector with Transfers styling */}
        <Tabs value={activeTab} onValueChange={(v) => setActiveTab(v as NetworkTab)} className="space-y-6">
          <div className="space-y-3">
            <div className="w-full overflow-hidden bg-gradient-to-r from-white to-gray-50 rounded-lg p-1 shadow-md border border-gray-200/50">
              <div className="overflow-x-auto">
                <div className="flex gap-1 w-full">
                  <button
                    onClick={() => setActiveTab('my-network')}
                    className={cn(
                      "flex-1 px-5 py-2.5 text-xs font-bold rounded-lg whitespace-nowrap transition-all duration-300 uppercase tracking-wider font-mono flex items-center justify-center gap-2 relative",
                      activeTab === 'my-network'
                        ? "bg-blue-500 text-white"
                        : "bg-transparent text-gray-600 hover:bg-gray-100 hover:text-gray-900"
                    )}
                  >
                    <span className="relative z-10 flex items-center gap-2">
                      <Users className="h-5 w-5" />
                      MY NETWORK
                      {acceptedConnections.length > 0 && (
                        <span className={cn(
                          "ml-1 px-2 py-0.5 rounded-full text-xs font-bold min-w-[1.5rem] inline-flex items-center justify-center",
                          activeTab === 'my-network'
                            ? "bg-white/20 text-white"
                            : "bg-gray-300 text-gray-700"
                        )}>
                          {acceptedConnections.length}
                        </span>
                      )}
                    </span>
                  </button>
                  <button
                    onClick={() => setActiveTab('requests')}
                    className={cn(
                      "flex-1 px-5 py-2.5 text-xs font-bold rounded-lg whitespace-nowrap transition-all duration-300 uppercase tracking-wider font-mono flex items-center justify-center gap-2 relative",
                      activeTab === 'requests'
                        ? "bg-blue-500 text-white"
                        : "bg-transparent text-gray-600 hover:bg-gray-100 hover:text-gray-900"
                    )}
                  >
                    <span className="relative z-10 flex items-center gap-2">
                      <Inbox className="h-5 w-5" />
                      REQUESTS
                      {(pendingRequests.length > 0 || connections.filter(c => c.connectionStatus === 'pending' && c.userId === parseInt(user?.id || '0')).length > 0) && (
                        <span className={cn(
                          "ml-1 px-2 py-0.5 rounded-full text-xs font-bold min-w-[1.5rem] inline-flex items-center justify-center",
                          activeTab === 'requests'
                            ? "bg-white/20 text-white"
                            : "bg-orange-500 text-white animate-pulse"
                        )}>
                          {pendingRequests.length + connections.filter(c => c.connectionStatus === 'pending' && c.userId === parseInt(user?.id || '0')).length}
                        </span>
                      )}
                    </span>
                  </button>
                  <button
                    onClick={() => setActiveTab('directory')}
                    className={cn(
                      "flex-1 px-5 py-2.5 text-xs font-bold rounded-lg whitespace-nowrap transition-all duration-300 uppercase tracking-wider font-mono flex items-center justify-center gap-2 relative",
                      activeTab === 'directory'
                        ? "bg-blue-500 text-white"
                        : "bg-transparent text-gray-600 hover:bg-gray-100 hover:text-gray-900"
                    )}
                  >
                    <span className="relative z-10 flex items-center gap-2">
                      <Globe className="h-5 w-5" />
                      DIRECTORY
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* My Network Tab */}
          <TabsContent value="my-network" className="space-y-6">
            <MyNetworkContent 
              connections={acceptedConnections}
              onRefresh={() => queryClient.invalidateQueries({ queryKey: ['connections'] })}
            />
          </TabsContent>

          {/* Requests Tab */}
          <TabsContent value="requests" className="space-y-6">
            <RequestsContent
              pendingRequests={pendingRequests}
              outgoingRequests={connections.filter(c => c.connectionStatus === 'pending' && c.userId === parseInt(user?.id || '0'))}
              onAccept={(id) => updateStatusMutation.mutate({ id, status: 'accepted' })}
              onReject={(id) => updateStatusMutation.mutate({ id, status: 'blocked' })}
              isLoading={updateStatusMutation.isPending}
            />
          </TabsContent>

          {/* Directory Tab */}
          <TabsContent value="directory" className="space-y-6">
            <DirectoryContent
              searchQuery={searchQuery}
              setSearchQuery={setSearchQuery}
              searchFilters={searchFilters}
              setSearchFilters={setSearchFilters}
              showAdvancedSearch={showAdvancedSearch}
              setShowAdvancedSearch={setShowAdvancedSearch}
              searchResults={searchResults}
              isSearching={isSearching}
              onSearch={handleAdvancedSearch}
              onConnect={(userId) => sendRequestMutation.mutate(userId)}
              isConnecting={sendRequestMutation.isPending}
              recentSearches={recentSearches}
              suggestedConnections={suggestedConnections}
            />
          </TabsContent>
        </Tabs>

        {/* Bottom padding for mobile navigation */}
        <div className="h-24"></div>
      </div>
    </div>
  );
};

// Supporting Components

// Network Stats Component
const NetworkStats: React.FC<{ connections: UserConnection[] }> = ({ connections }) => {
  const stats = useMemo(() => {
    const total = connections.length;
    const active = connections.filter(c => c.connectionStatus === 'accepted').length;
    const pending = connections.filter(c => c.connectionStatus === 'pending').length;
    const recentDays = 7;
    const recent = connections.filter(c => {
      const createdAt = new Date(c.createdAt);
      const daysSince = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60 * 24);
      return daysSince <= recentDays;
    }).length;
    
    return { total, active, pending, recent };
  }, [connections]);
  
  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
      {[
        { label: 'Total Network', value: stats.total, icon: <Users className="h-5 w-5" />, color: 'blue', gradient: 'from-blue-500 to-indigo-500' },
        { label: 'Active', value: stats.active, icon: <UserCheck className="h-5 w-5" />, color: 'green', gradient: 'from-green-500 to-emerald-500' },
        { label: 'Pending', value: stats.pending, icon: <Clock className="h-5 w-5" />, color: 'orange', gradient: 'from-orange-500 to-amber-500' },
        { label: 'Recent (7d)', value: stats.recent, icon: <Activity className="h-5 w-5" />, color: 'purple', gradient: 'from-purple-500 to-pink-500' }
      ].map((stat, idx) => (
        <div key={idx} className="group relative">
          <div className={cn(
                 "absolute -inset-0.5 bg-gradient-to-r opacity-0 group-hover:opacity-20 blur transition duration-300",
                 stat.gradient
               )}
               style={{ backgroundImage: `linear-gradient(to right, var(--tw-gradient-stops))` }}></div>
          <div className="relative bg-gradient-to-br from-white to-ios-secondary-background/50 rounded-xl p-5 border border-ios-border/50 shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-[1.02] hover:border-transparent transform-gpu">
            <div className="flex items-center justify-between mb-3">
              <div className={cn(
                "p-3 rounded-xl bg-gradient-to-br shadow-md transition-transform duration-300 group-hover:scale-110",
                stat.gradient
              )}>
                <div className="text-white">
                  {stat.icon}
                </div>
              </div>
              <span className="text-3xl font-black text-ios-primary-text font-mono tabular-nums">
                {stat.value}
              </span>
            </div>
            <p className="text-xs font-semibold text-ios-secondary-text uppercase tracking-wider">{stat.label}</p>
          </div>
        </div>
      ))}
    </div>
  );
};


// Enhanced Tab Button Component with better styling
interface TabButtonProps {
  title: string;
  icon: React.ReactNode;
  isSelected: boolean;
  onClick: () => void;
  badge?: number;
  description?: string;
}

const TabButton: React.FC<TabButtonProps> = ({ title, icon, isSelected, onClick, badge, description }) => (
  <button
    onClick={onClick}
    className={cn(
      "relative p-4 transition-all duration-300 rounded-xl group",
      isSelected 
        ? "bg-white shadow-lg border-2 border-ios-accent/20 scale-[1.02]" 
        : "bg-ios-tertiary-background/30 hover:bg-ios-tertiary-background/50 border-2 border-transparent hover:border-ios-border"
    )}
  >
    <div className="flex flex-col items-center gap-3">
      <div className={cn(
        "p-3 rounded-full transition-all duration-300",
        isSelected 
          ? "bg-ios-accent text-white shadow-md" 
          : "bg-ios-secondary-background text-ios-secondary-text group-hover:bg-white group-hover:shadow-sm"
      )}>
        {icon}
      </div>
      
      <div className="text-center">
        <div className="flex items-center justify-center gap-2">
          <span 
            className={cn(
              "text-sm font-bold uppercase tracking-wider transition-colors duration-300",
              isSelected ? "text-ios-primary-text" : "text-ios-secondary-text",
              "font-mono"
            )}
          >
            {title}
          </span>
          {badge !== undefined && badge > 0 && (
            <span className={cn(
              "text-xs font-bold px-2 py-0.5 rounded-full transition-all duration-300",
              isSelected 
                ? "bg-ios-accent text-white" 
                : "bg-ios-accent/10 text-ios-accent",
              "font-mono"
            )}>
              {badge}
            </span>
          )}
        </div>
        
        {description && (
          <p className={cn(
            "text-xs mt-1 transition-colors duration-300",
            isSelected ? "text-ios-secondary-text" : "text-ios-tertiary-text"
          )}>
            {description}
          </p>
        )}
      </div>
    </div>
    
    {/* Active indicator */}
    <div className={cn(
      "absolute bottom-0 left-1/2 transform -translate-x-1/2 h-1 rounded-full transition-all duration-300",
      isSelected 
        ? "w-12 bg-ios-accent" 
        : "w-0 bg-transparent"
    )} />
  </button>
);

interface UserSearchResultCardProps {
  user: User;
  onConnect: () => void;
  isLoading: boolean;
}

const UserSearchResultCard: React.FC<UserSearchResultCardProps> = ({ user, onConnect, isLoading }) => (
  <div className="group relative overflow-hidden rounded-2xl border-2 border-transparent hover:border-blue-500/30 transition-all duration-300 transform-gpu hover:scale-[1.01]">
    <div className="absolute inset-0 bg-gradient-to-r from-blue-500/5 via-indigo-500/5 to-purple-500/5 opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
    <CleanCard className="relative p-6 bg-gradient-to-br from-white to-ios-secondary-background/30 shadow-lg hover:shadow-2xl transition-all duration-300">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="relative">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center shadow-xl transform transition-all duration-300 group-hover:scale-110 group-hover:rotate-3">
              <span className="text-white font-black text-xl font-mono">
                {user.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
              </span>
            </div>
            <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-gradient-to-br from-green-400 to-emerald-500 rounded-full border-2 border-white shadow-md animate-pulse" />
          </div>
          <div>
            <div className="font-bold text-xl text-ios-primary-text group-hover:text-transparent group-hover:bg-clip-text group-hover:bg-gradient-to-r group-hover:from-blue-600 group-hover:to-indigo-600 transition-all duration-300">
              {user.name}
            </div>
            <div className="flex items-center gap-3 mt-1.5">
              {user.rank && (
                <span className="flex items-center gap-1.5 text-sm text-ios-secondary-text font-medium">
                  <Shield className="h-3.5 w-3.5 text-blue-500" />
                  {user.rank}
                </span>
              )}
              {user.unit && (
                <span className="flex items-center gap-1.5 text-sm text-ios-secondary-text font-medium">
                  <Building2 className="h-3.5 w-3.5 text-indigo-500" />
                  {user.unit}
                </span>
              )}
            </div>
          </div>
        </div>
        <Button
          size="sm"
          onClick={onConnect}
          disabled={isLoading}
          className="relative bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 text-white rounded-xl px-7 py-3 font-bold shadow-lg hover:shadow-xl transition-all duration-300 flex items-center gap-2.5 hover:scale-105 active:scale-95 disabled:opacity-50 disabled:cursor-not-allowed overflow-hidden group"
        >
          <div className="absolute inset-0 bg-gradient-to-r from-white/0 via-white/20 to-white/0 -skew-x-12 translate-x-[-200%] group-hover:translate-x-[200%] transition-transform duration-700" />
          {isLoading ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <>
              <UserPlus className="h-4 w-4 transition-transform duration-300 group-hover:scale-110" />
              <span className="font-mono uppercase tracking-widest text-xs">Connect</span>
            </>
          )}
        </Button>
      </div>
    </CleanCard>
  </div>
);

interface PendingRequestCardProps {
  request: UserConnection;
  onAccept: () => void;
  onReject: () => void;
  isLoading: boolean;
}

const PendingRequestCard: React.FC<PendingRequestCardProps> = ({ request, onAccept, onReject, isLoading }) => (
  <div className="group relative">
    <div className="absolute -inset-0.5 bg-gradient-to-r from-orange-500/20 to-amber-500/20 rounded-2xl opacity-50 group-hover:opacity-100 blur transition duration-300"></div>
    <CleanCard className="relative p-6 border-2 border-orange-500/20 hover:border-orange-500/40 transition-all duration-300 shadow-lg hover:shadow-xl bg-gradient-to-br from-orange-500/5 via-amber-500/5 to-transparent transform-gpu hover:scale-[1.01]">
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="relative">
              <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-orange-400 to-amber-500 flex items-center justify-center shadow-lg transform transition-all duration-300 group-hover:scale-110 group-hover:rotate-3">
                <span className="text-white font-black text-lg font-mono">
                  {request.connectedUser?.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
                </span>
              </div>
              <div className="absolute -top-1 -right-1 w-3 h-3 bg-orange-500 rounded-full animate-pulse" />
            </div>
            <div>
              <div className="font-bold text-lg text-ios-primary-text">
                {request.connectedUser?.name || 'Unknown User'}
              </div>
              <div className="text-sm text-ios-secondary-text mt-0.5 font-medium">
                {request.connectedUser?.rank && request.connectedUser?.unit 
                  ? `${request.connectedUser.rank} • ${request.connectedUser.unit}`
                  : request.connectedUser?.email || 'No additional info'
                }
              </div>
              <div className="flex items-center gap-2 mt-2">
                <Clock className="h-3 w-3 text-orange-500" />
                <span className="text-xs text-orange-600 font-bold uppercase tracking-wider">
                  Awaiting Response
                </span>
              </div>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <div className="px-4 py-2 bg-gradient-to-r from-orange-500/10 to-amber-500/10 text-orange-600 rounded-xl text-xs font-black uppercase tracking-widest font-mono shadow-sm">
              Pending
            </div>
          </div>
        </div>
        
        <div className="flex gap-3">
          <Button
            variant="outline"
            size="sm"
            onClick={onReject}
            disabled={isLoading}
            className="flex-1 border-2 border-ios-border hover:border-red-500/30 hover:bg-red-500/5 text-ios-secondary-text hover:text-red-600 rounded-xl px-5 py-3 font-bold transition-all duration-300 hover:scale-105 active:scale-95 group"
          >
            <XCircle className="h-4 w-4 mr-2 transition-transform duration-300 group-hover:scale-110" />
            <span className="font-mono uppercase tracking-widest text-xs">Decline</span>
          </Button>
          <Button
            size="sm"
            onClick={onAccept}
            disabled={isLoading}
            className="flex-1 bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 text-white rounded-xl px-5 py-3 font-bold shadow-lg hover:shadow-xl transition-all duration-300 hover:scale-105 active:scale-95 group relative overflow-hidden"
          >
            <div className="absolute inset-0 bg-gradient-to-r from-white/0 via-white/20 to-white/0 -skew-x-12 translate-x-[-200%] group-hover:translate-x-[200%] transition-transform duration-700" />
            <CheckCircle className="h-4 w-4 mr-2 transition-transform duration-300 group-hover:scale-110 relative z-10" />
            <span className="font-mono uppercase tracking-widest text-xs relative z-10">Accept</span>
          </Button>
        </div>
      </div>
    </CleanCard>
  </div>
);

interface ConnectionCardProps {
  connection: UserConnection;
}

const ConnectionCard: React.FC<ConnectionCardProps> = ({ connection }) => (
  <div className="group relative">
    <div className="absolute -inset-1 bg-gradient-to-r from-emerald-500/20 via-green-500/20 to-teal-500/20 rounded-2xl opacity-0 group-hover:opacity-100 blur-xl transition duration-500" />
    <CleanCard className="relative p-6 bg-gradient-to-br from-white to-emerald-50/30 border-2 border-emerald-500/10 hover:border-emerald-500/30 transition-all duration-300 shadow-lg hover:shadow-2xl transform-gpu hover:scale-[1.02]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="relative">
            <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-emerald-400 via-green-500 to-teal-500 flex items-center justify-center shadow-xl transform transition-all duration-300 group-hover:scale-110 group-hover:rotate-3">
              <span className="text-white font-black text-xl font-mono">
                {connection.connectedUser?.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
              </span>
            </div>
            <div className="absolute -top-1.5 -right-1.5 flex items-center justify-center w-7 h-7 bg-gradient-to-br from-emerald-400 to-green-500 rounded-full border-2 border-white shadow-md">
              <CheckCircle className="h-4 w-4 text-white" />
            </div>
          </div>
          <div className="flex-1">
            <div className="font-bold text-xl text-ios-primary-text group-hover:text-transparent group-hover:bg-clip-text group-hover:bg-gradient-to-r group-hover:from-emerald-600 group-hover:to-teal-600 transition-all duration-300">
              {connection.connectedUser?.name || 'Unknown User'}
            </div>
            <div className="flex items-center gap-3 mt-1.5">
              {connection.connectedUser?.rank && (
                <span className="flex items-center gap-1.5 text-sm text-ios-secondary-text font-medium">
                  <Shield className="h-3.5 w-3.5 text-emerald-500" />
                  {connection.connectedUser.rank}
                </span>
              )}
              {connection.connectedUser?.unit && (
                <span className="flex items-center gap-1.5 text-sm text-ios-secondary-text font-medium">
                  <Building2 className="h-3.5 w-3.5 text-teal-500" />
                  {connection.connectedUser.unit}
                </span>
              )}
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <div className="px-5 py-2.5 bg-gradient-to-r from-emerald-500/10 to-teal-500/10 text-emerald-600 rounded-xl text-xs font-black uppercase tracking-widest font-mono flex items-center gap-2.5 shadow-sm hover:shadow-md transition-all duration-300 hover:scale-105">
            <Link2 className="h-3.5 w-3.5 animate-pulse" />
            Connected
          </div>
        </div>
      </div>
    </CleanCard>
  </div>
);

// My Network Content Component - Professional Table View
interface MyNetworkContentProps {
  connections: UserConnection[];
  onRefresh: () => void;
}

const MyNetworkContent: React.FC<MyNetworkContentProps> = ({ connections, onRefresh }) => {
  const [selectedRows, setSelectedRows] = useState<Set<number>>(new Set());
  const [searchTerm, setSearchTerm] = useState('');
  const [messageModalOpen, setMessageModalOpen] = useState(false);
  const [messageRecipient, setMessageRecipient] = useState<{ id: number; name: string; rank?: string; unit?: string } | null>(null);
  
  const filteredConnections = useMemo(() => {
    if (!searchTerm) return connections;
    
    const term = searchTerm.toLowerCase();
    return connections.filter(conn => 
      conn.connectedUser?.name.toLowerCase().includes(term) ||
      conn.connectedUser?.rank?.toLowerCase().includes(term) ||
      conn.connectedUser?.unit?.toLowerCase().includes(term)
    );
  }, [connections, searchTerm]);
  
  const toggleRow = (id: number) => {
    const newSelected = new Set(selectedRows);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelectedRows(newSelected);
  };
  
  const toggleAll = () => {
    if (selectedRows.size === filteredConnections.length) {
      setSelectedRows(new Set());
    } else {
      setSelectedRows(new Set(filteredConnections.map(c => c.id)));
    }
  };

  const handleSendMessage = (user: { id: number; name: string; rank?: string; unit?: string }) => {
    setMessageRecipient(user);
    setMessageModalOpen(true);
  };
  
  if (connections.length === 0) {
    return (
      <div className="relative">
        <div className="absolute inset-0 bg-gradient-to-r from-blue-500/5 to-indigo-500/5 rounded-2xl blur-xl" />
        <CleanCard className="relative py-24 shadow-xl bg-gradient-to-br from-white to-ios-secondary-background/30">
          <MinimalEmptyState
            icon={<Users className="h-16 w-16 text-ios-tertiary-text" />}
            title="NO CONNECTIONS YET"
            description="Start building your network by searching for users in the Directory tab"
            action={
              <Button
                onClick={() => {
                  const directoryTab = document.querySelector('[value="directory"]') as HTMLButtonElement;
                  directoryTab?.click();
                }}
                className="bg-gradient-to-r from-blue-500 to-indigo-600 hover:from-blue-600 hover:to-indigo-700 text-white rounded-xl px-8 py-3 font-bold shadow-lg hover:shadow-xl transition-all duration-300 flex items-center gap-2.5 hover:scale-105 active:scale-95 uppercase tracking-wider"
              >
                <UserPlus className="h-5 w-5" />
                Browse Directory
              </Button>
            }
          />
        </CleanCard>
      </div>
    );
  }
  
  return (
    <div className="space-y-4">
      {/* Search and Actions Bar */}
      <CleanCard className="p-5 shadow-lg bg-gradient-to-br from-white to-ios-secondary-background/30 border border-ios-border/50">
        <div className="flex items-center justify-between gap-4">
          <div className="relative flex-1 max-w-md group">
            <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 h-5 w-5 text-ios-tertiary-text transition-colors duration-300 group-focus-within:text-ios-accent" />
            <Input
              placeholder="Search connections..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-12 pr-4 h-12 border-2 border-ios-border bg-ios-tertiary-background/50 hover:bg-white/70 rounded-xl text-base font-medium placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent focus-visible:border-transparent transition-all duration-300 shadow-sm hover:shadow-md"
            />
          </div>
          <div className="flex items-center gap-3">
            {selectedRows.size > 0 && (
              <span className="text-sm font-bold text-ios-secondary-text bg-ios-tertiary-background/50 px-3 py-1.5 rounded-lg">
                {selectedRows.size} selected
              </span>
            )}
            <Button
              variant="outline"
              size="sm"
              onClick={onRefresh}
              className="border-2 border-ios-border hover:border-ios-accent hover:bg-ios-accent hover:text-white text-ios-primary-text font-bold transition-all duration-300 px-4 py-2.5 rounded-xl hover:shadow-lg hover:scale-105 active:scale-95"
            >
              <Activity className="h-4 w-4 transition-transform duration-300 hover:rotate-180" />
            </Button>
          </div>
        </div>
      </CleanCard>
      
      {/* Connections Table */}
      <CleanCard className="overflow-hidden shadow-xl bg-gradient-to-br from-white to-ios-secondary-background/30 border border-ios-border/50">
        <Table>
          <TableHeader>
            <TableRow className="border-b-2 border-ios-border hover:bg-transparent bg-ios-secondary-background/20">
              <TableHead className="w-12 py-4">
                <Checkbox
                  checked={selectedRows.size === filteredConnections.length && filteredConnections.length > 0}
                  onCheckedChange={toggleAll}
                  className="data-[state=checked]:bg-gradient-to-r data-[state=checked]:from-blue-500 data-[state=checked]:to-indigo-500 data-[state=checked]:border-transparent transition-all duration-300 hover:scale-110"
                />
              </TableHead>
              <TableHead className="font-black text-xs uppercase tracking-widest text-ios-primary-text py-4">Name</TableHead>
              <TableHead className="font-black text-xs uppercase tracking-widest text-ios-primary-text py-4">Rank</TableHead>
              <TableHead className="font-black text-xs uppercase tracking-widest text-ios-primary-text py-4">Unit</TableHead>
              <TableHead className="font-black text-xs uppercase tracking-widest text-ios-primary-text py-4">Contact</TableHead>
              <TableHead className="font-black text-xs uppercase tracking-widest text-ios-primary-text py-4">Connected Since</TableHead>
              <TableHead className="font-black text-xs uppercase tracking-widest text-ios-primary-text py-4">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {filteredConnections.map((connection) => (
              <TableRow
                key={connection.id}
                className="border-b border-ios-border/50 hover:bg-gradient-to-r hover:from-ios-secondary-background/30 hover:to-transparent transition-all duration-300 group"
              >
                <TableCell className="py-4">
                  <Checkbox
                    checked={selectedRows.has(connection.id)}
                    onCheckedChange={() => toggleRow(connection.id)}
                    className="data-[state=checked]:bg-gradient-to-r data-[state=checked]:from-blue-500 data-[state=checked]:to-indigo-500 data-[state=checked]:border-transparent transition-all duration-300 hover:scale-110"
                  />
                </TableCell>
                <TableCell className="py-4">
                  <div className="flex items-center gap-3">
                    <div className="relative">
                      <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-400 to-teal-500 flex items-center justify-center shadow-md transition-all duration-300 group-hover:scale-110 group-hover:shadow-lg">
                        <span className="text-white font-black text-sm font-mono">
                          {connection.connectedUser?.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
                        </span>
                      </div>
                      <div className="absolute -bottom-1 -right-1 w-3 h-3 bg-green-500 rounded-full border border-white animate-pulse" />
                    </div>
                    <div className="font-bold text-base text-ios-primary-text group-hover:text-transparent group-hover:bg-clip-text group-hover:bg-gradient-to-r group-hover:from-emerald-600 group-hover:to-teal-600 transition-all duration-300">
                      {connection.connectedUser?.name || 'Unknown User'}
                    </div>
                  </div>
                </TableCell>
                <TableCell className="py-4">
                  <span className="text-sm font-medium text-ios-secondary-text flex items-center gap-1.5">
                    <Shield className="h-3.5 w-3.5 text-emerald-500 opacity-60" />
                    {connection.connectedUser?.rank || 'N/A'}
                  </span>
                </TableCell>
                <TableCell className="py-4">
                  <span className="text-sm font-medium text-ios-secondary-text flex items-center gap-1.5">
                    <Building2 className="h-3.5 w-3.5 text-teal-500 opacity-60" />
                    {connection.connectedUser?.unit || 'N/A'}
                  </span>
                </TableCell>
                <TableCell className="py-4">
                  <div className="flex flex-col gap-1.5">
                    {connection.connectedUser?.email && (
                      <span className="text-xs font-medium text-ios-secondary-text flex items-center gap-1.5 group-hover:text-ios-primary-text transition-colors duration-300">
                        <Mail className="h-3.5 w-3.5 text-blue-500 opacity-60" />
                        {connection.connectedUser.email}
                      </span>
                    )}
                    {connection.connectedUser?.phone && (
                      <span className="text-xs font-medium text-ios-secondary-text flex items-center gap-1.5 group-hover:text-ios-primary-text transition-colors duration-300">
                        <Phone className="h-3.5 w-3.5 text-indigo-500 opacity-60" />
                        {connection.connectedUser.phone}
                      </span>
                    )}
                  </div>
                </TableCell>
                <TableCell className="py-4">
                  <span className="text-sm text-ios-secondary-text font-mono">
                    {format(new Date(connection.createdAt), 'ddMMMyyyy').toUpperCase()}
                  </span>
                </TableCell>
                <TableCell className="py-4">
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-9 w-9 hover:bg-gradient-to-r hover:from-gray-100 hover:to-gray-50 rounded-xl transition-all duration-300 hover:scale-110 active:scale-95"
                      >
                        <MoreVertical className="h-4 w-4 transition-transform duration-300 hover:rotate-90" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-56 rounded-xl shadow-xl border-ios-border/50 bg-white/95 backdrop-blur-xl">
                      <DropdownMenuItem 
                        className="py-3 px-4 hover:bg-blue-50 focus:bg-blue-50 rounded-lg transition-all duration-200 cursor-pointer group text-gray-700 hover:text-gray-900 focus:text-gray-900"
                        onClick={() => connection.connectedUser && handleSendMessage({
                          id: connection.connectedUser.id,
                          name: connection.connectedUser.name,
                          rank: connection.connectedUser.rank,
                          unit: connection.connectedUser.unit
                        })}
                      >
                        <MessageSquare className="h-4 w-4 mr-3 text-blue-500 transition-transform duration-300 group-hover:scale-110" />
                        <span className="font-medium">Message</span>
                      </DropdownMenuItem>
                      <DropdownMenuItem className="py-3 px-4 hover:bg-purple-50 focus:bg-purple-50 rounded-lg transition-all duration-200 cursor-pointer group text-gray-700 hover:text-gray-900 focus:text-gray-900">
                        <ArrowLeftRight className="h-4 w-4 mr-3 text-purple-500 transition-transform duration-300 group-hover:scale-110" />
                        <span className="font-medium">Transfer Property</span>
                      </DropdownMenuItem>
                      <DropdownMenuItem className="py-3 px-4 hover:bg-emerald-50 focus:bg-emerald-50 rounded-lg transition-all duration-200 cursor-pointer group text-gray-700 hover:text-gray-900 focus:text-gray-900">
                        <Eye className="h-4 w-4 mr-3 text-emerald-500 transition-transform duration-300 group-hover:scale-110" />
                        <span className="font-medium">View Profile</span>
                      </DropdownMenuItem>
                      <DropdownMenuSeparator className="my-2 bg-ios-border/30" />
                      <DropdownMenuItem className="py-3 px-4 hover:bg-red-50 focus:bg-red-50 rounded-lg transition-all duration-200 cursor-pointer group text-red-600 hover:text-red-700 focus:text-red-700">
                        <UserX className="h-4 w-4 mr-3 transition-transform duration-300 group-hover:scale-110" />
                        <span className="font-medium">Remove Connection</span>
                      </DropdownMenuItem>
                    </DropdownMenuContent>
                  </DropdownMenu>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CleanCard>

      {/* Message Modal */}
      {messageRecipient && (
        <MessageModal
          isOpen={messageModalOpen}
          onClose={() => {
            setMessageModalOpen(false);
            setMessageRecipient(null);
          }}
          recipient={messageRecipient}
        />
      )}
    </div>
  );
};

// Requests Content Component
interface RequestsContentProps {
  pendingRequests: UserConnection[];
  outgoingRequests: UserConnection[];
  onAccept: (id: number) => void;
  onReject: (id: number) => void;
  isLoading: boolean;
}

const RequestsContent: React.FC<RequestsContentProps> = ({ 
  pendingRequests, 
  outgoingRequests, 
  onAccept, 
  onReject, 
  isLoading 
}) => {
  return (
    <div className="space-y-6">
      {/* Incoming Requests */}
      {pendingRequests.length > 0 && (
        <div>
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-orange-500/10 rounded-lg">
              <Inbox className="h-5 w-5 text-orange-500" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono">
                INCOMING REQUESTS
              </h3>
              <p className="text-xs text-ios-secondary-text mt-0.5">{pendingRequests.length} awaiting your response</p>
            </div>
          </div>
          
          <div className="space-y-3">
            {pendingRequests.map((request) => (
              <EnhancedPendingRequestCard
                key={request.id}
                request={request}
                onAccept={() => onAccept(request.id)}
                onReject={() => onReject(request.id)}
                isLoading={isLoading}
              />
            ))}
          </div>
        </div>
      )}
      
      {/* Outgoing Requests */}
      {outgoingRequests.length > 0 && (
        <div>
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-blue-500/10 rounded-lg">
              <SendIcon className="h-5 w-5 text-blue-500" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono">
                OUTGOING REQUESTS
              </h3>
              <p className="text-xs text-ios-secondary-text mt-0.5">{outgoingRequests.length} pending approval</p>
            </div>
          </div>
          
          <div className="space-y-3">
            {outgoingRequests.map((request) => (
              <OutgoingRequestCard
                key={request.id}
                request={request}
              />
            ))}
          </div>
        </div>
      )}
      
      {/* Empty State */}
      {pendingRequests.length === 0 && outgoingRequests.length === 0 && (
        <CleanCard className="py-24 shadow-sm">
          <MinimalEmptyState
            icon={<Inbox className="h-12 w-12" />}
            title="NO PENDING REQUESTS"
            description="You don't have any connection requests at the moment"
          />
        </CleanCard>
      )}
    </div>
  );
};

// Enhanced Pending Request Card
const EnhancedPendingRequestCard: React.FC<PendingRequestCardProps> = ({ request, onAccept, onReject, isLoading }) => (
  <CleanCard className="p-6 border border-orange-500/20 hover:border-orange-500/30 transition-all duration-200 shadow-sm hover:shadow-md">
    <div className="space-y-4">
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-orange-500/20 to-orange-500/10 flex items-center justify-center shadow-sm">
            <span className="text-orange-500 font-semibold text-lg font-mono">
              {request.connectedUser?.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
            </span>
          </div>
          <div>
            <div className="font-semibold text-lg text-ios-primary-text">
              {request.connectedUser?.name || 'Unknown User'}
            </div>
            <div className="flex items-center gap-3 mt-1">
              {request.connectedUser?.rank && (
                <span className="flex items-center gap-1 text-sm text-ios-secondary-text">
                  <Shield className="h-3 w-3" />
                  {request.connectedUser.rank}
                </span>
              )}
              {request.connectedUser?.unit && (
                <span className="flex items-center gap-1 text-sm text-ios-secondary-text">
                  <Building2 className="h-3 w-3" />
                  {request.connectedUser.unit}
                </span>
              )}
            </div>
            <div className="flex items-center gap-2 mt-2">
              <Clock className="h-3 w-3 text-ios-tertiary-text" />
              <span className="text-xs text-ios-tertiary-text">
                Requested {format(new Date(request.createdAt), 'MMM d, yyyy')}
              </span>
            </div>
          </div>
        </div>
        <div className="px-3 py-1 bg-orange-500/10 text-orange-500 rounded-lg text-xs font-semibold uppercase tracking-wider font-mono">
          Pending
        </div>
      </div>
      
      <div className="flex gap-3">
        <Button
          variant="outline"
          size="sm"
          onClick={onReject}
          disabled={isLoading}
          className="flex-1 border-ios-border hover:bg-ios-tertiary-background text-ios-secondary-text rounded-lg px-4 py-2.5 font-medium transition-all duration-200"
        >
          <XCircle className="h-4 w-4 mr-2" />
          Decline
        </Button>
        <Button
          size="sm"
          onClick={onAccept}
          disabled={isLoading}
          className="flex-1 bg-ios-success hover:bg-ios-success/90 text-white rounded-lg px-4 py-2.5 font-medium shadow-sm transition-all duration-200"
        >
          <CheckCircle className="h-4 w-4 mr-2" />
          Accept
        </Button>
      </div>
    </div>
  </CleanCard>
);

// Outgoing Request Card
interface OutgoingRequestCardProps {
  request: UserConnection;
}

const OutgoingRequestCard: React.FC<OutgoingRequestCardProps> = ({ request }) => (
  <div className="group relative">
    <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-500/20 to-indigo-500/20 rounded-2xl opacity-50 group-hover:opacity-100 blur transition duration-300"></div>
    <CleanCard className="relative p-6 border-2 border-blue-500/20 hover:border-blue-500/40 transition-all duration-300 shadow-lg hover:shadow-xl bg-gradient-to-br from-blue-500/5 via-indigo-500/5 to-transparent transform-gpu hover:scale-[1.01]">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="relative">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-400 to-indigo-500 flex items-center justify-center shadow-lg transform transition-all duration-300 group-hover:scale-110 group-hover:rotate-3">
              <span className="text-white font-black text-lg font-mono">
                {request.connectedUser?.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
              </span>
            </div>
            <div className="absolute -top-1 -right-1 w-3 h-3 bg-blue-500 rounded-full animate-pulse" />
          </div>
          <div>
            <div className="font-bold text-lg text-ios-primary-text">
              {request.connectedUser?.name || 'Unknown User'}
            </div>
            <div className="flex items-center gap-3 mt-1">
              {request.connectedUser?.rank && (
                <span className="flex items-center gap-1.5 text-sm text-ios-secondary-text font-medium">
                  <Shield className="h-3.5 w-3.5 text-blue-500" />
                  {request.connectedUser.rank}
                </span>
              )}
              {request.connectedUser?.unit && (
                <span className="flex items-center gap-1.5 text-sm text-ios-secondary-text font-medium">
                  <Building2 className="h-3.5 w-3.5 text-indigo-500" />
                  {request.connectedUser.unit}
                </span>
              )}
            </div>
            <div className="flex items-center gap-2 mt-2">
              <Clock className="h-3 w-3 text-blue-500" />
              <span className="text-xs text-blue-600 font-bold uppercase tracking-wider">
                Sent {format(new Date(request.createdAt), 'MMM d, yyyy')}
              </span>
            </div>
          </div>
        </div>
        <div className="px-4 py-2 bg-gradient-to-r from-blue-500/10 to-indigo-500/10 text-blue-600 rounded-xl text-xs font-black uppercase tracking-widest font-mono shadow-sm animate-pulse">
          Awaiting Response
        </div>
      </div>
    </CleanCard>
  </div>
);

// Directory Content Component with Advanced Search
interface DirectoryContentProps {
  searchQuery: string;
  setSearchQuery: (query: string) => void;
  searchFilters: SearchFilters;
  setSearchFilters: (filters: SearchFilters) => void;
  showAdvancedSearch: boolean;
  setShowAdvancedSearch: (show: boolean) => void;
  searchResults: User[];
  isSearching: boolean;
  onSearch: () => void;
  onConnect: (userId: number) => void;
  isConnecting: boolean;
  recentSearches: string[];
  suggestedConnections: User[];
}

const DirectoryContent: React.FC<DirectoryContentProps> = ({
  searchQuery,
  setSearchQuery,
  searchFilters,
  setSearchFilters,
  showAdvancedSearch,
  setShowAdvancedSearch,
  searchResults,
  isSearching,
  onSearch,
  onConnect,
  isConnecting,
  recentSearches,
  suggestedConnections
}) => {
  return (
    <div className="space-y-6">
      {/* Enhanced Search Section */}
      <CleanCard className="p-6 shadow-xl bg-gradient-to-br from-white to-ios-secondary-background/30 border border-ios-border/50">
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-gradient-to-br from-blue-500/10 to-indigo-500/10 rounded-xl shadow-sm group-hover:shadow-md transition-all duration-300">
                <Search className="h-6 w-6 text-ios-accent" />
              </div>
              <div>
                <h3 className="text-sm font-black text-ios-primary-text uppercase tracking-widest font-mono">
                  SEARCH DIRECTORY
                </h3>
                <p className="text-xs text-ios-secondary-text mt-1 font-medium">Find users by name, rank, or organization</p>
              </div>
            </div>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setShowAdvancedSearch(!showAdvancedSearch)}
              className="text-ios-accent hover:text-ios-accent/80 hover:bg-ios-accent/5 rounded-xl px-4 py-2 font-bold transition-all duration-300 hover:scale-105 active:scale-95"
            >
              <Filter className="h-4 w-4 mr-2 transition-transform duration-300" />
              Advanced
              <ChevronDown className={cn(
                "h-4 w-4 ml-1 transition-transform duration-300",
                showAdvancedSearch && "rotate-180"
              )} />
            </Button>
          </div>
          
          {/* Search Input */}
          <div className="relative">
            <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 h-5 w-5 text-ios-tertiary-text" />
            <Input
              placeholder="Search by name, rank, or unit..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && onSearch()}
              className="pl-12 pr-4 border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200"
            />
            {searchQuery && (
              <Button
                onClick={onSearch}
                disabled={isSearching}
                size="sm"
                className="absolute right-2 top-1/2 transform -translate-y-1/2 bg-ios-accent hover:bg-ios-accent/90 text-white h-10 px-6 rounded-lg shadow-md transition-all duration-200"
              >
                {isSearching ? (
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                ) : (
                  "Search"
                )}
              </Button>
            )}
          </div>
          
          {/* Advanced Filters */}
          {showAdvancedSearch && (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pt-4 border-t border-ios-border">
              <div>
                <label className="text-xs font-semibold text-ios-secondary-text uppercase tracking-wider mb-2 block">
                  Organization/Unit
                </label>
                <Input
                  placeholder="e.g., 1st Battalion"
                  value={searchFilters.organization || ''}
                  onChange={(e) => setSearchFilters({ ...searchFilters, organization: e.target.value })}
                  className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-10 text-sm placeholder:text-ios-tertiary-text"
                />
              </div>
              <div>
                <label className="text-xs font-semibold text-ios-secondary-text uppercase tracking-wider mb-2 block">
                  Rank
                </label>
                <Select
                  value={searchFilters.rank || ''}
                  onValueChange={(value) => setSearchFilters({ ...searchFilters, rank: value })}
                >
                  <SelectTrigger className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-10 text-sm">
                    <SelectValue placeholder="Select rank" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="">All Ranks</SelectItem>
                    <SelectItem value="PVT">Private (PVT)</SelectItem>
                    <SelectItem value="PFC">Private First Class (PFC)</SelectItem>
                    <SelectItem value="SPC">Specialist (SPC)</SelectItem>
                    <SelectItem value="CPL">Corporal (CPL)</SelectItem>
                    <SelectItem value="SGT">Sergeant (SGT)</SelectItem>
                    <SelectItem value="SSG">Staff Sergeant (SSG)</SelectItem>
                    <SelectItem value="SFC">Sergeant First Class (SFC)</SelectItem>
                    <SelectItem value="MSG">Master Sergeant (MSG)</SelectItem>
                    <SelectItem value="1SG">First Sergeant (1SG)</SelectItem>
                    <SelectItem value="SGM">Sergeant Major (SGM)</SelectItem>
                    <SelectItem value="2LT">Second Lieutenant (2LT)</SelectItem>
                    <SelectItem value="1LT">First Lieutenant (1LT)</SelectItem>
                    <SelectItem value="CPT">Captain (CPT)</SelectItem>
                    <SelectItem value="MAJ">Major (MAJ)</SelectItem>
                    <SelectItem value="LTC">Lieutenant Colonel (LTC)</SelectItem>
                    <SelectItem value="COL">Colonel (COL)</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <label className="text-xs font-semibold text-ios-secondary-text uppercase tracking-wider mb-2 block">
                  Location
                </label>
                <Input
                  placeholder="e.g., Fort Bragg"
                  value={searchFilters.location || ''}
                  onChange={(e) => setSearchFilters({ ...searchFilters, location: e.target.value })}
                  className="border-ios-border bg-ios-tertiary-background/50 rounded-lg h-10 text-sm placeholder:text-ios-tertiary-text"
                />
              </div>
            </div>
          )}
          
          {/* Recent Searches */}
          {recentSearches.length > 0 && !searchQuery && (
            <div className="pt-4 border-t border-ios-border">
              <h4 className="text-xs font-semibold text-ios-secondary-text uppercase tracking-wider mb-2">
                Recent Searches
              </h4>
              <div className="flex flex-wrap gap-2">
                {recentSearches.map((search, idx) => (
                  <button
                    key={idx}
                    onClick={() => {
                      setSearchQuery(search);
                      onSearch();
                    }}
                    className="px-3 py-1.5 bg-ios-tertiary-background hover:bg-ios-secondary-background text-ios-secondary-text text-sm rounded-lg transition-colors duration-200"
                  >
                    <Clock className="h-3 w-3 inline mr-1" />
                    {search}
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>
      </CleanCard>
      
      {/* Suggested Connections */}
      {suggestedConnections.length > 0 && searchResults.length === 0 && (
        <div>
          <div className="flex items-center gap-3 mb-4">
            <div className="p-2 bg-purple-500/10 rounded-lg">
              <UserPlus className="h-5 w-5 text-purple-500" />
            </div>
            <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono">
              SUGGESTED CONNECTIONS
            </h3>
          </div>
          <div className="space-y-3">
            {suggestedConnections.map((user) => (
              <EnhancedUserSearchResultCard
                key={user.id}
                user={user}
                onConnect={() => onConnect(user.id)}
                isLoading={isConnecting}
              />
            ))}
          </div>
        </div>
      )}
      
      {/* Search Results */}
      {searchResults.length > 0 && (
        <div>
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono">
              SEARCH RESULTS
            </h3>
            <span className="text-xs text-ios-secondary-text font-mono">
              {searchResults.length} FOUND
            </span>
          </div>
          <div className="space-y-3">
            {searchResults.map((user) => (
              <EnhancedUserSearchResultCard
                key={user.id}
                user={user}
                onConnect={() => onConnect(user.id)}
                isLoading={isConnecting}
              />
            ))}
          </div>
        </div>
      )}
      
      {/* Empty State */}
      {searchQuery && searchResults.length === 0 && !isSearching && (
        <CleanCard className="py-24 shadow-sm">
          <MinimalEmptyState
            icon={<Search className="h-12 w-12" />}
            title="NO RESULTS FOUND"
            description={`No users found matching "${searchQuery}". Try adjusting your search criteria.`}
          />
        </CleanCard>
      )}
    </div>
  );
};

// Enhanced User Search Result Card
const EnhancedUserSearchResultCard: React.FC<UserSearchResultCardProps> = ({ user, onConnect, isLoading }) => (
  <CleanCard className="p-6 shadow-sm hover:shadow-md transition-all duration-200">
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-4">
        <div className="w-14 h-14 rounded-xl bg-gradient-to-br from-blue-500 to-indigo-500 flex items-center justify-center shadow-sm">
          <span className="text-white font-bold text-lg font-mono">
            {user.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
          </span>
        </div>
        <div>
          <div className="font-semibold text-lg text-ios-primary-text">
            {user.name}
          </div>
          <div className="flex items-center gap-3 mt-1">
            {user.rank && (
              <span className="flex items-center gap-1 text-sm text-ios-secondary-text">
                <Shield className="h-3 w-3" />
                {user.rank}
              </span>
            )}
            {user.unit && (
              <span className="flex items-center gap-1 text-sm text-ios-secondary-text">
                <Building2 className="h-3 w-3" />
                {user.unit}
              </span>
            )}
            {user.email && (
              <span className="flex items-center gap-1 text-sm text-ios-secondary-text">
                <Mail className="h-3 w-3" />
                {user.email}
              </span>
            )}
          </div>
        </div>
      </div>
      <Button
        size="sm"
        onClick={onConnect}
        disabled={isLoading}
        className="bg-ios-accent hover:bg-ios-accent/90 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 flex items-center gap-2"
      >
        {isLoading ? (
          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
        ) : (
          <>
            <UserPlus className="h-4 w-4" />
            Connect
          </>
        )}
      </Button>
    </div>
  </CleanCard>
); 