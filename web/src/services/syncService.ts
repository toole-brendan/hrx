import { queryClient } from '@/lib/queryClient';
import { apiRequest } from '@/lib/queryClient';

// Sync interval in milliseconds (5 minutes)
const SYNC_INTERVAL = 5 * 60 * 1000;

let syncIntervalId: NodeJS.Timeout | null = null;

/**
 * Main sync function that handles periodic synchronization
 */
export async function syncProperties(): Promise<void> {
  console.log('Starting property sync...');
  
  try {
    // Invalidate and refetch all property-related queries
    await queryClient.invalidateQueries({ queryKey: ['/api/property'] });
    await queryClient.invalidateQueries({ queryKey: ['/api/transfers'] });
    await queryClient.invalidateQueries({ queryKey: ['/api/connections'] });
    
    console.log('Property sync completed successfully');
  } catch (error) {
    console.error('Error during property sync:', error);
  }
}

/**
 * Check if a serial number already exists
 */
export async function checkSerialExists(serialNumber: string): Promise<boolean> {
  try {
    const response = await apiRequest(
      'GET',
      `/api/property/check-serial?serial=${encodeURIComponent(serialNumber)}`
    );
    
    const data = await response.json();
    return data.exists || false;
  } catch (error) {
    console.error('Serial number check failed:', error);
    // Return false on error to allow the creation attempt
    // The backend will still catch duplicates
    return false;
  }
}

/**
 * Start periodic sync
 */
export function startPeriodicSync(): void {
  if (syncIntervalId) {
    clearInterval(syncIntervalId);
  }
  
  // Perform initial sync
  syncProperties();
  
  // Set up periodic sync
  syncIntervalId = setInterval(syncProperties, SYNC_INTERVAL);
  
  console.log(`Periodic sync started with ${SYNC_INTERVAL / 1000}s interval`);
}

/**
 * Stop periodic sync
 */
export function stopPeriodicSync(): void {
  if (syncIntervalId) {
    clearInterval(syncIntervalId);
    syncIntervalId = null;
    console.log('Periodic sync stopped');
  }
}

/**
 * Set up network connectivity listeners
 */
export function setupConnectivityListeners(): () => void {
  const handleOnline = () => {
    console.log('Network reconnected, triggering sync...');
    syncProperties();
  };
  
  const handleOffline = () => {
    console.log('Network disconnected');
  };
  
  // Add event listeners
  window.addEventListener('online', handleOnline);
  window.addEventListener('offline', handleOffline);
  
  // Return cleanup function
  return () => {
    window.removeEventListener('online', handleOnline);
    window.removeEventListener('offline', handleOffline);
  };
} 