// Helper to get the correct path with the base path included
export function getNavigationPath(path: string): string {
  // Ensure it starts with /
  return path.startsWith('/') ? path : `/${path}`;
}

// Helper to get the raw path without the base path
export function getPathWithoutBase(path: string): string {
  return path;
} // Helper to handle links in the application
export function handleNavigation(event: React.MouseEvent<HTMLAnchorElement>, path: string) { event.preventDefault(); window.history.pushState(null, '', getNavigationPath(path));
} 