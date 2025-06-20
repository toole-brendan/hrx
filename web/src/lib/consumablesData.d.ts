import { ConsumableItem } from "@/types";
export declare const consumableCategories: {
    id: string;
    name: string;
    icon: string;
}[];
export declare const consumables: ConsumableItem[];
export declare const consumptionHistory: {
    id: string;
    itemId: string;
    quantity: number;
    date: string;
    issuedTo: string;
    issuedBy: string;
}[];
