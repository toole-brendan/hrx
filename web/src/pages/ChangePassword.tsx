import React, { useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useLocation } from 'wouter';
import { useToast } from '@/hooks/use-toast';
import { 
  Shield, 
  Lock, 
  RotateCcw, 
  CheckCircle, 
  Circle,
  AlertTriangle,
  ArrowLeft
} from 'lucide-react';

// iOS-style components
import { 
  CleanCard, 
  ElegantSectionHeader,
  MinimalLoadingView
} from '@/components/ios';

export default function ChangePassword() {
  const { user } = useAuth();
  const [, setLocation] = useLocation();
  const { toast } = useToast();

  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmNewPassword, setConfirmNewPassword] = useState('');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  const passwordsMatch = newPassword === confirmNewPassword && newPassword.length > 0;
  const newPasswordStrong = newPassword.length >= 8;
  const formIsValid = currentPassword.length > 0 && passwordsMatch && newPasswordStrong;

  const handleBack = () => {
    setLocation('/profile');
  };

  const handleChangePassword = async () => {
    if (!formIsValid || !user) return;

    setIsLoading(true);
    setErrorMessage(null);

    try {
      const response = await fetch(`/api/users/${user.id}/password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        credentials: 'include',
        body: JSON.stringify({
          current_password: currentPassword,
          new_password: newPassword,
          confirm_password: confirmNewPassword,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to update password');
      }

      // Success
      setCurrentPassword('');
      setNewPassword('');
      setConfirmNewPassword('');
      toast({
        title: 'Password Changed',
        description: 'Your password has been updated successfully.',
      });
      setLocation('/profile');

    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to update password. Please try again.');
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
            CHANGE PASSWORD
          </h1>
        </div>

        <div className="space-y-8">
          
          {/* Security Notice */}
          <div className="px-3 py-3 bg-ios-accent/10 border border-ios-accent/20 rounded">
            <div className="flex items-center gap-3">
              <Shield className="h-4 w-4 text-ios-accent flex-shrink-0" />
              <p className="text-sm text-secondary-text">
                Verify your identity before setting a new password
              </p>
            </div>
          </div>

          {/* Current Password Section */}
          <div className="space-y-4">
            <ElegantSectionHeader 
              title="CURRENT PASSWORD" 
              className="mb-4"
            />
            
            <div className="px-6">
              <MinimalSecureField
                placeholder="Enter current password"
                value={currentPassword}
                onChange={setCurrentPassword}
                icon={<Lock className="h-4 w-4" />}
              />
            </div>
          </div>

          {/* New Password Section */}
          <div className="space-y-4">
            <ElegantSectionHeader 
              title="NEW PASSWORD" 
              className="mb-4"
            />
            
            <div className="px-6 space-y-3">
              <MinimalSecureField
                placeholder="Enter new password"
                value={newPassword}
                onChange={setNewPassword}
                icon={<RotateCcw className="h-4 w-4" />}
              />
              
              <MinimalSecureField
                placeholder="Confirm new password"
                value={confirmNewPassword}
                onChange={setConfirmNewPassword}
                icon={<RotateCcw className="h-4 w-4" />}
              />
            </div>
          </div>

          {/* Password Requirements */}
          <div className="space-y-4">
            <ElegantSectionHeader 
              title="REQUIREMENTS" 
              className="mb-4"
            />
            
            <CleanCard className="p-0">
              <div className="space-y-0">
                <RequirementRow
                  requirement="At least 8 characters"
                  isMet={newPassword.length >= 8}
                />
                
                <div className="h-px bg-ios-divider ml-11" />
                
                <RequirementRow
                  requirement="Passwords match"
                  isMet={passwordsMatch && newPassword.length > 0}
                />
              </div>
            </CleanCard>
          </div>

          {/* Error Message */}
          {errorMessage && (
            <div className="flex items-center gap-2 text-ios-destructive px-6">
              <AlertTriangle className="h-4 w-4" />
              <p className="text-sm">{errorMessage}</p>
            </div>
          )}

          {/* Update Password Button */}
          <div className="px-6 pt-2">
            <button
              onClick={handleChangePassword}
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
                  <span>Updating...</span>
                </div>
              ) : (
                'Update Password'
              )}
            </button>
          </div>

          {/* Bottom padding */}
          <div className="h-10" />
        </div>
      </div>
    </div>
  );
}

// Supporting Components

interface MinimalSecureFieldProps {
  placeholder: string;
  value: string;
  onChange: (value: string) => void;
  icon: React.ReactNode;
}

const MinimalSecureField: React.FC<MinimalSecureFieldProps> = ({ 
  placeholder, 
  value, 
  onChange, 
  icon 
}) => (
  <div className="flex items-center gap-3 p-3 bg-tertiary-background rounded border border-ios-border">
    <div className="text-tertiary-text w-5 flex justify-center">
      {icon}
    </div>
    
    <input
      type="password"
      placeholder={placeholder}
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className="flex-1 bg-transparent border-none outline-none text-primary-text placeholder:text-quaternary-text"
    />
  </div>
);

interface RequirementRowProps {
  requirement: string;
  isMet: boolean;
}

const RequirementRow: React.FC<RequirementRowProps> = ({ requirement, isMet }) => (
  <div className="flex items-center gap-3 px-3 py-3">
    <div className="w-5 flex justify-center">
      {isMet ? (
        <CheckCircle className="h-4 w-4 text-ios-success" />
      ) : (
        <Circle className="h-4 w-4 text-tertiary-text" />
      )}
    </div>
    
    <span className={`text-sm ${isMet ? 'text-primary-text' : 'text-secondary-text'}`}>
      {requirement}
    </span>
  </div>
); 