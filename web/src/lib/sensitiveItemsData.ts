import { format, subDays, addDays } from 'date-fns';

// Types for sensitive items
export interface SensitiveItem {
  id: string;
  name: string;
  category: 'weapon' | 'communication' | 'optics' | 'crypto' | 'other';
  serialNumber: string;
  assignedDate: string;
  status: 'verified' | 'pending' | 'overdue' | 'not-verified' | 'maintenance';
  securityLevel: 'routine' | 'controlled' | 'classified' | 'secret' | 'top-secret';
  location: string;
  assignedTo: string;
  notes?: string;
}

export interface SensitiveItemCategory {
  id: string;
  name: string;
  count: number;
  riskLevel: 'low' | 'medium' | 'high' | 'critical';
  icon: string;
}

// --- AUTHENTICATED MOCK DATA for CPT Rodriguez ---
const today = new Date();
const CPT_NAME = "CPT Rodriguez, Michael";
const LT_1_NAME = "LT Jenkins, Sarah";
const LT_2_NAME = "LT Chen, David";
const SFC_SUPPLY_NAME = "SFC Bell, Marcus";
const SGT_ARMS_ROOM_NAME = "SGT Miller, Kevin";

const formatDate = (date: Date) => format(date, 'yyyy-MM-dd');
const formatMilitaryDate = (date: Date): string => {
  const day = format(date, 'dd');
  const month = format(date, 'MMM').toUpperCase();
  const year = format(date, 'yyyy');
  return `${day}${month}${year}`;
};

// Helper to generate serial numbers
const generateSerial = (prefix: string, length: number = 8) => {
  const randomPart = Math.random().toString().substring(2, 2 + length);
  return `${prefix}-${randomPart.toUpperCase()}`;
};

// --- Sensitive Items List ---
export const sensitiveItems: SensitiveItem[] = [
  // Weapons (Assigned to CPT Rodriguez)
  {
    id: "si-m4-001",
    name: "M4A1 Carbine (CDR)",
    category: 'weapon',
    serialNumber: generateSerial("WPN", 8),
    assignedDate: formatDate(subDays(today, 90)),
    status: "verified",
    securityLevel: "controlled",
    location: "Arms Room (Issued)",
    assignedTo: CPT_NAME,
  },
  {
    id: "si-m17-cdr-001",
    name: "M17 Pistol (CDR)",
    category: 'weapon',
    serialNumber: generateSerial("WPN", 8),
    assignedDate: formatDate(subDays(today, 90)),
    status: "verified",
    securityLevel: "controlled",
    location: "Arms Room (Issued)",
    assignedTo: CPT_NAME,
  },
  // Optics (Assigned to CPT Rodriguez)
  {
    id: "si-pvs14-cdr-001",
    name: "AN/PVS-14 NVG (CDR)",
    category: 'optics',
    serialNumber: generateSerial("NVG", 7),
    assignedDate: formatDate(subDays(today, 80)),
    status: "verified",
    securityLevel: "controlled",
    location: "Arms Room (Issued)",
    assignedTo: CPT_NAME,
  },
  {
    id: "si-cows-cdr-001",
    name: "M150 C.O.W.S. (CDR)",
    category: 'optics',
    serialNumber: generateSerial("OPT", 8),
    assignedDate: formatDate(subDays(today, 90)),
    status: "verified",
    securityLevel: "controlled",
    location: "Arms Room (Issued - Attached to M4)",
    assignedTo: CPT_NAME,
  },
  // Communications (Assigned to CPT Rodriguez)
  {
    id: "si-prc152-cdr-001",
    name: "AN/PRC-152 Radio (CDR)",
    category: 'communication',
    serialNumber: generateSerial("COM", 8),
    assignedDate: formatDate(subDays(today, 70)),
    status: "pending", // Needs verification today
    securityLevel: "classified",
    location: "Comms Cage (Issued)",
    assignedTo: CPT_NAME,
  },
  // Crypto (Assigned to CPT Rodriguez - High Risk)
  {
    id: "si-kg175d-cdr-001",
    name: "KG-175D TACLANE (CDR)",
    category: 'crypto',
    serialNumber: generateSerial("CRY", 7),
    assignedDate: formatDate(subDays(today, 60)),
    status: "verified", // Verified this morning
    securityLevel: "secret",
    location: "Secure Comms Facility",
    assignedTo: CPT_NAME,
    notes: "CCI - Handle with two persons."
  },
];

// --- Categories --- (Counts need to be calculated from sensitiveItems)
const calculateCategoryCounts = (items: SensitiveItem[]) => {
  const counts = items.reduce((acc, item) => {
    acc[item.category] = (acc[item.category] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  return counts;
};

const itemCounts = calculateCategoryCounts(sensitiveItems);

export const sensitiveItemCategories: SensitiveItemCategory[] = [
  {
    id: 'weapon',
    name: 'Weapons (Small Arms & Crew Served)',
    count: itemCounts['weapon'] || 0,
    riskLevel: 'high',
    icon: 'weapon'
  },
  {
    id: 'optics',
    name: 'Optics / NVGs',
    count: itemCounts['optics'] || 0,
    riskLevel: 'medium',
    icon: 'optics'
  },
  {
    id: 'communication',
    name: 'Communications',
    count: itemCounts['communication'] || 0,
    riskLevel: 'medium',
    icon: 'communication'
  },
  {
    id: 'crypto',
    name: 'Crypto / CCI',
    count: itemCounts['crypto'] || 0,
    riskLevel: 'critical',
    icon: 'crypto'
  },
  {
    id: 'other',
    name: 'Other',
    count: itemCounts['other'] || 0,
    riskLevel: 'low',
    icon: 'other'
  },
];

// --- Summary Statistics --- (Calculated from sensitiveItems)
const calculateStats = (items: SensitiveItem[]) => {
  const inMaintenance = items.filter(item => item.status === 'maintenance').length;
  const highRiskItems = items.filter(item => item.securityLevel === 'secret' || item.securityLevel === 'top-secret').length;

  return {
    totalItems: items.length,
    inMaintenance: inMaintenance,
    highRiskItems: highRiskItems,
  };
};

export const sensitiveItemsStats = calculateStats(sensitiveItems); 