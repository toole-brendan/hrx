class TokenService {
  private accessToken: string | null = null;
  private refreshTimer: NodeJS.Timeout | null = null;
  private readonly TOKEN_KEY = 'handreceipt_access_token';
  private readonly TOKEN_EXPIRY_KEY = 'handreceipt_token_expiry';

  constructor() {
    // Load token from localStorage on initialization
    this.loadTokenFromStorage();
  }

  private loadTokenFromStorage() {
    const token = localStorage.getItem(this.TOKEN_KEY);
    const expiry = localStorage.getItem(this.TOKEN_EXPIRY_KEY);
    
    if (token && expiry) {
      const expiryTime = parseInt(expiry, 10);
      const now = Date.now();
      
      if (expiryTime > now) {
        // Token is still valid
        this.accessToken = token;
        const expiresIn = Math.floor((expiryTime - now) / 1000);
        this.scheduleRefresh(expiresIn);
      } else {
        // Token expired, clear it
        this.clearTokens();
      }
    }
  }

  setAccessToken(token: string, expiresIn: number) {
    this.accessToken = token;
    
    // Store in localStorage
    localStorage.setItem(this.TOKEN_KEY, token);
    const expiryTime = Date.now() + (expiresIn * 1000);
    localStorage.setItem(this.TOKEN_EXPIRY_KEY, expiryTime.toString());
    
    this.scheduleRefresh(expiresIn);
  }

  getAccessToken(): string | null {
    return this.accessToken;
  }

  clearTokens() {
    this.accessToken = null;
    
    // Clear from localStorage
    localStorage.removeItem(this.TOKEN_KEY);
    localStorage.removeItem(this.TOKEN_EXPIRY_KEY);
    
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
      this.refreshTimer = null;
    }
  }

  private scheduleRefresh(expiresIn: number) {
    if (this.refreshTimer) {
      clearTimeout(this.refreshTimer);
    }

    // Refresh 1 minute before expiry
    const refreshIn = (expiresIn - 60) * 1000;
    if (refreshIn > 0) {
      this.refreshTimer = setTimeout(() => {
        this.refreshAccessToken();
      }, refreshIn);
    }
  }

  private async refreshAccessToken() {
    // This will be called from AuthContext
    window.dispatchEvent(new Event('token-refresh-needed'));
  }

  getAuthHeaders(): HeadersInit {
    if (!this.accessToken) {
      return {};
    }
    return {
      Authorization: `Bearer ${this.accessToken}`,
    };
  }
}

export default new TokenService();