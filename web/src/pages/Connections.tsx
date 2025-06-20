import React, { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getConnections, searchUsers, sendConnectionRequest, updateConnectionStatus } from '@/services/connectionService';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useToast } from '@/hooks/use-toast';
import { useAuth } from '@/contexts/AuthContext';
import { Search, UserPlus, Users, Clock, CheckCircle, XCircle, Globe } from 'lucide-react';

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
       <div className="min-h-screen" style={{ backgroundColor: '#FAFAFA' }}>
         <MinimalLoadingView text="LOADING NETWORK" />
       </div>
     );
   }

  return (
    <div className="min-h-screen" style={{ backgroundColor: '#FAFAFA' }}>
      <div className="max-w-4xl mx-auto px-6 py-8">
        
        {/* Header - iOS style */}
        <div className="mb-10">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-6">
            <div></div>
            <div></div>
          </div>
          
          {/* Divider */}
          <div className="border-b border-ios-divider mb-6" />
          
          {/* Title section */}
          <div className="mb-8">
            <h1 className="text-5xl font-bold text-primary-text leading-tight" style={{ fontFamily: 'ui-serif, Georgia, serif' }}>
              Network
            </h1>
          </div>
        </div>

        {/* Tab selector - iOS style */}
        <div className="mb-6">
          <div className="border-b border-ios-border">
            <div className="flex justify-between items-center">
              <TabButton
                title="all"
                isSelected={selectedFilter === ConnectionFilter.ALL}
                onClick={() => setSelectedFilter(ConnectionFilter.ALL)}
                badge={connections.length}
              />
              <TabButton
                title="connected"
                isSelected={selectedFilter === ConnectionFilter.CONNECTED}
                onClick={() => setSelectedFilter(ConnectionFilter.CONNECTED)}
                badge={acceptedConnections.length}
              />
              <TabButton
                title="pending"
                isSelected={selectedFilter === ConnectionFilter.PENDING}
                onClick={() => setSelectedFilter(ConnectionFilter.PENDING)}
                badge={pendingRequests.length}
              />
            </div>
          </div>
        </div>

        {/* Search for new connections */}
        <div className="mb-6 space-y-4">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-tertiary-text" />
            <Input
              placeholder="Search for users to connect with..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={handleKeyPress}
              className="pl-10 border-0 bg-white rounded-lg h-10 text-base placeholder:text-quaternary-text focus-visible:ring-1 focus-visible:ring-ios-accent shadow-sm"
            />
            {searchQuery && (
              <Button
                onClick={handleSearchUsers}
                disabled={isSearching}
                size="sm"
                className="absolute right-2 top-1/2 transform -translate-y-1/2 bg-ios-accent hover:bg-ios-accent/90 h-7"
              >
                {isSearching ? (
                  <div className="animate-spin rounded-full h-3 w-3 border-b-2 border-white" />
                ) : (
                  "Search"
                )}
              </Button>
            )}
          </div>
          
          {/* Search Results */}
          {searchResults.length > 0 && (
            <CleanCard className="p-4">
              <div className="space-y-3">
                <div className="text-xs font-medium text-secondary-text uppercase tracking-wide">
                  Search Results
                </div>
                {searchResults.map((searchUser) => (
                  <UserSearchResultCard
                    key={searchUser.id}
                    user={searchUser}
                    onConnect={() => sendRequestMutation.mutate(searchUser.id)}
                    isLoading={sendRequestMutation.isPending}
                  />
                ))}
              </div>
            </CleanCard>
          )}
        </div>


        {/* Pending Requests Section */}
        {pendingRequests.length > 0 && (selectedFilter === ConnectionFilter.ALL || selectedFilter === ConnectionFilter.PENDING) && (
          <div className="mb-10">
            <ElegantSectionHeader 
              title="Pending Requests" 
              subtitle={`${pendingRequests.length} awaiting your response`}
              className="mb-6"
            />
            
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
            <ElegantSectionHeader 
              title={selectedFilter === ConnectionFilter.PENDING ? "Outgoing Requests" : "Connected Users"}
              subtitle={`${filteredConnections.length} in your network`}
              className="mb-6"
            />
            
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
                     <MinimalEmptyState
             title="No Connections Found"
             description={
               searchQuery.trim() 
                 ? "No connections match your search criteria. Try adjusting your search terms."
                 : selectedFilter === ConnectionFilter.ALL
                 ? "You haven't connected with anyone yet. Search for users above to start building your network."
                 : `No ${selectedFilter.toLowerCase()} connections found.`
             }
           />
        )}

        {/* Bottom padding for mobile navigation */}
        <div className="h-24"></div>
      </div>
    </div>
  );
};

// Supporting Components


// Tab Button Component (iOS style)
interface TabButtonProps {
  title: string;
  isSelected: boolean;
  onClick: () => void;
  badge?: number;
}

const TabButton: React.FC<TabButtonProps> = ({ title, isSelected, onClick, badge }) => (
  <button
    onClick={onClick}
    className="relative pb-4 transition-all duration-200"
  >
    <div className="flex items-center space-x-2">
      <span 
        className={`text-sm font-medium uppercase tracking-wider transition-colors duration-200 ${
          isSelected ? 'text-ios-accent' : 'text-tertiary-text'
        }`}
      >
        {title}
      </span>
      {badge !== undefined && badge > 0 && (
        <span className="bg-ios-destructive text-white text-[11px] font-medium px-1.5 py-0.5 rounded-full min-w-[1.25rem] text-center">
          {badge}
        </span>
      )}
    </div>
    <div 
      className={`absolute bottom-0 left-0 right-0 h-0.5 transition-all duration-200 ${
        isSelected ? 'bg-ios-accent' : 'bg-transparent'
      }`}
    />
  </button>
);

interface UserSearchResultCardProps {
  user: User;
  onConnect: () => void;
  isLoading: boolean;
}

const UserSearchResultCard: React.FC<UserSearchResultCardProps> = ({ user, onConnect, isLoading }) => (
  <CleanCard className="p-4">
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 rounded-full bg-ios-accent/10 flex items-center justify-center">
          <span className="text-ios-accent font-medium">
            {user.name?.split(' ').map(n => n[0]).join('') || '?'}
          </span>
        </div>
        <div>
          <div className="font-medium text-primary-text">
            {user.name}
          </div>
          <div className="text-sm text-secondary-text">
            {user.rank && user.unit ? `${user.rank} • ${user.unit}` : user.rank || user.unit || user.email}
          </div>
        </div>
      </div>
      <Button
        size="sm"
        onClick={onConnect}
        disabled={isLoading}
        className="bg-ios-accent hover:bg-ios-accent/90"
      >
        {isLoading ? (
          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
        ) : (
          <>
            <UserPlus className="h-4 w-4 mr-2" />
            Connect
          </>
        )}
      </Button>
    </div>
  </CleanCard>
);

interface PendingRequestCardProps {
  request: UserConnection;
  onAccept: () => void;
  onReject: () => void;
  isLoading: boolean;
}

const PendingRequestCard: React.FC<PendingRequestCardProps> = ({ request, onAccept, onReject, isLoading }) => (
  <CleanCard className="p-6">
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <div className="w-12 h-12 rounded-full bg-ios-warning/10 flex items-center justify-center">
            <span className="text-ios-warning font-medium">
              {request.connectedUser?.name?.split(' ').map(n => n[0]).join('') || '?'}
            </span>
          </div>
          <div>
            <div className="font-medium text-primary-text">
              {request.connectedUser?.name || 'Unknown User'}
            </div>
            <div className="text-sm text-secondary-text">
              {request.connectedUser?.rank && request.connectedUser?.unit 
                ? `${request.connectedUser.rank} • ${request.connectedUser.unit}`
                : request.connectedUser?.email || 'No additional info'
              }
            </div>
            <div className="text-sm text-ios-warning italic">
              Wants to connect
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <Clock className="h-4 w-4 text-ios-warning" />
          <StatusBadge status="pending" />
        </div>
      </div>
      
      <div className="flex gap-3">
        <Button
          variant="outline"
          size="sm"
          onClick={onReject}
          disabled={isLoading}
          className="flex-1 border-ios-divider"
        >
          <XCircle className="h-4 w-4 mr-2" />
          Decline
        </Button>
        <Button
          size="sm"
          onClick={onAccept}
          disabled={isLoading}
          className="flex-1 bg-ios-success hover:bg-ios-success/90"
        >
          <CheckCircle className="h-4 w-4 mr-2" />
          Accept
        </Button>
      </div>
    </div>
  </CleanCard>
);

interface ConnectionCardProps {
  connection: UserConnection;
}

const ConnectionCard: React.FC<ConnectionCardProps> = ({ connection }) => (
  <CleanCard className="p-4">
    <div className="flex items-center justify-between">
      <div className="flex items-center gap-4">
        <div className="w-12 h-12 rounded-full bg-ios-success/10 flex items-center justify-center">
          <span className="text-ios-success font-medium">
            {connection.connectedUser?.name?.split(' ').map(n => n[0]).join('') || '?'}
          </span>
        </div>
        <div>
          <div className="font-medium text-primary-text">
            {connection.connectedUser?.name || 'Unknown User'}
          </div>
          <div className="text-sm text-secondary-text">
            {connection.connectedUser?.rank && connection.connectedUser?.unit 
              ? `${connection.connectedUser.rank} • ${connection.connectedUser.unit}`
              : connection.connectedUser?.email || 'No additional info'
            }
          </div>
        </div>
      </div>
             <div className="flex items-center gap-2">
         <CheckCircle className="h-4 w-4 text-ios-success" />
         <StatusBadge status="approved" />
       </div>
    </div>
  </CleanCard>
); 