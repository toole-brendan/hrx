interface PageLayoutOptions {
    fullWidth?: boolean; /** * Container width preset: 'default' | 'narrow' | 'wide' | 'full' */
    width?: 'default' | 'narrow' | 'wide' | 'full'; /** * Base padding to apply */
    basePadding?: string; /** * Additional container classes */
    containerClasses?: string; /** * Whether to apply responsive scaling */
    responsiveScaling?: boolean; /** * Content spacing between children */
    spacing?: 'none' | 'xs' | 'sm' | 'md' | 'lg' | 'xl'; /** * Whether to apply animation effect */
    animate?: 'none' | 'fade-in' | 'slide-in';
} /** * Hook for managing page layout properties consistently across the app * with improved viewport scaling and spacing */
export declare function usePageLayout({ fullWidth, width, basePadding, containerClasses, responsiveScaling, spacing, animate, }?: PageLayoutOptions): void;
export {};
