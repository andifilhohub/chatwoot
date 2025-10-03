import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useStore } from 'vuex';
import internalChatAPI from '../api/internalChat';

export default function useInternalChatData() {
  const store = useStore();

  // Estado reativo
  const messages = ref([]);
  const rooms = ref([]);
  const currentRoom = ref(null);
  const isLoading = ref(false);
  const isConnected = ref(false);
  const newMessage = ref('');

  // ActionCable connection
  let subscription = null;

  // Getters do store
  const currentUser = computed(() => store.getters.getCurrentUser);
  const currentAccountId = computed(() => store.getters.getCurrentAccountId);

  // Carregar salas de chat
  const loadRooms = async () => {
    try {
      isLoading.value = true;
      const response = await internalChatAPI.getRooms();
      rooms.value = response.data || [];
    } catch (error) {
      // Log de erro removido para produção
    } finally {
      isLoading.value = false;
    }
  };

  // Carregar mensagens de uma sala
  const loadMessages = async roomId => {
    try {
      isLoading.value = true;
      const response = await internalChatAPI.getMessages(roomId);
      messages.value = response.data || [];
    } catch (error) {
      // Log de erro removido para produção
    } finally {
      isLoading.value = false;
    }
  };

  // Enviar mensagem
  const sendMessage = async content => {
    if (!content.trim() || !currentRoom.value) return;

    try {
      const messageData = {
        content: content.trim(),
        room_id: currentRoom.value.id,
        user_id: currentUser.value.id,
      };

      await internalChatAPI.sendMessage(messageData);
      newMessage.value = '';

      // Adicionar mensagem localmente para feedback imediato
      const tempMessage = {
        id: Date.now(),
        content: content.trim(),
        user: currentUser.value,
        created_at: new Date().toISOString(),
        temp: true,
      };
      messages.value.push(tempMessage);
    } catch (error) {
      // Log de erro removido para produção
    }
  };

  // Criar sala direta
  const createDirectRoom = async userId => {
    try {
      const response = await internalChatAPI.createDirectRoom(userId);
      const room = response.data;

      if (room) {
        rooms.value.push(room);
        currentRoom.value = room;
        await loadMessages(room.id);
      }

      return room;
    } catch (error) {
      // Log de erro removido para produção
      return null;
    }
  };

  // Selecionar sala atual
  const selectRoom = async room => {
    currentRoom.value = room;
    await loadMessages(room.id);

    // Conectar ao ActionCable para esta sala
    if (subscription) {
      subscription.unsubscribe();
    }

    if (window.App && window.App.cable) {
      subscription = window.App.cable.subscriptions.create(
        {
          channel: 'InternalChatChannel',
          room_id: room.id,
        },
        {
          connected() {
            isConnected.value = true;
          },

          disconnected() {
            isConnected.value = false;
          },

          received(data) {
            if (data.message) {
              // Remove mensagem temporária se existir
              const tempIndex = messages.value.findIndex(
                m => m.temp && m.content === data.message.content
              );
              if (tempIndex !== -1) {
                messages.value.splice(tempIndex, 1);
              }

              // Adiciona mensagem real
              messages.value.push(data.message);
            }
          },
        }
      );
    }
  };

  // Desconectar do ActionCable
  const disconnect = () => {
    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
    }
    isConnected.value = false;
  };

  // Lifecycle
  onMounted(() => {
    loadRooms();
  });

  onUnmounted(() => {
    disconnect();
  });

  return {
    // Estado
    messages,
    rooms,
    currentRoom,
    isLoading,
    isConnected,
    newMessage,

    // Métodos
    loadRooms,
    loadMessages,
    sendMessage,
    createDirectRoom,
    selectRoom,
    disconnect,

    // Computed
    currentUser,
    currentAccountId,
  };
}
