import React from 'react';
interface TransferTypeSelectorProps {
    onRequest: () => void;
    onOffer: () => void;
    disabled?: boolean;
}
export declare const TransferTypeSelector: React.FC<TransferTypeSelectorProps>;
export default TransferTypeSelector;
