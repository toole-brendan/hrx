import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { 
    getConnections, 
    searchUsers, 
    sendConnectionRequest,
    updateConnectionStatus 
} from '@/services/connectionService';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useToast } from '@/hooks/use-toast';
import { useAuth } from '@/contexts/AuthContext';

export const Connections: React.FC = () => {
    const [searchQuery, setSearchQuery] = useState('');
    const queryClient = useQueryClient();
    const { toast } = useToast();
    const { user } = useAuth();
    
    // Fetch existing connections
    const { data: connections = [] } = useQuery({
        queryKey: ['connections'],
        queryFn: getConnections,
    });
    
    // Search users
    const { data: searchResults = [], refetch: searchForUsers } = useQuery({
        queryKey: ['userSearch', searchQuery],
        queryFn: () => searchUsers(searchQuery),
        enabled: false,
    });
    
    // Mutations
    const sendRequestMutation = useMutation({
        mutationFn: sendConnectionRequest,
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['connections'] });
            toast({ title: 'Connection request sent' });
        },
    });
    
    const updateStatusMutation = useMutation({
        mutationFn: ({ id, status }: { id: number; status: 'accepted' | 'blocked' }) =>
            updateConnectionStatus(id, status),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: ['connections'] });
            toast({ title: 'Connection updated' });
        },
    });
    
    const pendingRequests = connections.filter(c => 
        c.connectionStatus === 'pending' && c.userId !== parseInt(user?.id || '0')
    );
    
    const acceptedConnections = connections.filter(c => 
        c.connectionStatus === 'accepted'
    );
    
    return (
        <div className="space-y-6">
            <h1 className="text-2xl font-bold">Connections</h1>
            
            {/* Search and Add */}
            <div className="bg-white p-4 rounded-lg shadow">
                <h2 className="text-lg font-semibold mb-3">Add Connection</h2>
                <div className="flex gap-2">
                    <Input
                        placeholder="Search by name, phone, or DODID"
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                    />
                    <Button onClick={() => searchForUsers()}>Search</Button>
                </div>
                
                {searchResults.length > 0 && (
                    <div className="mt-4 space-y-2">
                        {searchResults.map(user => (
                            <div key={user.id} className="flex justify-between items-center p-2 border rounded">
                                <div>
                                    <div className="font-medium">{user.name}</div>
                                    <div className="text-sm text-gray-500">
                                        {user.rank} - {user.unit}
                                    </div>
                                </div>
                                <Button 
                                    size="sm"
                                    onClick={() => sendRequestMutation.mutate(user.id)}
                                >
                                    Add
                                </Button>
                            </div>
                        ))}
                    </div>
                )}
            </div>
            
            {/* Pending Requests */}
            {pendingRequests.length > 0 && (
                <div className="bg-white p-4 rounded-lg shadow">
                    <h2 className="text-lg font-semibold mb-3">Pending Requests</h2>
                    <div className="space-y-2">
                        {pendingRequests.map(req => (
                            <div key={req.id} className="flex justify-between items-center p-2 border rounded">
                                <div>
                                    <div className="font-medium">{req.connectedUser?.name}</div>
                                    <div className="text-sm text-gray-500">
                                        {req.connectedUser?.rank} - {req.connectedUser?.unit}
                                    </div>
                                </div>
                                <div className="flex gap-2">
                                    <Button 
                                        size="sm"
                                        onClick={() => updateStatusMutation.mutate({
                                            id: req.id,
                                            status: 'accepted'
                                        })}
                                    >
                                        Accept
                                    </Button>
                                    <Button 
                                        size="sm"
                                        variant="destructive"
                                        onClick={() => updateStatusMutation.mutate({
                                            id: req.id,
                                            status: 'blocked'
                                        })}
                                    >
                                        Block
                                    </Button>
                                </div>
                            </div>
                        ))}
                    </div>
                </div>
            )}
            
            {/* Accepted Connections */}
            <div className="bg-white p-4 rounded-lg shadow">
                <h2 className="text-lg font-semibold mb-3">My Connections</h2>
                <div className="space-y-2">
                    {acceptedConnections.map(conn => (
                        <div key={conn.id} className="p-2 border rounded">
                            <div className="font-medium">{conn.connectedUser?.name}</div>
                            <div className="text-sm text-gray-500">
                                {conn.connectedUser?.rank} - {conn.connectedUser?.unit}
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
}; 