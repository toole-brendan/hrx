import { BASE_PATH } from './queryClient';

// Helper to get the correct path with the base path included
export function getNavigationPath(path: string): string {
  // If it's an absolute URL or already includes the base path, return it as is
  if (path.startsWith('http') || path.includes(BASE_PATH)) {
    return path;
  }
  
  // Format the path to ensure it starts with /
  const formattedPath = path.startsWith('/') ? path : `/${path}`;
  
  // Return the path with base path
  return `${BASE_PATH}${formattedPath}`;
}

// Helper to get the raw path without the base path
export function getPathWithoutBase(path: string): string {
  if (path.startsWith(BASE_PATH)) {
    return path.substring(BASE_PATH.length) || '/';
  }
  return path;
}

// Helper to handle links in the application
export function handleNavigation(event: React.MouseEvent<HTMLAnchorElement>, path: string) {
  event.preventDefault();
  window.history.pushState(null, '', getNavigationPath(path));
} 