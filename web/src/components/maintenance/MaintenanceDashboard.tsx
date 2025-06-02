import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { 
  Wrench, 
  AlertTriangle, 
  Clock, 
  CheckCircle, 
  TrendingUp, 
  Search,
  Filter,
  Calendar,
  User,
  FileText,
  BarChart3
} from 'lucide-react';
import { format } from 'date-fns';
import { getDocuments, Document } from '@/services/documentService';
import { DocumentViewer } from '../documents/DocumentViewer';

interface MaintenanceStats {
  totalRequests: number;
  pendingRequests: number;
  completedThisMonth: number;
  averageResponseTime: string;
}

interface MaintenanceRequest extends Document {
  priority?: 'routine' | 'urgent' | 'emergency';
  equipment?: {
    id: number;
    name: string;
    serialNumber: string;
    category?: string;
  };
}

export const MaintenanceDashboard: React.FC = () => {
  const [selectedTab, setSelectedTab] = useState('overview');
  const [searchTerm, setSearchTerm] = useState('');
  const [filterStatus, setFilterStatus] = useState('all');
  const [filterPriority, setFilterPriority] = useState('all');
  const [selectedDocument, setSelectedDocument] = useState<Document | null>(null);
  const [viewerOpen, setViewerOpen] = useState(false);

  // Fetch maintenance forms (documents with type 'maintenance_form')
  const { data: maintenanceData, isLoading } = useQuery({
    queryKey: ['documents', 'all', filterStatus !== 'all' ? filterStatus : undefined, 'maintenance_form'],
    queryFn: () => getDocuments('all', filterStatus !== 'all' ? filterStatus : undefined, 'maintenance_form'),
  });

  const maintenanceRequests: MaintenanceRequest[] = maintenanceData?.documents.map(doc => {
    const formData = JSON.parse(doc.formData);
    return {
      ...doc,
      priority: 'routine', // Default priority - could be extracted from formData
      equipment: {
        id: doc.propertyId || 0,
        name: formData.equipmentName,
        serialNumber: formData.serialNumber,
        category: 'equipment'
      }
    };
  }) || [];

  // Calculate statistics
  const stats: MaintenanceStats = {
    totalRequests: maintenanceRequests.length,
    pendingRequests: maintenanceRequests.filter(req => req.status === 'unread').length,
    completedThisMonth: maintenanceRequests.filter(req => 
      req.status === 'read' && 
      new Date(req.sentAt).getMonth() === new Date().getMonth()
    ).length,
    averageResponseTime: '2.3 days'
  };

  // Filter requests based on search and filters
  const filteredRequests = maintenanceRequests.filter(request => {
    const matchesSearch = searchTerm === '' || 
      request.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      request.equipment?.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      request.equipment?.serialNumber.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = filterStatus === 'all' || request.status === filterStatus;
    const matchesPriority = filterPriority === 'all' || request.priority === filterPriority;
    
    return matchesSearch && matchesStatus && matchesPriority;
  });

  const handleViewRequest = (request: MaintenanceRequest) => {
    setSelectedDocument(request);
    setViewerOpen(true);
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-muted-foreground">Loading maintenance dashboard...</div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Maintenance Dashboard</h1>
          <p className="text-muted-foreground">
            Monitor and manage equipment maintenance requests
          </p>
        </div>
        <Button>
          <FileText className="w-4 h-4 mr-2" />
          Generate Report
        </Button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
        <StatsCard
          title="Total Requests"
          value={stats.totalRequests}
          icon={<Wrench className="w-5 h-5" />}
          trend="+12%"
          trendUp={true}
        />
        <StatsCard
          title="Pending Requests"
          value={stats.pendingRequests}
          icon={<Clock className="w-5 h-5" />}
          trend="-5%"
          trendUp={false}
        />
        <StatsCard
          title="Completed This Month"
          value={stats.completedThisMonth}
          icon={<CheckCircle className="w-5 h-5" />}
          trend="+18%"
          trendUp={true}
        />
        <StatsCard
          title="Avg Response Time"
          value={stats.averageResponseTime}
          icon={<TrendingUp className="w-5 h-5" />}
          trend="-0.5d"
          trendUp={true}
        />
      </div>

      {/* Main Content */}
      <Tabs value={selectedTab} onValueChange={setSelectedTab}>
        <TabsList className="grid w-full grid-cols-3">
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="requests">All Requests</TabsTrigger>
          <TabsTrigger value="analytics">Analytics</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Recent Requests */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg font-semibold">Recent Requests</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {filteredRequests.slice(0, 5).map((request) => (
                    <RequestCard 
                      key={request.id} 
                      request={request} 
                      onClick={() => handleViewRequest(request)}
                      compact={true}
                    />
                  ))}
                  {filteredRequests.length === 0 && (
                    <p className="text-center text-muted-foreground py-4">
                      No maintenance requests found
                    </p>
                  )}
                </div>
              </CardContent>
            </Card>

            {/* Priority Breakdown */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg font-semibold">Priority Breakdown</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <PriorityItem 
                    priority="Emergency" 
                    count={maintenanceRequests.filter(r => r.priority === 'emergency').length}
                    color="bg-red-500"
                  />
                  <PriorityItem 
                    priority="Urgent" 
                    count={maintenanceRequests.filter(r => r.priority === 'urgent').length}
                    color="bg-orange-500"
                  />
                  <PriorityItem 
                    priority="Routine" 
                    count={maintenanceRequests.filter(r => r.priority === 'routine').length}
                    color="bg-blue-500"
                  />
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="requests" className="space-y-6">
          {/* Filters */}
          <Card>
            <CardContent className="p-4">
              <div className="flex flex-col md:flex-row gap-4">
                <div className="flex-1">
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
                    <Input
                      placeholder="Search by equipment name or serial number..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                </div>
                <Select value={filterStatus} onValueChange={setFilterStatus}>
                  <SelectTrigger className="w-[180px]">
                    <SelectValue placeholder="Filter by status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Status</SelectItem>
                    <SelectItem value="unread">Pending</SelectItem>
                    <SelectItem value="read">Reviewed</SelectItem>
                  </SelectContent>
                </Select>
                <Select value={filterPriority} onValueChange={setFilterPriority}>
                  <SelectTrigger className="w-[180px]">
                    <SelectValue placeholder="Filter by priority" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Priorities</SelectItem>
                    <SelectItem value="emergency">Emergency</SelectItem>
                    <SelectItem value="urgent">Urgent</SelectItem>
                    <SelectItem value="routine">Routine</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </CardContent>
          </Card>

          {/* Requests List */}
          <div className="space-y-4">
            {filteredRequests.map((request) => (
              <RequestCard 
                key={request.id} 
                request={request} 
                onClick={() => handleViewRequest(request)}
              />
            ))}
            {filteredRequests.length === 0 && (
              <Card>
                <CardContent className="p-8 text-center">
                  <p className="text-muted-foreground">No maintenance requests found</p>
                </CardContent>
              </Card>
            )}
          </div>
        </TabsContent>

        <TabsContent value="analytics" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg font-semibold">Request Volume Trend</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="h-64 flex items-center justify-center text-muted-foreground">
                  <div className="text-center">
                    <BarChart3 className="w-12 h-12 mx-auto mb-4" />
                    <p>Analytics charts would be implemented here</p>
                    <p className="text-sm">Integration with charting library like Chart.js or Recharts</p>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle className="text-lg font-semibold">Equipment Categories</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="h-64 flex items-center justify-center text-muted-foreground">
                  <div className="text-center">
                    <BarChart3 className="w-12 h-12 mx-auto mb-4" />
                    <p>Category breakdown chart would be here</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>
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

// Supporting Components

interface StatsCardProps {
  title: string;
  value: number | string;
  icon: React.ReactNode;
  trend?: string;
  trendUp?: boolean;
}

const StatsCard: React.FC<StatsCardProps> = ({ title, value, icon, trend, trendUp }) => (
  <Card>
    <CardContent className="p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-muted-foreground">{title}</p>
          <p className="text-2xl font-bold">{value}</p>
          {trend && (
            <p className={`text-xs ${trendUp ? 'text-green-600' : 'text-red-600'}`}>
              {trend} from last month
            </p>
          )}
        </div>
        <div className="p-2 bg-primary/10 rounded-md">
          {icon}
        </div>
      </div>
    </CardContent>
  </Card>
);

interface RequestCardProps {
  request: MaintenanceRequest;
  onClick: () => void;
  compact?: boolean;
}

const RequestCard: React.FC<RequestCardProps> = ({ request, onClick, compact = false }) => {
  const formData = JSON.parse(request.formData);
  
  return (
    <Card 
      className={`cursor-pointer hover:shadow-md transition-shadow ${
        request.status === 'unread' ? 'border-primary' : ''
      }`}
      onClick={onClick}
    >
      <CardContent className={compact ? "p-4" : "p-6"}>
        <div className="flex items-start justify-between">
          <div className="flex-1">
            <div className="flex items-center gap-2 mb-2">
              {request.status === 'unread' && (
                <Badge variant="secondary" className="text-xs">NEW</Badge>
              )}
              <Badge variant="outline" className="text-xs">
                {request.subtype}
              </Badge>
              <Badge 
                variant={
                  request.priority === 'emergency' ? 'destructive' :
                  request.priority === 'urgent' ? 'secondary' : 'outline'
                }
                className="text-xs"
              >
                {request.priority?.toUpperCase()}
              </Badge>
            </div>
            
            <h3 className={`font-semibold ${compact ? 'text-sm' : 'text-base'} mb-1`}>
              {request.equipment?.name} - {request.equipment?.serialNumber}
            </h3>
            
            <p className={`text-muted-foreground ${compact ? 'text-xs' : 'text-sm'} mb-2 line-clamp-2`}>
              {formData.description}
            </p>
            
            <div className="flex items-center gap-4 text-xs text-muted-foreground">
              <span className="flex items-center gap-1">
                <User className="w-3 h-3" />
                {request.sender?.rank} {request.sender?.name}
              </span>
              <span className="flex items-center gap-1">
                <Calendar className="w-3 h-3" />
                {format(new Date(request.sentAt), 'MMM d, yyyy')}
              </span>
            </div>
          </div>
          
          {!compact && (
            <div className="ml-4">
              <Button variant="ghost" size="sm">
                View Details
              </Button>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
};

interface PriorityItemProps {
  priority: string;
  count: number;
  color: string;
}

const PriorityItem: React.FC<PriorityItemProps> = ({ priority, count, color }) => (
  <div className="flex items-center justify-between">
    <div className="flex items-center gap-3">
      <div className={`w-3 h-3 rounded-full ${color}`} />
      <span className="text-sm font-medium">{priority}</span>
    </div>
    <Badge variant="secondary">{count}</Badge>
  </div>
);
