import React, { useState } from 'react';
import { Component } from '@/types'; // Assuming types are exported from index
import { Button } from '@/components/ui/button';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Trash2, Edit, PlusCircle, X, Check, ScanLine } from 'lucide-react';

interface ComponentListProps {
  itemId: string; // ID of the parent inventory item
  components: Component[];
  onAddComponent: (newComponent: Omit<Component, 'id'>) => void;
  onUpdateComponent: (updatedComponent: Component) => void;
  onRemoveComponent: (componentId: string) => void;
}

const ComponentList: React.FC<ComponentListProps> = ({
  itemId, // We might need this later for linking or API calls
  components,
  onAddComponent,
  onUpdateComponent,
  onRemoveComponent
}) => {
  const [isAdding, setIsAdding] = useState(false);
  const [editingComponentId, setEditingComponentId] = useState<string | null>(null);
  const [newComponentData, setNewComponentData] = useState<Omit<Component, 'id'>>({
    name: '',
    quantity: 1,
    required: false,
    status: 'present',
    nsn: '',
    serialNumber: '',
    notes: ''
  });
  const [editingComponentData, setEditingComponentData] = useState<Component | null>(null);

  const handleStartAdding = () => {
    setIsAdding(true);
    setEditingComponentId(null); // Ensure not editing while adding
    setNewComponentData({ name: '', quantity: 1, required: false, status: 'present', nsn: '', serialNumber: '', notes: '' });
  };

  const handleCancelAdding = () => {
    setIsAdding(false);
  };

  const handleSaveNewComponent = () => {
    // Add basic validation if needed
    if (newComponentData.name && newComponentData.quantity > 0) {
      onAddComponent(newComponentData);
      setIsAdding(false);
    }
  };

  const handleStartEditing = (component: Component) => {
    setEditingComponentId(component.id);
    setEditingComponentData({ ...component });
    setIsAdding(false); // Ensure not adding while editing
  };

  const handleCancelEditing = () => {
    setEditingComponentId(null);
    setEditingComponentData(null);
  };

  const handleSaveEditingComponent = () => {
    if (editingComponentData) {
      onUpdateComponent(editingComponentData);
      setEditingComponentId(null);
      setEditingComponentData(null);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>, field: keyof Omit<Component, 'id'>, isEditing: boolean) => {
    const value = e.target.value;
    if (isEditing && editingComponentData) {
      setEditingComponentData({ ...editingComponentData, [field]: value });
    } else if (!isEditing) {
      setNewComponentData({ ...newComponentData, [field]: value });
    }
  };

   const handleSelectChange = (value: string, field: keyof Omit<Component, 'id'>, isEditing: boolean) => {
    if (isEditing && editingComponentData) {
      setEditingComponentData({ ...editingComponentData, [field]: value as 'present' | 'missing' | 'damaged' });
    } else if (!isEditing) {
      setNewComponentData({ ...newComponentData, [field]: value as 'present' | 'missing' | 'damaged' });
    }
  };

  const handleCheckboxChange = (checked: boolean, field: keyof Omit<Component, 'id'>, isEditing: boolean) => {
    if (isEditing && editingComponentData) {
        setEditingComponentData({ ...editingComponentData, [field]: checked });
    } else if (!isEditing) {
        setNewComponentData({ ...newComponentData, [field]: checked });
    }
  };

 const handleQuantityChange = (value: string, isEditing: boolean) => {
    const quantity = parseInt(value, 10);
    if (!isNaN(quantity) && quantity >= 0) {
        if (isEditing && editingComponentData) {
            setEditingComponentData({ ...editingComponentData, quantity });
        } else if (!isEditing) {
            setNewComponentData({ ...newComponentData, quantity });
        }
    }
 };

 const handleSimulateScanVerify = (component: Component) => {
    // Simulate successful scan: Update status to 'present'
    if (component.status !== 'present') {
        onUpdateComponent({ ...component, status: 'present' });
    }
 };

  return (
    <div className="mt-4 space-y-4">
      <h4 className="font-semibold text-md">Components (BII/COEI)</h4>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Name</TableHead>
            <TableHead>NSN</TableHead>
            <TableHead>Serial No.</TableHead>
            <TableHead className="text-center">Qty</TableHead>
            <TableHead className="text-center">Required</TableHead>
            <TableHead>Status</TableHead>
            <TableHead>Notes</TableHead>
            <TableHead className="text-right">Actions</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {components.map((component) => (
            editingComponentId === component.id ? (
              // Edit Row
              <TableRow key={`edit-${component.id}`}>
                <TableCell><Input value={editingComponentData?.name} onChange={(e) => handleInputChange(e, 'name', true)} /></TableCell>
                <TableCell><Input value={editingComponentData?.nsn || ''} onChange={(e) => handleInputChange(e, 'nsn', true)} /></TableCell>
                <TableCell><Input value={editingComponentData?.serialNumber || ''} onChange={(e) => handleInputChange(e, 'serialNumber', true)} /></TableCell>
                <TableCell><Input type="number" value={editingComponentData?.quantity} onChange={(e) => handleQuantityChange(e.target.value, true)} className="w-16 text-center" min="0" /></TableCell>
                <TableCell className="text-center"><Checkbox checked={editingComponentData?.required} onCheckedChange={(checked) => handleCheckboxChange(Boolean(checked), 'required', true)} /></TableCell>
                <TableCell>
                  <Select value={editingComponentData?.status} onValueChange={(value) => handleSelectChange(value, 'status', true)}>
                    <SelectTrigger className="w-[100px]"><SelectValue /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="present">Present</SelectItem>
                      <SelectItem value="missing">Missing</SelectItem>
                      <SelectItem value="damaged">Damaged</SelectItem>
                    </SelectContent>
                  </Select>
                </TableCell>
                <TableCell><Input value={editingComponentData?.notes || ''} onChange={(e) => handleInputChange(e, 'notes', true)} /></TableCell>
                <TableCell className="text-right space-x-1">
                  <Button variant="ghost" size="icon" onClick={handleSaveEditingComponent} title="Save Changes"><Check className="h-4 w-4 text-green-600" /></Button>
                  <Button variant="ghost" size="icon" onClick={handleCancelEditing} title="Cancel Editing"><X className="h-4 w-4 text-red-600" /></Button>
                </TableCell>
              </TableRow>
            ) : (
              // Display Row
              <TableRow key={component.id}>
                <TableCell>{component.name}</TableCell>
                <TableCell>{component.nsn || '-'}</TableCell>
                <TableCell>{component.serialNumber || '-'}</TableCell>
                <TableCell className="text-center">{component.quantity}</TableCell>
                <TableCell className="text-center">{component.required ? 'Yes' : 'No'}</TableCell>
                <TableCell>
                  <div className="flex items-center gap-2">
                    <span className={`inline-block px-2 py-1 text-xs rounded-full whitespace-nowrap ${component.status === 'present' ? 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400' : component.status === 'missing' ? 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400' : 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400'}`}>
                      {component.status}
                    </span>
                    {component.status !== 'present' && (
                      <Button variant="outline" size="icon" className="h-6 w-6" onClick={() => handleSimulateScanVerify(component)} title="Simulate Scan/Verify">
                        <ScanLine className="h-3 w-3" />
                      </Button>
                    )}
                  </div>
                </TableCell>
                <TableCell>{component.notes || '-'}</TableCell>
                <TableCell className="text-right space-x-1">
                  <Button variant="ghost" size="icon" onClick={() => handleStartEditing(component)} title="Edit Component"><Edit className="h-4 w-4" /></Button>
                  <Button variant="ghost" size="icon" onClick={() => onRemoveComponent(component.id)} title="Remove Component"><Trash2 className="h-4 w-4 text-red-500" /></Button>
                </TableCell>
              </TableRow>
            )
          ))}

          {isAdding && (
            // Add New Row
            <TableRow key="add-new">
              <TableCell><Input placeholder="Component Name" value={newComponentData.name} onChange={(e) => handleInputChange(e, 'name', false)} /></TableCell>
              <TableCell><Input placeholder="NSN (Opt.)" value={newComponentData.nsn || ''} onChange={(e) => handleInputChange(e, 'nsn', false)} /></TableCell>
              <TableCell><Input placeholder="Serial (Opt.)" value={newComponentData.serialNumber || ''} onChange={(e) => handleInputChange(e, 'serialNumber', false)} /></TableCell>
              <TableCell><Input type="number" value={newComponentData.quantity} onChange={(e) => handleQuantityChange(e.target.value, false)} className="w-16 text-center" min="1" /></TableCell>
              <TableCell className="text-center"><Checkbox checked={newComponentData.required} onCheckedChange={(checked) => handleCheckboxChange(Boolean(checked), 'required', false)} /></TableCell>
              <TableCell>
                 <Select value={newComponentData.status} onValueChange={(value) => handleSelectChange(value, 'status', false)}>
                    <SelectTrigger className="w-[100px]"><SelectValue placeholder="Status" /></SelectTrigger>
                    <SelectContent>
                      <SelectItem value="present">Present</SelectItem>
                      <SelectItem value="missing">Missing</SelectItem>
                      <SelectItem value="damaged">Damaged</SelectItem>
                    </SelectContent>
                  </Select>
              </TableCell>
              <TableCell><Input placeholder="Notes (Opt.)" value={newComponentData.notes || ''} onChange={(e) => handleInputChange(e, 'notes', false)} /></TableCell>
              <TableCell className="text-right space-x-1">
                <Button variant="ghost" size="icon" onClick={handleSaveNewComponent} title="Save New Component"><Check className="h-4 w-4 text-green-500" /></Button>
                <Button variant="ghost" size="icon" onClick={handleCancelAdding} title="Cancel Add"><X className="h-4 w-4 text-red-500" /></Button>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </Table>

      {!isAdding && (
        <Button onClick={handleStartAdding} variant="outline" size="sm" className="mt-2">
          <PlusCircle className="h-4 w-4 mr-2" /> Add Component
        </Button>
      )}
    </div>
  );
};

export default ComponentList; 