import { getAllProperties, addProperty, getAllConsumables, addConsumable, addConsumptionHistory } from "./idb";
import { inventory } from "./mockData";
import { consumables, consumptionHistory } from "./consumablesData";

/**
 * Seed the IndexedDB with initial mock data for demo purposes
 */
export async function seedDatabase() {
  try {
    // Check if inventory data already exists
    const existingItems = await getAllProperties();
    if (existingItems.length === 0) {
      console.log("Seeding inventory data...");
      for (const item of inventory) {
        await addProperty(item);
      }
    } else {
      console.log("Inventory data already exists, skipping seeding.");
    }

    // Check if consumables data already exists
    const existingConsumables = await getAllConsumables();
    if (existingConsumables.length === 0) {
      console.log("Seeding consumables data...");
      for (const item of consumables) {
        await addConsumable(item);
      }
      
      // Seed consumption history entries
      console.log("Seeding consumption history data...");
      for (const entry of consumptionHistory) {
        await addConsumptionHistory(entry);
      }
    } else {
      console.log("Consumables data already exists, skipping seeding.");
    }

    console.log("Database seeding complete!");
  } catch (error) {
    console.error("Error seeding database:", error);
  }
} 