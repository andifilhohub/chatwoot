/* global axios */
import ApiClient from './ApiClient';

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
    return axios.post(`${this.url}/create_direct_room`, {
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
    const payload = {
      message: {
        content,
        room_type: roomType,
        room_id: roomId,
      },
    };

    return axios.post(`${this.url}/send_message`, payload)
      .catch(error => {
        console.error('❌ Internal chat API error:', error);
        throw error;
      });
  }
}

export default new InternalChatAPI();
