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
export declare const initialState: PropertyBookState;
export type PropertyBookAction = {
    type: 'SET_LOADING';
    payload: boolean;
} | {
    type: 'SET_ERROR';
    payload: string | null;
} | {
    type: 'SET_SEARCH_TERM';
    payload: string;
} | {
    type: 'SET_FILTER_CATEGORY';
    payload: string;
} | {
    type: 'SET_ACTIVE_TAB';
    payload: 'assigned' | 'signedout';
} | {
    type: 'TOGGLE_ITEM_SELECTION';
    payload: string;
} | {
    type: 'TOGGLE_EXPAND_ITEM';
    payload: string;
} | {
    type: 'TOGGLE_SELECT_ALL';
    payload: {
        itemIds: string[];
        selected: boolean;
    };
} | {
    type: 'SET_SORT';
    payload: {
        key: string;
        direction: 'ascending' | 'descending';
    };
} | {
    type: 'CLEAR_SORT';
} | {
    type: 'CLEAR_SELECTIONS';
};
export declare function propertyBookReducer(state: PropertyBookState, action: PropertyBookAction): PropertyBookState;
