export declare const generateTxId: () => string;
export interface BlockchainRecord {
    txId: string;
    timestamp: string;
    eventType: 'transfer' | 'verification' | 'status_change' | 'check_in' | 'check_out';
    itemId: string;
    serialNumber: string;
    eventData: any;
    verifiedBy?: string;
}
export declare const recordToBlockchain: (item: SensitiveItem, eventType: BlockchainRecord["eventType"], eventData: any, actor: string) => BlockchainRecord;
export declare const getBlockchainRecords: (serialNumber: string) => BlockchainRecord[];
export declare const clearBlockchainRecords: (serialNumber: string) => void;
export declare const isBlockchainEnabled: (item: SensitiveItem) => boolean;
