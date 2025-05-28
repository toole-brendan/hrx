import React from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { ScrollArea } from "@/components/ui/scroll-area";
import { MaintenanceItem, MaintenanceBulletin } from "@/lib/maintenanceData"; // Adjusted import - removed MaintenanceStats type
import { PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer } from 'recharts'; // Add recharts imports
import { format } from 'date-fns';
import {
    Wrench,
    Activity,
    Clock,
    AlertTriangle,
    CheckCircle,
    ListChecks,
    Box,
    Search as OpticsIcon // Renamed to avoid conflict
} from 'lucide-react';

// Define colors for the Pie Chart segments
const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8', '#82ca9d'];

// Define mock data for when real data is unavailable
const MOCK_MAINTENANCE_DATA: MaintenanceStatsData = {
    totalRequests: 42,
    pendingRequests: 8,
    inProgressRequests: 6,
    overdueTasks: 3,
    categoryBreakdown: [
        { category: 'Weapons', count: 12 },
        { category: 'Vehicles', count: 15 },
        { category: 'Electronics', count: 8 },
        { category: 'Communications', count: 7 }
    ],
    statusCounts: [
        { status: 'pending', count: 8 },
        { status: 'in-progress', count: 6 },
        { status: 'completed', count: 25 },
        { status: 'on-hold', count: 3 }
    ],
    upcomingMaintenance: [
        {
            id: 'mock-1',
            itemName: 'M240B Machine Gun',
            serialNumber: 'WPN-B240B111',
            status: 'scheduled',
            scheduledDate: '2025-03-31',
            description: 'Regular maintenance and barrel inspection',
            category: 'Weapons',
            priority: 'medium'
        },
        {
            id: 'mock-2',
            itemName: 'MEP-803A Generator',
            serialNumber: 'GEN-B803A005',
            status: 'scheduled',
            scheduledDate: '2025-04-01',
            description: 'Oil change and filter replacement',
            category: 'Equipment',
            priority: 'high'
        },
        {
            id: 'mock-3',
            itemName: 'HMMWV A2 Vehicle',
            serialNumber: 'VEH-H232A067',
            status: 'scheduled',
            scheduledDate: '2025-04-05',
            description: 'Tire rotation and brake inspection',
            category: 'Vehicles',
            priority: 'medium'
        },
        {
            id: 'mock-4',
            itemName: 'SINCGARS Radio Set',
            serialNumber: 'COM-S432R019',
            status: 'scheduled',
            scheduledDate: '2025-04-08',
            description: 'Antenna replacement and frequency calibration',
            category: 'Communications',
            priority: 'high'
        }
    ]
};

// Explicit type for stats - Defined fully here
interface MaintenanceStatsData { // Removed 'extends MaintenanceStats'
    total?: number;
    totalRequests: number;
    pendingRequests: number;
    inProgressRequests: number;
    overdueTasks: number;
    categoryBreakdown: { category: string; count: number; }[];
    statusCounts: { status: string; count: number; }[];
    upcomingMaintenance: MaintenanceItem[];
    
    // Additional optional properties from original data
    scheduled?: number;
    inProgress?: number;
    completed?: number;
    cancelled?: number;
    criticalPending?: number;
    openRequests?: number;
    openRequestsChange?: number;
    inProgressChange?: number;
    completedRequests?: number;
    completedChange?: number;
    averageTime?: number;
    averageTimeChange?: number;
}

interface MaintenanceDashboardProps {
    stats: MaintenanceStatsData | null; // Allow null initially
    onStatClick?: (filterType: 'status', value: string) => void; // Add callback prop
}

export const MaintenanceDashboard: React.FC<MaintenanceDashboardProps> = ({ stats, onStatClick }) => {
    // Use mock data if stats is null or missing key properties
    const displayStats = !stats || 
        stats.totalRequests === undefined || 
        stats.pendingRequests === undefined || 
        !stats.upcomingMaintenance?.length 
        ? MOCK_MAINTENANCE_DATA 
        : stats;

    const getStatusIcon = (status: string) => {
        switch (status) {
            case 'scheduled': return <Clock className="h-4 w-4 text-blue-500" />;
            case 'in-progress': return <Activity className="h-4 w-4 text-yellow-500" />;
            case 'on-hold': return <AlertTriangle className="h-4 w-4 text-orange-500" />;
            case 'completed': return <CheckCircle className="h-4 w-4 text-green-500" />;
            default: return <Wrench className="h-4 w-4 text-muted-foreground" />;
        }
    };

    // Helper to make cards clickable if callback exists
    const cardClickHandler = (filterType: 'status', value: string) => {
        if (onStatClick) {
            onStatClick(filterType, value);
        }
    };

    // Format date to military style (DDMMMYYYY)
    const formatMilitaryDate = (dateString: string) => {
        if (!dateString) return "N/A";
        
        try {
            const date = new Date(dateString);
            // Format as DDMMMYYYY with month in uppercase
            return format(date, 'ddMMMyyyy').toUpperCase();
        } catch (e) {
            return dateString;
        }
    };

    return (
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            {/* Stat Cards */}
            <Card className="rounded-none border-border shadow-none bg-card hover:bg-muted/10 transition-colors border-l-2 border-transparent">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 pt-4">
                    <CardTitle className="text-sm font-medium">Total Requests</CardTitle>
                    <ListChecks className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent className="pb-4">
                    <div className="text-2xl font-bold">{displayStats.totalRequests}</div>
                    <p className="text-xs text-muted-foreground">All active and historical requests</p>
                </CardContent>
            </Card>

            <Card 
                className={`rounded-none border-border shadow-none bg-card border-l-2 border-transparent ${onStatClick ? 'cursor-pointer hover:bg-muted/10 hover:border-primary/30 transition-colors' : ''}`}
                onClick={() => cardClickHandler('status', 'pending')}
            >
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 pt-4">
                    <CardTitle className="text-sm font-medium">Pending Requests</CardTitle>
                    <Clock className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent className="pb-4">
                    <div className="text-2xl font-bold">{displayStats.pendingRequests}</div>
                    <p className="text-xs text-muted-foreground">Awaiting assignment or action</p>
                </CardContent>
            </Card>

            <Card 
                 className={`rounded-none border-border shadow-none bg-card border-l-2 border-transparent ${onStatClick ? 'cursor-pointer hover:bg-muted/10 hover:border-primary/30 transition-colors' : ''}`}
                 onClick={() => cardClickHandler('status', 'in-progress')}
            >
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 pt-4">
                    <CardTitle className="text-sm font-medium">In Progress</CardTitle>
                    <Activity className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent className="pb-4">
                    <div className="text-2xl font-bold">{displayStats.inProgressRequests}</div>
                    <p className="text-xs text-muted-foreground">Currently being worked on</p>
                </CardContent>
            </Card>

            <Card className="rounded-none border-border shadow-none bg-card hover:bg-muted/10 transition-colors border-l-2 border-transparent hover:border-destructive/30">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2 pt-4">
                    <CardTitle className="text-sm font-medium">Overdue Tasks</CardTitle>
                    <AlertTriangle className="h-4 w-4 text-destructive" />
                </CardHeader>
                <CardContent className="pb-4">
                    <div className="text-2xl font-bold text-destructive">{displayStats.overdueTasks}</div>
                    <p className="text-xs text-muted-foreground">Past scheduled completion date</p>
                </CardContent>
            </Card>

            {/* Category Breakdown - Implementing with Recharts */}
            <Card className="md:col-span-2 lg:col-span-1 xl:col-span-2 rounded-none border-border shadow-none bg-card hover:bg-muted/5 transition-colors border-l-2 border-transparent">
                <CardHeader className="pt-4">
                    <CardTitle className="text-base font-semibold">Requests by Category</CardTitle>
                    <CardDescription className="text-xs">Breakdown of maintenance requests across equipment types.</CardDescription>
                </CardHeader>
                <CardContent className="h-[300px] p-4 pb-6">
                    {displayStats.categoryBreakdown && displayStats.categoryBreakdown.length > 0 ? (
                        <ResponsiveContainer width="100%" height="100%">
                            <PieChart>
                                <Pie
                                    data={displayStats.categoryBreakdown}
                                    cx="50%"
                                    cy="50%"
                                    innerRadius={60}
                                    outerRadius={80}
                                    fill="#8884d8"
                                    paddingAngle={5}
                                    dataKey="count"
                                    nameKey="category"
                                    label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
                                    labelLine={false}
                                >
                                    {displayStats.categoryBreakdown.map((entry, index) => (
                                        <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                                    ))}
                                </Pie>
                                <Tooltip 
                                    formatter={(value: any, name: any) => [value, `Category: ${name}`]}
                                    contentStyle={{ background: 'rgba(255, 255, 255, 0.9)', border: '1px solid #ddd', borderRadius: '4px' }}
                                />
                                <Legend 
                                    layout="horizontal"
                                    verticalAlign="bottom"
                                    align="center"
                                    wrapperStyle={{ paddingTop: '20px' }}
                                />
                            </PieChart>
                        </ResponsiveContainer>
                    ) : (
                        <div className="h-full flex items-center justify-center">
                            <p className="text-muted-foreground">No category data available</p>
                        </div>
                    )}
                </CardContent>
            </Card>

            {/* Upcoming Maintenance - Scrollable List */}
            <Card className="md:col-span-2 lg:col-span-2 xl:col-span-2 rounded-none border-border shadow-none bg-card hover:bg-muted/5 transition-colors border-l-2 border-transparent">
                <CardHeader className="pt-4">
                    <CardTitle className="text-base font-semibold">Upcoming Scheduled Maintenance</CardTitle>
                    <CardDescription className="text-xs">Items scheduled for maintenance soon.</CardDescription>
                </CardHeader>
                <CardContent className="p-0 pb-2">
                    <ScrollArea className="h-64 w-full border-t border-border/30">
                        <div className="divide-y divide-border/60">
                            {displayStats.upcomingMaintenance && displayStats.upcomingMaintenance.length > 0 ? (
                                displayStats.upcomingMaintenance.map((item) => (
                                    <div key={item.id} className="flex items-center justify-between p-4 hover:bg-muted/30 transition-colors border-l-2 border-transparent hover:border-primary/30">
                                        <div className="flex-1 min-w-0">
                                            <p className="text-sm font-medium truncate">{item.itemName}</p>
                                            <div className="flex items-center text-xs text-muted-foreground mt-1">
                                                <span className="truncate">SN: {item.serialNumber}</span>
                                            </div>
                                        </div>
                                        <div className="ml-4 flex-shrink-0 flex items-center space-x-3">
                                            <Badge variant="outline" className="text-xs px-3 py-1 rounded-sm bg-card/60">
                                                {formatMilitaryDate(item.scheduledDate || '')}
                                            </Badge>
                                            {getStatusIcon(item.status)}
                                        </div>
                                    </div>
                                ))
                            ) : (
                                <div className="py-16 px-6 text-center text-sm text-muted-foreground">
                                    No upcoming scheduled maintenance.
                                </div>
                            )}
                        </div>
                    </ScrollArea>
                </CardContent>
            </Card>
        </div>
    );
};
