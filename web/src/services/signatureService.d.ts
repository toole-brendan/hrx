export interface SignatureData {
    signature: string;
    timestamp: string;
}
export declare function uploadSignature(signatureData: string): Promise<void>;
export declare function getSignature(): Promise<string | null>;
export declare function saveSignatureLocally(signature: string): void;
export declare function getLocalSignature(): SignatureData | null;
export declare function clearLocalSignature(): void;
