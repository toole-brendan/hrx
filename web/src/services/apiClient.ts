import tokenService from './tokenService';

const API_BASE_URL = (import.meta.env.VITE_API_URL || 'http://localhost:8080') + '/api';

interface FetchOptions extends RequestInit {
  skipAuth?: boolean;
}

class ApiClient {
  async fetch<T = unknown>(
    endpoint: string,
    options: FetchOptions = {}
  ): Promise<T> {
    const { skipAuth = false, ...fetchOptions } = options;
    
    const url = endpoint.startsWith('http') ? endpoint : `${API_BASE_URL}${endpoint}`;
    
    const headers: HeadersInit = {
      ...(!skipAuth ? tokenService.getAuthHeaders() : {}),
      ...(options.body && !(options.body instanceof FormData) ? { 'Content-Type': 'application/json' } : {}),
      ...options.headers,
    };

    const response = await fetch(url, {
      ...fetchOptions,
      headers,
      credentials: 'include', // Keep for refresh token
    });

    // Handle 401 - try refresh
    if (response.status === 401 && !skipAuth) {
      console.log('[ApiClient] Got 401, attempting token refresh...');
      
      await new Promise<void>((resolve) => {
        const handler = () => {
          window.removeEventListener('token-refreshed', handler);
          resolve();
        };
        window.addEventListener('token-refreshed', handler);
        window.dispatchEvent(new Event('token-refresh-needed'));
        
        // Timeout after 5 seconds
        setTimeout(() => {
          window.removeEventListener('token-refreshed', handler);
          resolve();
        }, 5000);
      });

      // Retry request with new token
      const retryResponse = await fetch(url, {
        ...fetchOptions,
        headers: {
          ...tokenService.getAuthHeaders(),
          ...(options.body && !(options.body instanceof FormData) ? { 'Content-Type': 'application/json' } : {}),
          ...options.headers,
        },
        credentials: 'include',
      });

      if (!retryResponse.ok) {
        const error = await this.handleErrorResponse(retryResponse);
        throw new Error(error.message || `Request failed with status ${retryResponse.status}`);
      }

      return this.handleResponse<T>(retryResponse);
    }

    if (!response.ok) {
      const error = await this.handleErrorResponse(response);
      throw new Error(error.message || `Request failed with status ${response.status}`);
    }

    return this.handleResponse<T>(response);
  }

  private async handleResponse<T>(response: Response): Promise<T> {
    const text = await response.text();
    if (!text) {
      return null as T;
    }
    
    try {
      return JSON.parse(text);
    } catch (e) {
      console.error('Failed to parse JSON response:', text);
      throw new Error('Invalid JSON response from server');
    }
  }

  private async handleErrorResponse(response: Response): Promise<{ message: string; error?: string }> {
    try {
      const errorData = await response.json();
      return {
        message: errorData.error || errorData.message || `Request failed with status ${response.status}`,
        error: errorData.error,
      };
    } catch (e) {
      try {
        const text = await response.text();
        return { message: text || response.statusText };
      } catch (textErr) {
        return { message: response.statusText || `Request failed with status ${response.status}` };
      }
    }
  }
}

export default new ApiClient();