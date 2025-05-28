import { MaintenanceItem, MaintenanceLog, MaintenanceBulletin } from './maintenanceData';

// Define the action types
type MaintenanceAction =
  | { type: 'SET_MAINTENANCE_ITEMS'; payload: MaintenanceItem[] }
  | { type: 'SET_MAINTENANCE_LOGS'; payload: MaintenanceLog[] }
  | { type: 'SET_BULLETINS'; payload: MaintenanceBulletin[] }
  | { type: 'SET_STATS'; payload: any }
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string | null }
  | { type: 'SET_SUBMITTING'; payload: boolean }
  | { type: 'SET_SEARCH_TERM'; payload: string }
  | { type: 'SET_FILTER_CATEGORY'; payload: string }
  | { type: 'SET_FILTER_STATUS'; payload: string }
  | { type: 'SET_FILTER_PRIORITY'; payload: string }
  | { type: 'SET_DATE_RANGE'; payload: { from: Date | null; to: Date | null } }
  | { type: 'SET_SELECTED_TAB'; payload: 'my-requests' | 'dashboard' | 'bulletins' }
  | { type: 'SET_SELECTED_BULLETIN_STATUS'; payload: 'active' | 'resolved' | 'all' }
  | { type: 'ADD_MAINTENANCE_ITEM'; payload: MaintenanceItem }
  | { type: 'UPDATE_MAINTENANCE_ITEM'; payload: MaintenanceItem }
  | { type: 'DELETE_MAINTENANCE_ITEM'; payload: string }
  | { type: 'ADD_BULLETIN'; payload: MaintenanceBulletin }
  | { type: 'UPDATE_BULLETIN'; payload: MaintenanceBulletin }
  | { type: 'ADD_MAINTENANCE_LOG'; payload: MaintenanceLog }
  | { type: 'RESET_FILTERS' }
  | { type: 'SET_SORT_CONFIG'; payload: keyof MaintenanceItem | 'none' };

// Define the state shape
export interface MaintenanceState {
  // Data
  maintenanceItems: MaintenanceItem[];
  maintenanceLogs: MaintenanceLog[];
  bulletins: MaintenanceBulletin[];
  stats: any; // Stats are stored as a generic object
  
  // UI State
  isLoading: boolean;
  isSubmitting: boolean;
  error: string | null;
  searchTerm: string;
  filterCategory: string;
  filterStatus: string;
  filterPriority: string;
  dateRange: { from?: Date | null; to?: Date | null };
  
  // Active content
  selectedTab: 'my-requests' | 'dashboard' | 'bulletins';
  selectedBulletinStatus: 'active' | 'resolved' | 'all';
  sortConfig: { field: keyof MaintenanceItem | 'none'; order: 'asc' | 'desc' };
}

// Define the initial state
export const initialState: MaintenanceState = {
  maintenanceItems: [],
  maintenanceLogs: [],
  bulletins: [],
  stats: null,
  isLoading: false,
  isSubmitting: false,
  error: null,
  searchTerm: '',
  filterCategory: 'all',
  filterStatus: 'all',
  filterPriority: 'all',
  dateRange: { from: null, to: null },
  selectedTab: 'my-requests',
  selectedBulletinStatus: 'active',
  sortConfig: { field: 'reportedDate', order: 'desc' },
};

// The reducer function
export function maintenanceReducer(
  state: MaintenanceState = initialState,
  action: MaintenanceAction
): MaintenanceState {
  switch (action.type) {
    case 'SET_MAINTENANCE_ITEMS':
      return {
        ...state,
        maintenanceItems: action.payload,
      };
    
    case 'SET_MAINTENANCE_LOGS':
      return {
        ...state,
        maintenanceLogs: action.payload,
      };
    
    case 'SET_BULLETINS':
      return {
        ...state,
        bulletins: action.payload,
      };
    
    case 'SET_STATS':
      return {
        ...state,
        stats: action.payload,
      };
    
    case 'SET_LOADING':
      return {
        ...state,
        isLoading: action.payload,
      };
    
    case 'SET_ERROR':
      return {
        ...state,
        error: action.payload,
      };
    
    case 'SET_SUBMITTING':
      return {
        ...state,
        isSubmitting: action.payload,
      };
    
    case 'SET_SEARCH_TERM':
      return {
        ...state,
        searchTerm: action.payload,
      };
    
    case 'SET_FILTER_CATEGORY':
      return {
        ...state,
        filterCategory: action.payload,
      };
    
    case 'SET_FILTER_STATUS':
      return {
        ...state,
        filterStatus: action.payload,
      };
    
    case 'SET_FILTER_PRIORITY':
      return {
        ...state,
        filterPriority: action.payload,
      };
    
    case 'SET_DATE_RANGE':
      return {
        ...state,
        dateRange: action.payload,
      };
    
    case 'SET_SELECTED_TAB':
      return {
        ...state,
        selectedTab: action.payload,
      };
    
    case 'SET_SELECTED_BULLETIN_STATUS':
      return {
        ...state,
        selectedBulletinStatus: action.payload,
      };
    
    case 'ADD_MAINTENANCE_ITEM':
      return {
        ...state,
        maintenanceItems: [...state.maintenanceItems, action.payload],
      };
    
    case 'UPDATE_MAINTENANCE_ITEM':
      return {
        ...state,
        maintenanceItems: state.maintenanceItems.map(item => 
          item.id === action.payload.id ? action.payload : item
        ),
      };
    
    case 'DELETE_MAINTENANCE_ITEM':
      return {
        ...state,
        maintenanceItems: state.maintenanceItems.filter(item => 
          item.id !== action.payload
        ),
      };
    
    case 'ADD_BULLETIN':
      return {
        ...state,
        bulletins: [...state.bulletins, action.payload],
      };
    
    case 'UPDATE_BULLETIN':
      return {
        ...state,
        bulletins: state.bulletins.map(bulletin => 
          bulletin.id === action.payload.id ? action.payload : bulletin
        ),
      };
    
    case 'ADD_MAINTENANCE_LOG':
      return {
        ...state,
        maintenanceLogs: [...state.maintenanceLogs, action.payload],
      };
    
    case 'RESET_FILTERS':
      return {
        ...state,
        searchTerm: '',
        filterCategory: 'all',
        filterStatus: 'all',
        filterPriority: 'all',
        dateRange: { from: null, to: null },
        sortConfig: { field: 'reportedDate', order: 'desc' },
      };
    
    case 'SET_SORT_CONFIG':
      const newOrder = state.sortConfig.field === action.payload && state.sortConfig.order === 'asc' ? 'desc' : 'asc';
      const newField = action.payload === 'none' ? 'reportedDate' : action.payload;
      return {
        ...state,
        sortConfig: { field: newField, order: newOrder },
      };
    
    default:
      return state;
  }
} 