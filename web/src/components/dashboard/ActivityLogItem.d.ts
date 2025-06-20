import React from 'react';
interface ActivityLogItemProps {
    id: string;
    title: string;
    description?: string;
    timestamp: string;
    verified?: boolean;
}
export declare function ActivityLogItem({ id, title, description, timestamp, verified }: ActivityLogItemProps): React.JSX.Element;
export {};
