/* global axios */
import ApiClient from './ApiClient';

class ScheduledMessagesAPI extends ApiClient {
  constructor() {
    super('scheduled_messages', { accountScoped: true });
  }

  list(params = {}) {
    return axios.get(this.url, { params });
  }

  update(id, payload) {
    return axios.put(`${this.url}/${id}`, {
      scheduled_message: payload,
    });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new ScheduledMessagesAPI();
