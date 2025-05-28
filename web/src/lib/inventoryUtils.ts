import React from 'react';
import { Filter, Radio, Eye, Package, Shield, ClipboardCheck, Wrench, ArrowDownUp } from "lucide-react";

// Category options for dropdown filtering
export const categoryOptions = [
  { value: "all", label: "All Categories" },
  { value: "weapons", label: "Weapons Systems" },
  { value: "comsec", label: "COMSEC & Communications" },
  { value: "optics", label: "Optics & Sensors" },
  { value: "vehicles", label: "Vehicles & Mobility" },
  { value: "individual-equipment", label: "Individual Equipment (TA-50)" },
  { value: "medical", label: "Medical Equipment" },
  { value: "support-equipment", label: "Support & Training Equipment" },
  { value: "electronics", label: "IT & Electronics" },
  { value: "other", label: "Other Equipment" }
];

// Determine category from item name
export const getCategoryFromName = (name: string): string => {
  if (!name) return 'other';
  const nameLC = name.toLowerCase();
  
  // Class VII - Major End Items (Weapons)
  if (nameLC.includes("rifle") || nameLC.includes("carbine") || nameLC.includes("m4") || 
      nameLC.includes("m16") || nameLC.includes("pistol") || nameLC.includes("m9") || 
      nameLC.includes("m17") || nameLC.includes("gun") || nameLC.includes("weapon") || 
      nameLC.includes("m240") || nameLC.includes("m249")) 
      return "weapons";
  
  // Class VII - COMSEC/Communication Equipment
  if (nameLC.includes("radio") || nameLC.includes("prc-") || nameLC.includes("comm") || 
      nameLC.includes("jcr") || nameLC.includes("harris") || nameLC.includes("sincgars") || 
      nameLC.includes("antenna") || nameLC.includes("satellite")) 
      return "comsec";
  
  // Optical & Sensor Systems
  if (nameLC.includes("optic") || nameLC.includes("scope") || nameLC.includes("cco") || 
      nameLC.includes("acog") || nameLC.includes("pvs-") || nameLC.includes("nvg") || 
      nameLC.includes("thermal") || nameLC.includes("binocular") || 
      nameLC.includes("rangefinder")) 
      return "optics";
  
  // Class VII - Vehicles & Mobility
  if (nameLC.includes("vehicle") || nameLC.includes("truck") || nameLC.includes("humvee") || 
      nameLC.includes("lmtv") || nameLC.includes("mrap") || nameLC.includes("trailer") || 
      nameLC.includes("atv") || nameLC.includes("forklift")) 
      return "vehicles";
  
  // Class II - Individual Equipment (TA-50, CIF items)
  if (nameLC.includes("helmet") || nameLC.includes("ach") || nameLC.includes("vest") || 
      nameLC.includes("iotv") || nameLC.includes("plate carrier") || nameLC.includes("pack") || 
      nameLC.includes("rucksack") || nameLC.includes("canteen") || nameLC.includes("e-tool") || 
      nameLC.includes("sleeping") || nameLC.includes("poncho")) 
      return "individual-equipment";
  
  // Class VIII - Medical Equipment
  if (nameLC.includes("medical") || nameLC.includes("ifak") || nameLC.includes("aid kit") || 
      nameLC.includes("stretcher") || nameLC.includes("defibrillator") || nameLC.includes("medevac")) 
      return "medical";
  
  // Support & Training Equipment
  if (nameLC.includes("generator") || nameLC.includes("tool kit") || nameLC.includes("shop") || 
      nameLC.includes("trailer") || nameLC.includes("maintenance") || nameLC.includes("simulator") || 
      nameLC.includes("training")) 
      return "support-equipment";
  
  // IT & Electronics
  if (nameLC.includes("computer") || nameLC.includes("laptop") || nameLC.includes("server") || 
      nameLC.includes("projector") || nameLC.includes("printer") || nameLC.includes("electronic") || 
      nameLC.includes("gps")) 
      return "electronics";
  
  // Other
  return "other";
};

// Get icon component based on category
export const getCategoryIcon = (name: string): React.ReactNode => {
  const category = getCategoryFromName(name);
  switch (category) {
    case "weapons":
      return React.createElement(Filter, { className: "h-4 w-4" });
    case "comsec":
      return React.createElement(Radio, { className: "h-4 w-4" });
    case "optics":
      return React.createElement(Eye, { className: "h-4 w-4" });
    case "vehicles":
      return React.createElement(Package, { className: "h-4 w-4" });
    case "individual-equipment":
      return React.createElement(Shield, { className: "h-4 w-4" });
    case "medical":
      return React.createElement(ClipboardCheck, { className: "h-4 w-4" });
    case "support-equipment":
      return React.createElement(Wrench, { className: "h-4 w-4" });
    case "electronics":
      return React.createElement(ArrowDownUp, { className: "h-4 w-4" });
    default:
      return React.createElement(Package, { className: "h-4 w-4" });
  }
};

// Get color based on category
export const getCategoryColor = (name: string): string => {
  const category = getCategoryFromName(name);
  switch (category) {
    case "weapons":
      return "text-red-600 dark:text-red-500";
    case "comsec":
      return "text-blue-600 dark:text-blue-400";
    case "optics":
      return "text-purple-600 dark:text-purple-400";
    case "vehicles":
      return "text-amber-600 dark:text-amber-400";
    case "individual-equipment":
      return "text-green-600 dark:text-green-500";
    case "medical":
      return "text-rose-600 dark:text-rose-400";
    case "support-equipment":
      return "text-orange-600 dark:text-orange-400";
    case "electronics":
      return "text-cyan-600 dark:text-cyan-400";
    default:
      return "text-gray-600 dark:text-gray-400";
  }
};

// Get formatted category label
export const getCategoryLabel = (category: string): string => {
  const option = categoryOptions.find(opt => opt.value === category);
  return option ? option.label : 'Other Equipment';
};

// Normalize legacy status values to new military-specific terminology
export const normalizeItemStatus = (status: string): string => {
  // Standard lookup for legacy statuses
  const statusMap: Record<string, string> = {
    'Non-Operational': 'Deadline - Maintenance',
    'Damaged': 'Deadline - Maintenance',
    'In Repair': 'Deadline - Maintenance'
  };

  // Return the normalized status, or the original if no mapping exists
  return statusMap[status] || status;
}; 