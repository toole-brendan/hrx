import React, { useState, useEffect } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useLocation } from 'wouter';
import { useToast } from '@/hooks/use-toast';
import { 
  User, 
  Mail, 
  Star, 
  Building2,
  ArrowLeft,
  Save,
  Loader2,
  Shield,
  Phone,
  MapPin,
  UserCheck
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';

// iOS-style components
import { 
  CleanCard, 
  ElegantSectionHeader,
  MinimalLoadingView
} from '@/components/ios';

// Enhanced form section component
const FormSection: React.FC<{ 
  title: string; 
  icon?: React.ReactNode;
  children: React.ReactNode 
}> = ({ title, icon, children }) => (
  <div className="mb-8">
    <div className="flex items-center gap-3 mb-4">
      {icon && (
        <div className="p-2 bg-ios-accent/10 rounded-lg shadow-sm">
          {icon}
        </div>
      )}
      <h2 className="text-sm font-semibold text-ios-primary-text uppercase tracking-wider font-mono">
        {title}
      </h2>
    </div>
    <CleanCard className="p-0 shadow-lg hover:shadow-xl transition-shadow duration-300 overflow-hidden">
      {children}
    </CleanCard>
  </div>
);

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
      <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
        <div className="max-w-2xl mx-auto px-6 py-8">
          <MinimalLoadingView text="LOADING" />
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-ios-background to-ios-tertiary-background">
      <div className="max-w-3xl mx-auto px-6 py-8">
        
        {/* Enhanced Header */}
        <div className="mb-12">
          <button
            onClick={handleBack}
            className="flex items-center gap-2 text-ios-secondary-text hover:text-ios-primary-text transition-colors mb-6 group"
          >
            <ArrowLeft className="h-4 w-4 transition-transform duration-200 group-hover:-translate-x-0.5" />
            <span className="text-sm font-medium">Back to Profile</span>
          </button>
          
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold text-ios-primary-text">
                Edit Profile
              </h1>
              <p className="text-ios-secondary-text mt-2">
                Update your personal and military information
              </p>
            </div>
            <div className="p-3 bg-ios-accent/10 rounded-xl shadow-md">
              <UserCheck className="h-6 w-6 text-ios-accent" />
            </div>
          </div>
        </div>

        <div className="space-y-6">
          
          {/* Personal Information */}
          <FormSection 
            title="PERSONAL INFORMATION" 
            icon={<User className="h-5 w-5 text-ios-accent" />}
          >
            <div className="divide-y divide-ios-divider">
              <EnhancedFormField
                label="FIRST NAME"
                value={firstName}
                onChange={setFirstName}
                icon={<User className="h-4 w-4" />}
                placeholder="Enter your first name"
                required
              />
              
              <EnhancedFormField
                label="LAST NAME"
                value={lastName}
                onChange={setLastName}
                icon={<User className="h-4 w-4" />}
                placeholder="Enter your last name"
                required
              />
            </div>
          </FormSection>

          {/* Contact Information */}
          <FormSection 
            title="CONTACT INFORMATION" 
            icon={<Mail className="h-5 w-5 text-ios-accent" />}
          >
            <EnhancedFormField
              label="EMAIL ADDRESS"
              value={email}
              onChange={setEmail}
              icon={<Mail className="h-4 w-4" />}
              type="email"
              placeholder="your.email@military.gov"
              required
            />
          </FormSection>

          {/* Military Information */}
          <FormSection 
            title="MILITARY INFORMATION" 
            icon={<Shield className="h-5 w-5 text-ios-accent" />}
          >
            <div className="divide-y divide-ios-divider">
              <EnhancedFormField
                label="RANK"
                value={rank}
                onChange={setRank}
                icon={<Star className="h-4 w-4" />}
                placeholder="e.g., CPT, SGT, PVT"
              />
              
              <EnhancedFormField
                label="UNIT/ORGANIZATION"
                value={unit}
                onChange={setUnit}
                icon={<Building2 className="h-4 w-4" />}
                placeholder="Your unit designation"
              />
            </div>
          </FormSection>

          {/* Error Message */}
          {errorMessage && (
            <div className="bg-ios-destructive/10 border border-ios-destructive/20 rounded-lg p-4 shadow-md">
              <p className="text-sm text-ios-destructive font-medium">{errorMessage}</p>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex gap-3 pt-4">
            <Button
              variant="outline"
              onClick={handleBack}
              className="flex-1 border-ios-border hover:bg-ios-tertiary-background font-mono uppercase tracking-wider text-sm font-semibold"
            >
              Cancel
            </Button>
            
            <Button
              onClick={handleSaveProfile}
              disabled={!formIsValid || isLoading}
              className={cn(
                "flex-1 font-mono uppercase tracking-wider text-sm font-semibold shadow-sm transition-all duration-200 border-0",
                formIsValid && !isLoading
                  ? "bg-blue-500 hover:bg-blue-600 text-white"
                  : "bg-gray-300 text-gray-500 cursor-not-allowed"
              )}
            >
              {isLoading ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Saving...
                </>
              ) : (
                <>
                  <Save className="h-4 w-4 mr-2" />
                  Save Changes
                </>
              )}
            </Button>
          </div>

          {/* Bottom padding */}
          <div className="h-24" />
        </div>
      </div>
    </div>
  );
}

// Enhanced Form Field Component
interface EnhancedFormFieldProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  icon: React.ReactNode;
  type?: string;
  placeholder?: string;
  required?: boolean;
}

const EnhancedFormField: React.FC<EnhancedFormFieldProps> = ({ 
  label, 
  value, 
  onChange, 
  icon,
  type = 'text',
  placeholder,
  required = false
}) => {
  const [isFocused, setIsFocused] = useState(false);
  
  return (
    <div className={cn(
      "flex items-start gap-4 px-6 py-5 transition-all duration-200",
      isFocused && "bg-ios-tertiary-background/30"
    )}>
      <div className={cn(
        "p-2 rounded-lg transition-colors duration-200 mt-0.5 shadow-sm",
        isFocused ? "bg-ios-accent/10 text-ios-accent" : "bg-ios-tertiary-background text-ios-secondary-text"
      )}>
        {icon}
      </div>
      
      <div className="flex-1 space-y-2">
        <label className="block text-xs font-medium text-ios-tertiary-text uppercase tracking-wider font-mono">
          {label}
          {required && <span className="text-ios-destructive ml-1">*</span>}
        </label>
        
        <input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          placeholder={placeholder}
          className="w-full bg-transparent border-0 border-b-2 border-ios-border outline-none text-ios-primary-text placeholder:text-ios-quaternary-text pb-1 transition-all duration-200 focus:border-ios-accent"
          autoCapitalize="none"
        />
      </div>
    </div>
  );
};