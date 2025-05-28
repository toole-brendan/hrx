import { 
  saveInventoryItemsToDB, 
  saveConsumablesToDB, 
  addConsumptionHistoryEntryToDB, 
  getConsumablesFromDB,
  getInventoryItemsFromDB
} from "./idb";
import { inventory } from "./mockData";
import { consumables, consumptionHistory } from "./consumablesData";

/**
 * Seed the IndexedDB with initial mock data for demo purposes
 */
export async function seedDatabase() {
  try {
    // Check if inventory data already exists
    const existingItems = await getInventoryItemsFromDB();
    if (existingItems.length === 0) {
      console.log("Seeding inventory data...");
      await saveInventoryItemsToDB(inventory);
    } else {
      console.log("Inventory data already exists, skipping seeding.");
    }

    // Check if consumables data already exists
    const existingConsumables = await getConsumablesFromDB();
    if (existingConsumables.length === 0) {
      console.log("Seeding consumables data...");
      await saveConsumablesToDB(consumables);
      
      // Seed consumption history entries
      console.log("Seeding consumption history data...");
      for (const entry of consumptionHistory) {
        await addConsumptionHistoryEntryToDB(entry);
      }
    } else {
      console.log("Consumables data already exists, skipping seeding.");
    }

    console.log("Database seeding complete!");
  } catch (error) {
    console.error("Error seeding database:", error);
  }
} 