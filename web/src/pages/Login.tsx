import { useState, useRef } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useLocation } from "wouter";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { useToast } from "@/hooks/use-toast";
import logoImage from "@/assets/hr_logo5.png";

const loginSchema = z.object({
  username: z.string().min(1, "Username is required"),
  password: z.string().min(1, "Password is required"),
});

type LoginFormValues = z.infer<typeof loginSchema>;

const Login: React.FC = () => {
  const { login } = useAuth();
  const { toast } = useToast();
  const [isLoading, setIsLoading] = useState(false);
  const [, navigate] = useLocation();
  
  // Logo tap feature state
  const [logoTapCount, setLogoTapCount] = useState(0);
  const lastTapTimeRef = useRef<Date>(new Date());

  const form = useForm<LoginFormValues>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      username: "",
      password: "",
    },
  });

  const onSubmit = async (data: LoginFormValues) => {
    setIsLoading(true);
    try {
      await login(data.username, data.password);
      toast({
        title: "Login Successful",
        description: "Welcome to HandReceipt",
      });
      // Navigate to dashboard after successful login
      navigate("/dashboard");
    } catch (error) {
      toast({
        title: "Login Failed",
        description: "Invalid username or password",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  // Handle logo tap for hidden dev login
  const handleLogoTap = () => {
    const now = new Date();
    const timeSinceLastTap = now.getTime() - lastTapTimeRef.current.getTime();
    
    // Reset counter if more than 2 seconds since last tap
    if (timeSinceLastTap > 2000) {
      setLogoTapCount(1);
      console.log("Dev login: Starting new tap sequence");
    } else {
      setLogoTapCount(prev => prev + 1);
      console.log(`Dev login: Tap ${logoTapCount + 1} of 5`);
    }
    
    lastTapTimeRef.current = now;
    
    // Trigger dev login after 5 taps
    if (logoTapCount + 1 >= 5) {
      performDevLogin();
      setLogoTapCount(0);
    }
  };

  // Perform development login bypass
  const performDevLogin = async () => {
    console.log("🔧 DEV LOGIN ACTIVATED! Using test credentials...");
    
    // Use test credentials to actually authenticate with the backend
    form.setValue("username", "michael.rodriguez");
    form.setValue("password", "password123");
    
    // Show loading state
    setIsLoading(true);
    
    try {
      // Perform actual login with test credentials
      await login("michael.rodriguez", "password123");
      console.log("✅ Dev login successful via API!");
      toast({
        title: "Dev Login Successful",
        description: "Welcome, Michael Rodriguez",
      });
      navigate("/dashboard");
    } catch (error) {
      console.error("❌ Dev login failed:", error);
      toast({
        title: "Dev Login Failed",
        description: "Could not authenticate with dev credentials",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-black px-4 pb-4 pt-2">
      <div className="w-full max-w-md">
        <div className="text-center mb-0">
          <div className="flex justify-center mb-4">
            <div 
              className="relative cursor-pointer transition-all duration-200"
              onClick={handleLogoTap}
            >
              <img 
                src={logoImage} 
                alt="HandReceipt Logo" 
                className="h-96 w-auto select-none"
              />
              {/* Dev login progress indicator - circle around logo like iOS */}
              {logoTapCount > 0 && logoTapCount < 5 && (
                <>
                  <div 
                    className="absolute inset-0 border-2 border-gray-100/20 rounded-full animate-pulse"
                    style={{
                      transform: `scale(${1 + (logoTapCount * 0.05)})`,
                      transition: 'transform 0.2s ease-out'
                    }}
                  />
                  <div className="absolute -top-8 left-1/2 transform -translate-x-1/2 text-gray-100/50 text-sm font-bold">
                    {logoTapCount}
                  </div>
                </>
              )}
            </div>
          </div>
          <p className="text-gray-400 font-light italic mb-6">Military Supply Chain Management</p>
        </div>
        
        <Card className="bg-card border-gray-800" style={{ fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', Arial, sans-serif" }}>
          <CardHeader>
            <CardTitle className="text-white font-light tracking-wide">Sign In</CardTitle>
            <CardDescription className="text-gray-400 font-light">
              Enter your credentials to access your account
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                <FormField
                  control={form.control}
                  name="username"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-gray-200 text-xs uppercase tracking-wider font-light">Username</FormLabel>
                      <FormControl>
                        <Input 
                          placeholder="" 
                          {...field} 
                          className="bg-gray-100 border-gray-400 text-gray-900 placeholder:text-gray-500 font-light focus:outline-none focus:ring-0 focus:ring-offset-0 focus:border-gray-500 focus-visible:ring-0 focus-visible:ring-offset-0"
                          style={{ boxShadow: 'none' }}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <FormField
                  control={form.control}
                  name="password"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-gray-200 text-xs uppercase tracking-wider font-light">Password</FormLabel>
                      <FormControl>
                        <Input 
                          type="password" 
                          placeholder="" 
                          {...field} 
                          className="bg-gray-100 border-gray-400 text-gray-900 placeholder:text-gray-500 font-light focus:outline-none focus:ring-0 focus:ring-offset-0 focus:border-gray-500 focus-visible:ring-0 focus-visible:ring-offset-0"
                          style={{ boxShadow: 'none' }}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <Button 
                  type="submit" 
                  className="w-full bg-blue-500/70 hover:bg-blue-500/90 text-white text-xs uppercase tracking-wider font-light border-0"
                  disabled={isLoading}
                >
                  {isLoading ? (
                    <i className="fas fa-spinner fa-spin mr-2"></i>
                  ) : (
                    <i className="fas fa-sign-in-alt mr-2"></i>
                  )}
                  Sign In
                </Button>
              </form>
            </Form>
          </CardContent>
          <CardFooter className="flex flex-col space-y-2">
          </CardFooter>
        </Card>
      </div>
    </div>
  );
};

export default Login;
