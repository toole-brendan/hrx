export interface SearchResult {
    id: string | number;
    type: 'property' | 'user' | 'transfer' | 'document' | 'nsn';
    title: string;
    subtitle?: string;
    metadata?: string;
    icon?: string;
    relevance?: number;
}
export interface UniversalSearchResponse {
    properties: SearchResult[];
    users: SearchResult[];
    transfers: SearchResult[];
    documents: SearchResult[];
    nsn: SearchResult[];
    totalCount: number;
}
export interface RecentSearch {
    query: string;
    timestamp: number;
    resultCount: number;
}
export declare function searchUsers(query: string): Promise<SearchResult[]>;
export declare function searchNSN(query: string, limit?: number): Promise<SearchResult[]>;
export declare function searchProperties(query: string): Promise<SearchResult[]>;
export declare function searchTransfers(query: string): Promise<SearchResult[]>;
export declare function universalSearch(query: string): Promise<UniversalSearchResponse>;
export declare function getRecentSearches(): RecentSearch[];
export declare function saveRecentSearch(query: string, resultCount: number): void;
export declare function clearRecentSearches(): void;
