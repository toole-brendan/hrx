import React, { useState, useEffect, useCallback, useRef } from 'react';
import { useLocation } from 'wouter';
import { useDebounce } from '@/hooks/use-debounce';
import { 
  universalSearch, 
  SearchResult,
  UniversalSearchResponse,
  getRecentSearches,
  saveRecentSearch,
  clearRecentSearches,
  RecentSearch
} from '@/services/searchService';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { 
  Search as SearchIcon, 
  X,
  Clock,
  Box,
  User,
  ArrowRightLeft,
  FileText,
  Package,
  ChevronRight,
  Loader2,
  SearchX
} from 'lucide-react';
import { cn } from '@/lib/utils';

// Filter pill component
interface FilterPillProps {
  label: string;
  count?: number;
  active: boolean;
  onClick: () => void;
}

const FilterPill: React.FC<FilterPillProps> = ({ label, count, active, onClick }) => (
  <button
    onClick={onClick}
    className={cn(
      "px-4 py-2 rounded-full text-sm font-medium transition-all duration-200",
      "flex items-center space-x-1.5",
      active 
        ? "bg-ios-accent text-white" 
        : "bg-ios-secondary-background text-secondary-text hover:bg-ios-divider"
    )}
  >
    <span>{label}</span>
    {count !== undefined && count > 0 && (
      <span className={cn(
        "text-xs px-1.5 py-0.5 rounded-full",
        active ? "bg-white/20" : "bg-ios-divider"
      )}>
        {count}
      </span>
    )}
  </button>
);

// Search result row component
interface SearchResultRowProps {
  result: SearchResult;
  searchTerm: string;
  onClick: () => void;
}

const SearchResultRow: React.FC<SearchResultRowProps> = ({ result, searchTerm, onClick }) => {
  const getIcon = () => {
    const iconClass = "h-5 w-5";
    switch (result.icon) {
      case 'user':
        return <User className={iconClass} />;
      case 'box':
        return <Box className={iconClass} />;
      case 'arrow-right-left':
        return <ArrowRightLeft className={iconClass} />;
      case 'file-text':
        return <FileText className={iconClass} />;
      case 'package':
        return <Package className={iconClass} />;
      default:
        return <Box className={iconClass} />;
    }
  };

  const highlightMatch = (text: string) => {
    if (!searchTerm) return text;
    
    const regex = new RegExp(`(${searchTerm})`, 'gi');
    const parts = text.split(regex);
    
    return parts.map((part, index) => 
      regex.test(part) ? (
        <span key={index} className="font-semibold text-ios-accent">
          {part}
        </span>
      ) : (
        <span key={index}>{part}</span>
      )
    );
  };

  return (
    <button
      onClick={onClick}
      className="w-full flex items-center space-x-4 px-6 py-4 hover:bg-ios-secondary-background/50 transition-colors"
    >
      <div className="flex-shrink-0 w-10 h-10 rounded-full bg-ios-secondary-background flex items-center justify-center text-secondary-text">
        {getIcon()}
      </div>
      
      <div className="flex-1 text-left">
        <div className="font-medium text-primary-text">
          {highlightMatch(result.title)}
        </div>
        {result.subtitle && (
          <div className="text-sm text-secondary-text mt-0.5">
            {result.subtitle}
          </div>
        )}
        {result.metadata && (
          <div className="text-xs text-tertiary-text mt-1">
            {result.metadata}
          </div>
        )}
      </div>
      
      <ChevronRight className="h-4 w-4 text-tertiary-text flex-shrink-0" />
    </button>
  );
};

// Quick search suggestion component
interface QuickSearchProps {
  label: string;
  onClick: () => void;
}

const QuickSearch: React.FC<QuickSearchProps> = ({ label, onClick }) => (
  <button
    onClick={onClick}
    className="text-ios-accent text-sm font-medium hover:underline"
  >
    {label}
  </button>
);

// Main search component
type FilterType = 'all' | 'properties' | 'people' | 'transfers' | 'documents';

export default function Search() {
  const [, navigate] = useLocation();
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<FilterType>('all');
  const [isSearching, setIsSearching] = useState(false);
  const [results, setResults] = useState<UniversalSearchResponse | null>(null);
  const [recentSearches, setRecentSearches] = useState<RecentSearch[]>([]);
  const searchInputRef = useRef<HTMLInputElement>(null);
  
  const debouncedSearch = useDebounce(searchQuery, 300);

  // Load recent searches on mount
  useEffect(() => {
    setRecentSearches(getRecentSearches());
    // Focus search input on mount
    searchInputRef.current?.focus();
  }, []);

  // Perform search when debounced query changes
  useEffect(() => {
    if (debouncedSearch.length >= 2) {
      performSearch(debouncedSearch);
    } else if (debouncedSearch.length === 0) {
      setResults(null);
      setRecentSearches(getRecentSearches());
    }
  }, [debouncedSearch]);

  const performSearch = useCallback(async (query: string) => {
    setIsSearching(true);
    try {
      const searchResults = await universalSearch(query);
      setResults(searchResults);
      
      // Save to recent searches if results found
      if (searchResults.totalCount > 0) {
        saveRecentSearch(query, searchResults.totalCount);
      }
    } catch (error) {
      console.error('Search error:', error);
      setResults(null);
    } finally {
      setIsSearching(false);
    }
  }, []);

  const handleQuickSearch = (query: string) => {
    setSearchQuery(query);
  };

  const handleRecentSearch = (search: RecentSearch) => {
    setSearchQuery(search.query);
  };

  const handleResultClick = (result: SearchResult) => {
    // Navigate based on result type
    switch (result.type) {
      case 'property':
        navigate(`/property-book?item=${result.id}`);
        break;
      case 'user':
        navigate(`/network?user=${result.id}`);
        break;
      case 'transfer':
        navigate(`/transfers?id=${result.id}`);
        break;
      case 'document':
        navigate(`/documents?id=${result.id}`);
        break;
      case 'nsn':
        // For NSN items, navigate to property book with NSN filter
        navigate(`/property-book?nsn=${result.id}`);
        break;
    }
  };

  const getFilteredResults = () => {
    if (!results) return [];
    
    switch (activeFilter) {
      case 'properties':
        return [...results.properties, ...results.nsn];
      case 'people':
        return results.users;
      case 'transfers':
        return results.transfers;
      case 'documents':
        return results.documents;
      default:
        return [
          ...results.properties,
          ...results.users,
          ...results.transfers,
          ...results.documents,
          ...results.nsn
        ];
    }
  };

  const filteredResults = getFilteredResults();

  return (
    <div className="min-h-screen" style={{ backgroundColor: '#FAFAFA' }}>
      <div className="max-w-3xl mx-auto">
        {/* Search Header */}
        <div className="sticky top-0 z-10 bg-white border-b border-ios-divider">
          <div className="px-6 py-4">
            <div className="flex items-center space-x-4">
              <button
                onClick={() => navigate('/dashboard')}
                className="text-tertiary-text hover:text-primary-text transition-colors"
              >
                <X className="h-6 w-6" />
              </button>
              
              <div className="flex-1 relative">
                <SearchIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-tertiary-text" />
                <Input
                  ref={searchInputRef}
                  type="text"
                  placeholder="Search properties, people, transfers..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10 pr-10 h-11 bg-ios-secondary-background border-0 rounded-lg text-base"
                />
                {searchQuery && (
                  <button
                    onClick={() => setSearchQuery('')}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-tertiary-text hover:text-primary-text"
                  >
                    <X className="h-4 w-4" />
                  </button>
                )}
              </div>
            </div>
            
            {/* Filter Pills */}
            {results && (
              <div className="flex items-center space-x-2 mt-4 overflow-x-auto scrollbar-hide">
                <FilterPill
                  label="All"
                  count={results.totalCount}
                  active={activeFilter === 'all'}
                  onClick={() => setActiveFilter('all')}
                />
                <FilterPill
                  label="Properties"
                  count={results.properties.length + results.nsn.length}
                  active={activeFilter === 'properties'}
                  onClick={() => setActiveFilter('properties')}
                />
                <FilterPill
                  label="People"
                  count={results.users.length}
                  active={activeFilter === 'people'}
                  onClick={() => setActiveFilter('people')}
                />
                <FilterPill
                  label="Transfers"
                  count={results.transfers.length}
                  active={activeFilter === 'transfers'}
                  onClick={() => setActiveFilter('transfers')}
                />
                <FilterPill
                  label="Documents"
                  count={results.documents.length}
                  active={activeFilter === 'documents'}
                  onClick={() => setActiveFilter('documents')}
                />
              </div>
            )}
          </div>
        </div>

        {/* Search Content */}
        <div className="pb-20">
          {isSearching ? (
            // Loading state
            <div className="flex flex-col items-center justify-center py-20">
              <Loader2 className="h-8 w-8 text-ios-accent animate-spin mb-4" />
              <p className="text-secondary-text">Searching...</p>
            </div>
          ) : results ? (
            // Search results
            filteredResults.length > 0 ? (
              <div className="divide-y divide-ios-divider">
                {filteredResults.map((result, index) => (
                  <SearchResultRow
                    key={`${result.type}-${result.id}-${index}`}
                    result={result}
                    searchTerm={debouncedSearch}
                    onClick={() => handleResultClick(result)}
                  />
                ))}
              </div>
            ) : (
              // No results
              <div className="flex flex-col items-center justify-center py-20">
                <SearchX className="h-12 w-12 text-tertiary-text mb-4" />
                <h3 className="text-lg font-medium text-primary-text mb-2">No results found</h3>
                <p className="text-secondary-text text-center max-w-sm">
                  Try adjusting your search terms or filters
                </p>
              </div>
            )
          ) : (
            // Initial state with quick searches and recent searches
            <div className="px-6 py-8 space-y-8">
              {/* Quick Searches */}
              <div>
                <h3 className="text-xs font-medium text-tertiary-text uppercase tracking-wider mb-3">
                  Quick Searches
                </h3>
                <div className="flex flex-wrap gap-3">
                  <QuickSearch label="Active Properties" onClick={() => handleQuickSearch('status:active')} />
                  <QuickSearch label="Recent Transfers" onClick={() => handleQuickSearch('transfer')} />
                  <QuickSearch label="Maintenance Due" onClick={() => handleQuickSearch('maintenance')} />
                  <QuickSearch label="My Team" onClick={() => handleQuickSearch('team')} />
                </div>
              </div>
              
              {/* Recent Searches */}
              {recentSearches.length > 0 && (
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <h3 className="text-xs font-medium text-tertiary-text uppercase tracking-wider">
                      Recent Searches
                    </h3>
                    <button
                      onClick={() => {
                        clearRecentSearches();
                        setRecentSearches([]);
                      }}
                      className="text-xs text-ios-accent font-medium"
                    >
                      Clear
                    </button>
                  </div>
                  <div className="space-y-1">
                    {recentSearches.map((search, index) => (
                      <button
                        key={index}
                        onClick={() => handleRecentSearch(search)}
                        className="w-full flex items-center space-x-3 px-4 py-3 rounded-lg hover:bg-ios-secondary-background/50 transition-colors"
                      >
                        <Clock className="h-4 w-4 text-tertiary-text flex-shrink-0" />
                        <span className="flex-1 text-left text-primary-text">{search.query}</span>
                        <span className="text-xs text-tertiary-text">{search.resultCount} results</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}