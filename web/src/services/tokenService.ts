class TokenService {
  private accessToken: string | null = null;
  private refreshTimer: NodeJS.Timeout | null = null;

  setAccessToken(token: string, expiresIn: number) {
    this.accessToken = token;
    this.scheduleRefresh(expiresIn);
  }

  getAccessToken(): string | null {
    return this.accessToken;
  }

  clearTokens() {
    this.accessToken = null;
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