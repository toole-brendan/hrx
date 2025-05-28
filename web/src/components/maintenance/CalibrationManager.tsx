import React, { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Search, CheckCircle, Clock, Wrench, AlertTriangle, Calendar, Clipboard, FileText } from 'lucide-react';

const CalibrationManager: React.FC = () => {
  const [activeTab, setActiveTab] = useState("upcoming");
  const [logDialogOpen, setLogDialogOpen] = useState(false);
  const [selectedItem, setSelectedItem] = useState<any>(null);
  const [calibrationDate, setCalibrationDate] = useState("");
  const [calibrationNotes, setCalibrationNotes] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Set today's date as default when dialog opens
  useEffect(() => {
    if (logDialogOpen) {
      setCalibrationDate(new Date().toISOString().split('T')[0]);
    }
  }, [logDialogOpen]);

  // Mock data for demonstration
  const mockData = [
    { id: "cal1", name: "AN/PRC-152 Radio", serialNumber: "R2D2C3PO1", status: "upcoming", dueDate: "2023-07-15", lastCalibrated: "2023-01-15" },
    { id: "cal2", name: "M150 RCO ACOG", serialNumber: "AC90122", status: "overdue", dueDate: "2023-04-30", lastCalibrated: "2022-10-30" },
    { id: "cal3", name: "AN/PVS-14 NVGs", serialNumber: "NVG34287", status: "due", dueDate: "2023-05-05", lastCalibrated: "2023-02-05" },
    { id: "cal4", name: "Lensatic Compass", serialNumber: "C298371", status: "completed", dueDate: "2023-06-01", lastCalibrated: "2023-05-01" }
  ];

  // Filter data based on active tab
  const filteredData = mockData.filter(item => {
    if (activeTab === "upcoming") return item.status === "upcoming";
    if (activeTab === "overdue") return item.status === "overdue";
    if (activeTab === "due") return item.status === "due";
    return true; // "all" tab
  });

  // Component for displaying status badge
  const StatusBadge = ({ status }: { status: string }) => {
    switch (status) {
      case "upcoming":
        return <Badge className="uppercase bg-blue-100/70 dark:bg-transparent text-blue-700 dark:text-blue-400 border border-blue-600 dark:border-blue-500 text-[10px] tracking-wider px-2 rounded-none">UPCOMING</Badge>;
      case "overdue":
        return <Badge className="uppercase bg-red-100/70 dark:bg-transparent text-red-700 dark:text-red-400 border border-red-600 dark:border-red-500 text-[10px] tracking-wider px-2 rounded-none">OVERDUE</Badge>;
      case "due":
        return <Badge className="uppercase bg-amber-100/70 dark:bg-transparent text-amber-700 dark:text-amber-400 border border-amber-600 dark:border-amber-500 text-[10px] tracking-wider px-2 rounded-none">DUE NOW</Badge>;
      case "completed":
        return <Badge className="uppercase bg-green-100/70 dark:bg-transparent text-green-700 dark:text-green-400 border border-green-600 dark:border-green-500 text-[10px] tracking-wider px-2 rounded-none">COMPLETED</Badge>;
      default:
        return <Badge className="uppercase bg-gray-100/70 dark:bg-transparent text-gray-700 dark:text-gray-400 border border-gray-600 dark:border-gray-500 text-[10px] tracking-wider px-2 rounded-none">{status.toUpperCase()}</Badge>;
    }
  };

  // Handle the calibration log button click
  const handleLogCalibrationClick = (item: any) => {
    setSelectedItem(item);
    setLogDialogOpen(true);
  };

  // Handle the calibration log submission
  const handleSubmitCalibration = () => {
    if (!selectedItem || !calibrationDate) return;
    
    setIsSubmitting(true);
    
    // Simulate a network request
    setTimeout(() => {
      // In a real application, you would:
      // 1. Save the calibration record to your database
      // 2. Update the item's lastCalibrated date
      // 3. Calculate a new dueDate
      // 4. Update the status from overdue/due to "upcoming" or "completed"
      
      // For this mock implementation, let's just close the dialog
      setIsSubmitting(false);
      setLogDialogOpen(false);
      
      // Reset form
      setCalibrationDate("");
      setCalibrationNotes("");
      setSelectedItem(null);
      
      // Show success message - in a real app you would use a toast notification
      alert(`Successfully logged calibration for ${selectedItem.name}`);
    }, 1000);
  };

  return (
    <Card className="border-border shadow-none bg-card">
      <CardHeader>
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div>
            <CardTitle>Equipment Calibration</CardTitle>
            <CardDescription>Track and schedule equipment calibration</CardDescription>
          </div>
          <Button 
            variant="outline" 
            size="sm"
            className="flex items-center gap-1.5 h-9"
          >
            <Calendar className="h-4 w-4 mr-1" />
            <span className="text-xs uppercase tracking-wider">Export Schedule</span>
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
          <TabsList className="grid grid-cols-4 w-full rounded-none h-10 mb-6">
            <TabsTrigger value="upcoming" className="text-xs uppercase tracking-wider rounded-none">Upcoming</TabsTrigger>
            <TabsTrigger value="overdue" className="text-xs uppercase tracking-wider rounded-none">Overdue</TabsTrigger>
            <TabsTrigger value="due" className="text-xs uppercase tracking-wider rounded-none">Due Now</TabsTrigger>
            <TabsTrigger value="all" className="text-xs uppercase tracking-wider rounded-none">All Equipment</TabsTrigger>
          </TabsList>
          
          {activeTab === "overdue" && (
            <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-md">
              <div className="flex items-start">
                <AlertTriangle className="h-5 w-5 text-red-600 mr-2 mt-0.5" />
                <div>
                  <h3 className="font-medium text-red-800">Overdue Calibrations</h3>
                  <p className="text-sm text-red-700 mt-1">
                    {filteredData.length} items need immediate calibration.
                  </p>
                </div>
              </div>
            </div>
          )}

          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Equipment</TableHead>
                <TableHead>Serial Number</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Last Calibrated</TableHead>
                <TableHead>Due Date</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredData.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-8 text-muted-foreground">
                    No calibration items found
                  </TableCell>
                </TableRow>
              ) : (
                filteredData.map((item) => (
                  <TableRow key={item.id}>
                    <TableCell className="font-medium">{item.name}</TableCell>
                    <TableCell className="font-mono text-xs">{item.serialNumber}</TableCell>
                    <TableCell>
                      <StatusBadge status={item.status} />
                    </TableCell>
                    <TableCell>{item.lastCalibrated}</TableCell>
                    <TableCell>{item.dueDate}</TableCell>
                    <TableCell className="text-right">
                      <Button 
                        variant="outline"
                        size="sm"
                        onClick={() => handleLogCalibrationClick(item)}
                      >
                        <Wrench className="h-3.5 w-3.5 mr-1.5" />
                        Log Calibration
                      </Button>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </Tabs>
      </CardContent>

      {/* Calibration Log Dialog */}
      <Dialog open={logDialogOpen} onOpenChange={setLogDialogOpen}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center">
              <Clipboard className="h-5 w-5 mr-2 text-primary" />
              Log Calibration
            </DialogTitle>
            <DialogDescription>
              Record calibration details for {selectedItem?.name}
            </DialogDescription>
          </DialogHeader>
          
          <div className="space-y-4 py-4">
            <div className="space-y-1">
              <div className="bg-muted p-3 rounded-md mb-4">
                <div className="flex flex-col gap-1">
                  <div className="flex justify-between">
                    <span className="text-sm font-medium">Equipment:</span>
                    <span className="text-sm">{selectedItem?.name}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm font-medium">Serial Number:</span>
                    <span className="text-sm font-mono">{selectedItem?.serialNumber}</span>
                  </div>
                </div>
              </div>
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="calibration-date">Calibration Date</Label>
              <Input 
                id="calibration-date" 
                type="date" 
                value={calibrationDate}
                onChange={(e) => setCalibrationDate(e.target.value)}
                required
              />
            </div>
            
            <div className="space-y-2">
              <Label htmlFor="calibration-notes">Notes (Optional)</Label>
              <Textarea 
                id="calibration-notes" 
                placeholder="Enter any calibration notes or observations"
                value={calibrationNotes}
                onChange={(e) => setCalibrationNotes(e.target.value)}
                className="min-h-[100px]"
              />
            </div>
            
            <div className="rounded-md border p-3 flex items-start gap-3">
              <FileText className="h-5 w-5 text-blue-500 mt-0.5" />
              <div className="text-sm space-y-1">
                <p className="font-medium">Next Calibration</p>
                <p className="text-muted-foreground">This item will need to be calibrated again in 180 days.</p>
              </div>
            </div>
          </div>
          
          <DialogFooter>
            <Button 
              variant="outline" 
              onClick={() => setLogDialogOpen(false)}
            >
              Cancel
            </Button>
            <Button 
              onClick={handleSubmitCalibration}
              disabled={isSubmitting || !calibrationDate}
              className="flex items-center gap-1.5"
            >
              {isSubmitting ? (
                <>
                  <span className="h-4 w-4 border-t-2 border-b-2 border-white rounded-full animate-spin mr-2" />
                  Processing...
                </>
              ) : (
                <>
                  <CheckCircle className="h-4 w-4 mr-1.5" />
                  Log Calibration
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </Card>
  );
};

export default CalibrationManager; 