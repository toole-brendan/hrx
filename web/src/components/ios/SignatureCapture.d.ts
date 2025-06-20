import React from 'react';
interface SignatureCaptureProps {
    onSave: (signatureData: string) => void;
    onCancel: () => void;
    title?: string;
    className?: string;
}
export declare const SignatureCapture: React.FC<SignatureCaptureProps>;
export {};
