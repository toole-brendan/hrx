import React from "react";
import { Property } from "@/types";
import { PropertyBookState } from "@/lib/propertyBookReducer";
export type DisplayItem = Property & {
    assignedTo?: string;
    transferDate?: string;
    attached_components?: Array<{
        id: number;
        componentProperty: {
            name: string;
            serialNumber: string;
        };
        position?: string;
    }>;
};
type PropertyBookTableProps = {
    items: DisplayItem[];
    tab: 'assigned' | 'signedout';
    state: PropertyBookState;
    dispatch: React.Dispatch<any>;
    onItemSelect: (itemId: string) => void;
    onToggleExpand: (itemId: string) => void;
    onSelectAll: (checked: boolean) => void;
    onTransferRequest: (item: Property) => void;
    onViewDetails: (item: Property) => void;
    onRecallItem: (item: Property) => void;
    onSendMaintenanceForm: (item: Property) => void;
    onRequestSort: (key: string) => void;
    isLoading: boolean;
    error: string | null;
    StatusBadge: React.FC<{
        status: string;
    }>;
};
declare const PropertyBookTable: React.FC<PropertyBookTableProps>;
export default PropertyBookTable;
