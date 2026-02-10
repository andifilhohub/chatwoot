/* global axios */
import ApiClient from './ApiClient';

class IntegrahubSalesAPI extends ApiClient {
  constructor() {
    // accountScoped so baseUrl becomes /api/v1/accounts/:id/integrahub_sales
    super('integrahub_sales', { accountScoped: true });
  }

  create(payload) {
    if (typeof window !== 'undefined' && window.axios) {
      return window.axios.post(this.url, payload);
    }
    return axios.post(this.url, payload);
  }
}

export default new IntegrahubSalesAPI();
