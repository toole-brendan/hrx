import { useState, useEffect } from "react";
import { useLocation } from "wouter";
import { 
  Card, 
  CardContent, 
  CardHeader, 
  CardTitle, 
  CardDescription, 
  CardFooter 
} from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { 
  Select, 
  SelectContent, 
  SelectItem, 
  SelectTrigger, 
  SelectValue 
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { PageWrapper } from "@/components/ui/page-wrapper";
import { PageHeader } from "@/components/ui/page-header";
import { useToast } from "@/hooks/use-toast";
import { 
  BarChart,
  Bar, 
  PieChart, 
  Pie, 
  Cell, 
  LineChart, 
  Line, 
  XAxis, 
  YAxis,  
  CartesianGrid, 
  Tooltip, 
  Legend, 
  ResponsiveContainer 
} from "recharts";
import { 
  FileText, 
  Download, 
  Filter, 
  Calendar, 
  ShieldAlert, 
  Truck, 
  History, 
  User, 
  Layers, 
  Printer,
  Search,
  AlertTriangle,
  ArrowRight
} from "lucide-react";
import { inventory, transfers, activities, user } from "@/lib/mockData";
import { sensitiveItems } from "@/lib/sensitiveItemsData";
import { maintenanceItems } from "@/lib/maintenanceData";
import ReadinessDashboard from "@/components/reports/ReadinessDashboard";
import ShortageAnalysis from "@/components/reports/ShortageAnalysis";
import MockAuthorizationManager from "@/components/reports/MockAuthorizationManager";

// Define mock data for reports
const inventoryByCategory = [
  { name: "Weapons", value: 24, color: "#3b82f6" },
  { name: "Communications", value: 18, color: "#10b981" },
  { name: "Medical", value: 12, color: "#ef4444" },
  { name: "Tactical", value: 36, color: "#f97316" },
  { name: "Other", value: 8, color: "#8b5cf6" },
];

const transfersData = [
  { name: "Jan", pending: 4, approved: 12, rejected: 2 },
  { name: "Feb", pending: 3, approved: 14, rejected: 1 },
  { name: "Mar", pending: 2, approved: 10, rejected: 3 },
  { name: "Apr", pending: 5, approved: 13, rejected: 2 },
  { name: "May", pending: 4, approved: 15, rejected: 1 },
  { name: "Jun", pending: 6, approved: 11, rejected: 3 },
];

const inventoryStatusData = [
  { name: "Active", value: 78, color: "#22c55e" },
  { name: "Pending", value: 14, color: "#f59e0b" },
  { name: "Transferred", value: 8, color: "#3b82f6" },
];

const sensitiveItemsVerificationData = [
  { name: "Verified", value: 45, color: "#22c55e" },
  { name: "Due", value: 12, color: "#f59e0b" },
  { name: "Overdue", value: 3, color: "#ef4444" },
];

// Mock property book status summary
const propertyBookSummary = {
  totalItems: 165,
  assignedItems: 152,
  unassignedItems: 13,
  itemsByCategory: {
    weapons: 28,
    communications: 42,
    medical: 35,
    tactical: 45,
    other: 15
  },
  complianceRate: "92%",
  verificationStatus: "86%"
};

// Mock report types
const reportTypes = [
  { id: "inventory-status", name: "Inventory Status", icon: <Layers className="h-4 w-4 mr-2" /> },
  { id: "transfer-history", name: "Transfer History", icon: <History className="h-4 w-4 mr-2" /> },
  { id: "sensitive-items", name: "Sensitive Items", icon: <ShieldAlert className="h-4 w-4 mr-2" /> },
  { id: "unit-equipment", name: "Unit Equipment", icon: <User className="h-4 w-4 mr-2" /> },
  { id: "maintenance", name: "Maintenance", icon: <Truck className="h-4 w-4 mr-2" /> }
];

// Define interfaces for reports
interface ReportType {
  id: string;
  name: string;
  icon: React.ReactNode;
}

interface ReportFilter {
  dateRange: string;
  category: string;
  status: string;
}

interface ReportsProps {
  type?: string;
}

const Reports: React.FC<ReportsProps> = ({ type }) => {
  const [activeTab, setActiveTab] = useState("dashboard");
  const [selectedReportType, setSelectedReportType] = useState<string | null>(null);
  const [filters, setFilters] = useState<ReportFilter>({
    dateRange: "30",
    category: "all",
    status: "all"
  });
  const { toast } = useToast();
  const [, navigate] = useLocation();
  const [activeReport, setActiveReport] = useState("dashboard");

  // If a type is provided, switch to that report type
  useEffect(() => {
    if (type) {
      // Set the active report type based on the URL parameter
      switch(type) {
        case 'inventory':
          setActiveReport('inventory');
          break;
        case 'maintenance':
          setActiveReport('maintenance');
          break;
        case 'usage':
          setActiveReport('usage');
          break;
        case 'audit':
          setActiveReport('audit');
          break;
        case 'compliance':
          setActiveReport('compliance');
          break;
        // Add other report types as needed
      }
    }
  }, [type]);

  const handleGenerateReport = (reportType: string) => {
    setSelectedReportType(reportType);
    toast({
      title: "Report generated",
      description: `${reportType} report has been generated successfully.`,
    });
  };

  const handleExportReport = (format: string) => {
    toast({
      title: "Report exported",
      description: `Report has been exported as ${format.toUpperCase()} successfully.`,
    });
  };

  const handlePrintReport = () => {
    toast({
      title: "Report sent to printer",
      description: "Report has been sent to the printer successfully.",
    });
  };

  return (
    <PageWrapper withPadding={true}>
      {/* Header section with styling formatting */}
      <div className="pt-16 pb-10">
        {/* Category label - Small all-caps category label */}
        <div className="text-xs uppercase tracking-wider font-medium mb-1 text-muted-foreground">
          ANALYTICS
        </div>
        
        {/* Main title - following typography */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between space-y-4 sm:space-y-0">
          <div>
            <h1 className="text-3xl font-light tracking-tight mb-1">Reports & Analytics</h1>
            <p className="text-sm text-muted-foreground">Generate customized reports and view analytics for inventory, transfers, and equipment status</p>
          </div>
          <div className="flex items-center gap-2">
            <Button 
              variant="blue"
              size="sm"
              className="h-9 px-3 flex items-center gap-1.5 text-xs uppercase tracking-wider"
              onClick={() => handlePrintReport()}
            >
              <Printer className="h-4 w-4" />
              PRINT
            </Button>
            <Button 
              variant="blue"
              size="sm"
              className="h-9 px-3 flex items-center gap-1.5 text-xs uppercase tracking-wider"
              onClick={() => handleGenerateReport("Custom")}
            >
              <FileText className="h-4 w-4" />
              GENERATE REPORT
            </Button>
          </div>
        </div>
      </div>
      <Tabs defaultValue="dashboard" onValueChange={setActiveTab} value={activeTab}>
          <div className="mb-6">
            <div className="text-xs uppercase tracking-wider font-medium mb-4 text-muted-foreground">
              REPORT CATEGORIES
            </div>
            <TabsList className="grid grid-cols-7 w-full rounded-none h-10 border">
              <TabsTrigger value="dashboard" className="uppercase tracking-wider text-xs font-medium rounded-none">DASHBOARD</TabsTrigger>
              <TabsTrigger value="inventory" className="uppercase tracking-wider text-xs font-medium rounded-none">INVENTORY</TabsTrigger>
              <TabsTrigger value="transfers" className="uppercase tracking-wider text-xs font-medium rounded-none">TRANSFERS</TabsTrigger>
              <TabsTrigger value="readiness" className="uppercase tracking-wider text-xs font-medium rounded-none">READINESS</TabsTrigger>
              <TabsTrigger value="shortages" className="uppercase tracking-wider text-xs font-medium rounded-none">SHORTAGES</TabsTrigger>
              <TabsTrigger value="sensitive" className="uppercase tracking-wider text-xs font-medium rounded-none">SENSITIVE</TabsTrigger>
              <TabsTrigger value="custom" className="uppercase tracking-wider text-xs font-medium rounded-none">CUSTOM</TabsTrigger>
            </TabsList>
          </div>

          {/* Report Dashboard */}
          <TabsContent value="dashboard">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
              <Card className="overflow-hidden border-border shadow-none bg-card">
                <div className="p-3 border-b border-border">
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                    INVENTORY
                  </div>
                </div>
                <CardContent className="p-4">
                  <div className="flex flex-col">
                    <div className="text-3xl font-light tracking-tight">{inventory.length}</div>
                    <div className="text-xs tracking-wide text-muted-foreground mt-1">Total inventory items</div>
                  </div>
                </CardContent>
              </Card>
              <Card className="overflow-hidden border-border shadow-none bg-card">
                <div className="p-3 border-b border-border">
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                    TRANSFERS
                  </div>
                </div>
                <CardContent className="p-4">
                  <div className="flex flex-col">
                    <div className="text-3xl font-light tracking-tight">{transfers.filter(t => t.status === "pending").length}</div>
                    <div className="text-xs tracking-wide text-muted-foreground mt-1">Pending transfers</div>
                  </div>
                </CardContent>
              </Card>
              <Card className="overflow-hidden border-border shadow-none bg-card">
                <div className="p-3 border-b border-border">
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                    SENSITIVE ITEMS
                  </div>
                </div>
                <CardContent className="p-4">
                  <div className="flex flex-col">
                    <div className="text-3xl font-light tracking-tight">{sensitiveItems.length}</div>
                    <div className="text-xs tracking-wide text-muted-foreground mt-1">Tracked sensitive items</div>
                  </div>
                </CardContent>
              </Card>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
              <Card className="overflow-hidden border-border shadow-none bg-card">
                <div className="p-4 flex justify-between items-baseline border-b border-border">
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                      EQUIPMENT DISTRIBUTION
                    </div>
                    <div className="text-lg font-normal">
                      Inventory by Category
                    </div>
                  </div>
                </div>
                <CardContent className="p-4">
                  <div className="h-[300px]">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={inventoryByCategory}
                          cx="50%"
                          cy="50%"
                          labelLine={false}
                          outerRadius={80}
                          fill="#8884d8"
                          dataKey="value"
                          label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                        >
                          {inventoryByCategory.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={entry.color} />
                          ))}
                        </Pie>
                        <Legend />
                        <Tooltip />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                </CardContent>
              </Card>

              <Card className="overflow-hidden border-border shadow-none bg-card">
                <div className="p-4 flex justify-between items-baseline border-b border-border">
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                      ACTIVITY METRICS
                    </div>
                    <div className="text-lg font-normal">
                      Transfer Trends
                    </div>
                  </div>
                </div>
                <CardContent className="p-4">
                  <div className="h-[300px]">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart data={transfersData}>
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="name" />
                        <YAxis />
                        <Tooltip />
                        <Legend />
                        <Bar dataKey="approved" fill="#22c55e" name="Approved" />
                        <Bar dataKey="pending" fill="#f59e0b" name="Pending" />
                        <Bar dataKey="rejected" fill="#ef4444" name="Rejected" />
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                </CardContent>
              </Card>
            </div>

            <div className="mb-6">
              <Card className="overflow-hidden border-border shadow-none bg-card">
                <div className="p-4 flex justify-between items-baseline border-b border-border">
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                      ONE-CLICK REPORTING
                    </div>
                    <div className="text-lg font-normal">
                      Quick Report Generation
                    </div>
                  </div>
                </div>
                <CardContent className="p-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {reportTypes.map((report) => (
                      <Button
                        key={report.id}
                        variant="outline"
                        className="justify-start h-auto py-3 text-xs uppercase tracking-wider border-border hover:bg-muted/50"
                        onClick={() => handleGenerateReport(report.name)}
                      >
                        {report.icon}
                        {report.name}
                      </Button>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>

            <div className="mb-6">
              <Card className="overflow-hidden border-border shadow-none bg-card">
                <div className="p-4 flex justify-between items-baseline border-b border-border">
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                      PROPERTY BOOK
                    </div>
                    <div className="text-lg font-normal">
                      Current Status Summary
                    </div>
                  </div>
                </div>
                <CardContent className="p-4">
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                      <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                        STATUS SUMMARY
                      </div>
                      <div className="space-y-4 border-l-4 border-primary/30 pl-4">
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Total Items</span>
                          <span className="font-medium text-lg">{propertyBookSummary.totalItems}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Assigned Items</span>
                          <span className="font-medium text-lg">{propertyBookSummary.assignedItems}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Unassigned Items</span>
                          <span className="font-medium text-lg">{propertyBookSummary.unassignedItems}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Compliance Rate</span>
                          <span className="font-medium text-lg text-green-500">{propertyBookSummary.complianceRate}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Verification Rate</span>
                          <span className="font-medium text-lg text-amber-500">{propertyBookSummary.verificationStatus}</span>
                        </div>
                      </div>
                    </div>
                    <div>
                      <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                        ITEMS BY CATEGORY
                      </div>
                      <div className="space-y-4 border-l-4 border-primary/30 pl-4">
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Weapons</span>
                          <span className="font-medium text-lg">{propertyBookSummary.itemsByCategory.weapons}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Communications</span>
                          <span className="font-medium text-lg">{propertyBookSummary.itemsByCategory.communications}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Medical</span>
                          <span className="font-medium text-lg">{propertyBookSummary.itemsByCategory.medical}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Tactical</span>
                          <span className="font-medium text-lg">{propertyBookSummary.itemsByCategory.tactical}</span>
                        </div>
                        <div className="flex justify-between items-center">
                          <span className="text-sm">Other</span>
                          <span className="font-medium text-lg">{propertyBookSummary.itemsByCategory.other}</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </CardContent>
                <div className="px-4 py-2 border-t border-border flex justify-end">
                  <Button 
                    variant="ghost" 
                    className="text-xs uppercase tracking-wider text-blue-600 dark:text-blue-400 hover:bg-transparent hover:text-blue-800 dark:hover:text-blue-300"
                    onClick={() => navigate("/property-book")}
                  >
                    VIEW FULL PROPERTY BOOK
                    <ArrowRight className="h-3 w-3 ml-1" />
                  </Button>
                </div>
              </Card>
            </div>
          </TabsContent>

          {/* Inventory Reports */}
          <TabsContent value="inventory">
            <Card className="overflow-hidden border-border shadow-none bg-card mb-6">
              <div className="p-4 flex justify-between items-baseline border-b border-border">
                <div>
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                    INVENTORY OVERVIEW
                  </div>
                  <div className="text-lg font-normal">
                    Current Inventory Status
                  </div>
                </div>
              </div>
              <CardContent className="p-4">
                <div className="flex flex-col md:flex-row gap-6 mb-6">
                  <div className="md:w-1/2">
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                      STATUS DISTRIBUTION
                    </div>
                    <div className="h-[300px]">
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie
                            data={inventoryStatusData}
                            cx="50%"
                            cy="50%"
                            labelLine={false}
                            outerRadius={80}
                            fill="#8884d8"
                            dataKey="value"
                            label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                          >
                            {inventoryStatusData.map((entry, index) => (
                              <Cell key={`cell-${index}`} fill={entry.color} />
                            ))}
                          </Pie>
                          <Legend />
                          <Tooltip />
                        </PieChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                  <div className="md:w-1/2">
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                      CATEGORY DISTRIBUTION
                    </div>
                    <div className="h-[300px]">
                      <ResponsiveContainer width="100%" height="100%">
                        <BarChart
                          layout="vertical"
                          data={inventoryByCategory}
                          margin={{ top: 20, right: 30, left: 20, bottom: 5 }}
                        >
                          <CartesianGrid strokeDasharray="3 3" />
                          <XAxis type="number" />
                          <YAxis type="category" dataKey="name" />
                          <Tooltip />
                          <Bar dataKey="value" fill="#8884d8">
                            {inventoryByCategory.map((entry, index) => (
                              <Cell key={`cell-${index}`} fill={entry.color} />
                            ))}
                          </Bar>
                        </BarChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                </div>

                <div className="mb-6">
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                    ACTION ITEMS
                  </div>
                  <Alert className="border border-amber-200 dark:border-amber-900/50 bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-500 rounded-none">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertDescription>
                      {maintenanceItems.filter(item => item.status === 'scheduled').length} maintenance items scheduled this week
                    </AlertDescription>
                  </Alert>
                </div>

                <div className="pt-4 border-t border-border">
                  <div className="flex justify-between">
                    <Button
                      variant="outline"
                      className="text-xs uppercase tracking-wider border-border hover:bg-muted/50"
                      onClick={() => handleExportReport('pdf')}
                    >
                      <Download className="h-4 w-4 mr-2" />
                      EXPORT AS PDF
                    </Button>
                    <Button
                      variant="outline"
                      className="text-xs uppercase tracking-wider border-border hover:bg-muted/50"
                      onClick={() => handleExportReport('csv')}
                    >
                      <Download className="h-4 w-4 mr-2" />
                      EXPORT AS CSV
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Transfers Reports */}
          <TabsContent value="transfers">
            <Card className="overflow-hidden border-border shadow-none bg-card mb-6">
              <div className="p-4 flex justify-between items-baseline border-b border-border">
                <div>
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                    TRANSFER METRICS
                  </div>
                  <div className="text-lg font-normal">
                    Transfer Analytics
                  </div>
                </div>
              </div>
              <CardContent className="p-4">
                <div className="mb-6">
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                    HISTORICAL TRENDS
                  </div>
                  <div className="h-[300px]">
                    <ResponsiveContainer width="100%" height="100%">
                      <LineChart
                        data={transfersData}
                        margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
                      >
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="name" />
                        <YAxis />
                        <Tooltip />
                        <Legend />
                        <Line 
                          type="monotone" 
                          dataKey="approved" 
                          stroke="#22c55e" 
                          name="Approved" 
                          activeDot={{ r: 8 }} 
                        />
                        <Line 
                          type="monotone" 
                          dataKey="pending" 
                          stroke="#f59e0b" 
                          name="Pending" 
                        />
                        <Line 
                          type="monotone" 
                          dataKey="rejected" 
                          stroke="#ef4444" 
                          name="Rejected" 
                        />
                      </LineChart>
                    </ResponsiveContainer>
                  </div>
                </div>

                <div className="mb-6">
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                    TRANSFER STATUS SUMMARY
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div className="p-3 border border-border bg-muted/30">
                      <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground mb-1">APPROVED</div>
                      <div className="text-2xl font-light tracking-tight text-green-500">
                        {transfers.filter(t => t.status === "approved").length}
                      </div>
                      <p className="text-xs tracking-wide text-muted-foreground mt-0.5">Total approved transfers</p>
                    </div>
                    <div className="p-3 border border-border bg-muted/30">
                      <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground mb-1">PENDING</div>
                      <div className="text-2xl font-light tracking-tight text-amber-500">
                        {transfers.filter(t => t.status === "pending").length}
                      </div>
                      <p className="text-xs tracking-wide text-muted-foreground mt-0.5">Awaiting approval</p>
                    </div>
                    <div className="p-3 border border-border bg-muted/30">
                      <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground mb-1">REJECTED</div>
                      <div className="text-2xl font-light tracking-tight text-red-500">
                        {transfers.filter(t => t.status === "rejected").length}
                      </div>
                      <p className="text-xs tracking-wide text-muted-foreground mt-0.5">Transfer requests denied</p>
                    </div>
                  </div>
                </div>

                <div className="mb-6">
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                    PROCESSING METRICS
                  </div>
                  <div className="p-3 border border-border bg-muted/30">
                    <div className="uppercase text-[10px] tracking-wider font-medium text-muted-foreground mb-1">AVERAGE APPROVAL TIME</div>
                    <div className="text-2xl font-light tracking-tight">2.4 days</div>
                    <p className="text-xs tracking-wide text-muted-foreground mt-0.5">From request to approval</p>
                  </div>
                </div>

                <div className="pt-4 border-t border-border">
                  <div className="flex justify-between">
                    <Button
                      variant="outline"
                      className="text-xs uppercase tracking-wider border-border hover:bg-muted/50"
                      onClick={() => handleExportReport('pdf')}
                    >
                      <Download className="h-4 w-4 mr-2" />
                      EXPORT AS PDF
                    </Button>
                    <Button
                      variant="outline"
                      className="text-xs uppercase tracking-wider border-border hover:bg-muted/50"
                      onClick={() => handleExportReport('csv')}
                    >
                      <Download className="h-4 w-4 mr-2" />
                      EXPORT AS CSV
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Readiness Tab Content - Added */}
          <TabsContent value="readiness">
             <ReadinessDashboard />
          </TabsContent>

          {/* Sensitive Items Reports */}
          <TabsContent value="sensitive">
            <Card className="overflow-hidden border-border shadow-none bg-card mb-6">
              <div className="p-4 flex justify-between items-baseline border-b border-border">
                <div>
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                    SENSITIVE ITEMS
                  </div>
                  <div className="text-lg font-normal">
                    Verification Status Report
                  </div>
                </div>
              </div>
              <CardContent className="p-4">
                <div className="flex flex-col md:flex-row gap-6 mb-6">
                  <div className="md:w-1/2">
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                      VERIFICATION STATUS
                    </div>
                    <div className="h-[300px]">
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie
                            data={sensitiveItemsVerificationData}
                            cx="50%"
                            cy="50%"
                            labelLine={false}
                            outerRadius={80}
                            fill="#8884d8"
                            dataKey="value"
                            label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                          >
                            {sensitiveItemsVerificationData.map((entry, index) => (
                              <Cell key={`cell-${index}`} fill={entry.color} />
                            ))}
                          </Pie>
                          <Legend />
                          <Tooltip />
                        </PieChart>
                      </ResponsiveContainer>
                    </div>
                  </div>
                  <div className="md:w-1/2">
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                      VERIFICATION SCHEDULE
                    </div>
                    <div className="space-y-4 border-l-4 border-primary/30 pl-4">
                      <div className="flex justify-between items-center">
                        <span className="text-sm">Daily Verification</span>
                        <Badge className="bg-primary hover:bg-primary-600 rounded-none">5 items</Badge>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm">Weekly Verification</span>
                        <Badge className="bg-primary hover:bg-primary-600 rounded-none">12 items</Badge>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm">Monthly Verification</span>
                        <Badge className="bg-primary hover:bg-primary-600 rounded-none">28 items</Badge>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm">Quarterly Verification</span>
                        <Badge className="bg-primary hover:bg-primary-600 rounded-none">15 items</Badge>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="mb-6">
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-4">
                    VERIFICATION ALERTS
                  </div>
                  <Alert className="border border-red-200 dark:border-red-900/50 bg-red-50 dark:bg-red-900/20 text-red-800 dark:text-red-500 rounded-none">
                    <AlertTriangle className="h-4 w-4" />
                    <AlertDescription>
                      3 sensitive items are overdue for verification
                    </AlertDescription>
                  </Alert>
                </div>

                <div className="pt-4 border-t border-border">
                  <div className="flex justify-between">
                    <Button
                      variant="outline"
                      className="text-xs uppercase tracking-wider border-border hover:bg-muted/50"
                      onClick={() => handleExportReport('pdf')}
                    >
                      <Download className="h-4 w-4 mr-2" />
                      EXPORT AS PDF
                    </Button>
                    <Button
                      variant="outline"
                      className="text-xs uppercase tracking-wider border-border hover:bg-muted/50"
                      onClick={() => handleExportReport('csv')}
                    >
                      <Download className="h-4 w-4 mr-2" />
                      EXPORT AS CSV
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Shortages Tab Content - Added Manager */}
          <TabsContent value="shortages" className="space-y-6">
             {/* Render Manager first */}
             <MockAuthorizationManager />
             {/* Then render Analysis */}
             <ShortageAnalysis />
          </TabsContent>

          {/* Custom Reports */}
          <TabsContent value="custom">
            <Card className="overflow-hidden border-border shadow-none bg-card mb-6">
              <div className="p-4 flex justify-between items-baseline border-b border-border">
                <div>
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                    CUSTOM REPORT
                  </div>
                  <div className="text-lg font-normal">
                    Create Customized Reports
                  </div>
                </div>
              </div>
              <CardContent className="p-4">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-2">
                      REPORT TYPE
                    </div>
                    <Select defaultValue="inventory">
                      <SelectTrigger className="border-border rounded-none">
                        <SelectValue placeholder="Select report type" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="inventory">Inventory Report</SelectItem>
                        <SelectItem value="transfers">Transfers Report</SelectItem>
                        <SelectItem value="sensitive">Sensitive Items Report</SelectItem>
                        <SelectItem value="maintenance">Maintenance Report</SelectItem>
                        <SelectItem value="property">Property Book Report</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-2">
                      DATE RANGE
                    </div>
                    <Select defaultValue="30">
                      <SelectTrigger className="border-border rounded-none">
                        <SelectValue placeholder="Select date range" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="7">Last 7 days</SelectItem>
                        <SelectItem value="30">Last 30 days</SelectItem>
                        <SelectItem value="90">Last 90 days</SelectItem>
                        <SelectItem value="365">Last year</SelectItem>
                        <SelectItem value="custom">Custom range</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-2">
                      FORMAT
                    </div>
                    <Select defaultValue="pdf">
                      <SelectTrigger className="border-border rounded-none">
                        <SelectValue placeholder="Select format" />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value="pdf">PDF</SelectItem>
                        <SelectItem value="excel">Excel</SelectItem>
                        <SelectItem value="csv">CSV</SelectItem>
                      </SelectContent>
                    </Select>
                  </div>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-2">
                      ADDITIONAL FILTERS
                    </div>
                    <div className="flex gap-2">
                      <Select defaultValue="all">
                        <SelectTrigger className="border-border rounded-none">
                          <SelectValue placeholder="Status" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="all">All Statuses</SelectItem>
                          <SelectItem value="active">Active</SelectItem>
                          <SelectItem value="pending">Pending</SelectItem>
                          <SelectItem value="transferred">Transferred</SelectItem>
                        </SelectContent>
                      </Select>
                      <Select defaultValue="all">
                        <SelectTrigger className="border-border rounded-none">
                          <SelectValue placeholder="Category" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="all">All Categories</SelectItem>
                          <SelectItem value="weapons">Weapons</SelectItem>
                          <SelectItem value="communications">Communications</SelectItem>
                          <SelectItem value="medical">Medical</SelectItem>
                          <SelectItem value="tactical">Tactical</SelectItem>
                        </SelectContent>
                      </Select>
                    </div>
                  </div>
                  <div>
                    <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-2">
                      SEARCH
                    </div>
                    <div className="relative">
                      <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
                      <Input 
                        placeholder="Search by name, serial number, etc." 
                        className="pl-8 border-border rounded-none" 
                      />
                    </div>
                  </div>
                </div>

                <div className="flex justify-end">
                  <Button 
                    variant="blue"
                    size="sm"
                    className="h-9 px-3 flex items-center gap-1.5 text-xs uppercase tracking-wider"
                    onClick={() => handleGenerateReport("Custom")}
                  >
                    <FileText className="h-4 w-4 mr-2" />
                    GENERATE REPORT
                  </Button>
                </div>
              </CardContent>
            </Card>

            <Card className="overflow-hidden border-border shadow-none bg-card">
              <div className="p-4 flex justify-between items-baseline border-b border-border">
                <div>
                  <div className="uppercase text-xs tracking-wider font-medium text-muted-foreground mb-1">
                    SAVED REPORTS
                  </div>
                  <div className="text-lg font-normal">
                    Previously Generated Reports
                  </div>
                </div>
              </div>
              <CardContent className="p-4">
                <div className="space-y-4">
                  <div className="flex justify-between items-center p-3 border border-border bg-muted/30">
                    <div className="flex items-center gap-3">
                      <FileText className="h-5 w-5 text-primary" />
                      <div>
                        <div className="font-medium">Monthly Inventory Status</div>
                        <div className="text-xs tracking-wide text-muted-foreground mt-0.5">Generated 2 days ago</div>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Button variant="ghost" size="sm" className="hover:bg-muted/50">
                        <Download className="h-4 w-4 text-muted-foreground" />
                      </Button>
                      <Button variant="ghost" size="sm" className="hover:bg-muted/50">
                        <Printer className="h-4 w-4 text-muted-foreground" />
                      </Button>
                    </div>
                  </div>
                  <div className="flex justify-between items-center p-3 border border-border bg-muted/30">
                    <div className="flex items-center gap-3">
                      <FileText className="h-5 w-5 text-primary" />
                      <div>
                        <div className="font-medium">Quarterly Sensitive Items Verification</div>
                        <div className="text-xs tracking-wide text-muted-foreground mt-0.5">Generated 1 week ago</div>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Button variant="ghost" size="sm" className="hover:bg-muted/50">
                        <Download className="h-4 w-4 text-muted-foreground" />
                      </Button>
                      <Button variant="ghost" size="sm" className="hover:bg-muted/50">
                        <Printer className="h-4 w-4 text-muted-foreground" />
                      </Button>
                    </div>
                  </div>
                  <div className="flex justify-between items-center p-3 border border-border bg-muted/30">
                    <div className="flex items-center gap-3">
                      <FileText className="h-5 w-5 text-primary" />
                      <div>
                        <div className="font-medium">Annual Property Book Audit</div>
                        <div className="text-xs tracking-wide text-muted-foreground mt-0.5">Generated 3 weeks ago</div>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Button variant="ghost" size="sm" className="hover:bg-muted/50">
                        <Download className="h-4 w-4 text-muted-foreground" />
                      </Button>
                      <Button variant="ghost" size="sm" className="hover:bg-muted/50">
                        <Printer className="h-4 w-4 text-muted-foreground" />
                      </Button>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </PageWrapper>
  );
};

export default Reports;