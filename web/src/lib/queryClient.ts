import { QueryClient, QueryFunction } from '@tanstack/react-query';

type UnauthorizedBehavior = 'throw' | 'returnNull';

// Helper functions
async function throwIfResNotOk(res: Response) {
  if (!res.ok) {
    const text = (await res.text()) || res.statusText;
    throw new Error(`${res.status}: ${text}`);
  }
}

function getFullUrl(url: string): string {
  // If it's an absolute URL, return it as is
  if (url.startsWith('http')) {
    return url;
  }
  // For API calls and other relative URLs, just return as is
  return url;
}

export const getQueryFn: <T>(options: { on401: UnauthorizedBehavior; }) => QueryFunction<T> = ({ on401: unauthorizedBehavior }) => async ({ queryKey }) => {
  // Ensure URL has the correct base path
  const url = getFullUrl(queryKey[0] as string);
  const res = await fetch(url, {
    credentials: "include",
  });

  if (unauthorizedBehavior === "returnNull" && res.status === 401) {
    return null;
  }

  await throwIfResNotOk(res);
  return await res.json();
};

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      queryFn: getQueryFn({ on401: "throw" }),
      refetchInterval: 5 * 60 * 1000, // Refetch every 5 minutes
      refetchOnWindowFocus: true, // Refetch on window focus
      refetchOnReconnect: true, // Refetch when network reconnects
      staleTime: 2 * 60 * 1000, // Data is fresh for 2 minutes
      retry: 1, // Retry failed requests once
    },
    mutations: {
      retry: false,
    },
  },
});
