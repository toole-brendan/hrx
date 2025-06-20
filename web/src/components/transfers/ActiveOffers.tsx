import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getActiveOffers, acceptOffer } from '@/services/transferService';
import { useToast } from '@/hooks/use-toast';
import { formatDistanceToNow } from 'date-fns';

// Define the offer type based on backend structure
interface TransferOffer {
  id: number;
  property: {
    id: number;
    name: string;
    serialNumber: string;
  };
  offeringUser: {
    id: number;
    name: string;
    rank: string;
  };
  notes?: string;
  expiresAt?: string;
  createdAt: string;
}

export const ActiveOffers: React.FC = () => {
  const queryClient = useQueryClient();
  const { toast } = useToast();

  // Fetch active offers
  const { data: offers = [], isLoading } = useQuery<TransferOffer[]>({
    queryKey: ['activeOffers'],
    queryFn: getActiveOffers,
    refetchInterval: 30000, // Refresh every 30 seconds
  });

  // Accept offer mutation
  const acceptMutation = useMutation({
    mutationFn: acceptOffer,
    onSuccess: () => {
      // Invalidate queries
      queryClient.invalidateQueries({ queryKey: ['activeOffers'] });
      queryClient.invalidateQueries({ queryKey: ['transfers'] });
      queryClient.invalidateQueries({ queryKey: ['property'] });

      toast({
        title: 'Offer Accepted',
        description: 'The property transfer has been accepted.',
      });
    },
    onError: (error: Error) => {
      toast({
        title: 'Error',
        description: error?.message || 'Failed to accept offer',
        variant: 'destructive',
      });
    },
  });

  if (isLoading) {
    return null;
  }

  if (offers.length === 0) {
    return null;
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Offers for You</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {offers.map(offer => (
            <div key={offer.id} className="border rounded-lg p-4">
              <div className="flex justify-between items-start">
                <div>
                  <h4 className="font-semibold">{offer.property.name}</h4>
                  <p className="text-sm text-muted-foreground">
                    Serial: {offer.property.serialNumber}
                  </p>
                  <p className="text-sm mt-1">
                    From: {offer.offeringUser.name} ({offer.offeringUser.rank})
                  </p>
                  {offer.notes && (
                    <p className="text-sm mt-2 italic">{offer.notes}</p>
                  )}
                  {offer.expiresAt && (
                    <p className="text-sm text-muted-foreground mt-1">
                      Expires {formatDistanceToNow(new Date(offer.expiresAt), { addSuffix: true })}
                    </p>
                  )}
                </div>
                <Button
                  size="sm"
                  onClick={() => acceptMutation.mutate(offer.id)}
                  disabled={acceptMutation.isPending}
                >
                  Accept
                </Button>
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
};