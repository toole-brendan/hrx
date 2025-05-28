// Blockchain service for simulating Hyperledger Fabric integration on GovCloud
// This is a mock implementation for UI demonstration purposes

import { SensitiveItem } from './sensitiveItemsData';
import { format } from 'date-fns';

// Generate a mock blockchain transaction ID
export const generateTxId = (): string => {
  return `0x${Math.random().toString(16).substr(2, 16)}`;
};

// Types for blockchain records
export interface BlockchainRecord {
  txId: string;
  timestamp: string;
  eventType: 'transfer' | 'verification' | 'status_change' | 'check_in' | 'check_out';
  itemId: string;
  serialNumber: string;
  eventData: any;
  verifiedBy?: string;
}

// Simulate recording an event to the blockchain
export const recordToBlockchain = (
  item: SensitiveItem, 
  eventType: BlockchainRecord['eventType'],
  eventData: any,
  actor: string
): BlockchainRecord => {
  // In a real implementation, this would call the Hyperledger Fabric API
  const record: BlockchainRecord = {
    txId: generateTxId(),
    timestamp: format(new Date(), "yyyy-MM-dd'T'HH:mm:ss.SSSxxx"),
    eventType,
    itemId: item.id,
    serialNumber: item.serialNumber,
    eventData,
    verifiedBy: actor
  };
  
  console.log(`[BLOCKCHAIN SIM] Recording ${eventType} for ${item.serialNumber}`, record);
  
  // Simulate storing in localStorage for demo purposes
  const existingRecords = getBlockchainRecords(item.serialNumber);
  const updatedRecords = [record, ...existingRecords];
  localStorage.setItem(`blockchain_${item.serialNumber}`, JSON.stringify(updatedRecords));
  
  return record;
};

// Get blockchain records for an item
export const getBlockchainRecords = (serialNumber: string): BlockchainRecord[] => {
  const records = localStorage.getItem(`blockchain_${serialNumber}`);
  return records ? JSON.parse(records) : [];
};

// Clear blockchain records (for demo purposes)
export const clearBlockchainRecords = (serialNumber: string): void => {
  localStorage.removeItem(`blockchain_${serialNumber}`);
};

// Check if an item is blockchain-enabled
export const isBlockchainEnabled = (item: SensitiveItem): boolean => {
  // In this demo, we'll consider these categories as blockchain-enabled
  const blockchainEnabledCategories = ['weapon', 'crypto', 'communication'];
  
  // Consider items with secret/top-secret security level as blockchain-enabled
  const highSecurityLevels = ['secret', 'top-secret'];
  
  return blockchainEnabledCategories.includes(item.category) || 
         (item.securityLevel && highSecurityLevels.includes(item.securityLevel));
}; 