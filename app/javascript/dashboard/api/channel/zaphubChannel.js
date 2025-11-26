/* global axios */
import ApiClient from '../ApiClient';

class ZaphubChannel extends ApiClient {
  constructor() {
    super('channels/zaphub_channels', { accountScoped: true });
  }

  createSession(inboxId) {
    return axios.post(`${this.url}/${inboxId}/create_session`);
  }

  getQrCode(inboxId) {
    return axios.get(`${this.url}/${inboxId}/qr_code`);
  }

  checkStatus(inboxId) {
    return axios.get(`${this.url}/${inboxId}/status`);
  }

  disconnect(inboxId) {
    return axios.post(`${this.url}/${inboxId}/disconnect`);
  }
}

export default new ZaphubChannel();
