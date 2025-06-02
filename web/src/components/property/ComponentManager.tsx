import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { 
  Link2, 
  Unlink, 
  Plus, 
  Search,
  MapPin,
  Package,
  Check,
  X,
  ChevronDown,
  AlertCircle,
  Loader2
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { useToast } from '@/hooks/use-toast';

interface PropertyComponent {
  id: number;
  parentPropertyId: number;
  componentPropertyId: number;
  attachedAt: string;
  attachedByUserId: number;
  notes?: string;
  attachmentType: string;
  position?: string;
  componentProperty: {
    id: number;
    name: string;
    serialNumber: string;
    category?: string;
  };
  attachedByUser?: {
    id: number;
    name: string;
  };
}

interface AttachComponentRequest {
  componentId: number;
  position?: string;
  notes?: string;
}

interface ComponentManagerProps {
  propertyId: number;
  canEdit: boolean;
  onUpdate?: () => void;
}

// API service methods
const componentAPI = {
  async getPropertyComponents(propertyId: number): Promise<PropertyComponent[]> {
    const response = await fetch(`/api/properties/${propertyId}/components`, {
      credentials: 'include',
    });
    if (!response.ok) throw new Error('Failed to fetch components');
    const data = await response.json();
    return data.components || [];
  },

  async attachComponent(propertyId: number, request: AttachComponentRequest): Promise<PropertyComponent> {
    const response = await fetch(`/api/properties/${propertyId}/components`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({
        component_id: request.componentId,
        position: request.position,
        notes: request.notes,
      }),
    });
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to attach component');
    }
    const data = await response.json();
    return data.attachment;
  },

  async detachComponent(propertyId: number, componentId: number): Promise<void> {
    const response = await fetch(`/api/properties/${propertyId}/components/${componentId}`, {
      method: 'DELETE',
      credentials: 'include',
    });
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to detach component');
    }
  },

  async getAvailableComponents(propertyId: number): Promise<any[]> {
    const response = await fetch(`/api/properties/${propertyId}/available-components`, {
      credentials: 'include',
    });
    if (!response.ok) throw new Error('Failed to fetch available components');
    const data = await response.json();
    return data.availableComponents || [];
  },

  async updateComponentPosition(propertyId: number, componentId: number, position: string): Promise<void> {
    const response = await fetch(`/api/properties/${propertyId}/components/${componentId}/position`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ position }),
    });
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || 'Failed to update position');
    }
  },
};

export const ComponentManager: React.FC<ComponentManagerProps> = ({
  propertyId,
  canEdit,
  onUpdate
}) => {
  const [showAttachDialog, setShowAttachDialog] = useState(false);
  const queryClient = useQueryClient();
  const { toast } = useToast();
  
  const { data: components = [], refetch } = useQuery({
    queryKey: ['property-components', propertyId],
    queryFn: () => componentAPI.getPropertyComponents(propertyId),
    staleTime: 5 * 60 * 1000,
  });
  
  const attachMutation = useMutation({
    mutationFn: (data: AttachComponentRequest) => 
      componentAPI.attachComponent(propertyId, data),
    onSuccess: () => {
      refetch();
      onUpdate?.();
      setShowAttachDialog(false);
      toast({
        title: 'Component Attached',
        description: 'Component has been successfully attached.',
      });
    },
    onError: (error: Error) => {
      toast({
        title: 'Error',
        description: error.message,
        variant: 'destructive',
      });
    },
  });
  
  const detachMutation = useMutation({
    mutationFn: (componentId: number) => 
      componentAPI.detachComponent(propertyId, componentId),
    onSuccess: () => {
      refetch();
      onUpdate?.();
      toast({
        title: 'Component Detached',
        description: 'Component has been successfully detached.',
      });
    },
    onError: (error: Error) => {
      toast({
        title: 'Error',
        description: error.message,
        variant: 'destructive',
      });
    },
  });
  
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-lg font-semibold flex items-center gap-2">
          <Link2 className="w-5 h-5 text-gray-600" />
          Attached Components
        </h3>
        
        {canEdit && (
          <Button
            onClick={() => setShowAttachDialog(true)}
            size="sm"
            variant="outline"
            disabled={attachMutation.isPending}
          >
            <Plus className="w-4 h-4 mr-1" />
            Attach Component
          </Button>
        )}
      </div>
      
      {components.length === 0 ? (
        <div className="text-center py-8 text-gray-500">
          <Package className="w-12 h-12 mx-auto mb-2 opacity-50" />
          <p className="font-medium">No components attached</p>
          {canEdit && (
            <p className="text-sm mt-1">
              Click "Attach Component" to add accessories
            </p>
          )}
        </div>
      ) : (
        <div className="space-y-2">
          {components.map((component) => (
            <ComponentCard
              key={component.id}
              component={component}
              onDetach={() => detachMutation.mutate(component.componentPropertyId)}
              canDetach={canEdit}
              isDetaching={detachMutation.isPending}
            />
          ))}
        </div>
      )}
      
      {showAttachDialog && (
        <AttachComponentDialog
          propertyId={propertyId}
          onClose={() => setShowAttachDialog(false)}
          onAttach={(componentId, position, notes) => {
            attachMutation.mutate({ componentId, position, notes });
          }}
          isLoading={attachMutation.isPending}
        />
      )}
    </div>
  );
};

interface ComponentCardProps {
  component: PropertyComponent;
  onDetach: () => void;
  canDetach: boolean;
  isDetaching: boolean;
}

const ComponentCard: React.FC<ComponentCardProps> = ({ 
  component, 
  onDetach, 
  canDetach, 
  isDetaching 
}) => {
  const [showDetails, setShowDetails] = useState(false);

  return (
    <Card>
      <CardContent className="p-4">
        <div className="flex items-start gap-4">
          <div className="w-12 h-12 bg-blue-50 rounded-lg flex items-center justify-center flex-shrink-0">
            <Package className="w-6 h-6 text-blue-600" />
          </div>
          
          <div className="flex-1 min-w-0">
            <div className="flex items-start justify-between gap-4">
              <div className="flex-1">
                <h4 className="font-medium text-gray-900">
                  {component.componentProperty.name}
                </h4>
                <div className="flex flex-wrap items-center gap-3 mt-1 text-sm text-gray-600">
                  {component.position && (
                    <Badge variant="secondary" className="flex items-center gap-1">
                      <MapPin className="w-3 h-3" />
                      {component.position.replace('_', ' ')}
                    </Badge>
                  )}
                  <span>SN: {component.componentProperty.serialNumber}</span>
                  {component.attachedByUser && (
                    <span>by {component.attachedByUser.name}</span>
                  )}
                </div>
              </div>
              
              <div className="flex items-center gap-2">
                <Button
                  onClick={() => setShowDetails(!showDetails)}
                  size="sm"
                  variant="ghost"
                >
                  <ChevronDown className={`w-4 h-4 text-gray-600 transition-transform ${showDetails ? 'rotate-180' : ''}`} />
                </Button>
                
                {canDetach && (
                  <Button
                    onClick={onDetach}
                    size="sm"
                    variant="ghost"
                    disabled={isDetaching}
                    className="text-red-600 hover:bg-red-50 hover:text-red-700"
                  >
                    {isDetaching ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <Unlink className="w-4 h-4" />
                    )}
                  </Button>
                )}
              </div>
            </div>
            
            {showDetails && (
              <div className="mt-3 pt-3 border-t border-gray-100">
                <dl className="grid grid-cols-2 gap-2 text-sm">
                  <div>
                    <dt className="text-gray-600">Attached</dt>
                    <dd className="font-medium">
                      {new Date(component.attachedAt).toLocaleDateString()}
                    </dd>
                  </div>
                  <div>
                    <dt className="text-gray-600">Type</dt>
                    <dd className="font-medium capitalize">
                      {component.attachmentType}
                    </dd>
                  </div>
                  {component.notes && (
                    <div className="col-span-2">
                      <dt className="text-gray-600">Notes</dt>
                      <dd className="mt-1">{component.notes}</dd>
                    </div>
                  )}
                </dl>
              </div>
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
};

interface AttachComponentDialogProps {
  propertyId: number;
  onClose: () => void;
  onAttach: (componentId: number, position?: string, notes?: string) => void;
  isLoading: boolean;
}

const AttachComponentDialog: React.FC<AttachComponentDialogProps> = ({
  propertyId,
  onClose,
  onAttach,
  isLoading
}) => {
  const [searchText, setSearchText] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedComponent, setSelectedComponent] = useState<any>(null);
  const [selectedPosition, setSelectedPosition] = useState('');
  const [notes, setNotes] = useState('');

  const { data: availableComponents = [] } = useQuery({
    queryKey: ['available-components', propertyId],
    queryFn: () => componentAPI.getAvailableComponents(propertyId),
  });

  const categories = ['all', 'optics', 'grips', 'lights', 'suppressors', 'other'];

  const filteredComponents = availableComponents.filter(component => {
    const matchesSearch = searchText === '' || 
      component.name.toLowerCase().includes(searchText.toLowerCase()) ||
      component.serialNumber.toLowerCase().includes(searchText.toLowerCase());
    
    const matchesCategory = selectedCategory === 'all' || 
      (component.category && component.category.toLowerCase() === selectedCategory);
    
    return matchesSearch && matchesCategory;
  });

  const handleSubmit = () => {
    if (selectedComponent) {
      onAttach(selectedComponent.id, selectedPosition || undefined, notes || undefined);
    }
  };

  return (
    <Dialog open onOpenChange={onClose}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-hidden">
        <DialogHeader>
          <DialogTitle>Attach Component</DialogTitle>
        </DialogHeader>

        <div className="overflow-y-auto flex-1">
          {/* Search and Filters */}
          <div className="space-y-4 mb-6">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <Input
                placeholder="Search components..."
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                className="pl-10"
              />
            </div>

            <div className="flex gap-2 flex-wrap">
              {categories.map((category) => (
                <Button
                  key={category}
                  onClick={() => setSelectedCategory(category)}
                  variant={selectedCategory === category ? "default" : "outline"}
                  size="sm"
                >
                  {category.charAt(0).toUpperCase() + category.slice(1)}
                </Button>
              ))}
            </div>
          </div>

          {/* Component List */}
          <div className="space-y-2 mb-6">
            <h4 className="text-sm font-medium text-gray-700">
              Available Components ({filteredComponents.length})
            </h4>
            
            {filteredComponents.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <Package className="w-8 h-8 mx-auto mb-2 opacity-50" />
                <p>No available components found</p>
              </div>
            ) : (
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {filteredComponents.map((component) => (
                  <label
                    key={component.id}
                    className={`block p-3 border rounded-lg cursor-pointer transition-all ${
                      selectedComponent?.id === component.id
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                  >
                    <input
                      type="radio"
                      name="component"
                      value={component.id}
                      checked={selectedComponent?.id === component.id}
                      onChange={() => setSelectedComponent(component)}
                      className="sr-only"
                    />
                    
                    <div className="flex items-center gap-3">
                      <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${
                        selectedComponent?.id === component.id ? 'bg-blue-600' : 'bg-gray-100'
                      }`}>
                        <Package className={`w-5 h-5 ${
                          selectedComponent?.id === component.id ? 'text-white' : 'text-gray-600'
                        }`} />
                      </div>
                      
                      <div className="flex-1">
                        <p className="font-medium">{component.name}</p>
                        <p className="text-sm text-gray-600">
                          SN: {component.serialNumber}
                          {component.category && ` • ${component.category}`}
                        </p>
                      </div>
                      
                      {component.compatibleWith && (
                        <Badge variant="secondary" className="text-xs">
                          Compatible
                        </Badge>
                      )}
                    </div>
                  </label>
                ))}
              </div>
            )}
          </div>

          {/* Position and Notes */}
          {selectedComponent && (
            <div className="space-y-4">
              <div>
                <Label htmlFor="position">Attachment Position (Optional)</Label>
                <Input
                  id="position"
                  placeholder="e.g., rail_top, rail_side, barrel"
                  value={selectedPosition}
                  onChange={(e) => setSelectedPosition(e.target.value)}
                />
              </div>

              <div>
                <Label htmlFor="notes">Notes (Optional)</Label>
                <Textarea
                  id="notes"
                  placeholder="Add any notes about this attachment..."
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  rows={3}
                />
              </div>
            </div>
          )}
        </div>

        <DialogFooter>
          <Button onClick={onClose} variant="outline">
            Cancel
          </Button>
          <Button
            onClick={handleSubmit}
            disabled={!selectedComponent || isLoading}
          >
            {isLoading && <Loader2 className="w-4 h-4 mr-2 animate-spin" />}
            Attach Component
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default ComponentManager; 