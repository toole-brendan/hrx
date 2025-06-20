import React from 'react';
import { Transfer } from '@/types';
interface TransferRowProps {
    transfer: Transfer;
    currentUser: string;
}
declare const TransferRow: React.FC<TransferRowProps>;
export default TransferRow;
