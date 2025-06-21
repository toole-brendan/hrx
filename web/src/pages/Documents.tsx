import React, { useState, useMemo } from 'react';
import { useLocation } from 'wouter';
import { DocumentsInbox } from '@/components/documents/DocumentsInbox';
import { useQuery } from '@tanstack/react-query';
import { getDocuments } from '@/services/documentService';
import { 
  FileText, 
  Search, 
  Bell, 
  UserCircle,
  Inbox,
  Send,
  Archive,
  Filter,
  Download,
  Upload,
  Shield,
  File,
  FileCheck,
  FileX,
  FilePlus,
  Folder,
  FolderOpen,
  Scan,
  Trash2,
  MoreVertical,
  ChevronRight,
  Calendar,
  Clock,
  CheckCircle,
  AlertCircle,
  XCircle,
  Plus,
  Grid,
  List,
  SlidersHorizontal
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { useNotifications } from '@/contexts/NotificationContext';
import NotificationPanel from '@/components/modals/NotificationPanel';
import { DA2062ExportDialog } from '@/components/da2062/DA2062ExportDialog';
import { DA2062ImportDialog } from '@/components/da2062/DA2062ImportDialog';
import { cn } from '@/lib/utils';
import { CleanCard } from '@/components/ios';

// Document types and categories
export type DocumentCategory = 'forms' | 'receipts' | 'reports' | 'certificates' | 'correspondence' | 'all';

interface DocumentType {
  id: DocumentCategory;
  label: string;
  icon: React.ReactNode;
  color: string;
  count?: number;
}

const documentTypes: DocumentType[] = [
  { id: 'all', label: 'All Documents', icon: <Folder className="h-4 w-4" />, color: 'gray' },
  { id: 'forms', label: 'Forms', icon: <FileText className="h-4 w-4" />, color: 'blue' },
  { id: 'receipts', label: 'Receipts', icon: <FileCheck className="h-4 w-4" />, color: 'green' },
  { id: 'reports', label: 'Reports', icon: <File className="h-4 w-4" />, color: 'purple' },
  { id: 'certificates', label: 'Certificates', icon: <Shield className="h-4 w-4" />, color: 'orange' },
  { id: 'correspondence', label: 'Correspondence', icon: <Send className="h-4 w-4" />, color: 'pink' },
];

// View modes
type ViewMode = 'grid' | 'list';

// Enhanced Stat Card Component
interface StatCardProps {
  title: string;
  value: string | number;
  icon: React.ReactNode;
  trend?: {
    value: number;
    label: string;
  };
  subtitle?: string;
}

const StatCard: React.FC<StatCardProps> = ({ title, value, icon, trend, subtitle }) => (
  <div className="bg-gradient-to-br from-white to-ios-secondary-background rounded-xl p-6 border border-ios-border shadow-sm hover:shadow-md transition-all duration-300">
    <div className="flex items-start justify-between mb-4">
      <div className="p-3 bg-ios-accent/10 rounded-lg">
        {icon}
      </div>
      {trend && (
        <div className="text-right">
          <div className={`text-sm font-semibold ${trend.value > 0 ? 'text-green-500' : 'text-ios-tertiary-text'}`}>
            {trend.value > 0 && "+"}{trend.value}%
          </div>
          <div className="text-xs text-ios-tertiary-text">{trend.label}</div>
        </div>
      )}
    </div>
    <div>
      <div className="text-3xl font-bold text-ios-primary-text mb-1 font-['Courier_New',_monospace]">
        {typeof value === 'number' ? value.toLocaleString() : value}
      </div>
      <h3 className="text-sm font-medium text-ios-secondary-text">{title}</h3>
      {subtitle && (
        <p className="text-xs text-ios-tertiary-text mt-1">{subtitle}</p>
      )}
    </div>
  </div>
);

export default function Documents() {
  const [, navigate] = useLocation();
  const { unreadCount } = useNotifications();
  const [showNotifications, setShowNotifications] = useState(false);
  const [showingDA2062Export, setShowingDA2062Export] = useState(false);
  const [showingDA2062Import, setShowingDA2062Import] = useState(false);
  const [selectedCategory, setSelectedCategory] = useState<DocumentCategory>('all');
  const [viewMode, setViewMode] = useState<ViewMode>('list');
  const [searchQuery, setSearchQuery] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [selectedDocuments, setSelectedDocuments] = useState<Set<string>>(new Set());

  // Fetch document stats
  const { data: inboxData } = useQuery({
    queryKey: ['documents', 'inbox'],
    queryFn: () => getDocuments('inbox'),
  });

  const { data: sentData } = useQuery({
    queryKey: ['documents', 'sent'],
    queryFn: () => getDocuments('sent'),
  });

  const { data: allData } = useQuery({
    queryKey: ['documents', 'all'],
    queryFn: () => getDocuments('all'),
  });

  const unreadDocuments = inboxData?.unread_count || 0;
  const totalInbox = inboxData?.documents.length || 0;
  const totalSent = sentData?.documents.length || 0;
  const totalDocuments = allData?.documents.length || 0;

  // Handle bulk actions
  const handleBulkAction = (action: 'download' | 'archive' | 'delete') => {
    console.log(`Bulk ${action} for:`, Array.from(selectedDocuments));
    // Implement bulk actions here
    setSelectedDocuments(new Set());
  };

  return (
    <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
      <div className="max-w-7xl mx-auto px-6 py-8">
        {/* Enhanced Header section */}
        <div className="mb-8">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-3">
              <div className="p-3 bg-gradient-to-br from-ios-accent to-ios-accent/80 rounded-xl shadow-sm">
                <FileText className="h-6 w-6 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-bold text-ios-primary-text">
                  Documents
                </h1>
                <p className="text-sm text-ios-secondary-text mt-1">
                  Manage your forms, receipts, and official documents
                </p>
              </div>
            </div>
          </div>
          
        </div>

        {/* Professional Document Actions Toolbar */}
        <div className="mb-6">
          <CleanCard className="p-4 shadow-sm">
            <div className="flex items-center justify-between">
              {/* Left side - Create actions */}
              <div className="flex items-center gap-2">
                <Button
                  className="bg-ios-accent hover:bg-ios-accent/90 text-white rounded-lg px-4 py-2 font-medium shadow-sm transition-all duration-200 flex items-center gap-2"
                >
                  <Plus className="h-4 w-4" />
                  New Document
                </Button>
                <div className="h-8 w-px bg-ios-border mx-2" />
                <Button
                  variant="outline"
                  size="sm"
                  className="border-ios-border hover:bg-ios-tertiary-background text-ios-primary-text font-medium transition-all duration-200"
                  onClick={() => setShowingDA2062Import(true)}
                >
                  <Upload className="h-4 w-4 mr-2" />
                  Upload
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  className="border-ios-border hover:bg-ios-tertiary-background text-ios-primary-text font-medium transition-all duration-200"
                >
                  <Scan className="h-4 w-4 mr-2" />
                  Scan
                </Button>
              </div>
              
              {/* Right side - View and filter controls */}
              <div className="flex items-center gap-3">
                {/* Search */}
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-ios-tertiary-text" />
                  <Input
                    placeholder="Search documents..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    className="pl-10 pr-4 w-64 h-9 border-ios-border bg-ios-tertiary-background/50 rounded-lg text-sm placeholder:text-ios-tertiary-text focus-visible:ring-2 focus-visible:ring-ios-accent transition-all duration-200"
                  />
                </div>
                
                {/* View mode toggle */}
                <div className="flex items-center bg-ios-tertiary-background rounded-lg p-1">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setViewMode('list')}
                    className={cn(
                      "h-7 px-3 rounded-md transition-all duration-200",
                      viewMode === 'list' ? "bg-white shadow-sm" : "hover:bg-transparent"
                    )}
                  >
                    <List className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setViewMode('grid')}
                    className={cn(
                      "h-7 px-3 rounded-md transition-all duration-200",
                      viewMode === 'grid' ? "bg-white shadow-sm" : "hover:bg-transparent"
                    )}
                  >
                    <Grid className="h-4 w-4" />
                  </Button>
                </div>
                
                {/* Filter button */}
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowFilters(!showFilters)}
                  className="border-ios-border hover:bg-ios-tertiary-background text-ios-primary-text font-medium transition-all duration-200"
                >
                  <SlidersHorizontal className="h-4 w-4 mr-2" />
                  Filters
                </Button>
              </div>
            </div>
            
            {/* Bulk actions bar (shown when items selected) */}
            {selectedDocuments.size > 0 && (
              <div className="mt-4 pt-4 border-t border-ios-border flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <span className="text-sm text-ios-secondary-text">
                    {selectedDocuments.size} document{selectedDocuments.size > 1 ? 's' : ''} selected
                  </span>
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleBulkAction('download')}
                    className="border-ios-border hover:bg-ios-tertiary-background text-ios-primary-text font-medium transition-all duration-200"
                  >
                    <Download className="h-4 w-4 mr-2" />
                    Download
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleBulkAction('archive')}
                    className="border-ios-border hover:bg-ios-tertiary-background text-ios-primary-text font-medium transition-all duration-200"
                  >
                    <Archive className="h-4 w-4 mr-2" />
                    Archive
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleBulkAction('delete')}
                    className="border-ios-destructive/20 hover:bg-ios-destructive hover:border-ios-destructive text-ios-destructive hover:text-white font-medium transition-all duration-200"
                  >
                    <Trash2 className="h-4 w-4 mr-2" />
                    Delete
                  </Button>
                </div>
              </div>
            )}
          </CleanCard>
        </div>

        {/* Main content area with sidebar */}
        <div className="flex gap-6">
          {/* Sidebar - Document Categories */}
          <div className="w-64 flex-shrink-0">
            <CleanCard className="p-4 shadow-sm">
              <h3 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider mb-4 font-['Courier_New',_monospace]">
                CATEGORIES
              </h3>
              <div className="space-y-1">
                {documentTypes.map((type) => {
                  const isSelected = selectedCategory === type.id;
                  return (
                    <button
                      key={type.id}
                      onClick={() => setSelectedCategory(type.id)}
                      className={cn(
                        "w-full flex items-center justify-between px-3 py-2.5 rounded-lg transition-all duration-200 group",
                        isSelected
                          ? "bg-ios-accent text-white shadow-sm"
                          : "hover:bg-ios-tertiary-background text-ios-secondary-text hover:text-ios-primary-text"
                      )}
                    >
                      <div className="flex items-center gap-3">
                        <div className={cn(
                          "p-1.5 rounded-md transition-colors duration-200",
                          isSelected ? "bg-white/20" : `bg-${type.color}-500/10 text-${type.color}-500`
                        )}>
                          {type.icon}
                        </div>
                        <span className="text-sm font-medium">{type.label}</span>
                      </div>
                      <span className={cn(
                        "text-xs font-bold font-['Courier_New',_monospace]",
                        isSelected ? "text-white/80" : "text-ios-tertiary-text"
                      )}>
                        {type.count || 0}
                      </span>
                    </button>
                  );
                })}
              </div>
              
              {/* Date filters */}
              <div className="mt-6 pt-6 border-t border-ios-border">
                <h4 className="text-xs font-semibold text-ios-secondary-text uppercase tracking-wider mb-3">
                  Date Range
                </h4>
                <div className="space-y-2">
                  <Button
                    variant="outline"
                    size="sm"
                    className="w-full justify-start border-ios-border hover:bg-ios-tertiary-background text-ios-secondary-text font-normal"
                  >
                    <Calendar className="h-4 w-4 mr-2" />
                    Last 7 days
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    className="w-full justify-start border-ios-border hover:bg-ios-tertiary-background text-ios-secondary-text font-normal"
                  >
                    <Calendar className="h-4 w-4 mr-2" />
                    Last 30 days
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    className="w-full justify-start border-ios-border hover:bg-ios-tertiary-background text-ios-secondary-text font-normal"
                  >
                    <Calendar className="h-4 w-4 mr-2" />
                    Custom range
                  </Button>
                </div>
              </div>
            </CleanCard>
          </div>
          
          {/* Main content - Documents list */}
          <div className="flex-1">
            {/* Stats cards */}
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
              <StatCard
                title="Total Documents"
                value={totalDocuments}
                icon={<Archive className="h-5 w-5 text-ios-accent" />}
                subtitle="All categories"
              />
              <StatCard
                title="Pending Review"
                value={unreadDocuments}
                icon={<Clock className="h-5 w-5 text-orange-500" />}
                subtitle="Requires action"
              />
              <StatCard
                title="Approved"
                value={totalInbox - unreadDocuments}
                icon={<CheckCircle className="h-5 w-5 text-green-500" />}
                subtitle="This month"
              />
              <StatCard
                title="Drafts"
                value="3"
                icon={<FileX className="h-5 w-5 text-purple-500" />}
                subtitle="In progress"
              />
            </div>
            
            {/* Documents list/grid will go here */}
            <DocumentsInbox viewMode={viewMode} selectedCategory={selectedCategory} searchQuery={searchQuery} />
          </div>
        </div>
        
        {/* Bottom padding for mobile navigation */}
        <div className="h-24"></div>
      </div>

      {/* Notification Panel */}
      <NotificationPanel 
        isOpen={showNotifications}
        onClose={() => setShowNotifications(false)}
      />

      {/* DA2062 Export Dialog */}
      <DA2062ExportDialog
        isOpen={showingDA2062Export}
        onClose={() => {
          setShowingDA2062Export(false);
        }}
      />

      {/* DA2062 Import Dialog */}
      <DA2062ImportDialog
        isOpen={showingDA2062Import}
        onClose={() => setShowingDA2062Import(false)}
      />
    </div>
  );
} 