import { ConsumableItem } from "@/types";
import { format, subDays } from "date-fns";

// Generate some common consumable categories
export const consumableCategories = [
  { id: "cat-1", name: "Batteries", icon: "battery" },
  { id: "cat-2", name: "Medical Supplies", icon: "first-aid" },
  { id: "cat-3", name: "Cleaning Supplies", icon: "spray-can" },
  { id: "cat-4", name: "Office Supplies", icon: "clipboard" },
  { id: "cat-5", name: "POL (Petroleum, Oil, Lubricants)", icon: "droplet" },
  { id: "cat-6", name: "Field Rations", icon: "utensils" },
  { id: "cat-7", name: "Tools & Repair Parts", icon: "tool" }
];

// Mock consumable items data
export const consumables: ConsumableItem[] = [
  {
    id: "c-001",
    name: "AA Batteries",
    nsn: "6135-01-351-1131",
    category: "Batteries",
    unit: "each",
    currentQuantity: 48,
    minimumQuantity: 20,
    location: "Supply Room B3",
    lastRestockDate: format(subDays(new Date(), 15), 'yyyy-MM-dd')
  },
  {
    id: "c-002",
    name: "CR123A Batteries",
    nsn: "6135-01-351-1132",
    category: "Batteries",
    unit: "each",
    currentQuantity: 36,
    minimumQuantity: 30,
    location: "Supply Room B3",
    lastRestockDate: format(subDays(new Date(), 5), 'yyyy-MM-dd')
  },
  {
    id: "c-003",
    name: "Chem Lights (Green)",
    nsn: "6260-01-074-4229",
    category: "Field Supplies",
    unit: "box",
    currentQuantity: 5,
    minimumQuantity: 3,
    location: "Supply Room C1",
    notes: "Each box contains 20 light sticks",
    lastRestockDate: format(subDays(new Date(), 45), 'yyyy-MM-dd')
  },
  {
    id: "c-004",
    name: "CLP",
    nsn: "9150-01-054-6453",
    category: "Cleaning Supplies",
    unit: "bottle",
    currentQuantity: 15,
    minimumQuantity: 8,
    location: "Arms Room",
    notes: "4oz bottles",
    lastRestockDate: format(subDays(new Date(), 30), 'yyyy-MM-dd')
  },
  {
    id: "c-005",
    name: "CAT Tourniquets",
    nsn: "6515-01-521-7976",
    category: "Medical Supplies",
    unit: "each",
    currentQuantity: 12,
    minimumQuantity: 10,
    location: "Medical Cabinet A2",
    notes: "Combat Application Tourniquets",
    expirationDate: format(subDays(new Date(), -365), 'yyyy-MM-dd'), // 1 year from now
    lastRestockDate: format(subDays(new Date(), 60), 'yyyy-MM-dd')
  },
  {
    id: "c-006",
    name: "Gauze Bandages",
    nsn: "6510-00-058-5623",
    category: "Medical Supplies",
    unit: "pack",
    currentQuantity: 25,
    minimumQuantity: 15,
    location: "Medical Cabinet A2",
    notes: "Sterile, individually wrapped",
    expirationDate: format(subDays(new Date(), -180), 'yyyy-MM-dd'), // 6 months from now
    lastRestockDate: format(subDays(new Date(), 90), 'yyyy-MM-dd')
  },
  {
    id: "c-007",
    name: "Brake Fluid",
    nsn: "9150-00-257-5440",
    category: "POL",
    unit: "gallon",
    currentQuantity: 4,
    minimumQuantity: 2,
    location: "Motor Pool Storage",
    lastRestockDate: format(subDays(new Date(), 120), 'yyyy-MM-dd')
  },
  {
    id: "c-008",
    name: "Weapon Cleaning Brushes",
    nsn: "1005-00-494-6602",
    category: "Cleaning Supplies",
    unit: "each",
    currentQuantity: 8,
    minimumQuantity: 10, // Intentionally below minimum
    location: "Arms Room",
    lastRestockDate: format(subDays(new Date(), 150), 'yyyy-MM-dd')
  },
  {
    id: "c-009",
    name: "Field Dressings",
    nsn: "6510-00-159-4883",
    category: "Medical Supplies",
    unit: "each",
    currentQuantity: 30,
    minimumQuantity: 20,
    location: "Medical Cabinet A1",
    expirationDate: format(subDays(new Date(), -730), 'yyyy-MM-dd'), // 2 years from now
    lastRestockDate: format(subDays(new Date(), 45), 'yyyy-MM-dd')
  },
  {
    id: "c-010",
    name: "AAA Batteries",
    nsn: "6135-01-357-0818",
    category: "Batteries",
    unit: "each",
    currentQuantity: 24,
    minimumQuantity: 30, // Intentionally below minimum
    location: "Supply Room B3",
    lastRestockDate: format(subDays(new Date(), 75), 'yyyy-MM-dd')
  },
  {
    id: "c-011",
    name: "Printer Paper",
    nsn: "7530-00-290-0598",
    category: "Office Supplies",
    unit: "ream",
    currentQuantity: 5,
    minimumQuantity: 3,
    location: "Admin Office",
    lastRestockDate: format(subDays(new Date(), 20), 'yyyy-MM-dd')
  },
  {
    id: "c-012",
    name: "Engine Oil (5W-30)",
    nsn: "9150-01-438-5926",
    category: "POL",
    unit: "quart",
    currentQuantity: 12,
    minimumQuantity: 6,
    location: "Motor Pool Storage",
    lastRestockDate: format(subDays(new Date(), 35), 'yyyy-MM-dd')
  }
];

// Mock consumption history
export const consumptionHistory = [
  {
    id: "ch-001",
    itemId: "c-001", // AA Batteries
    quantity: 12,
    date: format(subDays(new Date(), 3), 'yyyy-MM-dd'),
    issuedTo: "2nd Platoon",
    issuedBy: "SSG Wilson"
  },
  {
    id: "ch-002",
    itemId: "c-004", // CLP
    quantity: 3,
    date: format(subDays(new Date(), 5), 'yyyy-MM-dd'),
    issuedTo: "Arms Room",
    issuedBy: "SPC Johnson"
  },
  {
    id: "ch-003",
    itemId: "c-005", // CAT Tourniquets
    quantity: 4,
    date: format(subDays(new Date(), 7), 'yyyy-MM-dd'),
    issuedTo: "Combat Medics",
    issuedBy: "SSG Martinez"
  },
  {
    id: "ch-004",
    itemId: "c-002", // CR123A Batteries
    quantity: 8,
    date: format(subDays(new Date(), 10), 'yyyy-MM-dd'),
    issuedTo: "1st Platoon",
    issuedBy: "SSG Wilson"
  },
  {
    id: "ch-005",
    itemId: "c-012", // Engine Oil
    quantity: 4,
    date: format(subDays(new Date(), 15), 'yyyy-MM-dd'),
    issuedTo: "Motor Pool",
    issuedBy: "SPC Davis"
  }
]; 