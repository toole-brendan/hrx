import React from 'react';
import { Transfer } from '@/types';
interface TransferDetailsModalProps {
    transfer: Transfer | null;
    isOpen: boolean;
    currentUser: string;
    isUpdating: boolean;
    onClose: () => void;
    onConfirmAction: (id: string, action: 'approve' | 'reject') => void;
}
declare const TransferDetailsModal: React.FC<TransferDetailsModalProps>;
export default TransferDetailsModal;
