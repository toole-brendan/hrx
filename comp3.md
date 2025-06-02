SAMPLE CODE FOR ATTACHMENT DIAGRAM

import React, { useState, useMemo } from 'react';
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

// Mock data for demonstration
const mockProperty = {
  id: 1,
  name: "M4A1 Carbine",
  serialNumber: "M4-12345",
  category: "weapons",
  attachmentPoints: ["rail_top", "rail_side", "barrel", "grip", "stock"],
  attachedComponents: [
    {
      id: 1,
      componentPropertyId: 101,
      position: "rail_top",
      attachedAt: new Date("2024-01-15"),
      componentProperty: {
        id: 101,
        name: "ACOG 4x32 Scope",
        serialNumber: "ACOG-98765",
        category: "optics"
      },
      attachedByUser: {
        displayName: "SGT Johnson"
      }
    }
  ]
};

const mockAvailableComponents = [
  {
    id: 102,
    name: "EOTech 512 Holographic Sight",
    serialNumber: "EOT-11111",
    category: "optics",
    compatibleWith: ["M4", "M16", "AR15"]
  },
  {
    id: 103,
    name: "Vertical Foregrip",
    serialNumber: "VFG-22222",
    category: "grips",
    compatibleWith: ["M4", "M16"]
  },
  {
    id: 104,
    name: "SureFire M600 Scout Light",
    serialNumber: "SF-33333",
    category: "lights",
    compatibleWith: ["M4", "M16", "AR15"]
  },
  {
    id: 105,
    name: "KAC Suppressor",
    serialNumber: "KAC-44444",
    category: "suppressors",
    compatibleWith: ["M4A1"]
  }
];

// Main Component Manager
const ComponentManager = ({ propertyId = 1, canEdit = true, onUpdate }) => {
  const [showAttachDialog, setShowAttachDialog] = useState(false);
  const [components, setComponents] = useState(mockProperty.attachedComponents);
  const [isLoading, setIsLoading] = useState(false);

  const handleAttach = async (componentId, position, notes) => {
    setIsLoading(true);
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    const newComponent = {
      id: Date.now(),
      componentPropertyId: componentId,
      position,
      attachedAt: new Date(),
      componentProperty: mockAvailableComponents.find(c => c.id === componentId),
      attachedByUser: { displayName: "Current User" },
      notes
    };
    
    setComponents([...components, newComponent]);
    setIsLoading(false);
    setShowAttachDialog(false);
    onUpdate?.();
  };

  const handleDetach = async (componentId) => {
    if (window.confirm('Are you sure you want to detach this component?')) {
      setComponents(components.filter(c => c.componentPropertyId !== componentId));
      onUpdate?.();
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h3 className="text-lg font-semibold flex items-center gap-2">
            <Link2 className="w-5 h-5 text-gray-600" />
            Attached Components
          </h3>
          <p className="text-sm text-gray-600 mt-1">
            {components.length} component{components.length !== 1 ? 's' : ''} attached to this item
          </p>
        </div>
        
        {canEdit && (
          <button
            onClick={() => setShowAttachDialog(true)}
            className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            <Plus className="w-4 h-4" />
            Attach Component
          </button>
        )}
      </div>

      {/* Visual Diagram */}
      {mockProperty.category === 'weapons' && (
        <AttachmentDiagram 
          property={mockProperty}
          components={components}
        />
      )}

      {/* Component List */}
      {components.length === 0 ? (
        <div className="text-center py-12">
          <Package className="w-12 h-12 mx-auto mb-3 text-gray-400" />
          <p className="text-gray-600 font-medium">No components attached</p>
          {canEdit && (
            <p className="text-sm text-gray-500 mt-1">
              Click "Attach Component" to add accessories
            </p>
          )}
        </div>
      ) : (
        <div className="space-y-3 mt-6">
          {components.map((component) => (
            <ComponentCard
              key={component.id}
              component={component}
              onDetach={() => handleDetach(component.componentPropertyId)}
              canDetach={canEdit}
            />
          ))}
        </div>
      )}

      {/* Attach Dialog */}
      {showAttachDialog && (
        <AttachComponentDialog
          property={mockProperty}
          existingComponents={components}
          onClose={() => setShowAttachDialog(false)}
          onAttach={handleAttach}
          isLoading={isLoading}
        />
      )}
    </div>
  );
};

// Visual Attachment Diagram
const AttachmentDiagram = ({ property, components }) => {
  const getPositionStyle = (position) => {
    const positions = {
      rail_top: { top: '20%', left: '50%', transform: 'translateX(-50%)' },
      rail_side: { top: '50%', right: '15%', transform: 'translateY(-50%)' },
      barrel: { top: '50%', left: '10%', transform: 'translateY(-50%)' },
      grip: { bottom: '20%', left: '40%', transform: 'translateX(-50%)' },
      stock: { top: '50%', right: '5%', transform: 'translateY(-50%)' }
    };
    return positions[position] || {};
  };

  return (
    <div className="relative bg-gray-50 rounded-lg p-8 mb-6" style={{ height: '250px' }}>
      {/* Weapon Silhouette */}
      <div className="absolute inset-0 flex items-center justify-center opacity-20">
        <svg viewBox="0 0 400 150" className="w-full h-full max-w-md">
          <path
            d="M 50 75 L 350 75 L 350 85 L 300 85 L 300 95 L 250 95 L 250 85 L 100 85 L 100 95 L 80 95 L 80 85 L 50 85 Z"
            fill="currentColor"
            className="text-gray-700"
          />
        </svg>
      </div>

      {/* Attachment Points */}
      {property.attachmentPoints.map((point) => {
        const component = components.find(c => c.position === point);
        const isOccupied = !!component;
        
        return (
          <div
            key={point}
            className="absolute"
            style={getPositionStyle(point)}
          >
            <div className="text-center">
              <div className={`
                w-10 h-10 rounded-full flex items-center justify-center
                ${isOccupied ? 'bg-green-500' : 'bg-gray-300'}
                shadow-md cursor-pointer hover:scale-110 transition-transform
              `}>
                {isOccupied ? (
                  <Check className="w-5 h-5 text-white" />
                ) : (
                  <Plus className="w-5 h-5 text-gray-600" />
                )}
              </div>
              <div className="mt-1">
                <p className="text-xs font-medium">
                  {point.replace('_', ' ')}
                </p>
                {component && (
                  <p className="text-xs text-gray-600 max-w-24 truncate">
                    {component.componentProperty.name}
                  </p>
                )}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
};

// Component Card
const ComponentCard = ({ component, onDetach, canDetach }) => {
  const [showDetails, setShowDetails] = useState(false);

  return (
    <div className="border border-gray-200 rounded-lg p-4 hover:border-gray-300 transition-colors">
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
                  <span className="flex items-center gap-1">
                    <MapPin className="w-3 h-3" />
                    {component.position.replace('_', ' ')}
                  </span>
                )}
                <span>SN: {component.componentProperty.serialNumber}</span>
                {component.attachedByUser && (
                  <span>by {component.attachedByUser.displayName}</span>
                )}
              </div>
            </div>
            
            <div className="flex items-center gap-2">
              <button
                onClick={() => setShowDetails(!showDetails)}
                className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <ChevronDown className={`w-4 h-4 text-gray-600 transition-transform ${showDetails ? 'rotate-180' : ''}`} />
              </button>
              
              {canDetach && (
                <button
                  onClick={onDetach}
                  className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                >
                  <Unlink className="w-4 h-4" />
                </button>
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
    </div>
  );
};

// Attach Component Dialog
const AttachComponentDialog = ({ property, existingComponents, onClose, onAttach, isLoading }) => {
  const [searchText, setSearchText] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('all');
  const [selectedComponent, setSelectedComponent] = useState(null);
  const [selectedPosition, setSelectedPosition] = useState('');
  const [notes, setNotes] = useState('');

  const categories = ['all', 'optics', 'grips', 'lights', 'suppressors'];

  const filteredComponents = useMemo(() => {
    const existingIds = existingComponents.map(c => c.componentPropertyId);
    
    return mockAvailableComponents.filter(component => {
      // Filter out already attached components
      if (existingIds.includes(component.id)) return false;
      
      // Search filter
      const matchesSearch = searchText === '' || 
        component.name.toLowerCase().includes(searchText.toLowerCase()) ||
        component.serialNumber.toLowerCase().includes(searchText.toLowerCase());
      
      // Category filter
      const matchesCategory = selectedCategory === 'all' || 
        component.category === selectedCategory;
      
      return matchesSearch && matchesCategory;
    });
  }, [searchText, selectedCategory, existingComponents]);

  const availablePositions = useMemo(() => {
    const occupiedPositions = existingComponents.map(c => c.position);
    return property.attachmentPoints.filter(pos => !occupiedPositions.includes(pos));
  }, [property.attachmentPoints, existingComponents]);

  const handleSubmit = () => {
    if (selectedComponent && selectedPosition) {
      onAttach(selectedComponent.id, selectedPosition, notes);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-xl shadow-xl max-w-2xl w-full max-h-[90vh] overflow-hidden">
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-semibold">Attach Component</h2>
            <button
              onClick={onClose}
              className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="overflow-y-auto" style={{ maxHeight: 'calc(90vh - 200px)' }}>
          {/* Search and Filters */}
          <div className="p-6 border-b border-gray-200">
            <div className="relative mb-4">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search components..."
                value={searchText}
                onChange={(e) => setSearchText(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>

            <div className="flex gap-2">
              {categories.map((category) => (
                <button
                  key={category}
                  onClick={() => setSelectedCategory(category)}
                  className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                    selectedCategory === category
                      ? 'bg-blue-600 text-white'
                      : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
                >
                  {category.charAt(0).toUpperCase() + category.slice(1)}
                </button>
              ))}
            </div>
          </div>

          {/* Component List */}
          <div className="p-6">
            <h3 className="text-sm font-medium text-gray-700 mb-3">
              Available Components ({filteredComponents.length})
            </h3>
            
            <div className="space-y-2">
              {filteredComponents.map((component) => (
                <label
                  key={component.id}
                  className={`block p-4 border rounded-lg cursor-pointer transition-all ${
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
                        SN: {component.serialNumber} • {component.category}
                      </p>
                    </div>
                    
                    {component.compatibleWith && (
                      <div className="text-sm text-green-600 font-medium">
                        Compatible
                      </div>
                    )}
                  </div>
                </label>
              ))}
            </div>

            {filteredComponents.length === 0 && (
              <div className="text-center py-8 text-gray-500">
                No available components found
              </div>
            )}
          </div>

          {/* Position Selection */}
          {selectedComponent && (
            <div className="px-6 pb-6">
              <h3 className="text-sm font-medium text-gray-700 mb-3">
                Select Attachment Position
              </h3>
              
              {availablePositions.length === 0 ? (
                <div className="flex items-center gap-2 p-4 bg-amber-50 text-amber-800 rounded-lg">
                  <AlertCircle className="w-5 h-5" />
                  <p>No available positions. Remove existing components first.</p>
                </div>
              ) : (
                <div className="grid grid-cols-3 gap-2">
                  {availablePositions.map((position) => (
                    <label
                      key={position}
                      className={`block p-3 border rounded-lg cursor-pointer text-center transition-all ${
                        selectedPosition === position
                          ? 'border-blue-500 bg-blue-50 text-blue-700'
                          : 'border-gray-200 hover:border-gray-300'
                      }`}
                    >
                      <input
                        type="radio"
                        name="position"
                        value={position}
                        checked={selectedPosition === position}
                        onChange={() => setSelectedPosition(position)}
                        className="sr-only"
                      />
                      {position.replace('_', ' ')}
                    </label>
                  ))}
                </div>
              )}

              {/* Notes */}
              <div className="mt-4">
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  Notes (Optional)
                </label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Add any notes about this attachment..."
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  rows={3}
                />
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-gray-200 bg-gray-50">
          <div className="flex justify-end gap-3">
            <button
              onClick={onClose}
              className="px-4 py-2 text-gray-700 hover:bg-gray-200 rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={!selectedComponent || !selectedPosition || isLoading}
              className={`px-4 py-2 rounded-lg font-medium transition-colors flex items-center gap-2 ${
                selectedComponent && selectedPosition && !isLoading
                  ? 'bg-blue-600 text-white hover:bg-blue-700'
                  : 'bg-gray-300 text-gray-500 cursor-not-allowed'
              }`}
            >
              {isLoading && <Loader2 className="w-4 h-4 animate-spin" />}
              Attach Component
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ComponentManager;