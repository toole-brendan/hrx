import { useState, useRef } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useLocation, Link } from "wouter";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardFooter,
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
  email: z.string().min(1, "Email is required").email("Invalid email address"),
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
      email: "",
      password: "",
    },
  });

  const onSubmit = async (data: LoginFormValues) => {
    setIsLoading(true);
    try {
      await login(data.email, data.password);
      toast({
        title: "Login Successful",
        description: "Welcome to HandReceipt",
      });
      // Navigate to dashboard after successful login
      navigate("/dashboard");
    } catch (error) {
      toast({
        title: "Login Failed",
        description: "Invalid email or password",
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
    form.setValue("email", "michael.rodriguez@example.com");
    form.setValue("password", "password123");
    
    // Show loading state
    setIsLoading(true);
    
    try {
      // Perform actual login with test credentials
      await login("michael.rodriguez@example.com", "password123");
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
    <div className="min-h-screen flex items-center justify-center bg-[#FAFAFA] px-4 pb-4 pt-2">
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
                className="h-48 w-auto select-none"
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
          <p className="text-gray-700 font-normal mb-6">Property Management System</p>
        </div>
        
        <Card className="bg-white shadow-md rounded-md" style={{ fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', Arial, sans-serif" }}>
          <CardContent className="pt-6">
            <p className="text-gray-500 mb-4">Sign in to continue</p>
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
                <FormField
                  control={form.control}
                  name="email"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-gray-600 text-xs uppercase tracking-wider font-medium">Email</FormLabel>
                      <FormControl>
                        <Input 
                          placeholder="" 
                          {...field} 
                          className="border-0 border-b-2 border-gray-300 text-gray-900 placeholder:text-gray-500 focus:border-black focus:outline-none focus:ring-0 focus:ring-offset-0 focus-visible:ring-0 focus-visible:ring-offset-0 rounded-none bg-transparent"
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
                      <FormLabel className="text-gray-600 text-xs uppercase tracking-wider font-medium">Password</FormLabel>
                      <FormControl>
                        <Input 
                          type="password" 
                          placeholder="" 
                          {...field} 
                          className="border-0 border-b-2 border-gray-300 text-gray-900 placeholder:text-gray-500 focus:border-black focus:outline-none focus:ring-0 focus:ring-offset-0 focus-visible:ring-0 focus-visible:ring-offset-0 rounded-none bg-transparent"
                          style={{ boxShadow: 'none' }}
                        />
                      </FormControl>
                      <FormMessage />
                    </FormItem>
                  )}
                />
                
                <Button 
                  type="submit" 
                  className="w-full bg-black hover:opacity-90 text-white font-normal"
                  disabled={isLoading}
                >
                  {isLoading ? (
                    <i className="fas fa-spinner fa-spin mr-2"></i>
                  ) : (
                    <i className="fas fa-arrow-right mr-2"></i>
                  )}
                  Sign In
                </Button>
              </form>
            </Form>
          </CardContent>
          <CardFooter>
            <div className="w-full text-center text-sm">
              <span className="text-gray-600">Don't have an account?</span>{' '}
              <Link href="/register"><a className="text-blue-600 font-medium underline">Create one</a></Link>
            </div>
          </CardFooter>
        </Card>
      </div>
    </div>
  );
};

export default Login;
