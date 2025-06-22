import React, { useState, useCallback, useEffect } from 'react';
import { Property } from '@/types';
import { UserConnection } from '@/services/connectionService';
import { useToast } from '@/hooks/use-toast';
import { cn } from '@/lib/utils';
import { 
  Package, 
  Users, 
  ArrowRight, 
  Search, 
  CheckCircle, 
  AlertCircle,
  Loader2,
  User,
  Hash,
  MapPin,
  Calendar
} from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { format } from 'date-fns';
import { CleanCard } from '@/components/ios';

interface DragDropTransferInterfaceProps {
  properties: Property[];
  connections: UserConnection[];
  onCreateTransfer: (data: { itemName: string; serialNumber: string; to: string }) => Promise<void>;
  isLoading?: boolean;
}

interface DraggedItem {
  property: Property;
  startX: number;
  startY: number;
}

interface DropPreview {
  connectionId: number;
  isValid: boolean;
}

export const DragDropTransferInterface: React.FC<DragDropTransferInterfaceProps> = ({
  properties,
  connections,
  onCreateTransfer,
  isLoading = false
}) => {
  const { toast } = useToast();
  const [searchTerm, setSearchTerm] = useState('');
  const [connectionSearch, setConnectionSearch] = useState('');
  const [draggedItem, setDraggedItem] = useState<DraggedItem | null>(null);
  const [dropPreview, setDropPreview] = useState<DropPreview | null>(null);
  const [isTransferring, setIsTransferring] = useState(false);

  // Filter available properties (only operational ones can be transferred)
  const transferableProperties = properties.filter(
    p => p.status === 'Operational' && p.assignedTo
  );

  // Filter properties based on search
  const filteredProperties = transferableProperties.filter(p => 
    p.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    p.serialNumber.toLowerCase().includes(searchTerm.toLowerCase()) ||
    p.category.toLowerCase().includes(searchTerm.toLowerCase())
  );

  // Filter accepted connections
  const acceptedConnections = connections.filter(
    c => c.connectionStatus === 'accepted' && c.connectedUser
  );

  // Filter connections based on search
  const filteredConnections = acceptedConnections.filter(c => 
    c.connectedUser?.name.toLowerCase().includes(connectionSearch.toLowerCase()) ||
    c.connectedUser?.rank.toLowerCase().includes(connectionSearch.toLowerCase()) ||
    c.connectedUser?.unit.toLowerCase().includes(connectionSearch.toLowerCase())
  );

  // Handle drag start
  const handleDragStart = useCallback((e: React.DragEvent, property: Property) => {
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('property/id', property.id);
    
    // Create custom drag image
    const dragImage = document.createElement('div');
    dragImage.className = 'drag-preview';
    dragImage.innerHTML = `
      <div class="flex items-center gap-2 p-3 bg-white rounded-lg shadow-lg border border-blue-500">
        <div class="p-2 bg-blue-500/10 rounded">
          <svg class="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path>
          </svg>
        </div>
        <div>
          <div class="font-semibold text-sm">${property.name}</div>
          <div class="text-xs text-gray-500">SN: ${property.serialNumber}</div>
        </div>
      </div>
    `;
    dragImage.style.position = 'absolute';
    dragImage.style.top = '-1000px';
    document.body.appendChild(dragImage);
    e.dataTransfer.setDragImage(dragImage, 150, 30);
    setTimeout(() => document.body.removeChild(dragImage), 0);
    
    setDraggedItem({
      property,
      startX: e.clientX,
      startY: e.clientY
    });
  }, []);

  // Handle drag over
  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
  }, []);

  // Handle drag enter on connection
  const handleConnectionDragEnter = useCallback((e: React.DragEvent, connectionId: number) => {
    e.preventDefault();
    setDropPreview({
      connectionId,
      isValid: true
    });
  }, []);

  // Handle drag leave on connection
  const handleConnectionDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    // Only clear if we're actually leaving the drop zone
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX;
    const y = e.clientY;
    
    if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) {
      setDropPreview(null);
    }
  }, []);

  // Handle drop on connection
  const handleDrop = useCallback(async (e: React.DragEvent, connection: UserConnection) => {
    e.preventDefault();
    
    if (!draggedItem || !connection.connectedUser) return;
    
    setIsTransferring(true);
    try {
      await onCreateTransfer({
        itemName: draggedItem.property.name,
        serialNumber: draggedItem.property.serialNumber,
        to: `${connection.connectedUser.rank} ${connection.connectedUser.name}`
      });
      
      toast({
        title: "Transfer Initiated",
        description: `Transfer request for ${draggedItem.property.name} sent to ${connection.connectedUser.rank} ${connection.connectedUser.name}`,
      });
    } catch (error) {
      toast({
        title: "Transfer Failed",
        description: error instanceof Error ? error.message : "Failed to create transfer",
        variant: "destructive"
      });
    } finally {
      setIsTransferring(false);
      setDraggedItem(null);
      setDropPreview(null);
    }
  }, [draggedItem, onCreateTransfer, toast]);

  // Handle drag end
  const handleDragEnd = useCallback(() => {
    setDraggedItem(null);
    setDropPreview(null);
  }, []);

  // Property card component
  const PropertyCard = ({ property }: { property: Property }) => (
    <div
      draggable
      onDragStart={(e) => handleDragStart(e, property)}
      onDragEnd={handleDragEnd}
      className={cn(
        "p-4 bg-white rounded-lg border-2 cursor-move transition-all duration-200",
        "hover:shadow-lg hover:border-blue-500 hover:scale-[1.02]",
        "active:scale-[0.98] active:shadow-xl",
        draggedItem?.property.id === property.id && "opacity-50 scale-95"
      )}
    >
      <div className="space-y-3">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <h4 className="font-semibold text-sm text-gray-900 line-clamp-1">
              {property.name}
            </h4>
            <p className="text-xs text-gray-500 mt-0.5 font-mono">
              SN: {property.serialNumber}
            </p>
          </div>
          <Badge 
            variant="secondary" 
            className="text-xs bg-blue-50 text-blue-700 border-blue-200"
          >
            {property.category}
          </Badge>
        </div>
        
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="flex items-center gap-1 text-gray-600">
            <MapPin className="w-3 h-3" />
            <span className="truncate">{property.location}</span>
          </div>
          {property.assignedDate && (
            <div className="flex items-center gap-1 text-gray-600">
              <Calendar className="w-3 h-3" />
              <span>{format(new Date(property.assignedDate), 'MMM d')}</span>
            </div>
          )}
        </div>
        
        {property.components && property.components.length > 0 && (
          <div className="text-xs text-gray-500">
            +{property.components.length} component{property.components.length > 1 ? 's' : ''}
          </div>
        )}
      </div>
    </div>
  );

  // Connection card component
  const ConnectionCard = ({ connection }: { connection: UserConnection }) => {
    const isDropTarget = dropPreview?.connectionId === connection.id;
    
    return (
      <div
        onDragOver={handleDragOver}
        onDragEnter={(e) => handleConnectionDragEnter(e, connection.id)}
        onDragLeave={handleConnectionDragLeave}
        onDrop={(e) => handleDrop(e, connection)}
        className={cn(
          "p-4 rounded-lg border-2 transition-all duration-200",
          isDropTarget
            ? "border-blue-500 bg-blue-50 shadow-lg scale-[1.02]"
            : "border-gray-200 bg-gray-50 hover:border-gray-300",
          "relative overflow-hidden"
        )}
      >
        {isDropTarget && (
          <div className="absolute inset-0 bg-blue-500/5 animate-pulse" />
        )}
        
        <div className="relative z-10 flex items-center gap-3">
          <div className={cn(
            "p-3 rounded-full transition-all duration-200",
            isDropTarget ? "bg-blue-500 text-white" : "bg-white text-gray-600"
          )}>
            <User className="w-5 h-5" />
          </div>
          
          <div className="flex-1">
            <h4 className="font-semibold text-sm text-gray-900">
              {connection.connectedUser?.rank} {connection.connectedUser?.name}
            </h4>
            <p className="text-xs text-gray-500">
              {connection.connectedUser?.unit}
            </p>
          </div>
          
          {isDropTarget && (
            <div className="flex items-center gap-2 text-blue-600">
              <ArrowRight className="w-5 h-5 animate-bounce-horizontal" />
              <span className="text-xs font-medium">Drop to transfer</span>
            </div>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-semibold text-gray-900">
            Drag & Drop Transfer
          </h2>
          <p className="text-sm text-gray-500 mt-1">
            Drag property items onto connections to initiate transfers
          </p>
        </div>
        {isTransferring && (
          <div className="flex items-center gap-2 text-blue-600">
            <Loader2 className="w-4 h-4 animate-spin" />
            <span className="text-sm">Creating transfer...</span>
          </div>
        )}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Properties Section */}
        <div className="space-y-4">
          <CleanCard className="p-4">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Package className="w-5 h-5 text-gray-600" />
                <h3 className="font-semibold text-gray-900">Your Properties</h3>
                <Badge variant="secondary" className="text-xs">
                  {filteredProperties.length} items
                </Badge>
              </div>
            </div>
            
            <div className="relative mb-4">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <Input
                placeholder="Search properties..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10"
              />
            </div>
            
            <div className="space-y-3 max-h-[600px] overflow-y-auto pr-2">
              {filteredProperties.length === 0 ? (
                <div className="text-center py-12 text-gray-500">
                  <Package className="w-12 h-12 mx-auto mb-3 opacity-20" />
                  <p className="text-sm">No transferable properties found</p>
                </div>
              ) : (
                filteredProperties.map(property => (
                  <PropertyCard key={property.id} property={property} />
                ))
              )}
            </div>
          </CleanCard>
        </div>

        {/* Connections Section */}
        <div className="space-y-4">
          <CleanCard className="p-4">
            <div className="flex items-center justify-between mb-4">
              <div className="flex items-center gap-2">
                <Users className="w-5 h-5 text-gray-600" />
                <h3 className="font-semibold text-gray-900">Your Connections</h3>
                <Badge variant="secondary" className="text-xs">
                  {filteredConnections.length} connections
                </Badge>
              </div>
            </div>
            
            <div className="relative mb-4">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
              <Input
                placeholder="Search connections..."
                value={connectionSearch}
                onChange={(e) => setConnectionSearch(e.target.value)}
                className="pl-10"
              />
            </div>
            
            <div className="space-y-3 max-h-[600px] overflow-y-auto pr-2">
              {filteredConnections.length === 0 ? (
                <div className="text-center py-12 text-gray-500">
                  <Users className="w-12 h-12 mx-auto mb-3 opacity-20" />
                  <p className="text-sm">No connections found</p>
                </div>
              ) : (
                filteredConnections.map(connection => (
                  <ConnectionCard key={connection.id} connection={connection} />
                ))
              )}
            </div>
          </CleanCard>
        </div>
      </div>

      {/* Instructions */}
      <Card className="p-4 bg-blue-50 border-blue-200">
        <div className="flex items-start gap-3">
          <AlertCircle className="w-5 h-5 text-blue-600 flex-shrink-0 mt-0.5" />
          <div className="text-sm text-blue-900">
            <p className="font-medium mb-1">How to use:</p>
            <ol className="list-decimal list-inside space-y-1 text-blue-800">
              <li>Find the property you want to transfer in the left panel</li>
              <li>Drag the property card</li>
              <li>Drop it onto the connection you want to transfer to</li>
              <li>The transfer request will be created automatically</li>
            </ol>
          </div>
        </div>
      </Card>
    </div>
  );
};

// Add CSS for custom drag animation
const style = document.createElement('style');
style.textContent = `
  @keyframes bounce-horizontal {
    0%, 100% { transform: translateX(0); }
    50% { transform: translateX(4px); }
  }
  
  .animate-bounce-horizontal {
    animation: bounce-horizontal 1s ease-in-out infinite;
  }
  
  .drag-preview {
    pointer-events: none;
  }
`;
document.head.appendChild(style);