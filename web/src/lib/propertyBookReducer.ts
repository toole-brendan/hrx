import { InventoryItem } from "@/types";

// Define state interface
export interface PropertyBookState {
  isLoading: boolean;
  error: string | null;
  searchTerm: string;
  filterCategory: string;
  selectedItemIds: Set<string>;
  expandedItemIds: Set<string>;
  activeTab: 'assigned' | 'signedout';
  sortConfig: {
    key: string | null;
    direction: 'ascending' | 'descending';
  } | null;
}

// Define initial state
export const initialState: PropertyBookState = {
  isLoading: true,
  error: null,
  searchTerm: "",
  filterCategory: "all",
  selectedItemIds: new Set(),
  expandedItemIds: new Set(),
  activeTab: 'assigned',
  sortConfig: null
};

// Define action types
export type PropertyBookAction =
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_SEARCH_TERM'; payload: string }
  | { type: 'SET_FILTER_CATEGORY'; payload: string }
  | { type: 'SET_ACTIVE_TAB'; payload: 'assigned' | 'signedout' }
  | { type: 'TOGGLE_ITEM_SELECTION'; payload: string }
  | { type: 'TOGGLE_EXPAND_ITEM'; payload: string }
  | { type: 'TOGGLE_SELECT_ALL'; payload: { itemIds: string[]; selected: boolean } }
  | { type: 'SET_SORT'; payload: { key: string; direction: 'ascending' | 'descending' } }
  | { type: 'CLEAR_SORT' }
  | { type: 'CLEAR_SELECTIONS' };

// Reducer function
export function propertyBookReducer(state: PropertyBookState, action: PropertyBookAction): PropertyBookState {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, isLoading: action.payload };
      
    case 'SET_ERROR':
      return { ...state, error: action.payload };
      
    case 'SET_SEARCH_TERM':
      return { ...state, searchTerm: action.payload };
      
    case 'SET_FILTER_CATEGORY':
      return { ...state, filterCategory: action.payload };
      
    case 'SET_ACTIVE_TAB':
      return { ...state, activeTab: action.payload };
      
    case 'TOGGLE_ITEM_SELECTION': {
      const newSelectedItemIds = new Set(state.selectedItemIds);
      if (newSelectedItemIds.has(action.payload)) {
        newSelectedItemIds.delete(action.payload);
      } else {
        newSelectedItemIds.add(action.payload);
      }
      return { ...state, selectedItemIds: newSelectedItemIds };
    }
    
    case 'TOGGLE_EXPAND_ITEM': {
      console.log("TOGGLE_EXPAND_ITEM reducer called with ID:", action.payload);
      console.log("Current expanded items:", Array.from(state.expandedItemIds));
      
      const newExpandedItemIds = new Set(state.expandedItemIds);
      
      if (newExpandedItemIds.has(action.payload)) {
        console.log("Removing item from expanded set");
        newExpandedItemIds.delete(action.payload);
      } else {
        console.log("Adding item to expanded set");
        newExpandedItemIds.add(action.payload);
      }
      
      console.log("New expanded items:", Array.from(newExpandedItemIds));
      
      return { ...state, expandedItemIds: newExpandedItemIds };
    }
    
    case 'TOGGLE_SELECT_ALL': {
      const { itemIds, selected } = action.payload;
      const newSelectedItemIds = new Set(state.selectedItemIds);
      
      if (selected) {
        // Add all itemIds to the selection
        itemIds.forEach(id => newSelectedItemIds.add(id));
      } else {
        // Remove all itemIds from the selection
        itemIds.forEach(id => newSelectedItemIds.delete(id));
      }
      
      return { ...state, selectedItemIds: newSelectedItemIds };
    }
    
    case 'SET_SORT':
      return { 
        ...state, 
        sortConfig: { 
          key: action.payload.key, 
          direction: action.payload.direction 
        } 
      };
      
    case 'CLEAR_SORT':
      return { ...state, sortConfig: null };
      
    case 'CLEAR_SELECTIONS':
      return { ...state, selectedItemIds: new Set() };
      
    default:
      return state;
  }
} 