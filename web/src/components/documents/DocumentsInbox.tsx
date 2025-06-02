import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Button } from '@/components/ui/button';
import { FileText, User, Calendar, Paperclip, Eye } from 'lucide-react';
import { format } from 'date-fns';
import { getDocuments, markAsRead, Document } from '@/services/documentService';
import { DocumentViewer } from './DocumentViewer';

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
      <div className="flex items-center justify-center h-64">
        <div className="text-muted-foreground">Loading documents...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-destructive">Failed to load documents</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold">Documents</h2>
        <p className="text-muted-foreground">Maintenance forms and other documents</p>
      </div>

      <Tabs value={selectedTab} onValueChange={setSelectedTab}>
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="inbox" className="relative">
            Inbox
            {(data?.unread_count ?? 0) > 0 && (
              <Badge variant="destructive" className="ml-2 h-5 w-5 rounded-full p-0 flex items-center justify-center text-xs">
                {data?.unread_count}
              </Badge>
            )}
          </TabsTrigger>
          <TabsTrigger value="sent">Sent</TabsTrigger>
          <TabsTrigger value="all">All Documents</TabsTrigger>
        </TabsList>

        <TabsContent value={selectedTab} className="mt-6">
          {(data?.documents.length ?? 0) === 0 ? (
            <Card className="p-8 text-center">
              <CardContent className="pt-6">
                <FileText className="w-12 h-12 mx-auto mb-4 text-muted-foreground" />
                <p className="text-muted-foreground">
                  {selectedTab === 'inbox' ? 'No documents received' : 
                   selectedTab === 'sent' ? 'No documents sent' : 'No documents'}
                </p>
              </CardContent>
            </Card>
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
    <Card
      className={`p-4 cursor-pointer transition-colors hover:bg-muted/50 ${
        isUnread ? 'border-primary bg-primary/5' : ''
      }`}
      onClick={onView}
    >
      <CardContent className="p-0">
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-2">
              {isUnread && (
                <Badge variant="secondary" className="text-xs">
                  NEW
                </Badge>
              )}
              <Badge variant="outline" className="text-xs">
                {document.subtype || document.type}
              </Badge>
            </div>

            <h3 className="font-medium mb-2 line-clamp-2">{document.title}</h3>

            <div className="flex items-center gap-4 text-sm text-muted-foreground mb-2">
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
              <p className="text-sm text-muted-foreground line-clamp-2">
                {document.description}
              </p>
            )}
          </div>

          <Button variant="ghost" size="sm" className="ml-4">
            <Eye className="w-4 h-4" />
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}; 