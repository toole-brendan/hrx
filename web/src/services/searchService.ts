const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

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

export async function searchUsers(query: string): Promise<SearchResult[]> {
  try {
    const response = await fetch(`${API_BASE_URL}/users/search?q=${encodeURIComponent(query)}`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
    });
    
    if (!response.ok) throw new Error('Failed to search users');
    const data = await response.json();
    
    return data.map((user: any) => ({
      id: user.id,
      type: 'user' as const,
      title: user.name || `${user.firstName} ${user.lastName}`.trim() || user.email,
      subtitle: user.email,
      metadata: user.rank ? `${user.rank} • ${user.unit || ''}`.trim() : user.unit,
      icon: 'user'
    }));
  } catch (error) {
    console.error('Error searching users:', error);
    return [];
  }
}

export async function searchNSN(query: string, limit: number = 10): Promise<SearchResult[]> {
  try {
    const response = await fetch(`${API_BASE_URL}/nsn/universal-search?q=${encodeURIComponent(query)}&limit=${limit}`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
    });
    
    if (!response.ok) throw new Error('Failed to search NSN');
    const data = await response.json();
    
    return data.map((item: any) => ({
      id: item.nsn,
      type: 'nsn' as const,
      title: item.itemName,
      subtitle: `NSN: ${formatNSN(item.nsn)}`,
      metadata: item.manufacturer ? `${item.manufacturer} • ${item.partNumber || ''}`.trim() : item.partNumber,
      icon: 'package'
    }));
  } catch (error) {
    console.error('Error searching NSN:', error);
    return [];
  }
}

export async function searchProperties(query: string): Promise<SearchResult[]> {
  try {
    // For now, fetch all properties and filter client-side
    // In production, this should be a server-side search endpoint
    const response = await fetch(`${API_BASE_URL}/properties`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
    });
    
    if (!response.ok) throw new Error('Failed to fetch properties');
    const data = await response.json();
    const searchLower = query.toLowerCase();
    
    return data
      .filter((property: any) => {
        return (
          property.name?.toLowerCase().includes(searchLower) ||
          property.serialNumber?.toLowerCase().includes(searchLower) ||
          property.nsn?.toLowerCase().includes(searchLower) ||
          property.description?.toLowerCase().includes(searchLower)
        );
      })
      .map((property: any) => ({
        id: property.id,
        type: 'property' as const,
        title: property.name,
        subtitle: property.serialNumber ? `S/N: ${property.serialNumber}` : undefined,
        metadata: property.nsn ? `NSN: ${formatNSN(property.nsn)}` : property.status,
        icon: 'box'
      }));
  } catch (error) {
    console.error('Error searching properties:', error);
    return [];
  }
}

export async function searchTransfers(query: string): Promise<SearchResult[]> {
  try {
    // For now, fetch all transfers and filter client-side
    // In production, this should be a server-side search endpoint
    const response = await fetch(`${API_BASE_URL}/transfers`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
    });
    
    if (!response.ok) throw new Error('Failed to fetch transfers');
    const data = await response.json();
    const searchLower = query.toLowerCase();
    
    return data
      .filter((transfer: any) => {
        return (
          transfer.id?.toString().includes(searchLower) ||
          transfer.status?.toLowerCase().includes(searchLower) ||
          transfer.fromUserName?.toLowerCase().includes(searchLower) ||
          transfer.toUserName?.toLowerCase().includes(searchLower)
        );
      })
      .map((transfer: any) => ({
        id: transfer.id,
        type: 'transfer' as const,
        title: `Transfer #${transfer.id}`,
        subtitle: `${transfer.fromUserName} → ${transfer.toUserName}`,
        metadata: `${transfer.status} • ${new Date(transfer.createdAt).toLocaleDateString()}`,
        icon: 'arrow-right-left'
      }));
  } catch (error) {
    console.error('Error searching transfers:', error);
    return [];
  }
}

export async function universalSearch(query: string): Promise<UniversalSearchResponse> {
  if (query.length < 2) {
    return {
      properties: [],
      users: [],
      transfers: [],
      documents: [],
      nsn: [],
      totalCount: 0
    };
  }

  // Perform parallel searches
  const [properties, users, transfers, nsn] = await Promise.all([
    searchProperties(query),
    searchUsers(query),
    searchTransfers(query),
    searchNSN(query)
  ]);

  const totalCount = properties.length + users.length + transfers.length + nsn.length;

  return {
    properties,
    users,
    transfers,
    documents: [], // TODO: Implement document search when endpoint is available
    nsn,
    totalCount
  };
}

// Recent searches management
const RECENT_SEARCHES_KEY = 'handreceipt_recent_searches';
const MAX_RECENT_SEARCHES = 10;

export function getRecentSearches(): RecentSearch[] {
  try {
    const stored = localStorage.getItem(RECENT_SEARCHES_KEY);
    return stored ? JSON.parse(stored) : [];
  } catch {
    return [];
  }
}

export function saveRecentSearch(query: string, resultCount: number): void {
  try {
    const searches = getRecentSearches();
    
    // Remove duplicate if exists
    const filtered = searches.filter(s => s.query.toLowerCase() !== query.toLowerCase());
    
    // Add new search at beginning
    const updated = [
      { query, timestamp: Date.now(), resultCount },
      ...filtered
    ].slice(0, MAX_RECENT_SEARCHES);
    
    localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(updated));
  } catch (error) {
    console.error('Error saving recent search:', error);
  }
}

export function clearRecentSearches(): void {
  try {
    localStorage.removeItem(RECENT_SEARCHES_KEY);
  } catch (error) {
    console.error('Error clearing recent searches:', error);
  }
}

// Helper function to format NSN
function formatNSN(nsn: string): string {
  if (!nsn || nsn.length !== 13) return nsn;
  return `${nsn.slice(0, 4)}-${nsn.slice(4, 6)}-${nsn.slice(6, 9)}-${nsn.slice(9)}`;
}