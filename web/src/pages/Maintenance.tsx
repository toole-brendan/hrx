import React from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { useLocation } from 'wouter';
import { useUnreadDocumentCount } from '@/hooks/useDocuments';
import { 
  Wrench, 
  FileText, 
  ArrowRight, 
  BookOpen,
  Send,
  Inbox
} from 'lucide-react';

export default function Maintenance() {
  const [, setLocation] = useLocation();
  const { data: unreadCount = 0 } = useUnreadDocumentCount();

  return (
    <div className="space-y-6 max-w-4xl mx-auto">
      {/* Header */}
      <div className="text-center space-y-4 py-8">
        <div className="flex justify-center">
          <div className="p-4 bg-primary/10 rounded-full">
            <Wrench className="w-8 h-8 text-primary" />
          </div>
        </div>
        <h1 className="text-3xl font-bold tracking-tight">Maintenance</h1>
        <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
          Send auto-populated DA maintenance forms from your property book and receive forms from others in your documents inbox.
        </p>
      </div>

      {/* How It Works */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <FileText className="w-5 h-5" />
            How Maintenance Forms Work
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-6">
            {/* Step 1 */}
            <div className="flex gap-4">
              <div className="flex-shrink-0 w-8 h-8 bg-primary text-primary-foreground rounded-full flex items-center justify-center text-sm font-semibold">
                1
              </div>
              <div className="space-y-2">
                <h3 className="font-semibold">Create Maintenance Request</h3>
                <p className="text-muted-foreground">
                  Go to your Property Book, find the equipment that needs maintenance, and click the 
                  <Badge variant="outline" className="mx-1">
                    <Wrench className="w-3 h-3 mr-1" />
                    Send Maintenance Form
                  </Badge>
                  button.
                </p>
              </div>
            </div>

            {/* Step 2 */}
            <div className="flex gap-4">
              <div className="flex-shrink-0 w-8 h-8 bg-primary text-primary-foreground rounded-full flex items-center justify-center text-sm font-semibold">
                2
              </div>
              <div className="space-y-2">
                <h3 className="font-semibold">Fill Out Form</h3>
                <p className="text-muted-foreground">
                  The DA Form (2404 or 5988-E) will be auto-populated with equipment details. 
                  Describe the problem, add photos if needed, and select who to send it to from your connections.
                </p>
              </div>
            </div>

            {/* Step 3 */}
            <div className="flex gap-4">
              <div className="flex-shrink-0 w-8 h-8 bg-primary text-primary-foreground rounded-full flex items-center justify-center text-sm font-semibold">
                3
              </div>
              <div className="space-y-2">
                <h3 className="font-semibold">Receive & Respond</h3>
                <p className="text-muted-foreground">
                  Forms you receive will appear in your Documents inbox. You can view, print, or forward them as needed.
                </p>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-blue-100 dark:bg-blue-900/20 rounded-lg">
                <BookOpen className="w-6 h-6 text-blue-600 dark:text-blue-400" />
              </div>
              <div className="flex-1">
                <h3 className="font-semibold mb-1">Create Maintenance Request</h3>
                <p className="text-sm text-muted-foreground mb-3">
                  Send maintenance forms for your equipment
                </p>
                <Button onClick={() => setLocation('/property-book')} className="w-full">
                  Go to Property Book
                  <ArrowRight className="w-4 h-4 ml-2" />
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center gap-4">
              <div className="p-3 bg-green-100 dark:bg-green-900/20 rounded-lg">
                <Inbox className="w-6 h-6 text-green-600 dark:text-green-400" />
              </div>
              <div className="flex-1">
                <div className="flex items-center gap-2 mb-1">
                  <h3 className="font-semibold">View Maintenance Forms</h3>
                  {unreadCount > 0 && (
                    <Badge variant="destructive" className="text-xs">
                      {unreadCount} new
                    </Badge>
                  )}
                </div>
                <p className="text-sm text-muted-foreground mb-3">
                  Review forms you've received from others
                </p>
                <Button onClick={() => setLocation('/documents')} className="w-full">
                  Go to Documents
                  <ArrowRight className="w-4 h-4 ml-2" />
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Supported Forms */}
      <Card>
        <CardHeader>
          <CardTitle className="text-lg">Supported Forms</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex items-center gap-3 p-3 border rounded-lg">
              <FileText className="w-5 h-5 text-muted-foreground" />
              <div>
                <div className="font-medium">DA Form 2404</div>
                <div className="text-sm text-muted-foreground">Equipment Inspection and Maintenance Worksheet</div>
              </div>
            </div>
            <div className="flex items-center gap-3 p-3 border rounded-lg">
              <FileText className="w-5 h-5 text-muted-foreground" />
              <div>
                <div className="font-medium">DA Form 5988-E</div>
                <div className="text-sm text-muted-foreground">Equipment Maintenance Request</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}