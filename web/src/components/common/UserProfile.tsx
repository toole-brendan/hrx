import { User } from "@/types";
import { useAuth } from "@/contexts/AuthContext";

interface UserProfileProps {
  user: User;
}

const UserProfile: React.FC<UserProfileProps> = ({ user }) => {
  const { logout } = useAuth();

  return (
    <div className="p-4 border-t border-[#545B62]">
      <div className="flex items-center">
        <div className="bg-[#4B5320] p-2 rounded-full">
          <i className="fas fa-user"></i>
        </div>
        <div className="ml-3 flex-1">
          <p className="font-medium">{user.name}</p>
          <p className="text-xs text-gray-300">ID: {user.id}</p>
        </div>
        <button 
          className="p-2 text-gray-300 hover:text-white"
          onClick={logout}
          title="Logout"
        >
          <i className="fas fa-sign-out-alt"></i>
        </button>
      </div>
    </div>
  );
};

export default UserProfile;
