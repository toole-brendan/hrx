import { useState, useRef } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useLocation, Link } from "wouter";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { Button } from "@/components/ui/button";
import {
  Form,
  FormControl,
  FormField,
  FormItem,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { useToast } from "@/hooks/use-toast";

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
      const errorMessage = 
        error instanceof Error ? error.message : "Invalid email or password";
      toast({
        title: "Login Failed",
        description: errorMessage,
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
    form.setValue("email", "toole.brendan@gmail.com");
    form.setValue("password", "Yankees1!");
    
    // Show loading state
    setIsLoading(true);
    
    try {
      // Perform actual login with test credentials
      await login("toole.brendan@gmail.com", "Yankees1!");
      console.log("✅ Dev login successful via API!");
      
      toast({
        title: "🔧 Dev Login Successful",
        description: "Logged in as Brendan Toole",
      });
      
      navigate("/dashboard");
    } catch (error) {
      console.error("❌ Dev login failed:", error);
      
      // More specific error handling
      const errorMessage = error instanceof Error ? error.message : "Unknown error";
      
      toast({
        title: "🔧 Dev Login Failed",
        description: `Dev credentials failed: ${errorMessage}`,
        variant: "destructive",
      });
      
      // Reset form if dev login fails
      form.setValue("email", "");
      form.setValue("password", "");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#FAFAFA] px-4">
      <div className="w-full max-w-[375px]">
        {/* Logo section */}
        <div className="text-center mb-10">
          <div 
            className="relative inline-block cursor-pointer"
            onClick={handleLogoTap}
          >
            <img 
              src="/hr_logo4.png" 
              alt="HandReceipt Logo" 
              className="h-[200px] w-auto mx-auto"
            />
            {/* Dev login progress indicator */}
            {logoTapCount > 0 && logoTapCount < 5 && (
              <div className="absolute bottom-5 left-1/2 transform -translate-x-1/2 flex gap-1">
                {[...Array(5)].map((_, index) => (
                  <div
                    key={index}
                    className={`w-1.5 h-1.5 rounded-full ${
                      index < logoTapCount ? 'bg-black' : 'bg-[#E0E0E0]'
                    }`}
                  />
                ))}
              </div>
            )}
          </div>
          <p className="text-[#4A4A4A] text-base font-normal -mt-6">
            Property Management System
          </p>
        </div>

        {/* Main content */}
        <div className="px-12">
          <p className="text-[#6B6B6B] text-base mb-5">Sign in to continue</p>

          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
              <FormField
                control={form.control}
                name="email"
                render={({ field }) => (
                  <FormItem>
                    <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                      EMAIL
                    </label>
                    <FormControl>
                      <div>
                        <Input
                          placeholder="Enter your email"
                          {...field}
                          className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black placeholder:text-[#9B9B9B] focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                          style={{ boxShadow: 'none' }}
                        />
                      </div>
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
                    <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                      PASSWORD
                    </label>
                    <FormControl>
                      <div>
                        <Input
                          type="password"
                          placeholder="Enter your password"
                          {...field}
                          className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black placeholder:text-[#9B9B9B] focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                          style={{ boxShadow: 'none' }}
                        />
                      </div>
                    </FormControl>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <Button
                type="submit"
                className="w-full bg-black hover:bg-black/90 text-white font-medium py-6 rounded-md mt-6"
                disabled={isLoading}
              >
                <span className="flex items-center justify-center gap-3">
                  {isLoading ? (
                    <div className="flex gap-1">
                      {[...Array(3)].map((_, i) => (
                        <div
                          key={i}
                          className="w-1.5 h-1.5 bg-white rounded-full animate-pulse"
                          style={{ animationDelay: `${i * 0.2}s` }}
                        />
                      ))}
                    </div>
                  ) : (
                    <>
                      <span>Sign In</span>
                      <i className="fas fa-arrow-right text-sm"></i>
                    </>
                  )}
                </span>
              </Button>
            </form>
          </Form>
        </div>
      </div>
    </div>
  );
};

export default Login;
