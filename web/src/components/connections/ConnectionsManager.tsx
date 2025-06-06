import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import { 
  Search, 
  UserPlus, 
  Users, 
  Clock, 
  CheckCircle, 
  XCircle,
  Phone,
  Mail,
  Shield
} from 'lucide-react';
import { Separator } from '@/components/ui/separator';

interface User {
  id: string;
  name: string;
  rank?: string;
  unit?: string;
  phone?: string;
  email?: string;
  dodid?: string;
}

interface Connection {
  id: string;
  connectedUser: User;
  status: 'accepted' | 'pending' | 'blocked';
  createdAt: string;
}

interface ConnectionRequest {
  id: string;
  requester: User;
  status: 'pending';
  createdAt: string;
}

interface ConnectionsManagerProps {
  connections?: Connection[];
  pendingRequests?: ConnectionRequest[];
  isLoading?: boolean;
}

const useConnections = () => {
  // Mock hook - in real implementation this would fetch from API
  const [connections] = useState<Connection[]>([]);
  const [isLoading] = useState(false);
  return { data: connections, isLoading };
};

const searchUsers = async (query: string): Promise<User[]> => {
  // Mock search function - in real implementation this would call API
  return [];
};

export const ConnectionsManager: React.FC<ConnectionsManagerProps> = ({
  connections = [],
  pendingRequests = [],
  isLoading = false
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<User[]>([]);
  const [isSearching, setIsSearching] = useState(false);

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    
    setIsSearching(true);
    try {
      const results = await searchUsers(searchQuery);
      setSearchResults(results);
    } catch (error) {
      console.error('Search failed:', error);
    } finally {
      setIsSearching(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch();
    }
  };

  const handleConnect = async (userId: string) => {
    // TODO: Implement connection request
    console.log('Sending connection request to:', userId);
  };

  const handleAcceptRequest = async (requestId: string) => {
    // TODO: Implement accept connection
    console.log('Accepting connection request:', requestId);
  };

  const handleRejectRequest = async (requestId: string) => {
    // TODO: Implement reject connection
    console.log('Rejecting connection request:', requestId);
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto mb-4"></div>
          <p className="text-muted-foreground">Loading connections...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Search Section */}
      <Card className="rounded-none border-l-4 border-l-primary">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Search className="h-5 w-5" />
            Search Users
          </CardTitle>
          <CardDescription>
            Find and connect with other users by name, phone number, or DOD ID
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex gap-2">
            <Input
              placeholder="Search by name, phone, or DODID"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyPress={handleKeyPress}
              className="rounded-none"
            />
            <Button 
              onClick={handleSearch}
              disabled={isSearching || !searchQuery.trim()}
              className="rounded-none"
            >
              {isSearching ? (
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
              ) : (
                <Search className="h-4 w-4" />
              )}
            </Button>
          </div>

          {/* Search Results */}
          {searchResults.length > 0 && (
            <div className="mt-4 space-y-2">
              <h4 className="font-semibold text-sm text-muted-foreground uppercase tracking-wide">
                Search Results
              </h4>
              {searchResults.map((user) => (
                <UserSearchResult 
                  key={user.id} 
                  user={user} 
                  onConnect={() => handleConnect(user.id)} 
                />
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Pending Requests Section */}
      {pendingRequests.length > 0 && (
        <Card className="rounded-none border-l-4 border-l-warning">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Clock className="h-5 w-5 text-warning" />
              Pending Requests
              <Badge variant="secondary" className="rounded-none">
                {pendingRequests.length}
              </Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              {pendingRequests.map((request) => (
                <PendingRequestRow
                  key={request.id}
                  request={request}
                  onAccept={() => handleAcceptRequest(request.id)}
                  onReject={() => handleRejectRequest(request.id)}
                />
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* Active Connections Section */}
      <Card className="rounded-none border-l-4 border-l-success">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Users className="h-5 w-5 text-success" />
            My Network
            <Badge variant="secondary" className="rounded-none">
              {connections.length}
            </Badge>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {connections.length === 0 ? (
            <div className="text-center py-8">
              <Users className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
              <h4 className="font-semibold mb-2">No connections yet</h4>
              <p className="text-muted-foreground text-sm">
                Search for users above to start building your network
              </p>
            </div>
          ) : (
            <ConnectionsList connections={connections} />
          )}
        </CardContent>
      </Card>
    </div>
  );
};

// Supporting Components
const UserSearchResult: React.FC<{
  user: User;
  onConnect: () => void;
}> = ({ user, onConnect }) => (
  <div className="flex items-center justify-between p-3 border rounded-none hover:bg-muted/50">
    <div className="flex items-center gap-3">
      <Avatar className="h-10 w-10">
        <AvatarFallback className="rounded-none">
          {user.name.split(' ').map(n => n[0]).join('')}
        </AvatarFallback>
      </Avatar>
      <div>
        <div className="flex items-center gap-2">
          <span className="font-medium">{user.name}</span>
          {user.rank && (
            <Badge variant="outline" className="rounded-none text-xs">
              {user.rank}
            </Badge>
          )}
        </div>
        <div className="flex items-center gap-4 text-sm text-muted-foreground">
          {user.unit && <span>{user.unit}</span>}
          {user.phone && (
            <span className="flex items-center gap-1">
              <Phone className="h-3 w-3" />
              {user.phone}
            </span>
          )}
        </div>
      </div>
    </div>
    <Button size="sm" onClick={onConnect} className="rounded-none">
      <UserPlus className="h-4 w-4 mr-1" />
      Connect
    </Button>
  </div>
);

const PendingRequestRow: React.FC<{
  request: ConnectionRequest;
  onAccept: () => void;
  onReject: () => void;
}> = ({ request, onAccept, onReject }) => (
  <div className="flex items-center justify-between p-3 border rounded-none bg-warning/5">
    <div className="flex items-center gap-3">
      <Avatar className="h-10 w-10">
        <AvatarFallback className="rounded-none">
          {request.requester.name.split(' ').map(n => n[0]).join('')}
        </AvatarFallback>
      </Avatar>
      <div>
        <div className="flex items-center gap-2">
          <span className="font-medium">{request.requester.name}</span>
          {request.requester.rank && (
            <Badge variant="outline" className="rounded-none text-xs">
              {request.requester.rank}
            </Badge>
          )}
        </div>
        <p className="text-sm text-muted-foreground">
          Wants to connect • {new Date(request.createdAt).toLocaleDateString()}
        </p>
      </div>
    </div>
    <div className="flex gap-2">
      <Button size="sm" variant="outline" onClick={onReject} className="rounded-none">
        <XCircle className="h-4 w-4 mr-1" />
        Decline
      </Button>
      <Button size="sm" onClick={onAccept} className="rounded-none">
        <CheckCircle className="h-4 w-4 mr-1" />
        Accept
      </Button>
    </div>
  </div>
);

const ConnectionsList: React.FC<{ connections: Connection[] }> = ({ connections }) => (
  <div className="space-y-3">
    {connections.map((connection) => (
      <div key={connection.id} className="flex items-center justify-between p-3 border rounded-none">
        <div className="flex items-center gap-3">
          <Avatar className="h-10 w-10">
            <AvatarFallback className="rounded-none">
              {connection.connectedUser.name.split(' ').map(n => n[0]).join('')}
            </AvatarFallback>
          </Avatar>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-medium">{connection.connectedUser.name}</span>
              {connection.connectedUser.rank && (
                <Badge variant="outline" className="rounded-none text-xs">
                  {connection.connectedUser.rank}
                </Badge>
              )}
            </div>
            <div className="flex items-center gap-4 text-sm text-muted-foreground">
              {connection.connectedUser.unit && <span>{connection.connectedUser.unit}</span>}
              <span>Connected {new Date(connection.createdAt).toLocaleDateString()}</span>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <CheckCircle className="h-4 w-4 text-success" />
          <Badge variant="secondary" className="rounded-none text-xs">
            Connected
          </Badge>
        </div>
      </div>
    ))}
  </div>
);

export default ConnectionsManager; 