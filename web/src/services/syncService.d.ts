/**
 * Main sync function that handles periodic synchronization
 */
export declare function syncProperties(): Promise<void>;
/**
 * Check if a serial number already exists
 */
export declare function checkSerialExists(serialNumber: string): Promise<boolean>;
/**
 * Start periodic sync
 */
export declare function startPeriodicSync(): void;
/**
 * Stop periodic sync
 */
export declare function stopPeriodicSync(): void;
/**
 * Set up network connectivity listeners
 */
export declare function setupConnectivityListeners(): () => void;
