import React from 'react';
interface TransferItemProps {
    id: string;
    name: string;
    source: string;
    destination?: string;
}
export declare function TransferItem({ id, name, source, destination, status, direction, onAccept, onDecline }: TransferItemProps): React.JSX.Element;
export {};
