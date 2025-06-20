import React from 'react';
export declare const categoryOptions: {
    value: string;
    label: string;
}[];
export declare const getCategoryFromName: (name: string) => string;
export declare const getCategoryIcon: (name: string) => React.ReactNode;
export declare const getCategoryColor: (name: string) => string;
export declare const getCategoryLabel: (category: string) => string;
export declare const normalizeItemStatus: (status: string) => string;
