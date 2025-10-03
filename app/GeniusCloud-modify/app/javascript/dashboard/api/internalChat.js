/* global axios */
import ApiClient from '../../../../../javascript/dashboard/api/ApiClient';

class InternalChatAPI extends ApiClient {
  constructor() {
    super('internal_chat', { accountScoped: true });
  }

  // Get all available rooms
  getRooms() {
    return axios.get(`${this.url}/rooms`);
  }

  // Create a direct room with a user
  createDirectRoom(targetUserId) {
    return axios.post(`${this.url}/rooms`, {
      target_user_id: targetUserId,
    });
  }

  // Get messages for specific room type and ID
  getMessages({ roomType, roomId, page = 1, perPage = 20 }) {
    const params = new URLSearchParams({ page, per_page: perPage });

    if (roomType === 'general') {
      return axios.get(`${this.url}/messages/general?${params}`);
    }
    // For direct and team chats, use the unified endpoint
    return axios.get(`${this.url}/messages/${roomType}/${roomId}?${params}`);
  }

  // Send message via HTTP (will trigger WebSocket broadcast)
  sendMessage({ roomType, roomId, content }) {
    return axios.post(`${this.url}/send_message`, {
      message: {
        content,
        room_type: roomType,
        room_id: roomId,
      },
    });
  }
}

export default new InternalChatAPI();
