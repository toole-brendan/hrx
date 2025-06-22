import { lazy, Suspense, ComponentType } from 'react';
import { MinimalLoadingView } from '@/components/ios';

// Helper function to create lazy loaded components with fallback
export function lazyLoad<T extends ComponentType<any>>(
  factory: () => Promise<{ default: T }>,
  fallback?: React.ReactNode
) {
  const LazyComponent = lazy(factory);

  return (props: React.ComponentProps<T>) => (
    <Suspense fallback={fallback || <MinimalLoadingView />}>
      <LazyComponent {...props} />
    </Suspense>
  );
}