import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
// Import Workbox for registration logic
// Use workbox-window for easier registration and update handling
import { Workbox } from 'workbox-window';
// Import the specific lifecycle event types
import type { WorkboxLifecycleEvent, WorkboxLifecycleWaitingEvent } from 'workbox-window';
// Import seedDatabase function to initialize data
import { seedDatabase } from './lib/seedDB'; // Fix WebSocket connection
// This injects the proper port into window.__vite_ws_port
(function injectWebSocketPort() { // Get the current port from the URL const currentPort = window.location.port || '5001'; // Create a global variable that Vite's client will use // @ts-ignore window.__vite_ws_port = currentPort; console.log(`WebSocket port set to: ${currentPort}`); // Monkey patch WebSocket to ensure it uses the correct port const originalWebSocket = window.WebSocket; // @ts-ignore window.WebSocket = function(url, protocols) { if (url.includes('localhost:undefined')) { url = url.replace('localhost:undefined', `localhost:${currentPort}`); console.log(`Fixed WebSocket URL: ${url}`); } return new originalWebSocket(url, protocols); }; // Copy properties from the original WebSocket for (const prop in originalWebSocket) { // @ts-ignore if (originalWebSocket.hasOwnProperty(prop)) { // @ts-ignore window.WebSocket[prop] = originalWebSocket[prop]; } } // @ts-ignore window.WebSocket.prototype = originalWebSocket.prototype;
})(); // Seed the database with initial data
seedDatabase().then(() => { console.log('Database seeding completed successfully');
}).catch(error => { console.error('Database seeding failed:', error);
}); // Create a valid DOM element to mount the app
const rootElement = document.getElementById('root');
if (!rootElement) { const newRoot = document.createElement('div'); newRoot.id = 'root'; document.body.appendChild(newRoot);
} // Ensure we have a valid root before creating the React root
ReactDOM.createRoot(document.getElementById('root')!).render( <React.StrictMode> <App /> </React.StrictMode>,
) // --- Service Worker Registration ---
if ('serviceWorker' in navigator) { // Get the current origin and path for correct registration const basePath = '/'; // Use Workbox window library for registration with correct base path const wb = new Workbox(`${basePath}service-worker.js`, { scope: basePath }); // Use the specific type for the 'waiting' listener wb.addEventListener('waiting', (event: WorkboxLifecycleWaitingEvent) => { console.log( `A new service worker has installed, but it's waiting to activate. ` + `New or updated content is available.` ); // Optional: Show a prompt to the user asking them to refresh // Example: if (confirm('New app version available. Reload to update?')) { // wb.messageSkipWaiting(); // } // For smoother updates during development or testing, skip waiting automatically // Remove this for production if you want manual user refresh prompt console.log('Service Worker: Automatically skipping waiting.'); wb.messageSkipWaiting(); }); // Use the specific type for the 'activated' listener wb.addEventListener('activated', (event: WorkboxLifecycleEvent) => { // The 'isUpdate' property should be available on the event object for 'activated' if (!event.isUpdate) { console.log('Service worker activated for the first time!'); } else { console.log('Service worker updated and activated.'); // Optional: Reload the page to ensure the user gets the latest assets // window.location.reload(); } }); // Register the service worker wb.register() .then((registration: ServiceWorkerRegistration | undefined) => { if (registration) { console.log('Service Worker registered with scope:', registration.scope); } else { console.log('Service Worker registration returned undefined.'); } }) .catch((error: Error) => { console.error('Service Worker registration failed:', error); }); } else { console.log('Service Worker API not supported in this browser.');
}
// --- End Service Worker Registration ---
