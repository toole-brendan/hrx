import React, { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Button } from '@/components/ui/button';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Checkbox } from '@/components/ui/checkbox';
import { 
  FileText, 
  User, 
  Calendar, 
  Paperclip, 
  Eye, 
  Download, 
  MoreVertical,
  FileCheck,
  File,
  FileX,
  Shield,
  Send,
  CheckCircle,
  Clock,
  AlertCircle
} from 'lucide-react';
import { format } from 'date-fns';
import { getDocuments, markAsRead, Document } from '@/services/documentService';
import { DocumentViewer } from './DocumentViewer';
import { CleanCard, ElegantSectionHeader, StatusBadge, MinimalEmptyState, MinimalLoadingView } from '@/components/ios';
import { cn } from '@/lib/utils';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

interface DocumentsInboxProps {
  viewMode?: 'grid' | 'list';
  selectedCategory?: string;
  searchQuery?: string;
}

export const DocumentsInbox: React.FC<DocumentsInboxProps> = ({ 
  viewMode = 'list', 
  selectedCategory = 'all', 
  searchQuery = '' 
}) => {
  const [selectedTab, setSelectedTab] = useState('inbox');
  const [selectedDocument, setSelectedDocument] = useState<Document | null>(null);
  const [viewerOpen, setViewerOpen] = useState(false);
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['documents', selectedTab],
    queryFn: () => getDocuments(selectedTab as 'inbox' | 'sent' | 'all'),
  });

  const markReadMutation = useMutation({
    mutationFn: markAsRead,
    onSuccess: () => {
      // Invalidate documents queries to refresh the list
      queryClient.invalidateQueries({ queryKey: ['documents'] });
    },
  });

  const handleViewDocument = async (doc: Document) => {
    if (doc.status === 'unread') {
      await markReadMutation.mutateAsync(doc.id);
    }
    setSelectedDocument(doc);
    setViewerOpen(true);
  };

  if (isLoading) {
    return (
      <MinimalLoadingView text="Loading documents..." size="lg" className="py-16" />
    );
  }

  if (error) {
    return (
      <CleanCard className="py-16 text-center">
        <p className="text-ios-destructive text-lg">Failed to load documents</p>
        <p className="text-secondary-text mt-2">Please try again later.</p>
      </CleanCard>
    );
  }

  return (
    <div className="space-y-6">

      {/* Tabs */}
      <CleanCard padding="none" className="shadow-sm overflow-hidden">
        <Tabs value={selectedTab} onValueChange={setSelectedTab}>
          <div className="bg-white p-1">
            <TabsList className="grid grid-cols-3 w-full gap-1 bg-transparent h-auto">
              <TabsTrigger
                value="inbox"
                className="px-4 py-2.5 text-xs font-semibold rounded-lg whitespace-nowrap transition-all duration-200 uppercase tracking-wider font-['Courier_New',_monospace] data-[state=active]:bg-ios-accent data-[state=active]:text-white data-[state=active]:shadow-sm data-[state=inactive]:bg-transparent data-[state=inactive]:text-ios-secondary-text hover:bg-ios-tertiary-background hover:text-ios-primary-text relative"
              >
                INBOX
                {(data?.unread_count ?? 0) > 0 && (
                  <span className="ml-2 px-2 py-0.5 bg-ios-destructive text-white rounded-full text-[10px] font-bold min-w-[1.5rem] inline-flex items-center justify-center">
                    {data?.unread_count}
                  </span>
                )}
              </TabsTrigger>
              <TabsTrigger
                value="sent"
                className="px-4 py-2.5 text-xs font-semibold rounded-lg whitespace-nowrap transition-all duration-200 uppercase tracking-wider font-['Courier_New',_monospace] data-[state=active]:bg-ios-accent data-[state=active]:text-white data-[state=active]:shadow-sm data-[state=inactive]:bg-transparent data-[state=inactive]:text-ios-secondary-text hover:bg-ios-tertiary-background hover:text-ios-primary-text"
              >
                SENT
              </TabsTrigger>
              <TabsTrigger
                value="all"
                className="px-4 py-2.5 text-xs font-semibold rounded-lg whitespace-nowrap transition-all duration-200 uppercase tracking-wider font-['Courier_New',_monospace] data-[state=active]:bg-ios-accent data-[state=active]:text-white data-[state=active]:shadow-sm data-[state=inactive]:bg-transparent data-[state=inactive]:text-ios-secondary-text hover:bg-ios-tertiary-background hover:text-ios-primary-text"
              >
                ALL DOCUMENTS
              </TabsTrigger>
            </TabsList>
          </div>

          <TabsContent value={selectedTab} className="p-0">
            {(data?.documents.length ?? 0) === 0 ? (
              <div className="p-6">
                <MinimalEmptyState
                  title={
                    selectedTab === 'inbox'
                      ? 'No documents received'
                      : selectedTab === 'sent'
                      ? 'No documents sent'
                      : 'No documents'
                  }
                  description={
                    selectedTab === 'inbox'
                      ? 'New documents will appear here'
                      : selectedTab === 'sent'
                      ? 'Documents you send will appear here'
                      : 'Your document history will appear here'
                  }
                  icon={<FileText className="h-12 w-12" />}
                />
              </div>
            ) : viewMode === 'list' ? (
              <DocumentsTable 
                documents={data?.documents || []} 
                selectedTab={selectedTab}
                onView={handleViewDocument}
                searchQuery={searchQuery}
              />
            ) : (
              <div className="p-6 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {data?.documents.map((doc) => (
                  <DocumentGridCard
                    key={doc.id}
                    document={doc}
                    selectedTab={selectedTab}
                    onView={() => handleViewDocument(doc)}
                  />
                ))}
              </div>
            )}
          </TabsContent>
        </Tabs>
      </CleanCard>

      {/* Document Viewer */}
      {selectedDocument && (
        <DocumentViewer
          document={selectedDocument}
          open={viewerOpen}
          onClose={() => {
            setViewerOpen(false);
            setSelectedDocument(null);
          }}
        />
      )}
    </div>
  );
};

// Professional Documents Table Component
interface DocumentsTableProps {
  documents: Document[];
  selectedTab: string;
  onView: (doc: Document) => void;
  searchQuery: string;
}

const DocumentsTable: React.FC<DocumentsTableProps> = ({ documents, selectedTab, onView, searchQuery }) => {
  const [selectedRows, setSelectedRows] = useState<Set<string>>(new Set());
  
  // Filter documents based on search query
  const filteredDocuments = useMemo(() => {
    if (!searchQuery) return documents;
    
    const query = searchQuery.toLowerCase();
    return documents.filter(doc => 
      doc.title.toLowerCase().includes(query) ||
      doc.type.toLowerCase().includes(query) ||
      doc.subtype?.toLowerCase().includes(query) ||
      doc.sender?.name.toLowerCase().includes(query) ||
      doc.recipient?.name.toLowerCase().includes(query)
    );
  }, [documents, searchQuery]);
  
  const toggleRow = (id: string) => {
    const newSelected = new Set(selectedRows);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelectedRows(newSelected);
  };
  
  const toggleAll = () => {
    if (selectedRows.size === filteredDocuments.length) {
      setSelectedRows(new Set());
    } else {
      setSelectedRows(new Set(filteredDocuments.map(doc => doc.id.toString())));
    }
  };
  
  const getDocumentIcon = (type: string, subtype?: string) => {
    const docType = subtype || type;
    switch (docType.toLowerCase()) {
      case 'form':
      case 'da-2062':
        return <FileText className="h-4 w-4" />;
      case 'receipt':
        return <FileCheck className="h-4 w-4" />;
      case 'report':
        return <File className="h-4 w-4" />;
      case 'certificate':
        return <Shield className="h-4 w-4" />;
      case 'correspondence':
        return <Send className="h-4 w-4" />;
      default:
        return <File className="h-4 w-4" />;
    }
  };
  
  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'unread':
        return <AlertCircle className="h-4 w-4 text-orange-500" />;
      case 'read':
        return <CheckCircle className="h-4 w-4 text-green-500" />;
      case 'pending':
        return <Clock className="h-4 w-4 text-amber-500" />;
      default:
        return <CheckCircle className="h-4 w-4 text-ios-tertiary-text" />;
    }
  };
  
  return (
    <div className="overflow-hidden">
      <Table>
        <TableHeader>
          <TableRow className="border-b border-ios-border hover:bg-transparent">
            <TableHead className="w-12">
              <Checkbox
                checked={selectedRows.size === filteredDocuments.length && filteredDocuments.length > 0}
                onCheckedChange={toggleAll}
                className="data-[state=checked]:bg-ios-accent data-[state=checked]:border-ios-accent"
              />
            </TableHead>
            <TableHead className="w-12"></TableHead>
            <TableHead className="font-semibold text-ios-primary-text">Document</TableHead>
            <TableHead className="font-semibold text-ios-primary-text">Type</TableHead>
            <TableHead className="font-semibold text-ios-primary-text">
              {selectedTab === 'sent' ? 'Recipient' : 'Sender'}
            </TableHead>
            <TableHead className="font-semibold text-ios-primary-text">Date</TableHead>
            <TableHead className="font-semibold text-ios-primary-text">Status</TableHead>
            <TableHead className="w-12"></TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {filteredDocuments.map((doc) => (
            <TableRow
              key={doc.id}
              className={cn(
                "border-b border-ios-border hover:bg-ios-secondary-background/50 cursor-pointer transition-colors",
                doc.status === 'unread' && "bg-ios-accent/5"
              )}
              onClick={() => onView(doc)}
            >
              <TableCell onClick={(e) => e.stopPropagation()}>
                <Checkbox
                  checked={selectedRows.has(doc.id.toString())}
                  onCheckedChange={() => toggleRow(doc.id.toString())}
                  className="data-[state=checked]:bg-ios-accent data-[state=checked]:border-ios-accent"
                />
              </TableCell>
              <TableCell>
                <div className={cn(
                  "p-2 rounded-lg",
                  doc.subtype === 'form' && "bg-blue-500/10 text-blue-500",
                  doc.subtype === 'receipt' && "bg-green-500/10 text-green-500",
                  doc.subtype === 'report' && "bg-purple-500/10 text-purple-500",
                  doc.subtype === 'certificate' && "bg-orange-500/10 text-orange-500",
                  (!doc.subtype || doc.subtype === 'correspondence') && "bg-pink-500/10 text-pink-500"
                )}>
                  {getDocumentIcon(doc.type, doc.subtype)}
                </div>
              </TableCell>
              <TableCell>
                <div className="flex flex-col">
                  <span className={cn(
                    "font-medium text-ios-primary-text",
                    doc.status === 'unread' && "font-semibold"
                  )}>
                    {doc.title}
                  </span>
                  {doc.description && (
                    <span className="text-xs text-ios-secondary-text line-clamp-1 mt-0.5">
                      {doc.description}
                    </span>
                  )}
                </div>
              </TableCell>
              <TableCell>
                <span className="text-sm text-ios-secondary-text capitalize">
                  {doc.subtype || doc.type}
                </span>
              </TableCell>
              <TableCell>
                <div className="flex flex-col">
                  <span className="text-sm text-ios-primary-text">
                    {selectedTab === 'sent' 
                      ? doc.recipient?.name || 'Unknown'
                      : doc.sender?.name || 'System'
                    }
                  </span>
                  {(selectedTab === 'sent' ? doc.recipient?.rank : doc.sender?.rank) && (
                    <span className="text-xs text-ios-secondary-text">
                      {selectedTab === 'sent' ? doc.recipient?.rank : doc.sender?.rank}
                    </span>
                  )}
                </div>
              </TableCell>
              <TableCell>
                <span className="text-sm text-ios-secondary-text">
                  {format(new Date(doc.sentAt), 'MMM d, yyyy')}
                </span>
              </TableCell>
              <TableCell>
                <div className="flex items-center gap-2">
                  {getStatusIcon(doc.status)}
                  {doc.status === 'unread' && (
                    <span className="text-xs font-semibold text-orange-500 uppercase">New</span>
                  )}
                </div>
              </TableCell>
              <TableCell onClick={(e) => e.stopPropagation()}>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-8 w-8 hover:bg-ios-tertiary-background"
                    >
                      <MoreVertical className="h-4 w-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end" className="w-48">
                    <DropdownMenuItem onClick={() => onView(doc)}>
                      <Eye className="h-4 w-4 mr-2" />
                      View
                    </DropdownMenuItem>
                    <DropdownMenuItem>
                      <Download className="h-4 w-4 mr-2" />
                      Download
                    </DropdownMenuItem>
                    <DropdownMenuSeparator />
                    <DropdownMenuItem className="text-ios-destructive">
                      <FileX className="h-4 w-4 mr-2" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  );
};

// Grid Card Component for Grid View
interface DocumentGridCardProps {
  document: Document;
  selectedTab: string;
  onView: () => void;
}

const DocumentGridCard: React.FC<DocumentGridCardProps> = ({ document, selectedTab, onView }) => {
  const getDocumentIcon = (type: string, subtype?: string) => {
    const docType = subtype || type;
    switch (docType.toLowerCase()) {
      case 'form':
      case 'da-2062':
        return <FileText className="h-6 w-6" />;
      case 'receipt':
        return <FileCheck className="h-6 w-6" />;
      case 'report':
        return <File className="h-6 w-6" />;
      case 'certificate':
        return <Shield className="h-6 w-6" />;
      case 'correspondence':
        return <Send className="h-6 w-6" />;
      default:
        return <File className="h-6 w-6" />;
    }
  };
  
  return (
    <CleanCard 
      className={cn(
        "p-6 cursor-pointer hover:shadow-lg transition-all duration-300 h-full flex flex-col",
        document.status === 'unread' && "border-ios-accent/30 bg-ios-accent/5"
      )}
      onClick={onView}
    >
      <div className="flex items-start justify-between mb-4">
        <div className={cn(
          "p-3 rounded-lg",
          document.subtype === 'form' && "bg-blue-500/10 text-blue-500",
          document.subtype === 'receipt' && "bg-green-500/10 text-green-500",
          document.subtype === 'report' && "bg-purple-500/10 text-purple-500",
          document.subtype === 'certificate' && "bg-orange-500/10 text-orange-500",
          (!document.subtype || document.subtype === 'correspondence') && "bg-pink-500/10 text-pink-500"
        )}>
          {getDocumentIcon(document.type, document.subtype)}
        </div>
        {document.status === 'unread' && (
          <span className="text-xs font-semibold text-orange-500 uppercase bg-orange-500/10 px-2 py-1 rounded">
            New
          </span>
        )}
      </div>
      
      <div className="flex-1 flex flex-col">
        <h3 className={cn(
          "font-semibold text-ios-primary-text mb-2 line-clamp-2",
          document.status === 'unread' && "font-bold"
        )}>
          {document.title}
        </h3>
        
        <p className="text-xs text-ios-secondary-text uppercase tracking-wider mb-3">
          {document.subtype || document.type}
        </p>
        
        <div className="mt-auto pt-4 border-t border-ios-border">
          <div className="flex items-center justify-between text-xs text-ios-secondary-text">
            <span className="flex items-center gap-1">
              <User className="h-3 w-3" />
              {selectedTab === 'sent' 
                ? document.recipient?.name || 'Unknown'
                : document.sender?.name || 'System'
              }
            </span>
            <span className="flex items-center gap-1">
              <Calendar className="h-3 w-3" />
              {format(new Date(document.sentAt), 'MMM d')}
            </span>
          </div>
        </div>
      </div>
    </CleanCard>
  );
};

interface DocumentCardProps {
  document: Document;
  selectedTab: string;
  onView: () => void;
}

const DocumentCard: React.FC<DocumentCardProps> = ({ document, selectedTab, onView }) => {
  let attachments = [];
  if (document.attachments) {
    try {
      // Try to parse as JSON
      attachments = JSON.parse(document.attachments);
    } catch (e) {
      // If parsing fails, check if it's a URL string
      if (typeof document.attachments === 'string' && document.attachments.startsWith('http')) {
        attachments = [{ url: document.attachments, name: 'Attachment' }];
      }
    }
  }
  const isUnread = document.status === 'unread';

  return (
    <div
      onClick={onView}
      className={`
        group relative bg-white rounded-xl border transition-all duration-300 cursor-pointer
        ${isUnread 
          ? 'border-ios-accent/30 bg-gradient-to-r from-ios-accent/5 to-transparent shadow-sm hover:shadow-md hover:border-ios-accent/50' 
          : 'border-ios-border hover:border-ios-accent/20 hover:shadow-md hover:bg-ios-secondary-background/50'
        }
      `}
    >
      <div className="p-5">
        <div className="flex items-start gap-4">
          {/* Document Type Icon */}
          <div className={`
            p-3 rounded-lg transition-all duration-300 group-hover:scale-110
            ${isUnread ? 'bg-ios-accent/20' : 'bg-ios-tertiary-background'}
          `}>
            <FileText className={`h-5 w-5 ${isUnread ? 'text-ios-accent' : 'text-ios-secondary-text'}`} />
          </div>

          {/* Content */}
          <div className="flex-1 min-w-0">
            <div className="flex items-start justify-between mb-2">
              <div className="flex items-center gap-3">
                {isUnread && (
                  <span className="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold bg-ios-accent text-white uppercase tracking-wider">
                    NEW
                  </span>
                )}
                <span className="text-xs uppercase tracking-wider text-ios-tertiary-text font-semibold font-['Courier_New',_monospace]">
                  {document.subtype || document.type}
                </span>
              </div>
              <Button
                variant="ghost"
                size="icon"
                className="opacity-0 group-hover:opacity-100 transition-opacity duration-200 hover:bg-ios-tertiary-background rounded-lg"
                onClick={(e) => {
                  e.stopPropagation();
                  onView();
                }}
              >
                <Eye className="h-4 w-4 text-ios-secondary-text" />
              </Button>
            </div>

            <h3 className="text-lg font-semibold text-ios-primary-text mb-2 line-clamp-2 group-hover:text-ios-accent transition-colors duration-200">
              {document.title}
            </h3>

            <div className="flex flex-wrap items-center gap-4 text-xs text-ios-secondary-text mb-3">
              <span className="flex items-center gap-1.5">
                <User className="h-3.5 w-3.5 text-ios-tertiary-text" />
                <span className="font-medium">
                  {selectedTab === 'sent'
                    ? `To: ${document.recipient?.rank || ''} ${document.recipient?.name || 'Unknown'}`
                    : `From: ${document.sender?.rank || ''} ${document.sender?.name || 'Unknown'}`
                  }
                </span>
              </span>
              <span className="flex items-center gap-1.5">
                <Calendar className="h-3.5 w-3.5 text-ios-tertiary-text" />
                <span className="font-medium">{format(new Date(document.sentAt), 'MMM d, yyyy')}</span>
              </span>
              {attachments.length > 0 && (
                <span className="flex items-center gap-1.5">
                  <Paperclip className="h-3.5 w-3.5 text-ios-tertiary-text" />
                  <span className="font-medium">{attachments.length} attachment{attachments.length > 1 ? 's' : ''}</span>
                </span>
              )}
            </div>

            {document.description && (
              <p className="text-sm text-ios-tertiary-text line-clamp-2">
                {document.description}
              </p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}; 