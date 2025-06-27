import React, { useState, useEffect } from 'react';
import { Switch, Route, useLocation, Router as WouterRouter } from "wouter";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { AuthProvider } from "@/contexts/AuthContext";
import { AppProvider } from "@/contexts/AppContext";
import { NotificationProvider } from "@/contexts/NotificationContext";
import { WebSocketProvider } from "@/contexts/WebSocketContext";
import { lazyLoad } from "@/utils/lazyLoad";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import AppShell from "./components/layout/AppShell";

// Lazy load all route components for code splitting
const NotFound = lazyLoad(() => import("@/pages/not-found"));
const Dashboard = lazyLoad(() => import("./pages/Dashboard"));
const Transfers = lazyLoad(() => import("./pages/Transfers"));
const Search = lazyLoad(() => import("./pages/Search"));
const AuditLog = lazyLoad(() => import("./pages/AuditLog"));
const Settings = lazyLoad(() => import("./pages/Settings"));
const PropertyBook = lazyLoad(() => import("./pages/PropertyBook"));
const Profile = lazyLoad(() => import("./pages/Profile"));
const EditProfile = lazyLoad(() => import("./pages/EditProfile"));
const ChangePassword = lazyLoad(() => import("./pages/ChangePassword"));
const SensitiveItems = lazyLoad(() => import("./pages/SensitiveItems"));
const Documents = lazyLoad(() => import("./pages/Documents"));
const Login = lazyLoad(() => import("./pages/Login"));
const Register = lazyLoad(() => import("./pages/Register"));
const Connections = lazyLoad(() => import("./pages/Connections").then(m => ({ default: m.Connections })));
const UserManagement = lazyLoad(() => import("./pages/UserManagement"));
const CorrectionLogPage = lazyLoad(() => import('./pages/CorrectionLogPage'));
import { queryClient } from "./lib/queryClient";
import { startPeriodicSync, stopPeriodicSync, setupConnectivityListeners } from "./services/syncService";

// Define interfaces for component props with ID parameters
interface ItemPageProps {
  id?: string;
}


// Add TransfersProps to fix the TypeScript error
interface TransfersProps {
  id?: string;
}

// Make all component props have any type to fix TypeScript errors with wouter
function Router() {
  // Debug logging for mobile rendering issues
  useEffect(() => {
    console.log('[HandReceipt Debug] App mounted', {
      userAgent: navigator.userAgent,
      viewport: {
        width: window.innerWidth,
        height: window.innerHeight,
        devicePixelRatio: window.devicePixelRatio
      },
      isMobile: window.innerWidth < 768,
      url: window.location.href
    });
  }, []);

  return (
    <AppShell>
      <Switch>
        <Route path="/" component={() => <Login />} />
        <Route path="/dashboard" component={() => <Dashboard />} />
        <Route path="/search" component={() => <Search />} />
        <Route path="/transfers" component={() => <Transfers />} />
        <Route path="/property-book" component={() => <PropertyBook />} />
        <Route path="/sensitive-items" component={() => <SensitiveItems />} />
        <Route path="/network" component={() => <Connections />} />
        <Route path="/documents" component={() => <Documents />} />
        <Route path="/user-management" component={() => <UserManagement />} />
        <Route path="/audit-log" component={() => <AuditLog />} />
        <Route path="/correction-log" component={() => <CorrectionLogPage />} />
        <Route path="/settings" component={() => <Settings />} />
        <Route path="/profile" component={() => <Profile />} />
        <Route path="/profile/edit" component={() => <EditProfile />} />
        <Route path="/change-password" component={() => <ChangePassword />} />
        <Route path="/login" component={() => <Login />} />
        <Route path="/register" component={() => <Register />} />
        <Route component={() => <NotFound />} />
      </Switch>
    </AppShell>
  );
}

const App: React.FC = () => {
  useEffect(() => {
    // Start periodic sync and set up connectivity listeners
    startPeriodicSync();
    const cleanupConnectivity = setupConnectivityListeners();

    // Cleanup on unmount
    return () => {
      stopPeriodicSync();
      cleanupConnectivity();
    };
  }, []);

  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>
          <AppProvider>
            <NotificationProvider>
              <WebSocketProvider>
                <WouterRouter>
                  <Router />
                </WouterRouter>
                <Toaster />
              </WebSocketProvider>
            </NotificationProvider>
          </AppProvider>
        </AuthProvider>
      </QueryClientProvider>
    </ErrorBoundary>
  );
};

export default App;
