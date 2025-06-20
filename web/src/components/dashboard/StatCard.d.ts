import React from 'react';
interface StatCardProps {
    title: string;
    value: string | number;
    icon?: React.ReactNode;
    change?: {
        value: number;
        label: string;
        direction: 'up' | 'down' | 'neutral';
    };
    className?: string;
}
export declare function StatCard({ title, value, icon, change, className }: StatCardProps): React.JSX.Element;
export {};
