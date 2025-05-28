// @ts-ignore
import { 
  User, 
  InventoryItem, 
  Transfer, 
  Activity, 
  Notification 
} from "@/types";

// Mock User
export const user: User = {
  id: "RODMC01",
  username: "michael.rodriguez",
  name: "CPT Rodriguez, Michael",
  rank: "Captain",
  position: "Company Commander",
  unit: "Bravo Company, 2-87 Infantry Battalion",
  yearsOfService: 6,
  commandTime: "3 months",
  responsibility: "Primary Hand Receipt Holder for company-level property",
  valueManaged: "$4.2M Equipment Value",
  upcomingEvents: [
    { title: "NTC Rotation Prep", date: "Ongoing" },
    { title: "Equipment Reset", date: "In Progress" },
    { title: "Command Maintenance", date: "Next Week" }
  ],
  equipmentSummary: {
    vehicles: 72,
    weapons: 143,
    communications: 95,
    opticalSystems: 63,
    sensitiveItems: 210
  }
};

// Mock Inventory Items
export const inventory: InventoryItem[] = [
  {
    id: "1",
    name: "ACH",
    serialNumber: "ACH-45678123",
    assignedDate: "15JAN2023",
    status: "Operational",
    description: "Advanced Combat Helmet",
    category: "individual-equipment",
    location: "Supply Room"
  },
  {
    id: "2",
    name: "MOLLE II Rucksack",
    serialNumber: "MOLLE-98745632",
    assignedDate: "22MAR2023",
    status: "Damaged",
    description: "MOLLE II Large Rucksack OD Green",
    category: "individual-equipment",
    location: "Supply Room",
    components: [
      {
        id: 'comp-ruck-1',
        name: 'Sustainment Pouch',
        quantity: 2,
        required: true,
        status: 'present',
        nsn: '8465-01-524-7226'
      },
      {
        id: 'comp-ruck-2',
        name: 'Waist Belt',
        quantity: 1,
        required: true,
        status: 'present'
      }
    ]
  },
  {
    id: "3",
    name: "IFAK",
    serialNumber: "IFAK-32165487",
    assignedDate: "10FEB2023",
    status: "In Repair",
    description: "Individual First Aid Kit",
    category: "medical",
    location: "Supply Room"
  },
  {
    id: "4",
    name: "IOTV",
    serialNumber: "IOTV-78912345",
    assignedDate: "05APR2023",
    status: "Deadline - Maintenance",
    description: "Improved Outer Tactical Vest",
    category: "individual-equipment",
    location: "Maintenance Shop",
    components: [
      {
        id: 'comp-iotv-1',
        name: 'Side Plate Pouch (Left)',
        quantity: 1,
        required: true,
        status: 'present'
      },
      {
        id: 'comp-iotv-2',
        name: 'Side Plate Pouch (Right)',
        quantity: 1,
        required: true,
        status: 'missing',
        notes: 'Reported missing 10JUL2023'
      },
       {
        id: 'comp-iotv-3',
        name: 'Shoulder Pads (Pair)',
        quantity: 1,
        required: true,
        status: 'damaged'
      }
    ]
  },
  {
    id: "5",
    name: "HGU-56/P Helmet",
    serialNumber: "HGU-45612378",
    assignedDate: "20JAN2023",
    status: "Non-Operational",
    description: "Aviator Helmet",
    category: "individual-equipment",
    location: "Supply Room"
  },
  {
    id: "6",
    name: "M11 Pistol",
    serialNumber: "M11-67812345",
    assignedDate: "05JAN2023",
    status: "Lost",
    description: "SIG Sauer P228 Pistol",
    category: "weapons",
    location: "Unknown - FLIPL Initiated",
    isSensitive: true
  },
  {
    id: "7",
    name: "JLTV",
    serialNumber: "JLTV-56781234",
    assignedDate: "15FEB2023",
    status: "Deadline - Maintenance",
    description: "Joint Light Tactical Vehicle",
    category: "vehicles",
    location: "Motor Pool",
    components: [
      {
        id: 'comp-jltv-1',
        name: 'BII Kit',
        quantity: 1,
        required: true,
        status: 'present'
      },
      {
        id: 'comp-jltv-2',
        name: 'Radio Mount',
        quantity: 1,
        required: true,
        status: 'present'
      }
    ]
  },
  {
    id: "8",
    name: "M256 Kit",
    serialNumber: "CBRN-45123789",
    assignedDate: "10MAR2023",
    status: "Operational",
    description: "Chemical Detection Kit",
    category: "support-equipment",
    location: "CBRN Room"
  },
  {
    id: "9",
    name: "PEQ-15",
    serialNumber: "PEQ-78123456",
    assignedDate: "22DEC2022",
    status: "Deadline - Supply",
    description: "Tactical Light/Laser",
    category: "optics",
    location: "Supply Room",
    requiresCalibration: true,
    calibrationInfo: {
      lastCalibrationDate: "15MAR2024",
      nextCalibrationDueDate: "15MAR2025",
      calibrationIntervalDays: 365,
      status: 'current',
      notes: "Waiting for replacement battery pack.",
      history: [
         { date: "15MAR2024", notes: "Annual calibration performed by TMDE Lab." },
         { date: "10MAR2023", notes: "Initial calibration by TMDE Lab." },
      ]
    }
  },
  {
    id: "10",
    name: "FILBE Pack",
    serialNumber: "FILBE-56123789",
    assignedDate: "18MAY2023",
    status: "Operational",
    description: "USMC Pack System",
    category: "individual-equipment",
    location: "Supply Room"
  },
  {
    id: "11",
    name: "Fluke 87V Multimeter",
    serialNumber: "FLK-11223344",
    assignedDate: "10JAN2024",
    status: "Deadline - Supply",
    description: "Precision Multimeter",
    category: "support-equipment",
    location: "Commo Shop",
    requiresCalibration: true,
    calibrationInfo: {
       lastCalibrationDate: "15JAN2024",
       nextCalibrationDueDate: "15JUL2024",
       calibrationIntervalDays: 180,
       status: 'due-soon',
       notes: "Waiting for replacement test probes."
    }
  },
  {
    id: "12",
    name: "AN/PRC-152 Radio",
    serialNumber: "PRC152-87654321",
    assignedDate: "10FEB2024",
    status: "In Repair",
    description: "Handheld Multiband Radio",
    category: "comsec",
    location: "Commo Cage",
    isSensitive: true
  },
  {
    id: "13",
    name: "M4A1 Carbine",
    serialNumber: "M4A1-12345678",
    assignedDate: "15JAN2023",
    status: "Deadline - Maintenance",
    description: "5.56mm Carbine with Burst Capability",
    category: "weapons",
    location: "Arms Room",
    isSensitive: true,
    components: [
      {
        id: 'comp-m4-1',
        name: 'ACOG Scope',
        quantity: 1,
        required: true,
        status: 'present',
        serialNumber: 'ACOG-87654321'
      },
      {
        id: 'comp-m4-2',
        name: 'Magazines',
        quantity: 7,
        required: true,
        status: 'present'
      },
      {
        id: 'comp-m4-3',
        name: 'Cleaning Kit',
        quantity: 1,
        required: true,
        status: 'present'
      }
    ]
  }
];

// Mock Transfers (Updated for CPT Rodriguez)
export const transfers: Transfer[] = [
  {
    id: "TR73921",
    name: "AN/PVS-14 Monocular NVG",
    serialNumber: "NVG789123",
    from: "SFC Smith, Anna",
    to: "CPT Rodriguez, Michael",
    date: "2024-07-28T10:30:00Z",
    status: "pending"
  },
  {
    id: "TR11235",
    name: "SINCGARS Radio Set",
    serialNumber: "RT1523-100987",
    from: "Supply Depot Alpha",
    to: "CPT Rodriguez, Michael",
    date: "2024-07-27T14:00:00Z",
    status: "pending"
  },
  {
    id: "TR55891",
    name: "M4A1 Carbine",
    serialNumber: "W123456",
    from: "1LT Jones, David",
    to: "CPT Rodriguez, Michael",
    date: "2024-07-29T09:15:00Z",
    status: "pending"
  },
  {
    id: "TR84055",
    name: "M17 Pistol",
    serialNumber: "PIS456789",
    from: "CPT Rodriguez, Michael",
    to: "SSG Miller, Ben",
    date: "2024-07-29T15:00:00Z",
    status: "pending"
  },
  {
    id: "TR91007",
    name: "Toughbook Laptop",
    serialNumber: "CF31-MK5-12345",
    from: "CPT Rodriguez, Michael",
    to: "PFC Davis, Sarah",
    date: "2024-07-26T11:00:00Z",
    status: "pending"
  },
  {
    id: "TR61102",
    name: "Rifle Combat Optic (RCO)",
    serialNumber: "RCO998877",
    from: "Supply Depot Alpha",
    to: "CPT Rodriguez, Michael",
    date: "2024-07-15T09:00:00Z",
    status: "approved",
    approvedDate: "2024-07-16T10:00:00Z"
  },
  {
    id: "TR33456",
    name: "Medical Aid Bag (Complete)",
    serialNumber: "MED-BAG-00123",
    from: "CPT Rodriguez, Michael",
    to: "SGT Chung, Wei",
    date: "2024-06-20T13:30:00Z",
    status: "approved",
    approvedDate: "2024-06-21T08:45:00Z"
  },
  {
    id: "TR44789",
    name: "Tool Set, General Mechanic",
    serialNumber: "GMTK-556677",
    from: "Maintenance Platoon",
    to: "CPT Rodriguez, Michael",
    date: "2024-07-01T16:00:00Z",
    status: "approved",
    approvedDate: "2024-07-02T11:20:00Z"
  },
  {
    id: "TR22901",
    name: "ACH Helmet (Damaged)",
    serialNumber: "ACH-DMG-001",
    from: "PFC Williams, James",
    to: "CPT Rodriguez, Michael",
    date: "2024-07-10T08:00:00Z",
    status: "rejected",
    rejectedDate: "2024-07-10T14:15:00Z",
    rejectionReason: "Item received damaged, requires turn-in."
  },
  {
    id: "TR50014",
    name: "AN/PRC-117G Radio",
    serialNumber: "PRC117G-WRONG-SN",
    from: "CPT Rodriguez, Michael",
    to: "Commo Section",
    date: "2024-06-25T10:00:00Z",
    status: "rejected",
    rejectedDate: "2024-06-26T09:30:00Z",
    rejectionReason: "Incorrect radio type requested by Commo."
  },
  {
    id: "TR10050",
    name: "Binoculars M22",
    serialNumber: "M22-BINOC-111",
    from: "CPT Rodriguez, Michael",
    to: "1LT Jones, David",
    date: "2024-05-15T11:00:00Z",
    status: "approved",
    approvedDate: "2024-05-16T08:00:00Z"
  },
];

// Mock Activities
export const activities: Activity[] = [
  {
    id: "act-1",
    type: "transfer-approved",
    description: "Transfer approved: IOTV",
    user: "From: 1SG Johnson",
    timeAgo: "2 hours ago",
  },
  {
    id: "act-2",
    type: "transfer-rejected",
    description: "Transfer rejected: M9 Bayonet",
    user: "To: PFC Williams",
    timeAgo: "4 hours ago",
  },
  {
    id: "act-3",
    type: "inventory-updated",
    description: "Inventory updated: +5 IFAK",
    user: "By: 1LT Parker",
    timeAgo: "Yesterday",
  },
  {
    id: "act-4",
    type: "transfer-approved",
    description: "Transfer approved: Nomex Gloves",
    user: "To: PFC Williams",
    timeAgo: "2 days ago",
  },
  {
    id: "act-5",
    type: "inventory-updated",
    description: "Inventory updated: -2 PRC-152",
    user: "By: SFC Martinez",
    timeAgo: "3 days ago",
  },
  {
    id: "act-6",
    type: "transfer-approved",
    description: "Transfer approved: M240B",
    user: "From: 1SG Johnson",
    timeAgo: "3 days ago",
  },
  {
    id: "act-7",
    type: "inventory-updated",
    description: "Inventory updated: +4 SAPI Plates",
    user: "By: CPT Smith",
    timeAgo: "4 days ago",
  },
  {
    id: "act-8",
    type: "transfer-approved",
    description: "Transfer approved: ASIP Radio",
    user: "To: SFC Martinez",
    timeAgo: "5 days ago",
  },
  {
    id: "act-9",
    type: "inventory-updated",
    description: "Inventory updated: +2 CLS Bags",
    user: "By: SFC Wilson",
    timeAgo: "1 week ago",
  },
  {
    id: "act-10",
    type: "transfer-rejected",
    description: "Transfer rejected: AT4",
    user: "To: SSG Brown",
    timeAgo: "1 week ago",
  },
];

// Mock Notifications
export const notifications: Notification[] = [
  {
    id: "not-1",
    type: "transfer-request",
    title: "Transfer Request",
    message: "SFC Martinez is requesting to transfer an M4A1 to you.",
    timeAgo: "10 minutes ago",
    read: false,
  },
  {
    id: "not-2",
    type: "transfer-approved",
    title: "Transfer Approved",
    message: "Your request to transfer PVS-14 has been approved.",
    timeAgo: "1 hour ago",
    read: false,
  },
  {
    id: "not-3",
    type: "system-alert",
    title: "System Alert",
    message: "Scheduled PMCS will occur tonight from 0200-0400 hours.",
    timeAgo: "3 hours ago",
    read: false,
  },
  {
    id: "not-4",
    type: "transfer-request",
    title: "Transfer Request",
    message: "SSG Rodriguez is requesting to transfer a PRC-152 to you.",
    timeAgo: "5 hours ago",
    read: false,
  },
  {
    id: "not-5",
    type: "transfer-request",
    title: "Transfer Request",
    message: "1LT Parker is requesting to transfer TCCC supplies to you.",
    timeAgo: "1 day ago",
    read: true,
  },
  {
    id: "not-6",
    type: "system-alert",
    title: "BN FRAGO",
    message: "Battalion FRAGO 12 published to SIPR. See S3 for details.",
    timeAgo: "1 day ago",
    read: false,
  },
  {
    id: "not-7",
    type: "transfer-request",
    title: "Transfer Request",
    message: "MAJ Wilson is requesting to transfer M2 .50 Cal to you.",
    timeAgo: "2 days ago",
    read: false,
  },
  {
    id: "not-8",
    type: "system-alert",
    title: "Arms Room Alert",
    message: "Monthly weapons maintenance scheduled for 15JUL2023 0900.",
    timeAgo: "2 days ago",
    read: true,
  },
  {
    id: "not-9",
    type: "transfer-approved",
    title: "Transfer Approved",
    message: "Your request to transfer ASIP Radio has been approved.",
    timeAgo: "4 days ago",
    read: true,
  },
  {
    id: "not-10",
    type: "system-alert",
    title: "Supply Alert",
    message: "Monthly sensitive items inventory on 20JUL2023 0800.",
    timeAgo: "1 week ago",
    read: true,
  },
];
