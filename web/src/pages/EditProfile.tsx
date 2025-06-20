import React, { useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useLocation } from 'wouter';
import { useToast } from '@/hooks/use-toast';
import { 
  User, 
  Mail, 
  Star, 
  Building2,
  ArrowLeft
} from 'lucide-react';

// iOS-style components
import { 
  CleanCard, 
  ElegantSectionHeader,
  MinimalLoadingView
} from '@/components/ios';

export default function EditProfile() {
  const { user } = useAuth();
  const [, setLocation] = useLocation();
  const { toast } = useToast();

  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [email, setEmail] = useState('');
  const [rank, setRank] = useState('');
  const [unit, setUnit] = useState('');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const formIsValid = firstName.trim().length > 0 && 
                     lastName.trim().length > 0 && 
                     email.trim().length > 0 && 
                     email.includes('@');

  const handleBack = () => {
    setLocation('/profile');
  };

  const loadCurrentUserData = () => {
    if (!user) return;
    
    setFirstName(user.firstName || '');
    setLastName(user.lastName || '');
    setEmail(user.email || '');
    setRank(user.rank || '');
    setUnit(user.unit || '');
  };

  useEffect(() => {
    loadCurrentUserData();
  }, [user]);

  const handleSaveProfile = async () => {
    if (!formIsValid || !user) return;

    setIsLoading(true);
    setErrorMessage(null);

    try {
      const response = await fetch(`/api/users/${user.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          first_name: firstName.trim(),
          last_name: lastName.trim(),
          email: email.trim(),
          rank: rank.trim(),
          unit: unit.trim(),
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to update profile');
      }

      const responseData = await response.json();
      
      // Profile updated successfully
      toast({
        title: 'Profile Updated',
        description: 'Your profile information has been saved successfully.',
      });
      setLocation('/profile');

    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to update profile. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  if (!user) {
    return (
      <div className="min-h-screen bg-ios-background">
        <MinimalLoadingView text="LOADING" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-ios-background">
      <div className="max-w-2xl mx-auto px-6 py-8">
        
        {/* Header with Back Button */}
        <div className="mb-10">
          <button
            onClick={handleBack}
            className="flex items-center gap-2 text-secondary-text hover:text-primary-text transition-colors mb-4"
          >
            <ArrowLeft className="h-4 w-4" />
            <span className="text-sm">Back</span>
          </button>
          
          <h1 className="text-3xl font-light text-primary-text tracking-tight font-mono">
            Edit Profile
          </h1>
        </div>

        <div className="space-y-8">
          
          {/* Personal Information */}
          <div className="space-y-6">
            <ElegantSectionHeader 
              title="Personal Information" 
              className="mb-4"
            />
            
            <CleanCard className="p-0">
              <div className="space-y-0">
                <ModernFormField
                  label="First Name"
                  value={firstName}
                  onChange={setFirstName}
                  icon={<User className="h-4 w-4" />}
                />
                
                <div className="h-px bg-ios-divider ml-12" />
                
                <ModernFormField
                  label="Last Name"
                  value={lastName}
                  onChange={setLastName}
                  icon={<User className="h-4 w-4" />}
                />
              </div>
            </CleanCard>
          </div>

          {/* Contact Information */}
          <div className="space-y-6">
            <ElegantSectionHeader 
              title="Contact Information" 
              className="mb-4"
            />
            
            <CleanCard className="p-0">
              <ModernFormField
                label="Email Address"
                value={email}
                onChange={setEmail}
                icon={<Mail className="h-4 w-4" />}
                type="email"
              />
            </CleanCard>
          </div>

          {/* Military Information */}
          <div className="space-y-6">
            <ElegantSectionHeader 
              title="Military Information" 
              className="mb-4"
            />
            
            <CleanCard className="p-0">
              <div className="space-y-0">
                <ModernFormField
                  label="Rank"
                  value={rank}
                  onChange={setRank}
                  icon={<Star className="h-4 w-4" />}
                />
                
                <div className="h-px bg-ios-divider ml-12" />
                
                <ModernFormField
                  label="Unit/Organization"
                  value={unit}
                  onChange={setUnit}
                  icon={<Building2 className="h-4 w-4" />}
                />
              </div>
            </CleanCard>
          </div>

          {/* Error Message */}
          {errorMessage && (
            <div className="px-6">
              <p className="text-sm text-ios-destructive">{errorMessage}</p>
            </div>
          )}

          {/* Save Button */}
          <div className="px-6 pt-2">
            <button
              onClick={handleSaveProfile}
              disabled={!formIsValid || isLoading}
              className={`w-full py-4 px-8 rounded font-medium text-white transition-all duration-200 ${
                formIsValid && !isLoading
                  ? 'bg-primary-text hover:bg-primary-text/90 active:bg-primary-text/80'
                  : 'bg-quaternary-text cursor-not-allowed'
              }`}
            >
              {isLoading ? (
                <div className="flex items-center justify-center gap-2">
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white" />
                  <span>Saving...</span>
                </div>
              ) : (
                'Save Changes'
              )}
            </button>
          </div>

          {/* Bottom padding */}
          <div className="h-20" />
        </div>
      </div>
    </div>
  );
}

// Supporting Components

interface ModernFormFieldProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  icon: React.ReactNode;
  type?: string;
}

const ModernFormField: React.FC<ModernFormFieldProps> = ({ 
  label, 
  value, 
  onChange, 
  icon,
  type = 'text'
}) => (
  <div className="flex items-center gap-4 px-4 py-4">
    <div className="text-ios-accent w-5 flex justify-center">
      {icon}
    </div>
    
    <div className="flex-1 space-y-2">
      <label className="block text-xs font-medium text-secondary-text uppercase tracking-wide">
        {label}
      </label>
      
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="w-full bg-transparent border-none outline-none text-primary-text placeholder:text-quaternary-text"
        autoCapitalize="none"
      />
    </div>
  </div>
); 