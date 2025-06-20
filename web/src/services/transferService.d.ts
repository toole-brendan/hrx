import { Transfer } from '@/types';
/**
 * Fetches all transfers from the API
 */
export declare function fetchTransfers(): Promise<Transfer[]>;
/**
 * Create a new transfer
 */
export declare function createTransfer(transferData: {
    propertyId: number;
    toUserId: number;
    includeComponents?: boolean;
    notes?: string;
}): Promise<Transfer>;
/**
 * Update the status of a transfer (approve/reject)
 */
export declare function updateTransferStatus(params: {
    id: string;
    status: 'approved' | 'rejected';
    notes?: string;
}): Promise<Transfer>;
/**
 * Get a single transfer by ID
 */
export declare function getTransferById(id: string): Promise<Transfer>;
/**
 * Delete a transfer (if permitted)
 */
export declare function deleteTransfer(id: string): Promise<void>;
/**
 * Request a transfer by serial number
 */
export declare function requestBySerial(data: {
    serialNumber: string;
    includeComponents?: boolean;
    notes?: string;
}): Promise<Transfer>;
/**
 * Create an offer to transfer property
 */
export declare function createOffer(data: {
    propertyId: number;
    recipientIds: number[];
    includeComponents?: boolean;
    notes?: string;
    expiresInDays?: number;
}): Promise<any>;
/**
 * Get active offers for the current user
 */
export declare function getActiveOffers(): Promise<any[]>;
/**
 * Accept a transfer offer
 */
export declare function acceptOffer(offerId: number): Promise<any>;
