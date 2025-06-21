import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Button } from '@/components/ui/button';
import { FileText, User, Calendar, Paperclip, Eye } from 'lucide-react';
import { format } from 'date-fns';
import { getDocuments, markAsRead, Document } from '@/services/documentService';
import { DocumentViewer } from './DocumentViewer'; // iOS Components
import { CleanCard, ElegantSectionHeader, StatusBadge, MinimalEmptyState, MinimalLoadingView } from '@/components/ios';

export const DocumentsInbox: React.FC = () => {
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

          <TabsContent value={selectedTab} className="p-6">
            {(data?.documents.length ?? 0) === 0 ? (
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
            ) : (
              <div className="space-y-4">
                {data?.documents.map((doc) => (
                  <DocumentCard
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