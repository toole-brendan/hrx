import React from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { MaintenanceBulletin } from "@/lib/maintenanceData"; // Adjust path if needed
import {
    Plus,
    Bell,
    AlertTriangle,
    Clock,
    FileText,
    Settings,
    Info,
    CheckCircle
} from 'lucide-react';

// Props interface for the component
interface MaintenanceBulletinBoardProps {
    bulletins: MaintenanceBulletin[];
    onAddBulletin: () => void;
}

export const MaintenanceBulletinBoard: React.FC<MaintenanceBulletinBoardProps> = ({ bulletins, onAddBulletin }) => {
    return (
        <div className="space-y-6">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-4">
                <div>
                    <h2 className="text-xl font-semibold">Maintenance Bulletins</h2>
                    <p className="text-muted-foreground text-sm">Important maintenance updates and notices.</p>
                </div>
                <Button
                    onClick={onAddBulletin}
                    size="sm"
                    variant="blue"
                    className="h-9 px-3 flex items-center gap-1.5 flex-shrink-0"
                >
                    <Plus className="h-4 w-4" />
                    <span className="text-xs uppercase tracking-wider">Post New Bulletin</span>
                </Button>
            </div>

            {/* Bulletin List */}
            <div className="grid grid-cols-1 gap-4">
                {bulletins.length === 0 ? (
                    <Card className="rounded-none border-border shadow-none bg-card">
                        <CardContent className="p-10 text-center text-muted-foreground">
                            <div className="inline-flex h-16 w-16 items-center justify-center rounded-full bg-muted mb-4">
                                <Bell className="h-8 w-8 text-muted-foreground/70" />
                            </div>
                            <h3 className="text-lg font-medium mb-1">No bulletins posted</h3>
                            <p className="text-sm">Check back later for important maintenance updates.</p>
                        </CardContent>
                    </Card>
                ) : (
                    bulletins.map(bulletin => (
                        <Card key={bulletin.id} className={`overflow-hidden border rounded-none shadow-none bg-card
                            ${bulletin.category === 'parts-shortage' ? 'border-l-4 border-l-amber-500' : ''}
                            ${bulletin.category === 'delay' ? 'border-l-4 border-l-blue-500' : ''}
                            ${bulletin.category === 'update' ? 'border-l-4 border-l-green-500' : ''}
                            ${bulletin.category === 'facility' ? 'border-l-4 border-l-purple-500' : ''}
                            ${bulletin.category === 'general' ? 'border-l-4 border-l-gray-500' : ''}
                            ${bulletin.resolved ? 'opacity-75 bg-muted/30' : ''} // Style resolved bulletins
                        `}>
                            <CardHeader className="pb-3">
                                <div className="flex flex-col sm:flex-row justify-between items-start gap-2">
                                    <div>
                                        <CardTitle className="flex items-center text-base md:text-lg mb-1">
                                            {bulletin.category === 'parts-shortage' && <AlertTriangle className="h-4 w-4 mr-2 text-amber-500 flex-shrink-0" />}
                                            {bulletin.category === 'delay' && <Clock className="h-4 w-4 mr-2 text-blue-500 flex-shrink-0" />}
                                            {bulletin.category === 'update' && <FileText className="h-4 w-4 mr-2 text-green-500 flex-shrink-0" />}
                                            {bulletin.category === 'facility' && <Settings className="h-4 w-4 mr-2 text-purple-500 flex-shrink-0" />}
                                            {bulletin.category === 'general' && <Info className="h-4 w-4 mr-2 text-gray-500 flex-shrink-0" />}
                                            <span className="leading-tight">{bulletin.title}</span>
                                        </CardTitle>
                                        <CardDescription className="text-xs">
                                            Posted by {bulletin.postedBy} on {bulletin.postedDate}
                                            {bulletin.resolved && bulletin.resolvedDate && ` • Resolved on ${bulletin.resolvedDate}`}
                                        </CardDescription>
                                    </div>
                                    <div className="mt-1 sm:mt-0">
                                        {bulletin.resolved ? (
                                            <Badge className="uppercase bg-green-100/70 dark:bg-transparent text-green-700 dark:text-green-400 border border-green-600 dark:border-green-500 text-[10px] tracking-wider px-2 rounded-none">
                                                RESOLVED
                                            </Badge>
                                        ) : (
                                            <Badge className="uppercase bg-amber-100/70 dark:bg-transparent text-amber-700 dark:text-amber-400 border border-amber-600 dark:border-amber-500 text-[10px] tracking-wider px-2 rounded-none">
                                                ACTIVE
                                            </Badge>
                                        )}
                                    </div>
                                </div>
                            </CardHeader>
                            <CardContent>
                                <p className="text-sm mb-3">{bulletin.message}</p>

                                {bulletin.affectedItems && bulletin.affectedItems.length > 0 && (
                                    <div className="flex flex-wrap gap-1 mt-2">
                                        <span className="text-xs text-muted-foreground mr-1">Affected:</span>
                                        {bulletin.affectedItems.map((item, index) => (
                                            <Badge key={index} variant="secondary" className="text-[10px] px-1.5 py-0 rounded-sm">
                                                {item}
                                            </Badge>
                                        ))}
                                    </div>
                                )}
                            </CardContent>
                            {/* Optional Footer for actions like 'Mark as Resolved' */}
                            {/* <CardFooter> ... </CardFooter> */}
                        </Card>
                    ))
                )}
            </div>
        </div>
    );
}; 