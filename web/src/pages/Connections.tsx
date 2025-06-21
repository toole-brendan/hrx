import React, { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getConnections, searchUsers, sendConnectionRequest, updateConnectionStatus } from '@/services/connectionService';
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
  Activity
} from 'lucide-react';
import { cn } from '@/lib/utils';

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

export const Connections: React.FC = () => {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedFilter, setSelectedFilter] = useState<ConnectionFilter>(ConnectionFilter.ALL);
  const [searchResults, setSearchResults] = useState<User[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [showUserDetails, setShowUserDetails] = useState<User | null>(null);
  
  const queryClient = useQueryClient();
  const { toast } = useToast();
  const { user } = useAuth();

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


     if (isLoading) {
     return (
       <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
         <div className="max-w-6xl mx-auto px-6 py-8">
           <CleanCard className="py-24 shadow-sm">
             <MinimalLoadingView text="LOADING NETWORK" />
           </CleanCard>
         </div>
       </div>
     );
   }

  return (
    <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
      <div className="max-w-6xl mx-auto px-6 py-8">
        
        {/* Enhanced Header section */}
        <div className="mb-12">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-8">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-xl shadow-sm">
                <Users className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-bold text-ios-primary-text">
                  Network
                </h1>
                <p className="text-sm text-ios-secondary-text mt-1">
                  Build your trusted network for secure property transfers
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Network Stats */}
        <NetworkStats connections={connections} />
        
        {/* Filter Pills */}
        <div className="mb-8">
          <div className="flex items-center gap-3 p-2 bg-white rounded-xl shadow-sm border border-ios-border">
            {[
              { id: ConnectionFilter.ALL, label: 'All', icon: <Users className="h-4 w-4" />, count: connections.length },
              { id: ConnectionFilter.CONNECTED, label: 'Connected', icon: <Link2 className="h-4 w-4" />, count: acceptedConnections.length },
              { id: ConnectionFilter.PENDING, label: 'Pending', icon: <Clock className="h-4 w-4" />, count: pendingRequests.length }
            ].map((filter) => (
              <button
                key={filter.id}
                onClick={() => setSelectedFilter(filter.id)}
                className={cn(
                  "flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-medium text-sm transition-all duration-200",
                  selectedFilter === filter.id
                    ? "bg-ios-accent text-white shadow-md"
                    : "bg-transparent text-ios-secondary-text hover:bg-ios-tertiary-background"
                )}
              >
                {filter.icon}
                <span>{filter.label}</span>
                {filter.count > 0 && (
                  <span className={cn(
                    "ml-1 px-2 py-0.5 rounded-full text-xs font-bold font-['Courier_New',_monospace]",
                    selectedFilter === filter.id
                      ? "bg-white/20 text-white"
                      : "bg-ios-tertiary-background text-ios-secondary-text"
                  )}>
                    {filter.count}
                  </span>
                )}
              </button>
            ))}
          </div>
        </div>

        {/* Search Section */}
        <div className="mb-8">
          <CleanCard className="p-6 shadow-sm">
            <div className="space-y-4">
              <div className="flex items-center gap-3 mb-4">
                <div className="p-2 bg-ios-accent/10 rounded-lg">
                  <UserPlus className="h-5 w-5 text-ios-accent" />
                </div>
                <div>
                  <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                    FIND NEW CONNECTIONS
                  </h3>
                  <p className="text-xs text-ios-secondary-text mt-0.5">Search by name, rank, or unit</p>
                </div>
              </div>
              <div className="relative">
                <Search className="absolute left-4 top-1/2 transform -translate-y-1/2 h-5 w-5 text-ios-tertiary-text" />
                <Input
                  placeholder="Search for users to connect with..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  onKeyPress={handleKeyPress}
                  className="pl-12 pr-4 border-ios-border bg-ios-tertiary-background/50 rounded-lg h-12 text-base placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200"
                />
                {searchQuery && (
                  <Button
                    onClick={handleSearchUsers}
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
            </div>
          </CleanCard>
          
          {/* Search Results */}
          {searchResults.length > 0 && (
            <div className="mt-4">
              <CleanCard className="p-6 shadow-sm">
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                      SEARCH RESULTS
                    </h3>
                    <span className="text-xs text-ios-secondary-text font-['Courier_New',_monospace]">
                      {searchResults.length} FOUND
                    </span>
                  </div>
                  <div className="space-y-3">
                    {searchResults.map((searchUser) => (
                      <UserSearchResultCard
                        key={searchUser.id}
                        user={searchUser}
                        onConnect={() => sendRequestMutation.mutate(searchUser.id)}
                        isLoading={sendRequestMutation.isPending}
                      />
                    ))}
                  </div>
                </div>
              </CleanCard>
            </div>
          )}
        </div>


        {/* Pending Requests Section */}
        {pendingRequests.length > 0 && (selectedFilter === ConnectionFilter.ALL || selectedFilter === ConnectionFilter.PENDING) && (
          <div className="mb-10">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-orange-500/10 rounded-lg">
                  <Clock className="h-5 w-5 text-orange-500" />
                </div>
                <div>
                  <h2 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                    PENDING REQUESTS
                  </h2>
                  <p className="text-xs text-ios-secondary-text mt-0.5">{pendingRequests.length} awaiting your response</p>
                </div>
              </div>
            </div>
            
            <div className="space-y-4">
              {pendingRequests.map((request) => (
                <PendingRequestCard
                  key={request.id}
                  request={request}
                  onAccept={() => updateStatusMutation.mutate({ id: request.id, status: 'accepted' })}
                  onReject={() => updateStatusMutation.mutate({ id: request.id, status: 'blocked' })}
                  isLoading={updateStatusMutation.isPending}
                />
              ))}
            </div>
          </div>
        )}

        {/* Connections List */}
        {filteredConnections.length > 0 ? (
          <div className="mb-10">
            <div className="flex items-center justify-between mb-6">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-green-500/10 rounded-lg">
                  <Users className="h-5 w-5 text-green-500" />
                </div>
                <div>
                  <h2 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-['Courier_New',_monospace]">
                    {selectedFilter === ConnectionFilter.PENDING ? "OUTGOING REQUESTS" : "CONNECTED USERS"}
                  </h2>
                  <p className="text-xs text-ios-secondary-text mt-0.5">{filteredConnections.length} in your network</p>
                </div>
              </div>
            </div>
            
            <div className="space-y-4">
              {filteredConnections.map((connection) => (
                <ConnectionCard
                  key={connection.id}
                  connection={connection}
                />
              ))}
            </div>
          </div>
        ) : (
          <CleanCard className="py-24 shadow-sm">
            <MinimalEmptyState
              icon={<Users className="h-12 w-12" />}
              title="NO CONNECTIONS FOUND"
              description={
                searchQuery.trim() 
                  ? "No connections match your search criteria. Try adjusting your search terms."
                  : selectedFilter === ConnectionFilter.ALL
                  ? "You haven't connected with anyone yet. Search for users above to start building your network."
                  : `No ${selectedFilter.toLowerCase()} connections found.`
              }
              action={
                selectedFilter === ConnectionFilter.ALL && !searchQuery.trim() ? (
                  <Button
                    onClick={() => setSearchQuery('')}
                    className="bg-ios-accent hover:bg-ios-accent/90 text-white rounded-lg px-6 py-2.5 font-medium shadow-sm transition-all duration-200 flex items-center gap-2"
                  >
                    <UserPlus className="h-4 w-4" />
                    Search for Users
                  </Button>
                ) : undefined
              }
            />
          </CleanCard>
        )}

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
        { label: 'Total Network', value: stats.total, icon: <Users className="h-5 w-5" />, color: 'blue' },
        { label: 'Active', value: stats.active, icon: <UserCheck className="h-5 w-5" />, color: 'green' },
        { label: 'Pending', value: stats.pending, icon: <Clock className="h-5 w-5" />, color: 'orange' },
        { label: 'Recent (7d)', value: stats.recent, icon: <Activity className="h-5 w-5" />, color: 'purple' }
      ].map((stat, idx) => (
        <div key={idx} className="bg-white rounded-xl p-4 border border-ios-border shadow-sm hover:shadow-md transition-all duration-200">
          <div className="flex items-center justify-between mb-2">
            <div className={cn(
              "p-2 rounded-lg",
              stat.color === 'blue' && "bg-blue-500/10 text-blue-500",
              stat.color === 'green' && "bg-green-500/10 text-green-500",
              stat.color === 'orange' && "bg-orange-500/10 text-orange-500",
              stat.color === 'purple' && "bg-purple-500/10 text-purple-500"
            )}>
              {stat.icon}
            </div>
            <span className="text-2xl font-bold text-ios-primary-text font-['Courier_New',_monospace]">
              {stat.value}
            </span>
          </div>
          <p className="text-xs text-ios-secondary-text">{stat.label}</p>
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
              "font-['Courier_New',_monospace]"
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
              "font-['Courier_New',_monospace]"
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
  <div className="group relative overflow-hidden rounded-xl border-2 border-transparent hover:border-blue-500/30 transition-all duration-300">
    <div className="absolute inset-0 bg-gradient-to-r from-blue-500/5 to-indigo-500/5 opacity-0 group-hover:opacity-100 transition-opacity duration-300" />
    <CleanCard className="relative p-6 shadow-sm hover:shadow-lg transition-all duration-200">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="relative">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-500 flex items-center justify-center shadow-lg">
              <span className="text-white font-bold text-lg font-['Courier_New',_monospace]">
                {user.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
              </span>
            </div>
            <div className="absolute -bottom-1 -right-1 w-4 h-4 bg-green-500 rounded-full border-2 border-white" />
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
            </div>
          </div>
        </div>
        <Button
          size="sm"
          onClick={onConnect}
          disabled={isLoading}
          className="bg-gradient-to-r from-blue-500 to-indigo-500 hover:from-blue-600 hover:to-indigo-600 text-white rounded-lg px-6 py-2.5 font-medium shadow-md hover:shadow-lg transition-all duration-200 flex items-center gap-2"
        >
          {isLoading ? (
            <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
          ) : (
            <>
              <UserPlus className="h-4 w-4" />
              <span className="font-['Courier_New',_monospace] uppercase tracking-wider text-xs">Connect</span>
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
  <CleanCard className="p-6 border border-orange-500/20 hover:border-orange-500/30 transition-all duration-200 shadow-sm hover:shadow-md bg-gradient-to-r from-orange-500/5 to-transparent">
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-orange-500/20 to-orange-500/10 flex items-center justify-center shadow-sm">
            <span className="text-orange-500 font-semibold font-['Courier_New',_monospace]">
              {request.connectedUser?.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
            </span>
          </div>
          <div>
            <div className="font-semibold text-ios-primary-text font-['Courier_New',_monospace] uppercase tracking-wider">
              {request.connectedUser?.name || 'Unknown User'}
            </div>
            <div className="text-sm text-ios-secondary-text mt-0.5">
              {request.connectedUser?.rank && request.connectedUser?.unit 
                ? `${request.connectedUser.rank} • ${request.connectedUser.unit}`
                : request.connectedUser?.email || 'No additional info'
              }
            </div>
            <div className="text-xs text-orange-500 font-semibold mt-1 font-['Courier_New',_monospace] uppercase tracking-wider">
              Connection Request
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <div className="px-3 py-1 bg-orange-500/10 text-orange-500 rounded-lg text-xs font-semibold uppercase tracking-wider font-['Courier_New',_monospace]">
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
          className="flex-1 border-ios-border hover:bg-ios-tertiary-background text-ios-secondary-text rounded-lg px-4 py-2.5 font-medium transition-all duration-200"
        >
          <XCircle className="h-4 w-4 mr-2" />
          <span className="font-['Courier_New',_monospace] uppercase tracking-wider text-xs">Decline</span>
        </Button>
        <Button
          size="sm"
          onClick={onAccept}
          disabled={isLoading}
          className="flex-1 bg-ios-success hover:bg-ios-success/90 text-white rounded-lg px-4 py-2.5 font-medium shadow-sm transition-all duration-200"
        >
          <CheckCircle className="h-4 w-4 mr-2" />
          <span className="font-['Courier_New',_monospace] uppercase tracking-wider text-xs">Accept</span>
        </Button>
      </div>
    </div>
  </CleanCard>
);

interface ConnectionCardProps {
  connection: UserConnection;
}

const ConnectionCard: React.FC<ConnectionCardProps> = ({ connection }) => (
  <div className="group relative">
    <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-500 to-indigo-500 rounded-xl opacity-0 group-hover:opacity-20 blur transition duration-300" />
    <CleanCard className="relative p-6 border-2 border-transparent hover:border-blue-500/20 transition-all duration-200 shadow-sm hover:shadow-lg">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="relative">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-400 to-emerald-500 flex items-center justify-center shadow-lg">
              <span className="text-white font-bold text-lg font-['Courier_New',_monospace]">
                {connection.connectedUser?.name?.split(' ').map(n => n[0]).join('').toUpperCase() || '?'}
              </span>
            </div>
            <div className="absolute -top-1 -right-1 flex items-center justify-center w-6 h-6 bg-emerald-500 rounded-full border-2 border-white">
              <CheckCircle className="h-3 w-3 text-white" />
            </div>
          </div>
          <div className="flex-1">
            <div className="font-semibold text-lg text-ios-primary-text">
              {connection.connectedUser?.name || 'Unknown User'}
            </div>
            <div className="flex items-center gap-3 mt-1">
              {connection.connectedUser?.rank && (
                <span className="flex items-center gap-1 text-sm text-ios-secondary-text">
                  <Shield className="h-3 w-3" />
                  {connection.connectedUser.rank}
                </span>
              )}
              {connection.connectedUser?.unit && (
                <span className="flex items-center gap-1 text-sm text-ios-secondary-text">
                  <Building2 className="h-3 w-3" />
                  {connection.connectedUser.unit}
                </span>
              )}
            </div>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <div className="px-4 py-2 bg-gradient-to-r from-emerald-500/10 to-emerald-400/10 text-emerald-600 rounded-lg text-xs font-semibold uppercase tracking-wider font-['Courier_New',_monospace] flex items-center gap-2">
            <Link2 className="h-3 w-3" />
            Connected
          </div>
        </div>
      </div>
    </CleanCard>
  </div>
); 