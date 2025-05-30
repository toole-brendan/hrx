import { useState } from "react";
import { useLocation, Link } from "wouter";
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";
import logoImage from "@/assets/hr_logo5.png";

// Import API_BASE_URL from a shared location or define it here
const API_BASE_URL = 'https://api.handreceipt.com'; // Production API URL

const registerSchema = z.object({
  username: z.string().min(3, "Username must be at least 3 characters"),
  email: z.string().email("Invalid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  confirmPassword: z.string(),
  first_name: z.string().min(2, "First name is required"),
  last_name: z.string().min(2, "Last name is required"),
  rank: z.string().min(1, "Rank is required"),
  unit: z.string().min(1, "Unit is required"),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
});

type RegisterFormValues = z.infer<typeof registerSchema>;

const MILITARY_RANKS = [
  "PVT", "PV2", "PFC", "SPC", "CPL", "SGT", "SSG", "SFC", "MSG", "1SG", "SGM",
  "2LT", "1LT", "CPT", "MAJ", "LTC", "COL", "BG", "MG", "LTG", "GEN"
];

const Register: React.FC = () => {
  const [, setLocation] = useLocation();
  const { toast } = useToast();
  const [isLoading, setIsLoading] = useState(false);

  const form = useForm<RegisterFormValues>({
    resolver: zodResolver(registerSchema),
    defaultValues: {
      username: "",
      email: "",
      password: "",
      confirmPassword: "",
      first_name: "",
      last_name: "",
      rank: "",
      unit: "",
    },
  });

  const onSubmit = async (data: RegisterFormValues) => {
    setIsLoading(true);
    try {
      const response = await fetch(`${API_BASE_URL}/api/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: data.username,
          email: data.email,
          password: data.password,
          first_name: data.first_name,
          last_name: data.last_name,
          rank: data.rank,
          unit: data.unit,
          role: "user"
        }),
        credentials: 'include',
      });

      if (response.ok) {
        toast({
          title: "Registration Successful",
          description: "Your account has been created. Please log in.",
        });
        setLocation('/login');
      } else {
        const error = await response.json();
        throw new Error(error.message || 'Registration failed');
      }
    } catch (error: any) {
      toast({
        title: "Registration Failed",
        description: error.message || "An error occurred during registration",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-black px-4 pb-4 pt-2">
      <div className="w-full max-w-lg">
        <div className="text-center mb-0">
          <div className="flex justify-center mb-4">
            <img 
              src={logoImage} 
              alt="HandReceipt Logo" 
              className="h-96 w-auto select-none"
            />
          </div>
        </div>
        
        <Card className="bg-card border-gray-800" style={{ fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', Arial, sans-serif" }}>
          <CardHeader>
            <CardTitle className="text-white font-light tracking-wide">Register</CardTitle>
            <CardDescription className="text-gray-400 font-light">
              Create a new account to access the system
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Form {...form}>
              <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
                <div className="grid grid-cols-2 gap-4">
                  <FormField
                    control={form.control}
                    name="first_name"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-gray-200 text-xs uppercase tracking-wider font-light">First Name</FormLabel>
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
                    name="last_name"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-gray-200 text-xs uppercase tracking-wider font-light">Last Name</FormLabel>
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
                </div>

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
                  name="email"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-gray-200 text-xs uppercase tracking-wider font-light">Email</FormLabel>
                      <FormControl>
                        <Input 
                          type="email" 
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

                <div className="grid grid-cols-2 gap-4">
                  <FormField
                    control={form.control}
                    name="rank"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-gray-200 text-xs uppercase tracking-wider font-light">Rank</FormLabel>
                        <Select onValueChange={field.onChange} defaultValue={field.value}>
                          <FormControl>
                            <SelectTrigger className="bg-gray-100 border-gray-400 text-gray-900 font-light focus:outline-none focus:ring-0 focus:ring-offset-0 focus:border-gray-500">
                              <SelectValue placeholder="Select rank" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent>
                            {MILITARY_RANKS.map((rank) => (
                              <SelectItem key={rank} value={rank}>
                                {rank}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="unit"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-gray-200 text-xs uppercase tracking-wider font-light">Unit</FormLabel>
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
                </div>

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

                <FormField
                  control={form.control}
                  name="confirmPassword"
                  render={({ field }) => (
                    <FormItem>
                      <FormLabel className="text-gray-200 text-xs uppercase tracking-wider font-light">Confirm Password</FormLabel>
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
                    <i className="fas fa-user-plus mr-2"></i>
                  )}
                  Create Account
                </Button>
              </form>
            </Form>
          </CardContent>
          <CardFooter className="flex flex-col space-y-2">
            <p className="text-sm text-center text-gray-400">
              Already have an account?{" "}
              <Link to="/login" className="text-blue-500/70 hover:text-blue-500/90 hover:underline">
                Sign in
              </Link>
            </p>
          </CardFooter>
        </Card>
      </div>
    </div>
  );
};

export default Register; 