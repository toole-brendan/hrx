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
  itemId?: string;  // Reference to inventory item if applicable
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
  {
    id: "m_006",
    itemId: "veh_002",
    itemName: "MRAP Vehicle",
    serialNumber: "MRAP-372859",
    category: "vehicle",
    maintenanceType: "emergency",
    status: "in-progress",
    priority: "critical",
    description: "Hydraulic system failure in rear access door",
    reportedBy: "CPT Rodriguez",
    reportedDate: formatDate(subDays(today, 1)),
    assignedTo: "SSG Thompson",
    estimatedCompletionTime: formatDate(addDays(today, 1)),
    partsRequired: [
      {
        id: "p002",
        name: "Hydraulic Pump",
        partNumber: "MRAP-HYD-225",
        quantity: 1,
        available: true
      },
      {
        id: "p003",
        name: "Hydraulic Fluid",
        partNumber: "HYD-FLUID-MIL",
        quantity: 5,
        available: true
      }
    ]
  },
  {
    id: "m_007",
    itemId: "opt_002",
    itemName: "ACOG Sight",
    serialNumber: "ACOG-987123",
    category: "optics",
    maintenanceType: "corrective",
    status: "completed",
    priority: "medium",
    description: "Reticle illumination not working",
    reportedBy: "SGT Davis",
    reportedDate: formatDate(subDays(today, 15)),
    scheduledDate: formatDate(subDays(today, 10)),
    assignedTo: "SPC Parker",
    completedDate: formatDate(subDays(today, 8)),
    notes: "Battery housing repaired, illumination restored"
  },
  {
    id: "m_008",
    itemId: "com_002",
    itemName: "SATCOM Terminal",
    serialNumber: "SATCOM-456789",
    category: "communication",
    maintenanceType: "scheduled",
    status: "scheduled",
    priority: "high",
    description: "Quarterly maintenance and calibration",
    reportedBy: "CW2 Nelson",
    reportedDate: formatDate(subDays(today, 5)),
    scheduledDate: formatDate(addDays(today, 5))
  },
  {
    id: "m_009",
    itemId: "veh_003",
    itemName: "M1078 LMTV",
    serialNumber: "LMTV-789456",
    category: "vehicle",
    maintenanceType: "corrective",
    status: "bn-level",
    priority: "high",
    description: "Transmission slipping during gear shifts",
    reportedBy: "SFC Washington",
    reportedDate: formatDate(subDays(today, 12)),
    scheduledDate: formatDate(subDays(today, 5)),
    notes: "Requires battalion maintenance support"
  },
  {
    id: "m_010",
    itemId: "wpn_005",
    itemName: "M240B Machine Gun",
    serialNumber: "M240B-321654",
    category: "weapon",
    maintenanceType: "preventive",
    status: "scheduled",
    priority: "medium",
    description: "Preventive maintenance before field exercise",
    reportedBy: "SSG Miller",
    reportedDate: formatDate(today),
    scheduledDate: formatDate(addDays(today, 3))
  }
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
  {
    id: "log_003",
    maintenanceId: "m_002",
    timestamp: format(subDays(today, 2), 'yyyy-MM-dd HH:mm:ss'),
    action: "status-change",
    performedBy: "SPC Adams",
    notes: "Status changed to in-progress. Initial diagnosis: possible fuel pump issue."
  },
  {
    id: "log_004",
    maintenanceId: "m_003",
    timestamp: format(subDays(today, 10), 'yyyy-MM-dd HH:mm:ss'),
    action: "created",
    performedBy: "LT Johnson",
    notes: "Maintenance request created for AN/PRC-152 Radio"
  },
  {
    id: "log_005",
    maintenanceId: "m_003",
    timestamp: format(subDays(today, 8), 'yyyy-MM-dd HH:mm:ss'),
    action: "status-change",
    performedBy: "SFC Williams",
    notes: "Status changed to in-progress. Diagnostic tests show RF module failure."
  },
  {
    id: "log_006",
    maintenanceId: "m_003",
    timestamp: format(subDays(today, 7), 'yyyy-MM-dd HH:mm:ss'),
    action: "parts-ordered",
    performedBy: "SFC Williams",
    notes: "RF Module ordered. ETA 5 days."
  },
  {
    id: "log_007",
    maintenanceId: "m_003",
    timestamp: format(subDays(today, 6), 'yyyy-MM-dd HH:mm:ss'),
    action: "status-change",
    performedBy: "SFC Williams",
    notes: "Status changed to awaiting-parts."
  },
  {
    id: "log_008",
    maintenanceId: "m_005",
    timestamp: format(subDays(today, 20), 'yyyy-MM-dd HH:mm:ss'),
    action: "created",
    performedBy: "SFC Martinez",
    notes: "Maintenance request created for M249 SAW"
  },
  {
    id: "log_009",
    maintenanceId: "m_005",
    timestamp: format(subDays(today, 17), 'yyyy-MM-dd HH:mm:ss'),
    action: "status-change",
    performedBy: "SSG Thompson",
    notes: "Status changed to scheduled. Assigned to SPC Torres."
  },
  {
    id: "log_010",
    maintenanceId: "m_005",
    timestamp: format(subDays(today, 15), 'yyyy-MM-dd HH:mm:ss'),
    action: "status-change",
    performedBy: "SPC Torres",
    notes: "Status changed to in-progress. Beginning inspection and maintenance."
  },
  {
    id: "log_011",
    maintenanceId: "m_005",
    timestamp: format(subDays(today, 14), 'yyyy-MM-dd HH:mm:ss'),
    action: "updated",
    performedBy: "SPC Torres",
    notes: "Barrel replaced and all parts cleaned. Function check complete."
  },
  {
    id: "log_012",
    maintenanceId: "m_005",
    timestamp: format(subDays(today, 14), 'yyyy-MM-dd HH:mm:ss'),
    action: "completed",
    performedBy: "SPC Torres",
    notes: "Maintenance completed successfully. Weapon ready for service."
  },
  {
    id: "log_013",
    maintenanceId: "m_007",
    timestamp: format(subDays(today, 15), 'yyyy-MM-dd HH:mm:ss'),
    action: "created",
    performedBy: "SGT Davis",
    notes: "Maintenance request created for ACOG Sight"
  },
  {
    id: "log_014",
    maintenanceId: "m_007",
    timestamp: format(subDays(today, 12), 'yyyy-MM-dd HH:mm:ss'),
    action: "status-change",
    performedBy: "SSG Thompson",
    notes: "Status changed to scheduled. Assigned to SPC Parker."
  },
  {
    id: "log_015",
    maintenanceId: "m_007",
    timestamp: format(subDays(today, 10), 'yyyy-MM-dd HH:mm:ss'),
    action: "status-change",
    performedBy: "SPC Parker",
    notes: "Status changed to in-progress. Diagnosing illumination issue."
  },
  {
    id: "log_016",
    maintenanceId: "m_007",
    timestamp: format(subDays(today, 9), 'yyyy-MM-dd HH:mm:ss'),
    action: "updated",
    performedBy: "SPC Parker",
    notes: "Found corrosion in battery contacts. Cleaning and repairing."
  },
  {
    id: "log_017",
    maintenanceId: "m_007",
    timestamp: format(subDays(today, 8), 'yyyy-MM-dd HH:mm:ss'),
    action: "completed",
    performedBy: "SPC Parker",
    notes: "Repaired battery housing, replaced contacts, and verified illumination function. Item ready for service."
  }
];

// Mock data - Maintenance Bulletins
export const maintenanceBulletins: MaintenanceBulletin[] = [
  {
    id: "b1",
    title: "Parts Shortage: M4 Firing Pin",
    message: "We are currently experiencing a shortage of M4 firing pins. Maintenance requests requiring this part will be delayed by approximately 2 weeks. We've placed an emergency order and expect delivery by April 15.",
    category: 'parts-shortage',
    affectedItems: ["M4A1 Carbine"],
    postedBy: "SFC Wright",
    postedDate: formatDate(subDays(today, 2)),
    resolved: false
  },
  {
    id: "b2",
    title: "HMMWV Maintenance Delay",
    message: "Due to increased operational tempo, all non-critical HMMWV maintenance is being rescheduled. Critical repairs remain prioritized. Contact the maintenance shop for updated schedule information.",
    category: 'delay',
    affectedItems: ["HMMWV"],
    postedBy: "CW2 Nelson",
    postedDate: formatDate(subDays(today, 5)),
    resolved: false
  },
  {
    id: "b3",
    title: "Updated Radio Repair Procedure",
    message: "A new maintenance procedure has been implemented for AN/PRC-152 radios experiencing signal loss. The updated technical manual is available in the maintenance shop. All personnel performing radio maintenance must review before conducting repairs.",
    category: 'update',
    affectedItems: ["AN/PRC-152 Radio"],
    postedBy: "SFC Williams",
    postedDate: formatDate(subDays(today, 10)),
    resolved: false
  },
  {
    id: "b4",
    title: "Maintenance Bay 3 Closure",
    message: "Maintenance Bay 3 will be closed from April 10-15 for facility upgrades. All scheduled maintenance during this period will be relocated to Bay 1. Please adjust planning accordingly.",
    category: 'facility',
    postedBy: "MSG Reynolds",
    postedDate: formatDate(subDays(today, 7)),
    resolved: false
  },
  {
    id: "b5",
    title: "Battery Testing Equipment Available",
    message: "New battery testing equipment is now available in the maintenance shop. This equipment can test all vehicle and radio batteries and provide detailed diagnostic information. See the duty NCO for training and usage.",
    category: 'general',
    postedBy: "SFC Ellis",
    postedDate: formatDate(subDays(today, 15)),
    resolved: false
  },
  {
    id: "b6",
    title: "M240B Barrel Recall",
    message: "Barrels with serial numbers starting with 'MB19' manufactured in January 2023 have been recalled due to potential heat treatment issues. Check your inventory and submit affected barrels for replacement immediately.",
    category: 'parts-shortage',
    affectedItems: ["M240B Machine Gun"],
    postedBy: "CW3 Garcia",
    postedDate: formatDate(subDays(today, 30)),
    resolvedDate: formatDate(subDays(today, 5)),
    resolved: true
  }
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