interface Activity {
    id: string;
    description: string;
    timeAgo: string;
    type: string;
}
interface RecentActivityProps {
    activities?: Activity[];
}
declare const RecentActivity: React.FC<RecentActivityProps>;
export default RecentActivity;
