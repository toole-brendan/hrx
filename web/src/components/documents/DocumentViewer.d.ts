import React from 'react';
import { Document } from '@/services/documentService';
interface DocumentViewerProps {
    document: Document;
    open: boolean;
    onClose: () => void;
}
export declare const DocumentViewer: React.FC<DocumentViewerProps>;
export {};
