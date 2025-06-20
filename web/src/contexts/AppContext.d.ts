import { ReactNode } from 'react';
interface AppContextType {
    sidebarCollapsed: boolean;
    toggleSidebar: () => void;
}
export declare const AppContext: import("react").Context<AppContextType>;
export declare const useApp: () => AppContextType;
export declare const AppProvider: ({ children }: {
    children: ReactNode;
}) => import("react").JSX.Element;
export {};
