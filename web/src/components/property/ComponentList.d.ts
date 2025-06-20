import React from 'react';
import { Component } from '@/types';
interface ComponentListProps {
    itemId: string;
    components: Component[];
    onAddComponent: (newComponent: Omit<Component, 'id'>) => void;
    onUpdateComponent: (updatedComponent: Component) => void;
    onRemoveComponent: (componentId: string) => void;
}
declare const ComponentList: React.FC<ComponentListProps>;
export default ComponentList;
