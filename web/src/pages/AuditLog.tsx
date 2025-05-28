import { useState } from "react";
import { activities } from "@/lib/mockData";
import { 
  Card, 
  CardContent, 
  CardHeader, 
  CardTitle, 
  CardDescription 
} from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { PageWrapper } from "@/components/ui/page-wrapper";
import { PageHeader } from "@/components/ui/page-header";
import { Search, FileDown, CheckCircle, XCircle, RefreshCw, Info, DatabaseZap, History } from "lucide-react";

const AuditLog: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState("");
  const [activityType, setActivityType] = useState<string>("all");

  const filteredActivities = activities.filter(activity => {
    const matchesSearch = activity.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          activity.user.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesType = activityType === "all" || activity.type === activityType;
    
    return matchesSearch && matchesType;
  });

  const getActivityTypeIcon = (type: string) => {
    switch (type) {
      case "transfer-approved":
        return <CheckCircle className="h-4 w-4 text-green-600" />;
      case "transfer-rejected":
        return <XCircle className="h-4 w-4 text-red-600" />;
      case "inventory-updated":
        return <RefreshCw className="h-4 w-4 text-blue-600" />;
      default:
        return <Info className="h-4 w-4 text-gray-500" />;
    }
  };

  // Action buttons for the page header
  const actions = (
    <>
      <Button variant="outline" className="flex items-center gap-1">
        <DatabaseZap className="h-4 w-4" />
        <span>Verify Ledger</span>
      </Button>
      <Button variant="outline" className="flex items-center gap-1">
        <FileDown className="h-4 w-4" />
        <span>Export History</span>
      </Button>
    </>
  );

  return (
    <PageWrapper withPadding={true}>
      <PageHeader
        title="Ledger History & Verification"
        description="Explore and verify the immutable equipment transaction history"
        actions={actions}
        className="mb-4 sm:mb-5 md:mb-6"
      />

      <Card>
        <CardHeader>
          <CardTitle>Transaction History</CardTitle>
          <CardDescription>Immutable log of all equipment actions recorded in the secure ledger</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-col md:flex-row gap-4 mb-6">
            <div className="relative flex-1">
              <Input
                placeholder="Search by item, user, or transaction ID"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10"
              />
              <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            </div>
            <div className="w-full md:w-64">
              <Select
                value={activityType}
                onValueChange={setActivityType}
              >
                <SelectTrigger>
                  <SelectValue placeholder="Filter by type" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Activities</SelectItem>
                  <SelectItem value="transfer-approved">Transfers Approved</SelectItem>
                  <SelectItem value="transfer-rejected">Transfers Rejected</SelectItem>
                  <SelectItem value="inventory-updated">Inventory Updates</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="divide-y divide-gray-200 dark:divide-gray-700">
            {filteredActivities.length === 0 ? (
              <div className="py-4 text-center text-gray-500 dark:text-gray-400">No ledger entries found</div>
            ) : (
              filteredActivities.map((activity) => (
                <div key={activity.id} className="py-4 flex items-start">
                  <div className="mr-4 mt-1">
                    <div className="h-8 w-8 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
                      {getActivityTypeIcon(activity.type)}
                    </div>
                  </div>
                  <div className="flex-1">
                    <p className="font-medium">{activity.description}</p>
                    <div className="flex flex-col sm:flex-row sm:items-center text-sm text-gray-500 dark:text-gray-400 mt-1">
                      <span>{activity.user}</span>
                      <span className="hidden sm:inline mx-2">•</span>
                      <span>{activity.timeAgo}</span>
                      <span className="hidden sm:inline mx-2">•</span>
                      <span className="font-mono text-xs">{activity.id}</span>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </CardContent>
      </Card>
    </PageWrapper>
  );
};

export default AuditLog;
