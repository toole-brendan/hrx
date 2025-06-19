import { format, addDays, subDays } from 'date-fns';

// Date helper
const today = new Date();
const formatDate = (date: Date) => format(date, 'yyyy-MM-dd');

// Maintenance request types
export type MaintenanceStatus = 'scheduled' | 'in-progress' | 'awaiting-parts' | 'bn-level' | 'completed' | 'cancelled';
export type MaintenancePriority = 'low' | 'medium' | 'high' | 'critical';
export type MaintenanceCategory = 'weapon' | 'vehicle' | 'communication' | 'optics' | 'other';
export type MaintenanceAction = 'created' | 'updated' | 'status-change' | 'parts-ordered' | 'parts-received' | 'completed';

// Type for a maintenance item/request
export interface MaintenanceItem {
  id: string;
  itemId?: string; // Reference to inventory item if applicable
  itemName: string;
  serialNumber: string;
  category: MaintenanceCategory;
  maintenanceType?: 'scheduled' | 'corrective' | 'preventive' | 'emergency';
  status: MaintenanceStatus;
  priority: MaintenancePriority;
  description: string;
  reportedBy: string;
  reportedDate: string;
  scheduledDate?: string;
  assignedTo?: string;
  estimatedCompletionTime?: string;
  completedDate?: string;
  notes?: string;
  partsRequired?: MaintenancePart[];
}

// Type for parts needed for maintenance
interface MaintenancePart {
  id: string;
  name: string;
  partNumber: string;
  quantity: number;
  available: boolean;
  estimatedArrival?: string;
}

// Type for maintenance logs/history
export interface MaintenanceLog {
  id: string;
  maintenanceId: string;
  timestamp: string;
  action: MaintenanceAction;
  performedBy: string;
  notes: string;
}

// Type for maintenance bulletins
export interface MaintenanceBulletin {
  id: string;
  title: string;
  message: string;
  category: 'parts-shortage' | 'delay' | 'update' | 'facility' | 'general';
  affectedItems?: string[];
  postedBy: string;
  postedDate: string;
  resolvedDate?: string;
  resolved: boolean;
}

// Mock data - Maintenance Items
export const maintenanceItems: MaintenanceItem[] = [
  {
    id: "m_001",
    itemId: "wpn_001",
    itemName: "M4A1 Carbine",
    serialNumber: "M4A1-123456",
    category: "weapon",
    maintenanceType: "scheduled",
    status: "scheduled",
    priority: "medium",
    description: "Regular maintenance and cleaning required",
    reportedBy: "SFC Martinez",
    reportedDate: formatDate(subDays(today, 3)),
    scheduledDate: formatDate(addDays(today, 2)),
    notes: "Last service was 3 months ago"
  },
  {
    id: "m_002",
    itemId: "veh_001",
    itemName: "HMMWV",
    serialNumber: "HMV-987654",
    category: "vehicle",
    maintenanceType: "corrective",
    status: "in-progress",
    priority: "high",
    description: "Check engine light is on and vehicle making unusual noise during operation",
    reportedBy: "CPT Rodriguez",
    reportedDate: formatDate(subDays(today, 7)),
    scheduledDate: formatDate(subDays(today, 2)),
    assignedTo: "SPC Adams",
    estimatedCompletionTime: formatDate(addDays(today, 1))
  },
  {
    id: "m_003",
    itemId: "com_001",
    itemName: "AN/PRC-152 Radio",
    serialNumber: "PRC152-2756",
    category: "communication",
    maintenanceType: "corrective",
    status: "awaiting-parts",
    priority: "critical",
    description: "Radio intermittently loses signal during operations",
    reportedBy: "LT Johnson",
    reportedDate: formatDate(subDays(today, 10)),
    scheduledDate: formatDate(subDays(today, 5)),
    assignedTo: "SFC Williams",
    notes: "Replacement module has been ordered",
    partsRequired: [
      {
        id: "p001",
        name: "RF Module",
        partNumber: "PRC152-RF-011",
        quantity: 1,
        available: false,
        estimatedArrival: formatDate(addDays(today, 5))
      }
    ]
  },
  {
    id: "m_004",
    itemId: "opt_001",
    itemName: "AN/PVS-14 Night Vision",
    serialNumber: "PVS14-35791",
    category: "optics",
    maintenanceType: "corrective",
    status: "scheduled",
    priority: "high",
    description: "Extensive image distortion on left side of viewing area",
    reportedBy: "SSG Miller",
    reportedDate: formatDate(subDays(today, 2)),
    scheduledDate: formatDate(addDays(today, 1))
  },
  {
    id: "m_005",
    itemId: "wpn_003",
    itemName: "M249 SAW",
    serialNumber: "M249-567123",
    category: "weapon",
    maintenanceType: "preventive",
    status: "completed",
    priority: "medium",
    description: "Regular maintenance and barrel replacement",
    reportedBy: "SFC Martinez",
    reportedDate: formatDate(subDays(today, 20)),
    scheduledDate: formatDate(subDays(today, 15)),
    assignedTo: "SPC Torres",
    completedDate: formatDate(subDays(today, 14)),
    notes: "New barrel installed, weapon test-fired successfully"
  },
];

// Mock data - Maintenance Logs
export const maintenanceLogs: MaintenanceLog[] = [
  {
    id: "log_001",
    maintenanceId: "m_002",
    timestamp: format(subDays(today, 7), 'yyyy-MM-dd HH:mm:ss'),
    action: "created",
    performedBy: "CPT Rodriguez",
    notes: "Maintenance request created for HMMWV"
  },
  {
    id: "log_002",
    maintenanceId: "m_002",
    timestamp: format(subDays(today, 5), 'yyyy-MM-dd HH:mm:ss'),
    action: "status-change",
    performedBy: "SFC Ellis",
    notes: "Status changed to scheduled. Assigned to SPC Adams."
  },
];

// Mock data - Maintenance Bulletins
export const maintenanceBulletins: MaintenanceBulletin[] = [
  {
    id: "b1",
    title: "Parts Shortage: M4 Firing Pin",
    message: "We are currently experiencing a shortage of M4 firing pins. Maintenance requests requiring this part will be delayed by approximately 2 weeks.",
    category: 'parts-shortage',
    affectedItems: ["M4A1 Carbine"],
    postedBy: "SFC Wright",
    postedDate: formatDate(subDays(today, 2)),
    resolved: false
  },
  {
    id: "b2",
    title: "HMMWV Maintenance Delay",
    message: "Due to increased operational tempo, all non-critical HMMWV maintenance is being rescheduled.",
    category: 'delay',
    affectedItems: ["HMMWV"],
    postedBy: "CW2 Nelson",
    postedDate: formatDate(subDays(today, 5)),
    resolved: false
  },
];

// Stats aggregation for dashboard
export const maintenanceStats = {
  total: maintenanceItems.length,
  scheduled: maintenanceItems.filter(item => item.status === 'scheduled').length,
  inProgress: maintenanceItems.filter(item => ['in-progress', 'awaiting-parts', 'bn-level'].includes(item.status)).length,
  completed: maintenanceItems.filter(item => item.status === 'completed').length,
  cancelled: maintenanceItems.filter(item => item.status === 'cancelled').length,
  criticalPending: maintenanceItems.filter(item => 
    item.priority === 'critical' && 
    item.status !== 'completed' && 
    item.status !== 'cancelled'
  ).length
}; 