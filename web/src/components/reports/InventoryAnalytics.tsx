import { useMemo } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { 
  Area, 
  AreaChart, 
  Bar, 
  BarChart, 
  CartesianGrid, 
  Cell, 
  Legend, 
  Pie, 
  PieChart, 
  ResponsiveContainer, 
  Tooltip, 
  XAxis, 
  YAxis 
} from "recharts";

interface InventoryAnalyticsProps {
  inventory: any[];
  transfers: any[];
}

const InventoryAnalytics: React.FC<InventoryAnalyticsProps> = ({ inventory, transfers }) => {
  const categoryData = useMemo(() => {
    const categories: { [key: string]: number } = {
      "Weapons": 0,
      "Communications": 0,
      "Medical": 0,
      "Tactical": 0,
      "Other": 0
    };
    
    // Mock category data since our mock data doesn't include categories
    categories["Weapons"] = 12;
    categories["Communications"] = 8;
    categories["Medical"] = 5;
    categories["Tactical"] = 15;
    categories["Other"] = 3;
    
    return Object.keys(categories).map(name => ({
      name,
      value: categories[name]
    }));
  }, [inventory]);

  const statusData = useMemo(() => {
    const statuses: { [key: string]: number } = {
      "Active": 0,
      "Pending": 0,
      "Transferred": 0
    };
    
    inventory.forEach(item => {
      statuses[item.status] = (statuses[item.status] || 0) + 1;
    });
    
    return Object.keys(statuses).map(name => ({
      name,
      value: statuses[name]
    }));
  }, [inventory]);

  const transferTrendData = useMemo(() => {
    // Mock monthly transfer data for demonstration
    return [
      { month: 'Jan', count: 5, approved: 4, rejected: 1 },
      { month: 'Feb', count: 8, approved: 7, rejected: 1 },
      { month: 'Mar', count: 12, approved: 9, rejected: 3 },
      { month: 'Apr', count: 6, approved: 5, rejected: 1 },
      { month: 'May', count: 9, approved: 7, rejected: 2 },
      { month: 'Jun', count: 15, approved: 12, rejected: 3 },
    ];
  }, [transfers]);

  const transferTypeData = useMemo(() => {
    // Mock transfer types for demonstration
    return [
      { name: 'PCS Moves', value: 35 },
      { name: 'CIF Turn-in', value: 20 },
      { name: 'Unit Transfer', value: 25 },
      { name: 'Field Exercise', value: 15 },
      { name: 'Other', value: 5 },
    ];
  }, [transfers]);

  const itemAvailabilityTrend = useMemo(() => {
    // Mock availability trend data
    return [
      { month: 'Jan', available: 85, assigned: 70 },
      { month: 'Feb', available: 88, assigned: 75 },
      { month: 'Mar', available: 90, assigned: 82 },
      { month: 'Apr', available: 92, assigned: 84 },
      { month: 'May', available: 88, assigned: 86 },
      { month: 'Jun', available: 95, assigned: 90 },
    ];
  }, [inventory]);

  const COLORS = ['#4B5320', '#8D9245', '#4f4a7d', '#1C2541', '#0B132B'];

  return (
    <Card className="w-full">
      <CardHeader>
        <CardTitle>Inventory Analytics</CardTitle>
        <CardDescription>
          Equipment tracking metrics and statistics
        </CardDescription>
      </CardHeader>
      <CardContent>
        <Tabs defaultValue="overview">
          <TabsList className="mb-4">
            <TabsTrigger value="overview">Overview</TabsTrigger>
            <TabsTrigger value="transfers">Transfers</TabsTrigger>
            <TabsTrigger value="availability">Availability</TabsTrigger>
          </TabsList>

          <TabsContent value="overview" className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm font-medium">
                    Equipment by Category
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="h-60">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={categoryData}
                          cx="50%"
                          cy="50%"
                          labelLine={false}
                          label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                          outerRadius={80}
                          fill="#8884d8"
                          dataKey="value"
                        >
                          {categoryData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                          ))}
                        </Pie>
                        <Tooltip />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm font-medium">
                    Equipment Status
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="h-60">
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart
                        data={statusData}
                        layout="vertical"
                        margin={{ top: 5, right: 30, left: 20, bottom: 5 }}
                      >
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis type="number" />
                        <YAxis dataKey="name" type="category" />
                        <Tooltip />
                        <Bar dataKey="value" barSize={30}>
                          {statusData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                          ))}
                        </Bar>
                      </BarChart>
                    </ResponsiveContainer>
                  </div>
                </CardContent>
              </Card>
            </div>

            <Card>
              <CardHeader className="pb-2 flex flex-row items-center justify-between">
                <CardTitle className="text-sm font-medium">
                  Key Inventory Metrics
                </CardTitle>
                <Select defaultValue="unit">
                  <SelectTrigger className="w-36 h-8">
                    <SelectValue placeholder="Select view" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="unit">By Unit</SelectItem>
                    <SelectItem value="individual">By Individual</SelectItem>
                    <SelectItem value="location">By Location</SelectItem>
                  </SelectContent>
                </Select>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="bg-[#eef1f5] rounded-md p-3">
                    <p className="text-sm text-gray-500">Total Equipment</p>
                    <p className="text-2xl font-bold">{inventory.length}</p>
                    <p className="text-xs text-[#4B5320]">+3 from last month</p>
                  </div>
                  <div className="bg-[#eef1f5] rounded-md p-3">
                    <p className="text-sm text-gray-500">Pending Transfers</p>
                    <p className="text-2xl font-bold">{transfers.filter(t => t.status === "pending").length}</p>
                    <p className="text-xs text-[#4B5320]">-2 from last week</p>
                  </div>
                  <div className="bg-[#eef1f5] rounded-md p-3">
                    <p className="text-sm text-gray-500">Sensitive Items</p>
                    <p className="text-2xl font-bold">23</p>
                    <p className="text-xs text-green-600">100% accounted for</p>
                  </div>
                  <div className="bg-[#eef1f5] rounded-md p-3">
                    <p className="text-sm text-gray-500">Damaged Items</p>
                    <p className="text-2xl font-bold">5</p>
                    <p className="text-xs text-yellow-600">2 pending repair</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="transfers" className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm font-medium">
                    Transfer Trends
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="h-60">
                    <ResponsiveContainer width="100%" height="100%">
                      <AreaChart
                        data={transferTrendData}
                        margin={{ top: 10, right: 30, left: 0, bottom: 0 }}
                      >
                        <CartesianGrid strokeDasharray="3 3" />
                        <XAxis dataKey="month" />
                        <YAxis />
                        <Tooltip />
                        <Legend />
                        <Area 
                          type="monotone" 
                          dataKey="count" 
                          stackId="1"
                          stroke="#4B5320" 
                          fill="#4B5320" 
                        />
                        <Area 
                          type="monotone" 
                          dataKey="approved" 
                          stackId="2"
                          stroke="#8D9245" 
                          fill="#8D9245" 
                        />
                        <Area 
                          type="monotone" 
                          dataKey="rejected" 
                          stackId="2"
                          stroke="#DC3545" 
                          fill="#DC3545" 
                        />
                      </AreaChart>
                    </ResponsiveContainer>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm font-medium">
                    Transfer Types
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="h-60">
                    <ResponsiveContainer width="100%" height="100%">
                      <PieChart>
                        <Pie
                          data={transferTypeData}
                          cx="50%"
                          cy="50%"
                          labelLine={false}
                          label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                          outerRadius={80}
                          fill="#8884d8"
                          dataKey="value"
                        >
                          {transferTypeData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                          ))}
                        </Pie>
                        <Tooltip />
                      </PieChart>
                    </ResponsiveContainer>
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="availability" className="space-y-4">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">
                  Equipment Availability Trend
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="h-60">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart
                      data={itemAvailabilityTrend}
                      margin={{ top: 10, right: 30, left: 0, bottom: 0 }}
                    >
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="month" />
                      <YAxis />
                      <Tooltip />
                      <Legend />
                      <Area 
                        type="monotone" 
                        dataKey="available" 
                        stroke="#4B5320" 
                        fill="#4B5320" 
                        fillOpacity={0.3}
                      />
                      <Area 
                        type="monotone" 
                        dataKey="assigned" 
                        stroke="#1C2541" 
                        fill="#1C2541"
                        fillOpacity={0.3} 
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm font-medium">
                    Shortage Analysis
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="divide-y divide-gray-200">
                    <div className="py-2">
                      <div className="flex justify-between">
                        <span>Communication Radios</span>
                        <span className="text-red-500">3 short</span>
                      </div>
                      <div className="w-full bg-gray-200 h-2 mt-1">
                        <div className="bg-red-500 h-2" style={{ width: '85%' }}></div>
                      </div>
                    </div>
                    <div className="py-2">
                      <div className="flex justify-between">
                        <span>Night Vision Goggles</span>
                        <span className="text-yellow-500">1 short</span>
                      </div>
                      <div className="w-full bg-gray-200 h-2 mt-1">
                        <div className="bg-yellow-500 h-2" style={{ width: '95%' }}></div>
                      </div>
                    </div>
                    <div className="py-2">
                      <div className="flex justify-between">
                        <span>Tactical Vests</span>
                        <span className="text-green-500">Full inventory</span>
                      </div>
                      <div className="w-full bg-gray-200 h-2 mt-1">
                        <div className="bg-green-500 h-2" style={{ width: '100%' }}></div>
                      </div>
                    </div>
                    <div className="py-2">
                      <div className="flex justify-between">
                        <span>Medical Kits</span>
                        <span className="text-red-500">5 short</span>
                      </div>
                      <div className="w-full bg-gray-200 h-2 mt-1">
                        <div className="bg-red-500 h-2" style={{ width: '75%' }}></div>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="pb-2">
                  <CardTitle className="text-sm font-medium">
                    Maintenance Schedule
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="divide-y divide-gray-200">
                    <div className="py-2 flex justify-between items-center">
                      <div>
                        <p className="font-medium">M4A1 Carbines</p>
                        <p className="text-sm text-gray-500">Annual inspection</p>
                      </div>
                      <div className="bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded">
                        Due in 14 days
                      </div>
                    </div>
                    <div className="py-2 flex justify-between items-center">
                      <div>
                        <p className="font-medium">Communications Equipment</p>
                        <p className="text-sm text-gray-500">Quarterly check</p>
                      </div>
                      <div className="bg-red-100 text-red-800 text-xs px-2 py-1 rounded">
                        Overdue by 3 days
                      </div>
                    </div>
                    <div className="py-2 flex justify-between items-center">
                      <div>
                        <p className="font-medium">Night Vision Devices</p>
                        <p className="text-sm text-gray-500">Battery replacement</p>
                      </div>
                      <div className="bg-green-100 text-green-800 text-xs px-2 py-1 rounded">
                        Completed
                      </div>
                    </div>
                    <div className="py-2 flex justify-between items-center">
                      <div>
                        <p className="font-medium">Humvee Radios</p>
                        <p className="text-sm text-gray-500">Software update</p>
                      </div>
                      <div className="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">
                        Scheduled for next week
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>
        </Tabs>
      </CardContent>
    </Card>
  );
};

export default InventoryAnalytics;