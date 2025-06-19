import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import themePlugin from "@replit/vite-plugin-shadcn-theme-json";
import path from "path";
import runtimeErrorOverlay from "@replit/vite-plugin-runtime-error-modal";

// Use process.cwd() instead of import.meta for compatibility
const __dirname = process.cwd();

export default defineConfig({
  plugins: [
    react(),
    runtimeErrorOverlay(),
    themePlugin(),
    ...(process.env.NODE_ENV !== "production" &&
    process.env.REPL_ID !== undefined
      ? [
          await import("@replit/vite-plugin-cartographer").then((m) =>
            m.cartographer(),
          ),
        ]
      : []),
  ],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
      "@shared": path.resolve(__dirname, "shared"),
    },
  },
  root: __dirname,
  build: {
    outDir: path.resolve(__dirname, "dist/public"),
    emptyOutDir: true,
    target: 'esnext',
  },
  define: {
    // Define environment variables for build
    __API_URL__: JSON.stringify(process.env.VITE_API_URL || 'http://localhost:8080'),
    __APP_ENVIRONMENT__: JSON.stringify(process.env.VITE_APP_ENVIRONMENT || 'development'),
  },
  server: {
    fs: {
      strict: false,
      allow: ['.', '..', '../..', '/Users/brendantoole/HR_30MAR', '/Users/brendantoole/HR_30MAR/frontend_defense'],
    },
    cors: true,
    port: 5001,
    strictPort: false,
    hmr: {
      port: 5001,
      host: 'localhost'
    },
    headers: {
      'Access-Control-Allow-Origin': '*',
    },
    watch: {
      usePolling: true,
    },
    proxy: {
      // Proxy API requests to backend
      '/api': {
        target: 'http://localhost:8080',
        changeOrigin: true,
        secure: false,
        rewrite: (path) => path, // Keep the path as is
        configure: (proxy, options) => {
          proxy.on('proxyReq', (proxyReq, req, res) => {
            // Log proxy requests for debugging
            if (req.method && req.url && options.target) {
              console.log('Proxying:', req.method, req.url, '->', options.target + req.url);
            }
            // Forward cookies from the client
            if (req.headers.cookie) {
              proxyReq.setHeader('Cookie', req.headers.cookie);
            }
          });
          proxy.on('proxyRes', (proxyRes, req, res) => {
            // Handle Set-Cookie headers
            const setCookieHeader = proxyRes.headers['set-cookie'];
            if (setCookieHeader) {
              // Modify cookies to work with localhost
              const modifiedCookies = setCookieHeader.map(cookie => {
                return cookie
                  .replace(/Domain=[^;]+;?/gi, '') // Remove domain restriction
                  .replace(/Secure;?/gi, '') // Remove secure flag for localhost
                  .replace(/SameSite=None/gi, 'SameSite=Lax'); // Change SameSite
              });
              proxyRes.headers['set-cookie'] = modifiedCookies;
            }
          });
        }
      }
    }
  },
});
