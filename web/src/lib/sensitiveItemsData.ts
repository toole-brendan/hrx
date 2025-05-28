import { format, subDays, addDays } from 'date-fns';

// Types for sensitive items
export interface SensitiveItem {
  id: string;
  name: string;
  category: 'weapon' | 'communication' | 'optics' | 'crypto' | 'other';
  serialNumber: string;
  assignedDate: string;
  status: 'verified' | 'pending' | 'overdue' | 'not-verified' | 'maintenance';
  lastVerified: string;
  nextVerification: string;
  securityLevel: 'routine' | 'controlled' | 'classified' | 'secret' | 'top-secret';
  location: string;
  assignedTo: string;
  notes?: string;
}

export interface VerificationLog {
  id: string;
  itemId: string;
  date: string;
  time: string;
  verifiedBy: string;
  status: 'verified' | 'missing' | 'damaged';
  notes?: string;
}

export interface SensitiveItemCategory {
  id: string;
  name: string;
  count: number;
  verificationFrequency: string;
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
    lastVerified: formatMilitaryDate(subDays(today, 1)),
    nextVerification: formatMilitaryDate(addDays(today, 6)),
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
    lastVerified: formatMilitaryDate(subDays(today, 1)),
    nextVerification: formatMilitaryDate(addDays(today, 6)),
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
    lastVerified: formatMilitaryDate(subDays(today, 1)),
    nextVerification: formatMilitaryDate(addDays(today, 13)),
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
    lastVerified: formatMilitaryDate(subDays(today, 1)),
    nextVerification: formatMilitaryDate(addDays(today, 6)),
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
    lastVerified: formatMilitaryDate(subDays(today, 8)),
    nextVerification: formatMilitaryDate(today), // Due today
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
    lastVerified: formatMilitaryDate(today), // Verified today
    nextVerification: formatMilitaryDate(addDays(today, 1)), // Daily check
    securityLevel: "secret",
    location: "Secure Comms Facility",
    assignedTo: CPT_NAME,
    notes: "CCI - Handle with two persons."
  },

  // --- Items Signed Down to Others ---
  // Weapon signed to PL
  {
    id: "si-m4-002",
    name: "M4A1 Carbine",
    category: 'weapon',
    serialNumber: generateSerial("WPN", 8),
    assignedDate: formatDate(subDays(today, 45)),
    status: "verified",
    lastVerified: formatMilitaryDate(subDays(today, 2)),
    nextVerification: formatMilitaryDate(addDays(today, 5)),
    securityLevel: "controlled",
    location: "Issued to 1st PL",
    assignedTo: LT_1_NAME,
  },
  // NVG signed to PL - OVERDUE Verification
  {
    id: "si-pvs14-pl1-001",
    name: "AN/PVS-14 NVG",
    category: 'optics',
    serialNumber: generateSerial("NVG", 7),
    assignedDate: formatDate(subDays(today, 45)),
    status: "overdue", 
    lastVerified: formatMilitaryDate(subDays(today, 16)), // Last verified over 2 weeks ago
    nextVerification: formatMilitaryDate(subDays(today, 2)), // Was due 2 days ago
    securityLevel: "controlled",
    location: "Issued to 1st PL",
    assignedTo: LT_1_NAME,
  },
  // Radio signed to another PL
  {
    id: "si-prc152-pl2-001",
    name: "AN/PRC-152 Radio",
    category: 'communication',
    serialNumber: generateSerial("COM", 8),
    assignedDate: formatDate(subDays(today, 40)),
    status: "verified",
    lastVerified: formatMilitaryDate(subDays(today, 3)),
    nextVerification: formatMilitaryDate(addDays(today, 4)),
    securityLevel: "classified",
    location: "Issued to 2nd PL",
    assignedTo: LT_2_NAME,
  },
  // Crew Served Weapon (Arms Room NCO)
  {
    id: "si-m240b-arms-001",
    name: "M240B Machine Gun",
    category: 'weapon',
    serialNumber: generateSerial("WPN", 8),
    assignedDate: formatDate(subDays(today, 120)),
    status: "verified",
    lastVerified: formatMilitaryDate(subDays(today, 1)),
    nextVerification: formatMilitaryDate(addDays(today, 6)),
    securityLevel: "controlled",
    location: "Arms Room",
    assignedTo: SGT_ARMS_ROOM_NAME,
  },
   // Crypto fill device (Supply NCO)
  {
    id: "si-cyz10-supply-001",
    name: "AN/CYZ-10 DTD", // Data Transfer Device
    category: 'crypto',
    serialNumber: generateSerial("CRY", 7),
    assignedDate: formatDate(subDays(today, 30)),
    status: "pending", // Verification pending
    lastVerified: formatMilitaryDate(subDays(today, 2)),
    nextVerification: formatMilitaryDate(today), // Due today
    securityLevel: "secret",
    location: "Supply Cage (Secure Section)",
    assignedTo: SFC_SUPPLY_NAME,
    notes: "Requires monthly key update."
  },

  // --- Unassigned Items ---
  {
    id: "si-m4-003",
    name: "M4A1 Carbine",
    category: 'weapon',
    serialNumber: generateSerial("WPN", 8),
    assignedDate: "",
    status: "not-verified",
    lastVerified: formatMilitaryDate(subDays(today, 30)), // Not recently verified
    nextVerification: "N/A",
    securityLevel: "controlled",
    location: "Arms Room (Spare)",
    assignedTo: "", // Unassigned
  },
  {
    id: "si-pvs14-spare-001",
    name: "AN/PVS-14 NVG",
    category: 'optics',
    serialNumber: generateSerial("NVG", 7),
    assignedDate: "",
    status: "maintenance", // In maintenance
    lastVerified: formatMilitaryDate(subDays(today, 20)),
    nextVerification: "N/A",
    securityLevel: "controlled",
    location: "Maintenance Turn-in",
    assignedTo: "",
    notes: "Submitted for repair - cracked housing."
  },
  {
    id: "si-prc152-spare-001",
    name: "AN/PRC-152 Radio",
    category: 'communication',
    serialNumber: generateSerial("COM", 8),
    assignedDate: "",
    status: "not-verified",
    lastVerified: formatMilitaryDate(subDays(today, 40)),
    nextVerification: "N/A",
    securityLevel: "classified",
    location: "Comms Cage (Spare)",
    assignedTo: "",
  },
   {
    id: "si-kiv7m-001",
    name: "KIV-7M COMSEC Module",
    category: 'crypto',
    serialNumber: generateSerial("CRY", 7),
    assignedDate: "",
    status: "not-verified",
    lastVerified: formatMilitaryDate(subDays(today, 50)),
    nextVerification: "N/A",
    securityLevel: "secret",
    location: "Secure Comms Facility (Spare)",
    assignedTo: "",
  },
  {
    id: "si-m2a1-arms-001",
    name: "M2A1 .50 Cal Machine Gun",
    category: 'weapon',
    serialNumber: generateSerial("WPN", 8),
    assignedDate: "",
    status: "verified",
    lastVerified: formatMilitaryDate(subDays(today, 1)),
    nextVerification: formatMilitaryDate(addDays(today, 6)),
    securityLevel: "controlled",
    location: "Arms Room (Weapons Plt)",
    assignedTo: SGT_ARMS_ROOM_NAME, // Still arms room NCO responsibility
  },
];

// --- Verification Logs ---
export const verificationLogs: VerificationLog[] = [
  {
    id: "log-si-m4-001-1",
    itemId: "si-m4-001",
    date: format(subDays(today, 1), 'yyyy-MM-dd'),
    time: "06:05",
    verifiedBy: SGT_ARMS_ROOM_NAME,
    status: "verified",
    notes: "Daily arms room check."
  },
  {
    id: "log-si-pvs14-001-1",
    itemId: "si-pvs14-cdr-001",
    date: format(subDays(today, 1), 'yyyy-MM-dd'),
    time: "06:07",
    verifiedBy: SGT_ARMS_ROOM_NAME,
    status: "verified",
  },
   {
    id: "log-si-prc152-001-1",
    itemId: "si-prc152-cdr-001",
    date: format(subDays(today, 8), 'yyyy-MM-dd'),
    time: "14:30",
    verifiedBy: "Commo SGT",
    status: "verified",
    notes: "TPC with XO complete."
  },
   {
    id: "log-si-kg175d-001-1",
    itemId: "si-kg175d-cdr-001",
    date: format(today, 'yyyy-MM-dd'),
    time: "09:00",
    verifiedBy: CPT_NAME,
    status: "verified",
    notes: "TPC with XO complete."
  },
   {
    id: "log-si-m4-pl1-001-1",
    itemId: "si-m4-002",
    date: format(subDays(today, 2), 'yyyy-MM-dd'),
    time: "10:15",
    verifiedBy: SGT_ARMS_ROOM_NAME,
    status: "verified",
    notes: "Signed out for range."
  },
   {
    id: "log-si-pvs14-pl1-001",
    itemId: "si-pvs14-pl1-001",
    date: format(subDays(today, 16), 'yyyy-MM-dd'),
    time: "08:00",
    verifiedBy: LT_1_NAME,
    status: "verified", 
  },
  {
    id: "log-si-m240b-arms-001",
    itemId: "si-m240b-arms-001",
    date: format(subDays(today, 1), 'yyyy-MM-dd'),
    time: "06:10",
    verifiedBy: SGT_ARMS_ROOM_NAME,
    status: "verified",
  },
  {
    id: "log-si-cyz10-supply-001",
    itemId: "si-cyz10-supply-001",
    date: format(subDays(today, 2), 'yyyy-MM-dd'),
    time: "15:00",
    verifiedBy: SFC_SUPPLY_NAME,
    status: "verified",
  },
  {
    id: "log-si-m4-spare-001-1",
    itemId: "si-m4-003",
    date: format(subDays(today, 30), 'yyyy-MM-dd'),
    time: "13:00",
    verifiedBy: SGT_ARMS_ROOM_NAME,
    status: "verified",
    notes: "Last inventory check before deployment."
  },
  {
    id: "log-si-m2a1-arms-001-1",
    itemId: "si-m2a1-arms-001",
    date: format(subDays(today, 1), 'yyyy-MM-dd'),
    time: "06:15",
    verifiedBy: SGT_ARMS_ROOM_NAME,
    status: "verified",
    notes: "Verified during morning arms room check."
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
    verificationFrequency: 'Daily/Weekly',
    riskLevel: 'high',
    icon: 'weapon'
  },
  {
    id: 'optics',
    name: 'Optics / NVGs',
    count: itemCounts['optics'] || 0,
    verificationFrequency: 'Weekly/Monthly',
    riskLevel: 'medium',
    icon: 'optics'
  },
  {
    id: 'communication',
    name: 'Communications',
    count: itemCounts['communication'] || 0,
    verificationFrequency: 'Weekly',
    riskLevel: 'medium',
    icon: 'communication'
  },
  {
    id: 'crypto',
    name: 'Crypto / CCI',
    count: itemCounts['crypto'] || 0,
    verificationFrequency: 'Daily/Weekly',
    riskLevel: 'critical',
    icon: 'crypto' 
  },
   {
    id: 'other',
    name: 'Other',
    count: itemCounts['other'] || 0,
    verificationFrequency: 'Monthly',
    riskLevel: 'low',
    icon: 'other'
  },
];

// --- Verification Schedule --- (Simplified - maybe just next major check)
export const verificationSchedule = [
  {
    date: format(addDays(today, 3), 'PP'), // Example: Full check in 3 days
    time: "09:00",
    itemsToVerify: sensitiveItems.length, // All items for full check
    status: "upcoming"
  },
  {
    date: format(addDays(today, 1), 'PP'), // Example: Daily Crypto check
    time: "08:00",
    itemsToVerify: itemCounts['crypto'] || 0,
    status: "upcoming"
  },
];

// --- Summary Statistics --- (Calculated from sensitiveItems)
const calculateStats = (items: SensitiveItem[]) => {
  const now = new Date();
  const todayStr = formatDate(now);
  
  const verifiedToday = verificationLogs.filter(log => log.date === todayStr && log.status === 'verified').length;
  const pendingVerification = items.filter(item => item.status === 'pending' || item.status === 'overdue').length;
  const overdueVerification = items.filter(item => item.status === 'overdue').length;
  const inMaintenance = items.filter(item => item.status === 'maintenance').length;
  const highRiskItems = items.filter(item => item.securityLevel === 'secret' || item.securityLevel === 'top-secret').length;
  
  // Find the latest verification date among all items actually verified
  const verifiedDates = items
    .filter(item => item.lastVerified && item.lastVerified !== "N/A")
    .map(item => {
      // Attempt to parse the custom military date format
      try {
        const day = parseInt(item.lastVerified.substring(0, 2), 10);
        const monthStr = item.lastVerified.substring(2, 5);
        const year = parseInt(item.lastVerified.substring(5, 9), 10);
        const monthIndex = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"].indexOf(monthStr);
        if (monthIndex === -1 || isNaN(day) || isNaN(year)) return null;
        return new Date(year, monthIndex, day);
      } catch (e) {
        return null; // Handle potential parsing errors
      }
    })
    .filter(date => date !== null) as Date[];

  const lastFullVerificationDate = verifiedDates.length > 0 
    ? new Date(Math.max(...verifiedDates.map(d => d.getTime()))) 
    : null;
    
  const lastFullVerification = lastFullVerificationDate ? formatMilitaryDate(lastFullVerificationDate) : 'Pending Initial';

  // Example compliance calculation
  const totalAccountable = items.length - items.filter(item => item.status === 'maintenance').length; // Exclude maintenance items
  const verifiedOrPending = items.filter(item => item.status === 'verified' || item.status === 'pending').length;
  const compliancePercentage = totalAccountable > 0 ? Math.round((verifiedOrPending / totalAccountable) * 100) : 100;
  
  return {
    totalItems: items.length,
    verifiedToday: verifiedToday,
    pendingVerification: pendingVerification,
    overdueVerification: overdueVerification,
    inMaintenance: inMaintenance,
    highRiskItems: highRiskItems,
    lastFullVerification: lastFullVerification,
    verificationCompliance: `${compliancePercentage}%`,
    itemsOverdue: overdueVerification,
  };
}

export const sensitiveItemsStats = calculateStats(sensitiveItems);