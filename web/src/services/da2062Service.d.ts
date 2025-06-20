export interface DA2062Item {
    stockNumber?: string;
    itemDescription: string;
    quantity: number;
    unitOfIssue?: string;
    serialNumber?: string;
    confidence: number;
    quantityConfidence: number;
    hasExplicitSerial: boolean;
}
export interface DA2062Form {
    unitName?: string;
    dodaac?: string;
    items: DA2062Item[];
    formNumber?: string;
    confidence: number;
    pageCount?: number;
    processedAt?: string;
}
export interface EditableDA2062Item extends DA2062Item {
    id: string;
    description: string;
    nsn: string;
    quantity: string;
    serialNumber: string;
    unit?: string;
    isSelected: boolean;
    needsVerification: boolean;
}
export interface BatchImportItem {
    name: string;
    serialNumber: string;
    nsn?: string;
    quantity: number;
    description?: string;
    unitOfIssue?: string;
    importMetadata?: {
        source: string;
        formReference?: string;
        confidence?: number;
        ocrConfidence?: number;
        serialSource?: string;
        verificationNeeded?: boolean;
        extractedAt?: string;
        pageNumber?: number;
    };
}
export interface BatchImportResponse {
    items: any[];
    created_count: number;
    failed_count: number;
    total_attempted: number;
    verified_count: number;
    verification_needed: any[];
    failed_items: Array<{
        item: BatchImportItem;
        error: string;
        reason: string;
    }>;
    summary?: any;
    message?: string;
    error?: string;
}
export interface UploadProgress {
    phase: 'uploading' | 'processing' | 'extracting' | 'parsing' | 'validating' | 'complete' | 'error';
    message: string;
    progress?: number;
}
export declare function uploadDA2062(file: File, onProgress?: (progress: UploadProgress) => void): Promise<DA2062Form>;
export declare function batchImportItems(items: BatchImportItem[]): Promise<BatchImportResponse>;
export declare function getUnverifiedItems(): Promise<any[]>;
export declare function verifyImportedItem(itemId: number, data: {
    serialNumber?: string;
    nsn?: string;
}): Promise<any>;
export declare function generateSerialNumber(baseName: string, index: number): string;
export declare function getConfidenceColor(confidence: number): string;
export declare function getConfidenceLabel(confidence: number): string;
export declare function formatNSN(nsn: string): string;
