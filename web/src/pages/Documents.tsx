import React, { useState } from 'react';
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
  Shield
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { useNotifications } from '@/contexts/NotificationContext';
import NotificationPanel from '@/components/modals/NotificationPanel';
import { DA2062ExportDialog } from '@/components/da2062/DA2062ExportDialog';
import { DA2062ImportDialog } from '@/components/da2062/DA2062ImportDialog';

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

  return (
    <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
      <div className="max-w-6xl mx-auto px-6 py-8">
        {/* Enhanced Header section */}
        <div className="mb-12">
          {/* Top navigation bar */}
          <div className="flex items-center justify-between mb-8">
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
          
          {/* Key Metrics Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
            <StatCard
              title="Inbox"
              value={totalInbox}
              icon={<Inbox className="h-5 w-5 text-ios-accent" />}
              subtitle={unreadDocuments > 0 ? `${unreadDocuments} unread` : 'All read'}
            />
            <StatCard
              title="Sent"
              value={totalSent}
              icon={<Send className="h-5 w-5 text-blue-500" />}
            />
            <StatCard
              title="Total Documents"
              value={totalDocuments}
              icon={<Archive className="h-5 w-5 text-green-500" />}
              subtitle="All time"
            />
            <StatCard
              title="Forms Processed"
              value="0"
              icon={<Shield className="h-5 w-5 text-purple-500" />}
              subtitle="This month"
            />
          </div>

          {/* Quick Actions Bar */}
          <div className="flex items-center gap-3 mb-6">
            <Button
              variant="outline"
              size="sm"
              className="flex items-center gap-2 border-ios-accent/30 hover:bg-ios-accent hover:border-ios-accent hover:text-white text-ios-primary-text font-medium transition-all duration-200"
              onClick={() => setShowingDA2062Export(true)}
            >
              <Upload className="h-4 w-4" />
              Export DA-2062
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="flex items-center gap-2 border-ios-accent/30 hover:bg-ios-accent hover:border-ios-accent hover:text-white text-ios-primary-text font-medium transition-all duration-200"
              onClick={() => setShowingDA2062Import(true)}
            >
              <Download className="h-4 w-4" />
              Import DA-2062
            </Button>
            <Button
              variant="outline"
              size="sm"
              className="flex items-center gap-2 border-ios-accent/30 hover:bg-ios-accent hover:border-ios-accent hover:text-white text-ios-primary-text font-medium transition-all duration-200"
            >
              <Filter className="h-4 w-4" />
              Filter
            </Button>
          </div>
        </div>

        {/* DocumentsInbox component */}
        <DocumentsInbox />

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