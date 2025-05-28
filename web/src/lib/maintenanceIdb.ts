import { openDB } from 'idb';
import { MaintenanceItem, MaintenanceLog, MaintenanceBulletin, maintenanceItems, maintenanceLogs, maintenanceBulletins, maintenanceStats } from './maintenanceData';
import { format, addDays } from 'date-fns';

// Database name and version
const DB_NAME = 'maintenance_db';
const DB_VERSION = 1;

// Store names
const ITEMS_STORE = 'maintenance_items';
const LOGS_STORE = 'maintenance_logs';
const BULLETINS_STORE = 'maintenance_bulletins';
const STATS_STORE = 'maintenance_stats';

// Initialize the database
async function initDB() {
  return openDB(DB_NAME, DB_VERSION, {
    upgrade(db) {
      // Create stores if they don't exist
      if (!db.objectStoreNames.contains(ITEMS_STORE)) {
        db.createObjectStore(ITEMS_STORE, { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains(LOGS_STORE)) {
        db.createObjectStore(LOGS_STORE, { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains(BULLETINS_STORE)) {
        db.createObjectStore(BULLETINS_STORE, { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains(STATS_STORE)) {
        db.createObjectStore(STATS_STORE, { keyPath: 'id' });
      }
    }
  });
}

// Initialize the database with mock data if it's empty
export async function initializeMaintenanceDataIfEmpty(
  items = maintenanceItems,
  logs = maintenanceLogs,
  bulletins = maintenanceBulletins,
  stats = maintenanceStats
) {
  const db = await initDB();
  
  // Check if stores are empty
  const itemsCount = await db.count(ITEMS_STORE);
  const logsCount = await db.count(LOGS_STORE);
  const bulletinsCount = await db.count(BULLETINS_STORE);
  
  // If empty, populate with mock data
  const tx = db.transaction([ITEMS_STORE, LOGS_STORE, BULLETINS_STORE, STATS_STORE], 'readwrite');
  
  if (itemsCount === 0) {
    for (const item of items) {
      await tx.objectStore(ITEMS_STORE).add(item);
    }
    console.log(`Added ${items.length} maintenance items to IndexedDB`);
  }
  
  if (logsCount === 0) {
    for (const log of logs) {
      await tx.objectStore(LOGS_STORE).add(log);
    }
    console.log(`Added ${logs.length} maintenance logs to IndexedDB`);
  }
  
  if (bulletinsCount === 0) {
    for (const bulletin of bulletins) {
      await tx.objectStore(BULLETINS_STORE).add(bulletin);
    }
    console.log(`Added ${bulletins.length} maintenance bulletins to IndexedDB`);
  }
  
  // Always update stats (but only if they don't exist, add them)
  // Get scheduled items for upcomingMaintenance - ensure we have at least a few
  const scheduledItems = items.filter(i => i.status === 'scheduled');
  
  // Create sample upcoming maintenance data if none exists
  const upcomingMaintenance = scheduledItems.length > 0 
    ? scheduledItems
        .sort((a, b) => new Date(a.scheduledDate || '').getTime() - new Date(b.scheduledDate || '').getTime())
        .map(i => ({
          id: i.id,
          itemName: i.itemName,
          serialNumber: i.serialNumber,
          category: i.category,
          scheduledDate: i.scheduledDate,
          priority: i.priority,
          assignedTo: i.assignedTo || "Unassigned",
          status: 'scheduled'
        }))
        .slice(0, 5)
    : [
        {
          id: "m_sample_1",
          itemName: "M4A1 Carbine",
          serialNumber: "M4A1-123456",
          category: "weapon",
          scheduledDate: format(addDays(new Date(), 2), 'yyyy-MM-dd'),
          priority: "medium",
          assignedTo: "SPC Johnson",
          status: 'scheduled'
        },
        {
          id: "m_sample_2",
          itemName: "HMMWV Maintenance",
          serialNumber: "HMV-987654",
          category: "vehicle",
          scheduledDate: format(addDays(new Date(), 4), 'yyyy-MM-dd'),
          priority: "high",
          assignedTo: "SSG Rodriguez",
          status: 'scheduled'
        },
        {
          id: "m_sample_3",
          itemName: "AN/PVS-14 NVG",
          serialNumber: "NVG-12345",
          category: "optics",
          scheduledDate: format(addDays(new Date(), 7), 'yyyy-MM-dd'),
          priority: "medium",
          assignedTo: "SPC Davis",
          status: 'scheduled'
        }
      ];
  
  // Add stats with a fixed ID for easy retrieval
  const statsData = {
    id: 'maintenance_stats',
    ...stats,
    // Add more detailed stats for the dashboard
    openRequests: items.filter(i => i.status !== 'completed' && i.status !== 'cancelled').length,
    openRequestsChange: 5, // Mock change percentage
    inProgressRequests: items.filter(i => i.status === 'in-progress').length,
    inProgressChange: 10, // Mock change percentage
    completedRequests: items.filter(i => i.status === 'completed').length,
    completedChange: 15, // Mock change percentage
    averageTime: 24, // Mock average hours
    averageTimeChange: -5, // Mock improvement
    // Format categoryBreakdown as an array for the PieChart
    categoryBreakdown: [
      { category: "Weapons", count: 35 },
      { category: "Vehicles", count: 25 },
      { category: "Communications", count: 15 },
      { category: "Optics", count: 15 },
      { category: "Other", count: 10 }
    ],
    // Add statusCounts for potential future use
    statusCounts: [
      { status: "Scheduled", count: items.filter(i => i.status === 'scheduled').length },
      { status: "In Progress", count: items.filter(i => i.status === 'in-progress').length },
      { status: "Awaiting Parts", count: items.filter(i => i.status === 'awaiting-parts').length },
      { status: "Battalion Level", count: items.filter(i => i.status === 'bn-level').length },
      { status: "Completed", count: items.filter(i => i.status === 'completed').length },
      { status: "Cancelled", count: items.filter(i => i.status === 'cancelled').length }
    ],
    // Use our prepared upcomingMaintenance data
    upcomingMaintenance
  };
  
  await tx.objectStore(STATS_STORE).put(statsData);
  await tx.done;
}

// Get all maintenance items
export async function getMaintenanceItemsFromDB() {
  const db = await initDB();
  return db.getAll(ITEMS_STORE);
}

// Get maintenance item by ID
export async function getMaintenanceItemByIdFromDB(id: string) {
  const db = await initDB();
  return db.get(ITEMS_STORE, id);
}

// Get all maintenance logs
export async function getMaintenanceLogsFromDB() {
  const db = await initDB();
  return db.getAll(LOGS_STORE);
}

// Get maintenance logs by maintenance item ID
export async function getMaintenanceLogsByItemIdFromDB(maintenanceId: string) {
  const db = await initDB();
  const logs = await db.getAll(LOGS_STORE);
  return logs.filter(log => log.maintenanceId === maintenanceId);
}

// Get all maintenance bulletins
export async function getMaintenanceBulletinsFromDB() {
  const db = await initDB();
  return db.getAll(BULLETINS_STORE);
}

// Get maintenance stats
export async function getMaintenanceStatsFromDB() {
  const db = await initDB();
  return db.get(STATS_STORE, 'maintenance_stats');
}

// Add a new maintenance item
export async function addMaintenanceItemToDB(item: MaintenanceItem) {
  const db = await initDB();
  
  // Add the item
  await db.put(ITEMS_STORE, item);
  
  // Create a log entry for the new item
  const logEntry: MaintenanceLog = {
    id: `log_${Date.now()}`,
    maintenanceId: item.id,
    timestamp: format(new Date(), 'yyyy-MM-dd HH:mm:ss'),
    action: 'created',
    performedBy: item.reportedBy,
    notes: `Maintenance request created for ${item.itemName}`
  };
  
  await db.put(LOGS_STORE, logEntry);
  
  // Update stats
  await updateMaintenanceStatsInDB();
  
  return item;
}

// Update a maintenance item status
export async function updateMaintenanceItemStatusInDB(
  id: string,
  newStatus: MaintenanceItem['status'],
  performedBy: string,
  notes?: string
) {
  const db = await initDB();
  const tx = db.transaction([ITEMS_STORE, LOGS_STORE], 'readwrite');
  
  // Get the current item
  const item = await tx.objectStore(ITEMS_STORE).get(id);
  if (!item) {
    throw new Error(`Item with ID ${id} not found`);
  }
  
  // Update status and other fields
  const updatedItem = {
    ...item,
    status: newStatus,
    assignedTo: item.assignedTo || performedBy // Assign if not already assigned
  };
  
  // Add completion date if completed
  if (newStatus === 'completed') {
    updatedItem.completedDate = format(new Date(), 'yyyy-MM-dd');
  }
  
  // Save the updated item
  await tx.objectStore(ITEMS_STORE).put(updatedItem);
  
  // Create a log entry for the status change
  const logEntry: MaintenanceLog = {
    id: `log_${Date.now()}`,
    maintenanceId: id,
    timestamp: format(new Date(), 'yyyy-MM-dd HH:mm:ss'),
    action: 'status-change',
    performedBy: performedBy,
    notes: notes || `Status changed to ${newStatus}`
  };
  
  await tx.objectStore(LOGS_STORE).put(logEntry);
  
  // If it's completed, add a completed log entry too
  if (newStatus === 'completed') {
    const completedLog: MaintenanceLog = {
      id: `log_${Date.now() + 1}`,
      maintenanceId: id,
      timestamp: format(new Date(), 'yyyy-MM-dd HH:mm:ss'),
      action: 'completed',
      performedBy: performedBy,
      notes: notes || `Maintenance completed for ${item.itemName}`
    };
    
    await tx.objectStore(LOGS_STORE).put(completedLog);
  }
  
  await tx.done;
  
  // Update stats after transaction is done
  await updateMaintenanceStatsInDB();
  
  return { item: updatedItem, logs: await getMaintenanceLogsByItemIdFromDB(id) };
}

// Add a maintenance log
export async function addMaintenanceLogToDB(log: MaintenanceLog) {
  const db = await initDB();
  await db.put(LOGS_STORE, log);
  return log;
}

// Add a maintenance bulletin
export async function addMaintenanceBulletinToDB(bulletin: MaintenanceBulletin) {
  const db = await initDB();
  await db.put(BULLETINS_STORE, bulletin);
  return bulletin;
}

// Update maintenance stats based on current items
async function updateMaintenanceStatsInDB() {
  const db = await initDB();
  const tx = db.transaction([ITEMS_STORE, STATS_STORE], 'readwrite');
  
  // Get all items to calculate stats
  const items = await tx.objectStore(ITEMS_STORE).getAll();
  
  // Get existing stats
  const existingStats = await tx.objectStore(STATS_STORE).get('maintenance_stats');
  
  // Calculate updated stats
  const total = items.length;
  const scheduled = items.filter(item => item.status === 'scheduled').length;
  const inProgress = items.filter(item => item.status === 'in-progress').length;
  const completed = items.filter(item => item.status === 'completed').length;
  const cancelled = items.filter(item => item.status === 'cancelled').length;
  const awaitingParts = items.filter(item => item.status === 'awaiting-parts').length;
  const bnLevel = items.filter(item => item.status === 'bn-level').length;
  
  // Get scheduled items for upcomingMaintenance
  const scheduledItems = items.filter(i => i.status === 'scheduled');
  
  // Create sample upcoming maintenance data if none exists
  const upcomingMaintenance = scheduledItems.length > 0 
    ? scheduledItems
        .sort((a, b) => new Date(a.scheduledDate || '').getTime() - new Date(b.scheduledDate || '').getTime())
        .map(i => ({
          id: i.id,
          itemName: i.itemName,
          serialNumber: i.serialNumber,
          category: i.category,
          scheduledDate: i.scheduledDate,
          priority: i.priority,
          assignedTo: i.assignedTo || "Unassigned",
          status: 'scheduled'
        }))
        .slice(0, 5)
    : [
        {
          id: "m_sample_1",
          itemName: "M4A1 Carbine",
          serialNumber: "M4A1-123456",
          category: "weapon",
          scheduledDate: format(addDays(new Date(), 2), 'yyyy-MM-dd'),
          priority: "medium",
          assignedTo: "SPC Johnson",
          status: 'scheduled'
        },
        {
          id: "m_sample_2",
          itemName: "HMMWV Maintenance",
          serialNumber: "HMV-987654",
          category: "vehicle",
          scheduledDate: format(addDays(new Date(), 4), 'yyyy-MM-dd'),
          priority: "high",
          assignedTo: "SSG Rodriguez",
          status: 'scheduled'
        },
        {
          id: "m_sample_3",
          itemName: "AN/PVS-14 NVG",
          serialNumber: "NVG-12345",
          category: "optics",
          scheduledDate: format(addDays(new Date(), 7), 'yyyy-MM-dd'),
          priority: "medium",
          assignedTo: "SPC Davis",
          status: 'scheduled'
        }
      ];
  
  // Create updated stats object with enhanced dashboard data
  const updatedStats = {
    ...existingStats,
    total,
    scheduled,
    inProgress: inProgress + awaitingParts + bnLevel,
    completed,
    cancelled,
    criticalPending: items.filter(item => 
      item.priority === 'critical' && 
      item.status !== 'completed' && 
      item.status !== 'cancelled'
    ).length,
    openRequests: items.filter(i => i.status !== 'completed' && i.status !== 'cancelled').length,
    openRequestsChange: 5, // Mock change for demo
    inProgressRequests: inProgress,
    inProgressChange: 10, // Mock change for demo
    completedRequests: completed,
    completedChange: 15, // Mock change for demo
    averageTime: 24, // Mock average hours
    averageTimeChange: -5, // Mock improvement
    totalRequests: total, // Add totalRequests for dashboard
    pendingRequests: scheduled, // Map scheduled to pending
    overdueTasks: items.filter(i => 
      i.status !== 'completed' && 
      i.status !== 'cancelled' && 
      i.scheduledDate && 
      new Date(i.scheduledDate) < new Date()
    ).length, // Calculate overdue tasks
    // Format categoryBreakdown as an array for the PieChart
    categoryBreakdown: [
      { category: "Weapons", count: 35 },
      { category: "Vehicles", count: 25 },
      { category: "Communications", count: 15 },
      { category: "Optics", count: 15 },
      { category: "Other", count: 10 }
    ],
    // Add statusCounts for potential future use
    statusCounts: [
      { status: "Scheduled", count: scheduled },
      { status: "In Progress", count: inProgress },
      { status: "Awaiting Parts", count: awaitingParts },
      { status: "Battalion Level", count: bnLevel },
      { status: "Completed", count: completed },
      { status: "Cancelled", count: cancelled }
    ],
    // Use our prepared upcomingMaintenance data
    upcomingMaintenance
  };
  
  // Save updated stats
  await tx.objectStore(STATS_STORE).put(updatedStats);
  await tx.done;
  
  return updatedStats;
}

// Delete a maintenance item (with cascading delete of logs)
export async function deleteMaintenanceItemFromDB(id: string) {
  const db = await initDB();
  const tx = db.transaction([ITEMS_STORE, LOGS_STORE], 'readwrite');
  
  // Delete the item
  await tx.objectStore(ITEMS_STORE).delete(id);
  
  // Get all logs and delete those related to this item
  const logs = await tx.objectStore(LOGS_STORE).getAll();
  const itemLogs = logs.filter(log => log.maintenanceId === id);
  
  for (const log of itemLogs) {
    await tx.objectStore(LOGS_STORE).delete(log.id);
  }
  
  await tx.done;
  
  // Update stats
  await updateMaintenanceStatsInDB();
  
  return { success: true, deletedLogsCount: itemLogs.length };
} 