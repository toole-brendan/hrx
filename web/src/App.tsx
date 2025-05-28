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
import QRManagement from "./pages/QRManagement";
import Reports from "./pages/Reports";
import Login from "./pages/Login";
import UserManagement from "./pages/UserManagement";
import CorrectionLogPage from './pages/CorrectionLogPage';
import LedgerVerificationPage from './pages/LedgerVerificationPage';
import { queryClient } from "./lib/queryClient";
import { BASE_PATH } from "./lib/queryClient";
import { saveInventoryItemsToDB, getInventoryItemsFromDB } from "./lib/idb";
import { inventory as mockInventory } from "./lib/mockData";

// Define interfaces for component props with ID parameters
interface ItemPageProps {
  id?: string;
}

interface ReportPageProps {
  type?: string;
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
  // Base path for all routes
  const basePath = BASE_PATH;
  
  return (
    <AppShell>
      <Switch>
        <Route path={`${basePath}`} component={() => <Dashboard />} />
        <Route path={`${basePath}/`} component={() => <Dashboard />} />
        <Route path={`${basePath}/dashboard`} component={() => <Dashboard />} />
        <Route path={`${basePath}/transfers`} component={() => <Transfers />} />
        <Route path={`${basePath}/transfers/:id`}>
          {(params) => <Transfers id={params.id} />}
        </Route>
        <Route path={`${basePath}/property-book`} component={() => <PropertyBook />} />
        <Route path={`${basePath}/property-book/:id`}>
          {(params) => <PropertyBook id={params.id} />}
        </Route>
        <Route path={`${basePath}/sensitive-items`} component={() => <SensitiveItems />} />
        <Route path={`${basePath}/sensitive-items/:id`}>
          {(params) => <SensitiveItems id={params.id} />}
        </Route>
        <Route path={`${basePath}/maintenance`} component={() => <Maintenance />} />
        <Route path={`${basePath}/maintenance/:id`}>
          {(params) => <Maintenance id={params.id} />}
        </Route>
        <Route path={`${basePath}/qr-management`} component={() => <QRManagement />} />
        <Route path={`${basePath}/qr-management/:code`}>
          {(params) => <QRManagement code={params.code} />}
        </Route>
        <Route path={`${basePath}/reports`} component={() => <Reports />} />
        <Route path={`${basePath}/reports/:type`}>
          {(params) => <Reports type={params.type} />}
        </Route>
        <Route path={`${basePath}/audit-log`} component={() => <AuditLog />} />
        <Route path={`${basePath}/correction-log`} component={() => <CorrectionLogPage />} />
        <Route path={`${basePath}/ledger-verification`} component={() => <LedgerVerificationPage />} />
        <Route path={`${basePath}/settings`} component={() => <Settings />} />
        <Route path={`${basePath}/profile`} component={() => <Profile />} />
        <Route path={`${basePath}/user-management`} component={() => <UserManagement />} />
        <Route path={`${basePath}/login`} component={() => <Login />} />
        <Route path={`${basePath}/*`} component={() => <NotFound />} />
      </Switch>
    </AppShell>
  );
}

const App: React.FC = () => {
  // Handle initial redirection if needed
  useEffect(() => {
    const path = window.location.pathname;
    // If we're at the root path, redirect to the defense path
    if (path === '/' || path === '') {
      window.history.replaceState(null, "", `${BASE_PATH}`);
    }
  }, []);

  // Create a redirection effect for the base path
  useEffect(() => {
    // Use a 'click' event listener to intercept link clicks and add the base path
    const handleClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement;
      const link = target.closest('a');
      if (link && link.href && link.href.startsWith(window.location.origin) && !link.href.includes(BASE_PATH)) {
        e.preventDefault();
        // Extract the path and add the base path
        const url = new URL(link.href);
        const path = url.pathname === '/' ? BASE_PATH : `${BASE_PATH}${url.pathname}`;
        window.history.pushState(null, "", path + url.search + url.hash);
      }
    };

    document.addEventListener('click', handleClick);
    return () => document.removeEventListener('click', handleClick);
  }, []);

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
