import React from 'react';
interface ComponentManagerProps {
    propertyId: number;
    canEdit: boolean;
    onUpdate?: () => void;
}
export declare const ComponentManager: React.FC<ComponentManagerProps>;
export default ComponentManager;
