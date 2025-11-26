/* global axios */
import ApiClient from './ApiClient';

class IntegrahubProductsAPI extends ApiClient {
  constructor() {
    // accountScoped so baseUrl becomes /api/v1/accounts/:id/integrahub_products
    super('integrahub_products', { accountScoped: true });
  }

  // params: { q, limit, page }
  search(params = {}) {
    const query = new URLSearchParams();
    Object.keys(params || {}).forEach((k) => {
      if (params[k] !== undefined && params[k] !== null && params[k] !== '') {
        query.append(k, params[k]);
      }
    });

    const url = query.toString() ? `${this.url}?${query.toString()}` : this.url;
    // Prefer the app-configured axios instance (set by APIHelper -> window.axios)
    if (typeof window !== 'undefined' && window.axios) {
      return window.axios.get(url);
    }
    // Fallback to global/module axios for tests or non-browser environments
    return axios.get(url);
  }
}

export default new IntegrahubProductsAPI();
