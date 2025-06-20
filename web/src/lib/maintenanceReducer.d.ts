import { MaintenanceItem, MaintenanceLog, MaintenanceBulletin } from './maintenanceData';
type MaintenanceAction = {
    type: 'SET_MAINTENANCE_ITEMS';
    payload: MaintenanceItem[];
} | {
    type: 'SET_MAINTENANCE_LOGS';
    payload: MaintenanceLog[];
} | {
    type: 'SET_BULLETINS';
    payload: MaintenanceBulletin[];
} | {
    type: 'SET_STATS';
    payload: any;
} | {
    type: 'SET_LOADING';
    payload: boolean;
} | {
    type: 'SET_ERROR';
    payload: string | null;
} | {
    type: 'SET_SUBMITTING';
    payload: boolean;
} | {
    type: 'SET_SEARCH_TERM';
    payload: string;
} | {
    type: 'SET_FILTER_CATEGORY';
    payload: string;
} | {
    type: 'SET_FILTER_STATUS';
    payload: string;
} | {
    type: 'SET_FILTER_PRIORITY';
    payload: string;
} | {
    type: 'SET_DATE_RANGE';
    payload: {
        from: Date | null;
        to: Date | null;
    };
} | {
    type: 'SET_SELECTED_TAB';
    payload: 'my-requests' | 'dashboard' | 'bulletins';
} | {
    type: 'SET_SELECTED_BULLETIN_STATUS';
    payload: 'active' | 'resolved' | 'all';
} | {
    type: 'ADD_MAINTENANCE_ITEM';
    payload: MaintenanceItem;
} | {
    type: 'UPDATE_MAINTENANCE_ITEM';
    payload: MaintenanceItem;
} | {
    type: 'DELETE_MAINTENANCE_ITEM';
    payload: string;
} | {
    type: 'ADD_BULLETIN';
    payload: MaintenanceBulletin;
} | {
    type: 'UPDATE_BULLETIN';
    payload: MaintenanceBulletin;
} | {
    type: 'ADD_MAINTENANCE_LOG';
    payload: MaintenanceLog;
} | {
    type: 'RESET_FILTERS';
} | {
    type: 'SET_SORT_CONFIG';
    payload: keyof MaintenanceItem | 'none';
};
export interface MaintenanceState {
}
export declare const initialState: MaintenanceState;
export declare function maintenanceReducer(state: MaintenanceState | undefined, action: MaintenanceAction): MaintenanceState;
export {};
