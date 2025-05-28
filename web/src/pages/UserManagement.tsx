import { useState, useMemo } from "react";
import { 
  Card, 
  CardContent, 
  CardHeader, 
  CardTitle, 
  CardDescription 
} from "@/components/ui/card";
import { 
  Table, 
  TableBody, 
  TableCell, 
  TableHead, 
  TableHeader, 
  TableRow 
} from "@/components/ui/table";
import { 
  DropdownMenu, 
  DropdownMenuContent, 
  DropdownMenuItem, 
  DropdownMenuTrigger 
} from "@/components/ui/dropdown-menu";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { PageWrapper } from "@/components/ui/page-wrapper";
import { PageHeader } from "@/components/ui/page-header";
import { MoreHorizontal, PlusCircle, Search, UserCog } from "lucide-react";

// Mock User Data Interface
interface User {
  id: string;
  name: string;
  rank: string;
  role: 'Admin' | 'Commander' | 'Supply Sergeant' | 'Squad Leader' | 'Soldier';
  status: 'Active' | 'Inactive' | 'Pending';
  lastLogin: string;
}

// Mock user data
const mockUsers: User[] = [
  { id: 'usr_1', name: 'Smith, John', rank: 'SFC', role: 'Supply Sergeant', status: 'Active', lastLogin: '2024-07-22 08:15' },
  { id: 'usr_2', name: 'Doe, Jane', rank: 'CPT', role: 'Commander', status: 'Active', lastLogin: '2024-07-23 10:00' },
  { id: 'usr_3', name: 'Williams, David', rank: 'SSG', role: 'Squad Leader', status: 'Active', lastLogin: '2024-07-21 14:30' },
  { id: 'usr_4', name: 'Brown, Emily', rank: 'SPC', role: 'Soldier', status: 'Active', lastLogin: '2024-07-23 09:05' },
  { id: 'usr_5', name: 'Jones, Michael', rank: 'MAJ', role: 'Admin', status: 'Active', lastLogin: '2024-07-23 11:20' },
  { id: 'usr_6', name: 'Garcia, Maria', rank: 'SGT', role: 'Squad Leader', status: 'Inactive', lastLogin: '2024-06-15 17:00' },
  { id: 'usr_7', name: 'Miller, James', rank: 'PFC', role: 'Soldier', status: 'Pending', lastLogin: 'N/A' },
];

const UserManagement: React.FC = () => {
  const [users, setUsers] = useState<User[]>(mockUsers);
  const [searchTerm, setSearchTerm] = useState("");
  const [roleFilter, setRoleFilter] = useState<string>("all");
  const [statusFilter, setStatusFilter] = useState<string>("all");

  const filteredUsers = useMemo(() => {
    return users.filter(user => {
      const matchesSearch = user.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
                            user.rank.toLowerCase().includes(searchTerm.toLowerCase());
      const matchesRole = roleFilter === "all" || user.role === roleFilter;
      const matchesStatus = statusFilter === "all" || user.status === statusFilter;
      return matchesSearch && matchesRole && matchesStatus;
    });
  }, [users, searchTerm, roleFilter, statusFilter]);

  const getStatusBadgeVariant = (status: User['status']): "default" | "secondary" | "destructive" | "outline" => {
    switch (status) {
      case 'Active': return 'default'; // Using 'default' for green-like active status
      case 'Inactive': return 'secondary'; // Using 'secondary' for gray-like inactive status
      case 'Pending': return 'outline'; // Using 'outline' for yellow-like pending status
      default: return 'secondary';
    }
  };
  
   const getRoleBadgeVariant = (role: User['role']): "default" | "secondary" | "destructive" | "outline" => {
    switch (role) {
      case 'Admin': return 'destructive'; // Example: Admin gets a distinct variant
      case 'Commander': return 'default'; // Example: Commander gets default
      case 'Supply Sergeant': return 'secondary'; // Example: Supply Sergeant gets secondary
      default: return 'outline'; // Other roles get outline
    }
  };


  // Action buttons for the page header
  const actions = (
    <Button>
      <PlusCircle className="mr-2 h-4 w-4" /> Add New User
    </Button>
  );

  return (
    <PageWrapper withPadding={true}>
      <PageHeader
        title="User Management"
        description="Administer user accounts, roles, and permissions"
        actions={actions}
        className="mb-4 sm:mb-5 md:mb-6"
      />

      <Card>
        <CardHeader>
          <CardTitle>User Directory</CardTitle>
          <CardDescription>View, manage, and configure user access.</CardDescription>
          <div className="flex flex-col md:flex-row gap-4 pt-4">
            <div className="relative flex-1">
              <Input
                placeholder="Search by name or rank..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pl-10"
              />
              <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
            </div>
            <Select value={roleFilter} onValueChange={setRoleFilter}>
              <SelectTrigger className="w-full md:w-[180px]">
                <SelectValue placeholder="Filter by role" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Roles</SelectItem>
                <SelectItem value="Admin">Admin</SelectItem>
                <SelectItem value="Commander">Commander</SelectItem>
                <SelectItem value="Supply Sergeant">Supply Sergeant</SelectItem>
                <SelectItem value="Squad Leader">Squad Leader</SelectItem>
                <SelectItem value="Soldier">Soldier</SelectItem>
              </SelectContent>
            </Select>
            <Select value={statusFilter} onValueChange={setStatusFilter}>
              <SelectTrigger className="w-full md:w-[180px]">
                <SelectValue placeholder="Filter by status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Statuses</SelectItem>
                <SelectItem value="Active">Active</SelectItem>
                <SelectItem value="Inactive">Inactive</SelectItem>
                <SelectItem value="Pending">Pending</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Name</TableHead>
                <TableHead>Rank</TableHead>
                <TableHead>Role</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Last Login</TableHead>
                <TableHead><span className="sr-only">Actions</span></TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredUsers.length > 0 ? (
                filteredUsers.map((user) => (
                  <TableRow key={user.id}>
                    <TableCell className="font-medium">{user.name}</TableCell>
                    <TableCell>{user.rank}</TableCell>
                    <TableCell>
                      <Badge variant={getRoleBadgeVariant(user.role)}>{user.role}</Badge>
                    </TableCell>
                    <TableCell>
                      <Badge variant={getStatusBadgeVariant(user.status)}>{user.status}</Badge>
                    </TableCell>
                    <TableCell>{user.lastLogin}</TableCell>
                    <TableCell>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" className="h-8 w-8 p-0">
                            <span className="sr-only">Open menu</span>
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem>Edit User</DropdownMenuItem>
                          <DropdownMenuItem>Reset Password</DropdownMenuItem>
                          <DropdownMenuItem className={user.status === 'Active' ? 'text-destructive' : ''}>
                            {user.status === 'Active' ? 'Deactivate User' : 'Activate User'}
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </TableCell>
                  </TableRow>
                ))
              ) : (
                <TableRow>
                  <TableCell colSpan={6} className="h-24 text-center">
                    No users found.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </PageWrapper>
  );
};

export default UserManagement; 