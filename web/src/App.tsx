import React, { useState, useEffect } from 'react';
import { Switch, Route, useLocation, Router as WouterRouter } from "wouter";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { AuthProvider } from "@/contexts/AuthContext";
import { AppProvider } from "@/contexts/AppContext";
import { NotificationProvider } from "@/contexts/NotificationContext";
import NotFound from "@/pages/not-found";
import AppShell from "./components/layout/AppShell";
import Dashboard from "./pages/Dashboard";
import Transfers from "./pages/Transfers";
import AuditLog from "./pages/AuditLog";
import Settings from "./pages/Settings";
import PropertyBook from "./pages/PropertyBook";
import Profile from "./pages/Profile";
import SensitiveItems from "./pages/SensitiveItems";
import Maintenance from "./pages/Maintenance";
import Documents from "./pages/Documents";
import Login from "./pages/Login";
import Register from "./pages/Register";
import UserManagement from "./pages/UserManagement";
import CorrectionLogPage from './pages/CorrectionLogPage';
import LedgerVerificationPage from './pages/LedgerVerificationPage';
import { queryClient } from "./lib/queryClient";

// Define interfaces for component props with ID parameters
interface ItemPageProps {
  id?: string;
}

interface QRPageProps {
  code?: string;
}

// Add TransfersProps to fix the TypeScript error
interface TransfersProps {
  id?: string;
}

// Make all component props have any type to fix TypeScript errors with wouter
function Router() {
  return (
    <AppShell>
      <Switch>
        <Route path="/" component={() => <Login />} />
        <Route path="/dashboard" component={() => <Dashboard />} />
        <Route path="/transfers" component={() => <Transfers />} />
        <Route path="/transfers/:id">
          {(params) => <Transfers id={params.id} />}
        </Route>
        <Route path="/property-book" component={() => <PropertyBook />} />
        <Route path="/property-book/:id">
          {(params) => <PropertyBook id={params.id} />}
        </Route>
        <Route path="/sensitive-items" component={() => <SensitiveItems />} />
        <Route path="/sensitive-items/:id">
          {(params) => <SensitiveItems id={params.id} />}
        </Route>
        <Route path="/maintenance" component={() => <Maintenance />} />
        <Route path="/maintenance/:id">
          {(params) => <Maintenance id={params.id} />}
        </Route>
        <Route path="/documents" component={() => <Documents />} />
        <Route path="/user-management" component={() => <UserManagement />} />
        <Route path="/audit-log" component={() => <AuditLog />} />
        <Route path="/correction-log" component={() => <CorrectionLogPage />} />
        <Route path="/ledger-verification" component={() => <LedgerVerificationPage />} />
        <Route path="/settings" component={() => <Settings />} />
        <Route path="/profile" component={() => <Profile />} />
        <Route path="/login" component={() => <Login />} />
        <Route path="/register" component={() => <Register />} />
        <Route component={() => <NotFound />} />
      </Switch>
    </AppShell>
  );
}

const App: React.FC = () => {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <AppProvider>
          <NotificationProvider>
            <WouterRouter>
              <Router />
            </WouterRouter>
            <Toaster />
          </NotificationProvider>
        </AppProvider>
      </AuthProvider>
    </QueryClientProvider>
  );
}

export default App;
