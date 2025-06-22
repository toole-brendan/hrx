import React, { useState } from 'react';
import { useAuth } from '@/contexts/AuthContext';
import { useLocation } from 'wouter';
import { useToast } from '@/hooks/use-toast';
import { 
  Shield, 
  Lock, 
  CheckCircle, 
  AlertTriangle,
  ArrowLeft,
  Save,
  Loader2
} from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

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
  type = 'password',
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
      
      <div className="flex-1">
        <label className="text-xs font-medium text-ios-tertiary-text uppercase tracking-wider font-mono mb-2 block">
          {label} {required && <span className="text-ios-destructive">*</span>}
        </label>
        <Input
          type={type}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          placeholder={placeholder}
          className={cn(
            "bg-transparent border-0 border-b-2 rounded-none px-0 h-auto py-1 text-base",
            "placeholder:text-ios-quaternary-text focus:ring-0 focus:outline-none transition-colors duration-200",
            isFocused ? "border-ios-accent text-ios-primary-text" : "border-ios-border text-ios-secondary-text"
          )}
          required={required}
        />
      </div>
    </div>
  );
};

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
          currentPassword,
          newPassword,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.error || 'Failed to update password');
      }

      toast({
        title: "Password Updated",
        description: "Your password has been successfully changed.",
      });

      // Redirect to profile after a short delay
      setTimeout(() => {
        setLocation('/profile');
      }, 1000);
    } catch (error: any) {
      setErrorMessage(error.message || 'Failed to update password');
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
      <div className="max-w-2xl mx-auto px-6 py-8">
        
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
                Change Password
              </h1>
              <p className="text-ios-secondary-text mt-2">
                Update your account password for enhanced security
              </p>
            </div>
            <div className="p-3 bg-ios-accent/10 rounded-xl shadow-md">
              <Lock className="h-6 w-6 text-ios-accent" />
            </div>
          </div>
        </div>

        <div className="space-y-6">
          
          {/* Security Notice */}
          <div className="px-4 py-4 bg-gradient-to-r from-ios-accent/10 to-ios-accent/5 border border-ios-accent/20 rounded-lg shadow-md hover:shadow-lg transition-shadow duration-300">
            <div className="flex items-center gap-3">
              <div className="p-2 bg-white rounded-lg shadow-md">
                <Shield className="h-5 w-5 text-ios-accent" />
              </div>
              <div>
                <p className="text-xs font-semibold text-ios-primary-text uppercase tracking-wider font-mono">Security Notice</p>
                <p className="text-xs text-ios-secondary-text mt-0.5">
                  Choose a strong password with at least 8 characters
                </p>
              </div>
            </div>
          </div>

          {/* Current Password */}
          <FormSection 
            title="VERIFY IDENTITY" 
            icon={<Lock className="h-5 w-5 text-ios-accent" />}
          >
            <EnhancedFormField
              label="Current Password"
              value={currentPassword}
              onChange={setCurrentPassword}
              icon={<Lock className="h-4 w-4" />}
              placeholder="Enter your current password"
              required
            />
          </FormSection>

          {/* New Password */}
          <FormSection 
            title="NEW PASSWORD" 
            icon={<Shield className="h-5 w-5 text-ios-accent" />}
          >
            <div className="divide-y divide-ios-divider">
              <EnhancedFormField
                label="New Password"
                value={newPassword}
                onChange={setNewPassword}
                icon={<Lock className="h-4 w-4" />}
                placeholder="Enter new password"
                required
              />
              
              <EnhancedFormField
                label="Confirm New Password"
                value={confirmNewPassword}
                onChange={setConfirmNewPassword}
                icon={<Lock className="h-4 w-4" />}
                placeholder="Confirm new password"
                required
              />
            </div>
          </FormSection>

          {/* Password Requirements */}
          <FormSection 
            title="PASSWORD REQUIREMENTS" 
            icon={<CheckCircle className="h-5 w-5 text-ios-accent" />}
          >
            <div className="px-6 py-4 space-y-3">
              <div className={cn(
                "flex items-center gap-3 text-sm transition-colors duration-200",
                newPassword.length >= 8 ? "text-green-600" : "text-ios-secondary-text"
              )}>
                <CheckCircle className={cn(
                  "h-4 w-4",
                  newPassword.length >= 8 ? "text-green-600" : "text-ios-tertiary-text"
                )} />
                <span>At least 8 characters</span>
              </div>
              
              <div className={cn(
                "flex items-center gap-3 text-sm transition-colors duration-200",
                passwordsMatch && newPassword.length > 0 ? "text-green-600" : "text-ios-secondary-text"
              )}>
                <CheckCircle className={cn(
                  "h-4 w-4",
                  passwordsMatch && newPassword.length > 0 ? "text-green-600" : "text-ios-tertiary-text"
                )} />
                <span>Passwords match</span>
              </div>
            </div>
          </FormSection>

          {/* Error Message */}
          {errorMessage && (
            <div className="flex items-center gap-2 text-ios-destructive px-4 py-3 bg-red-50 border border-red-200 rounded-lg shadow-sm">
              <AlertTriangle className="h-4 w-4 flex-shrink-0" />
              <p className="text-sm">{errorMessage}</p>
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
              onClick={handleChangePassword}
              disabled={!formIsValid || isLoading}
              className={cn(
                "flex-1 font-mono uppercase tracking-wider text-sm font-semibold shadow-lg hover:shadow-xl transition-all duration-200 border-0",
                formIsValid && !isLoading
                  ? "bg-blue-500 hover:bg-blue-600 text-white"
                  : "bg-gray-300 text-gray-500 cursor-not-allowed"
              )}
            >
              {isLoading ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Updating...
                </>
              ) : (
                <>
                  <Save className="h-4 w-4 mr-2" />
                  Update Password
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