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
      {/* Header */}
      <div className="mb-8">
        <ElegantSectionHeader title="DOCUMENTS" className="mb-4" />
        <div>
          <h1 className="text-3xl font-light tracking-tight text-primary-text">
            Document Management
          </h1>
          <p className="text-secondary-text mt-1">
            Maintenance forms and official documents
          </p>
        </div>
      </div>

      {/* Tabs */}
      <CleanCard padding="none">
        <Tabs value={selectedTab} onValueChange={setSelectedTab}>
          <div className="border-b border-ios-border">
            <TabsList className="grid grid-cols-3 w-full bg-transparent">
              <TabsTrigger
                value="inbox"
                className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none relative"
              >
                INBOX
                {(data?.unread_count ?? 0) > 0 && (
                  <span className="ml-2 px-1.5 py-0.5 h-5 min-w-[1.25rem] bg-ios-destructive text-white rounded-full text-[10px] flex items-center justify-center absolute -top-1 -right-1">
                    {data?.unread_count}
                  </span>
                )}
              </TabsTrigger>
              <TabsTrigger
                value="sent"
                className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none"
              >
                SENT
              </TabsTrigger>
              <TabsTrigger
                value="all"
                className="text-sm uppercase tracking-wide font-medium data-[state=active]:bg-transparent data-[state=active]:text-primary-text data-[state=active]:border-b-2 data-[state=active]:border-ios-accent rounded-none"
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
  const attachments = document.attachments ? JSON.parse(document.attachments) : [];
  const isUnread = document.status === 'unread';

  return (
    <CleanCard
      hoverable
      onClick={onView}
      className={isUnread ? 'border-ios-accent bg-ios-accent/5' : ''}
    >
      <div className="flex items-start justify-between">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2 mb-2">
            {isUnread && (
              <StatusBadge status="pending" size="sm">
                NEW
              </StatusBadge>
            )}
            <span className="text-xs uppercase tracking-wide text-tertiary-text font-medium">
              {document.subtype || document.type}
            </span>
          </div>

          <h3 className="font-medium text-primary-text mb-2 line-clamp-2">
            {document.title}
          </h3>

          <div className="flex items-center gap-4 text-sm text-secondary-text mb-2">
            <span className="flex items-center gap-1">
              <User className="w-3 h-3" />
              {selectedTab === 'sent'
                ? `To: ${document.recipient?.rank || ''} ${document.recipient?.name || 'Unknown'}`
                : `From: ${document.sender?.rank || ''} ${document.sender?.name || 'Unknown'}`
              }
            </span>
            <span className="flex items-center gap-1">
              <Calendar className="w-3 h-3" />
              {format(new Date(document.sentAt), 'MMM d, yyyy')}
            </span>
            {attachments.length > 0 && (
              <span className="flex items-center gap-1">
                <Paperclip className="w-3 h-3" />
                {attachments.length}
              </span>
            )}
          </div>

          {document.description && (
            <p className="text-sm text-tertiary-text line-clamp-2">
              {document.description}
            </p>
          )}
        </div>

        <Button
          variant="ghost"
          size="icon"
          className="ml-4 hover:bg-gray-100 rounded-none"
          onClick={(e) => {
            e.stopPropagation();
            onView();
          }}
        >
          <Eye className="w-4 h-4" />
        </Button>
      </div>
    </CleanCard>
  );
}; 