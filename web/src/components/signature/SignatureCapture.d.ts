import React from 'react';
interface SignatureCaptureProps {
    onCapture: (signature: string) => void;
    onCancel: () => void;
    isOpen: boolean;
}
export declare const SignatureCapture: React.FC<SignatureCaptureProps>;
export {};
