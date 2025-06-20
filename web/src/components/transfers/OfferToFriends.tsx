import React, { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { createOffer } from '@/services/transferService';
import { useToast } from '@/hooks/use-toast';
import { Property } from '@/types';
import { getConnections } from '@/services/connectionService';

interface Props {
  property?: Property;
}

export const OfferToFriends: React.FC<Props> = ({ property }) => {
  const [selectedFriends, setSelectedFriends] = useState<number[]>([]);
  const [notes, setNotes] = useState('');
  const [expiresInDays, setExpiresInDays] = useState(7);
  const queryClient = useQueryClient();
  const { toast } = useToast();

  // Fetch connections
  const { data: connections = [], isLoading: loadingConnections } = useQuery({
    queryKey: ['connections'],
    queryFn: getConnections,
  });

  // Create offer mutation
  const mutation = useMutation({
    mutationFn: createOffer,
    onSuccess: () => {
      // Reset form
      setSelectedFriends([]);
      setNotes('');
      setExpiresInDays(7);

      // Invalidate relevant queries
      queryClient.invalidateQueries({ queryKey: ['transfers'] });

      toast({
        title: 'Offer Sent',
        description: 'Your property offer has been sent successfully.',
      });
    },
    onError: (error: Error) => {
      toast({
        title: 'Error',
        description: error?.message || 'Failed to create offer',
        variant: 'destructive',
      });
    },
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    if (!property || selectedFriends.length === 0) return;

    mutation.mutate({
      propertyId: parseInt(property.id),
      recipientIds: selectedFriends,
      notes: notes || undefined,
      expiresInDays,
    });
  };

  const toggleFriend = (friendId: number) => {
    setSelectedFriends(prev =>
      prev.includes(friendId)
        ? prev.filter(id => id !== friendId)
        : [...prev, friendId]
    );
  };

  if (!property) {
    return <div className="text-sm text-muted-foreground">Please select a property first</div>;
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <Label>Offering: {property.name}</Label>
        <p className="text-sm text-muted-foreground">
          Serial: {property.serialNumber}
        </p>
      </div>

      <div>
        <Label>Select Recipients</Label>
        <div className="mt-2 space-y-2 max-h-48 overflow-y-auto border rounded-md p-2">
          {loadingConnections ? (
            <p className="text-sm text-muted-foreground p-2">Loading connections...</p>
          ) : connections.length === 0 ? (
            <p className="text-sm text-muted-foreground p-2">
              No connections found. Add friends to send offers.
            </p>
          ) : (
            connections.map(conn => (
              <label
                key={conn.id}
                className="flex items-center space-x-2 p-2 hover:bg-accent rounded cursor-pointer"
              >
                <Checkbox
                  checked={selectedFriends.includes(conn.connectedUserId)}
                  onCheckedChange={() => toggleFriend(conn.connectedUserId)}
                />
                <div className="flex-1">
                  <div className="font-medium">
                    {conn.connectedUser?.name || 'Unknown User'}
                  </div>
                  <div className="text-sm text-muted-foreground">
                    {conn.connectedUser?.rank} - {conn.connectedUser?.unit}
                  </div>
                </div>
              </label>
            ))
          )}
        </div>
      </div>

      <div>
        <Label htmlFor="notes">Notes (Optional)</Label>
        <Textarea
          id="notes"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Add any notes about this offer"
          rows={3}
          className="mt-1"
        />
      </div>

      <div>
        <Label htmlFor="expires">Expires in (days)</Label>
        <Input
          id="expires"
          type="number"
          min={1}
          max={30}
          value={expiresInDays}
          onChange={(e) => setExpiresInDays(parseInt(e.target.value) || 7)}
          className="mt-1"
        />
      </div>

      <Button
        type="submit"
        disabled={selectedFriends.length === 0 || mutation.isPending}
        className="w-full"
      >
        {mutation.isPending ? 'Creating Offer...' : 'Send Offer'}
      </Button>
    </form>
  );
};