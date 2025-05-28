// client/public/service-worker.js

// Import Workbox libraries (adjust path based on build output or use CDN)
// For development, CDN might be easier initially. For build, use imports.
// Assuming workbox-sw is available globally via CDN for now, or will be injected by build.

// Check if Workbox loaded
if (typeof importScripts === 'function') {
    // Use importScripts to load Workbox libraries from CDN (easier for initial setup)
    importScripts('https://storage.googleapis.com/workbox-cdn/releases/7.0.0/workbox-sw.js');
    console.log('Workbox libraries loaded via importScripts.');
} else {
    console.error('importScripts is not available. Workbox could not be loaded.');
    // Consider alternative loading or error handling
}


// Set up basic Workbox configuration
if (self.workbox) {
    console.log(`Workbox ${self.workbox.version} is loaded `);

    // Optional: Enable debug logging during development
    self.workbox.setConfig({ debug: true }); // Set to false for production

    // --- Precaching --- 
    // This list will be populated by the build process (e.g., Vite PWA plugin)
    // self.__WB_MANIFEST is the default placeholder Workbox uses.
    const precacheManifest = self.__WB_MANIFEST || [];
    if (precacheManifest.length > 0) {
       console.log('Precaching manifest found:', precacheManifest);
       self.workbox.precaching.precacheAndRoute(precacheManifest);
    } else {
       console.warn('Workbox precaching manifest is empty. App shell might not be cached effectively.');
       // Fallback: Cache the main entry points if manifest is missing (less efficient)
       self.workbox.precaching.precacheAndRoute([
         { url: '/index.html', revision: null },
         { url: '/src/main.tsx', revision: null },
         // Add other essential files manually if needed
       ]);
    }

    // Clean up old caches
    self.workbox.precaching.cleanupOutdatedCaches();

    // --- Runtime Caching --- 

    // Cache Google Fonts
    self.workbox.routing.registerRoute(
        ({ url }) => url.origin === 'https://fonts.googleapis.com' || url.origin === 'https://fonts.gstatic.com',
        new self.workbox.strategies.StaleWhileRevalidate({
            cacheName: 'google-fonts',
            plugins: [
                new self.workbox.expiration.ExpirationPlugin({ maxEntries: 30, maxAgeSeconds: 60 * 60 * 24 * 365 }), // Cache for a year
            ],
        })
    );

    // Cache application images (adjust path/origin if necessary)
    self.workbox.routing.registerRoute(
        ({ request }) => request.destination === 'image',
        new self.workbox.strategies.CacheFirst({
            cacheName: 'images',
            plugins: [
                new self.workbox.expiration.ExpirationPlugin({ maxEntries: 60, maxAgeSeconds: 30 * 24 * 60 * 60 }), // Cache for 30 days
            ],
        })
    );

    // Special route for node_modules filesystem access
    self.workbox.routing.registerRoute(
        ({ url }) => url.pathname.includes('/@fs/') && url.pathname.includes('/node_modules/'),
        new self.workbox.strategies.NetworkFirst({
            cacheName: 'node-modules',
            plugins: [
                new self.workbox.expiration.ExpirationPlugin({ maxEntries: 200, maxAgeSeconds: 60 * 60 * 24 }), // Cache for a day
            ],
        })
    );

    // Cache CSS and JavaScript files (App Shell handled by precaching)
    // Use StaleWhileRevalidate for potentially dynamic JS/CSS chunks not in precache
    self.workbox.routing.registerRoute(
        ({ request }) => request.destination === 'script' || request.destination === 'style',
        new self.workbox.strategies.StaleWhileRevalidate({
            cacheName: 'static-resources',
        })
    );

    // --- Navigation Fallback --- 
    // Optional: If you want SPA routing to work offline, serve index.html for navigation requests
    const handler = self.workbox.precaching.createHandlerBoundToURL('/index.html');
    const navigationRoute = new self.workbox.routing.NavigationRoute(handler);
    self.workbox.routing.registerRoute(navigationRoute);


    // --- Offline Google Analytics (Optional) ---
    // self.workbox.googleAnalytics.initialize();

    // --- Additional Logic --- 
    // Add event listeners for push notifications, background sync etc. later


    // Ensure the service worker takes control immediately
    self.addEventListener('message', (event) => {
        if (event.data && event.data.type === 'SKIP_WAITING') {
            console.log('Service Worker: Skip waiting message received.');
            self.skipWaiting();
        }
    });

     console.log('Workbox service worker configured.');

} else {
    console.error('Workbox could not be loaded. Service worker not configured.');
} 