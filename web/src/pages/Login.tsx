import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useLocation, Link } from "wouter";
import LissajousCurve from "@/components/LissajousCurve";
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
import { useQueryClient } from "@tanstack/react-query";

const loginSchema = z.object({
  email: z.string().min(1, "Email is required").email("Invalid email address"),
  password: z.string().min(1, "Password is required"),
});

type LoginFormValues = z.infer<typeof loginSchema>;

const Login: React.FC = () => {
  const { login } = useAuth();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const [isLoading, setIsLoading] = useState(false);
  const [, navigate] = useLocation();

  // Logo tap feature state - DISABLED
  // const [logoTapCount, setLogoTapCount] = useState(0);
  // const lastTapTimeRef = useRef<Date>(new Date());

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
      
      // Wait longer to ensure auth state is fully propagated
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Now invalidate all queries to ensure they refetch with new auth
      await queryClient.invalidateQueries();
      
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

  // Handle logo tap for hidden dev login - DISABLED
  // const handleLogoTap = () => {
  //   const now = new Date();
  //   const timeSinceLastTap = now.getTime() - lastTapTimeRef.current.getTime();

  //   // Reset counter if more than 2 seconds since last tap
  //   if (timeSinceLastTap > 2000) {
  //     setLogoTapCount(1);
  //     console.log("Dev login: Starting new tap sequence");
  //   } else {
  //     setLogoTapCount(prev => prev + 1);
  //     console.log(`Dev login: Tap ${logoTapCount + 1} of 5`);
  //   }

  //   lastTapTimeRef.current = now;

  //   // Trigger dev login after 5 taps
  //   if (logoTapCount + 1 >= 5) {
  //     performDevLogin();
  //     setLogoTapCount(0);
  //   }
  // };

  // // Perform development login bypass - DISABLED
  // const performDevLogin = async () => {
  //   console.log("🔧 DEV LOGIN ACTIVATED! Using test credentials...");
    
  //   // Use test credentials to actually authenticate with the backend
  //   form.setValue("email", "toole.brendan@gmail.com");
  //   form.setValue("password", "Yankees1!");
    
  //   // Show loading state
  //   setIsLoading(true);
    
  //   try {
  //     // Perform actual login with test credentials
  //     await login("toole.brendan@gmail.com", "Yankees1!");
  //     console.log("✅ Dev login successful via API!");
      
  //     toast({
  //       title: "🔧 Dev Login Successful",
  //       description: "Logged in as Brendan Toole",
  //     });
      
  //     navigate("/dashboard");
  //   } catch (error) {
  //     console.error("❌ Dev login failed:", error);
      
  //     // More specific error handling
  //     const errorMessage = error instanceof Error ? error.message : "Unknown error";
      
  //     toast({
  //       title: "🔧 Dev Login Failed",
  //       description: `Dev credentials failed: ${errorMessage}`,
  //       variant: "destructive",
  //     });
      
  //     // Reset form if dev login fails
  //     form.setValue("email", "");
  //     form.setValue("password", "");
  //   } finally {
  //     setIsLoading(false);
  //   }
  // };

  // Handle demo login
  const handleDemoLogin = async () => {
    console.log("[Login.handleDemoLogin] Demo login initiated...");
    
    // Set demo credentials
    form.setValue("email", "john.smith@example.mil");
    form.setValue("password", "password123");
    
    // Show loading state
    setIsLoading(true);
    
    try {
      console.log("[Login.handleDemoLogin] Calling login function...");
      // Perform login with demo credentials
      await login("john.smith@example.mil", "password123");
      console.log("[Login.handleDemoLogin] ✅ Login function completed successfully!");
      
      console.log("[Login.handleDemoLogin] Waiting 1000ms for auth state to propagate...");
      // Wait longer to ensure auth state is fully propagated
      await new Promise(resolve => setTimeout(resolve, 1000));
      console.log("[Login.handleDemoLogin] Wait complete, invalidating queries...");
      
      // Now invalidate all queries to ensure they refetch with new auth
      await queryClient.invalidateQueries();
      console.log("[Login.handleDemoLogin] Queries invalidated, showing toast...");
      
      toast({
        title: "Welcome to HandReceipt Demo",
        description: "Logged in as SSG John Smith",
      });
      
      console.log("[Login.handleDemoLogin] Navigating to dashboard...");
      navigate("/dashboard");
    } catch (error) {
      console.error("❌ Demo login failed:", error);
      
      const errorMessage = error instanceof Error ? error.message : "Demo login failed";
      
      toast({
        title: "Demo Login Failed",
        description: errorMessage,
        variant: "destructive",
      });
      
      // Reset form if demo login fails
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
          <div className="relative inline-block">
            <LissajousCurve />
          </div>
          <h1 className="text-[#333333] text-2xl font-['Michroma'] mt-2 mb-1 tracking-wider">
            HANDRECEIPT
          </h1>
          <p className="text-[#4A4A4A] text-base font-normal">
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
                className="w-full bg-blue-500 text-white hover:bg-blue-600 rounded-md px-4 py-2 text-sm font-medium uppercase transition-all duration-200 border-0 mt-6"
                disabled={isLoading}
              >
                <span className="flex items-center justify-center gap-2">
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
                      <i className="fas fa-sign-in-alt text-sm"></i>
                      <span>SIGN IN</span>
                    </>
                  )}
                </span>
              </Button>
            </form>
          </Form>

          {/* Demo Login Button */}
          <button
            onClick={handleDemoLogin}
            className="w-full text-sm font-medium text-ios-accent bg-transparent border border-ios-accent hover:bg-blue-500 hover:border-blue-500 hover:text-white px-4 py-2 uppercase transition-all duration-200 rounded-md [&:hover_svg]:text-white mt-3 flex items-center justify-center"
            disabled={isLoading}
          >
            <span className="flex items-center justify-center gap-2">
              {isLoading ? (
                <div className="flex gap-1">
                  {[...Array(3)].map((_, i) => (
                    <div
                      key={i}
                      className="w-1.5 h-1.5 bg-current rounded-full animate-pulse"
                      style={{ animationDelay: `${i * 0.2}s` }}
                    />
                  ))}
                </div>
              ) : (
                <>
                  <i className="fas fa-user-astronaut text-sm"></i>
                  <span>DEMO</span>
                </>
              )}
            </span>
          </button>
        </div>
      </div>
    </div>
  );
};

export default Login;
