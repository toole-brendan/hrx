export interface UserConnection {
    id: number;
    userId: number;
    connectedUserId: number;
    connectionStatus: 'pending' | 'accepted' | 'blocked';
    connectedUser?: {
        id: number;
        name: string;
        rank: string;
        unit: string;
        phone?: string;
    };
    createdAt: string;
}
export declare function getConnections(): Promise<UserConnection[]>;
export declare function searchUsers(query: string): Promise<any[]>;
export declare function sendConnectionRequest(targetUserId: number): Promise<UserConnection>;
export declare function updateConnectionStatus(connectionId: number, status: 'accepted' | 'blocked'): Promise<UserConnection>;
