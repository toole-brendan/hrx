import { useState } from "react";
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
  FormMessage 
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { 
  Select, 
  SelectContent, 
  SelectItem, 
  SelectTrigger, 
  SelectValue 
} from "@/components/ui/select";
import { useToast } from "@/hooks/use-toast";

// API Configuration
const API_BASE_URL = import.meta.env.DEV 
  ? ''  // Empty string for relative paths in development
  : (import.meta.env.VITE_API_URL || 'http://localhost:8000/api');

const registerSchema = z.object({
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
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email: data.email,
          password: data.password,
          first_name: data.first_name,
          last_name: data.last_name,
          rank: data.rank,
          unit: data.unit,
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
        throw new Error(error.error || error.message || 'Registration failed');
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
    <div className="min-h-screen flex items-center justify-center bg-[#FAFAFA] px-4">
      <div className="w-full max-w-[375px]">
        {/* Logo section */}
        <div className="text-center mb-10">
          <img
            src="/hr_logo4.png"
            alt="HandReceipt Logo"
            className="h-[200px] w-auto mx-auto"
          />
          <p className="text-[#4A4A4A] text-base font-normal -mt-6">
            Property Management System
          </p>
        </div>

        {/* Main content */}
        <div className="px-12">
          <h2 className="text-black text-lg font-normal mb-5">Create Account</h2>

          <Form {...form}>
            <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <FormField
                  control={form.control}
                  name="first_name"
                  render={({ field }) => (
                    <FormItem>
                      <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                        FIRST NAME
                      </label>
                      <FormControl>
                        <Input
                          placeholder=""
                          {...field}
                          className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black placeholder:text-[#9B9B9B] focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
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
                      <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                        LAST NAME
                      </label>
                      <FormControl>
                        <Input
                          placeholder=""
                          {...field}
                          className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black placeholder:text-[#9B9B9B] focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
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
                name="email"
                render={({ field }) => (
                  <FormItem>
                    <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                      EMAIL
                    </label>
                    <FormControl>
                      <Input
                        type="email"
                        placeholder=""
                        {...field}
                        className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black placeholder:text-[#9B9B9B] focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
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
                      <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                        RANK
                      </label>
                      <Select onValueChange={field.onChange} defaultValue={field.value}>
                        <FormControl>
                          <SelectTrigger className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus:ring-0 focus:ring-offset-0 h-auto">
                            <SelectValue
                              placeholder="Select rank"
                              className="placeholder:text-[#9B9B9B]"
                            />
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
                      <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                        UNIT
                      </label>
                      <FormControl>
                        <Input
                          placeholder=""
                          {...field}
                          className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black placeholder:text-[#9B9B9B] focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
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
                    <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                      PASSWORD
                    </label>
                    <FormControl>
                      <Input
                        type="password"
                        placeholder=""
                        {...field}
                        className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black placeholder:text-[#9B9B9B] focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
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
                    <label className="text-[#6B6B6B] text-xs uppercase tracking-[0.1em] font-normal block mb-2">
                      CONFIRM PASSWORD
                    </label>
                    <FormControl>
                      <Input
                        type="password"
                        placeholder=""
                        {...field}
                        className="border-0 border-b border-[#E0E0E0] rounded-none px-0 py-2 text-base text-black placeholder:text-[#9B9B9B] focus:border-black focus:border-b-2 transition-all duration-200 bg-transparent focus-visible:ring-0 focus-visible:ring-offset-0"
                        style={{ boxShadow: 'none' }}
                      />
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
                      <span>Create Account</span>
                      <i className="fas fa-user-plus text-sm"></i>
                    </>
                  )}
                </span>
              </Button>
            </form>
          </Form>

          {/* Sign in link */}
          <div className="text-center mt-8">
            <p className="text-[#6B6B6B] text-sm">
              Already have an account?
            </p>
            <Link to="/login">
              <a className="text-[#0066CC] text-sm font-medium hover:underline">
                Sign in
              </a>
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Register; 