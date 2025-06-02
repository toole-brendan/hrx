import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { requestBySerial } from '@/services/transferService';
import { useToast } from '@/hooks/use-toast';
import { Link2 } from 'lucide-react';

export const SerialNumberRequest: React.FC = () => {
    const [serialNumber, setSerialNumber] = useState('');
    const [includeComponents, setIncludeComponents] = useState(false);
    const [notes, setNotes] = useState('');
    const queryClient = useQueryClient();
    const { toast } = useToast();
    
    const mutation = useMutation({
        mutationFn: requestBySerial,
        onSuccess: () => {
            // Reset form
            setSerialNumber('');
            setIncludeComponents(false);
            setNotes('');
            
            // Invalidate transfers query
            queryClient.invalidateQueries({ queryKey: ['transfers'] });
            
            toast({
                title: 'Transfer Requested',
                description: 'Your transfer request has been submitted.',
            });
        },
        onError: (error: any) => {
            toast({
                title: 'Error',
                description: error?.message || 'Failed to request transfer',
                variant: 'destructive',
            });
        },
    });
    
    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        
        mutation.mutate({
            serialNumber: serialNumber.trim(),
            includeComponents: includeComponents,
            notes: notes || undefined,
        });
    };
    
    return (
        <form onSubmit={handleSubmit} className="space-y-4">
            <div>
                <Label htmlFor="serial">Serial Number</Label>
                <Input
                    id="serial"
                    value={serialNumber}
                    onChange={(e) => setSerialNumber(e.target.value)}
                    placeholder="Enter property serial number"
                    required
                    className="mt-1"
                />
            </div>
            
            <div className="flex items-center space-x-2">
                <Checkbox
                    id="include-components"
                    checked={includeComponents}
                    onCheckedChange={(checked) => setIncludeComponents(checked === true)}
                    disabled={mutation.isPending}
                />
                <Label htmlFor="include-components" className="flex items-center gap-2 cursor-pointer">
                    <Link2 className="w-4 h-4" />
                    Include attached components (if any)
                </Label>
            </div>
            
            <div>
                <Label htmlFor="notes">Notes (Optional)</Label>
                <Textarea
                    id="notes"
                    value={notes}
                    onChange={(e) => setNotes(e.target.value)}
                    placeholder="Add any notes for the request"
                    rows={3}
                    className="mt-1"
                />
            </div>
            
            <Button 
                type="submit" 
                disabled={!serialNumber.trim() || mutation.isPending}
                className="w-full"
            >
                {mutation.isPending ? 'Requesting...' : 'Request Transfer'}
            </Button>
        </form>
    );
}; 