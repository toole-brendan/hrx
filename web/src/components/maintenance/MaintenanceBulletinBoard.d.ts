import React from 'react';
import { MaintenanceBulletin } from "@/lib/maintenanceData";
interface MaintenanceBulletinBoardProps {
    bulletins: MaintenanceBulletin[];
    onAddBulletin: () => void;
}
export declare const MaintenanceBulletinBoard: React.FC<MaintenanceBulletinBoardProps>;
export {};
