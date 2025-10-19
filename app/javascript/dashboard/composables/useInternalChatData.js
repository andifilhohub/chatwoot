import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { createConsumer } from '@rails/actioncable';
import { useStore } from 'vuex';
import internalChatAPI from '../api/internalChat';
import { useInternalChat } from './useInternalChat';

export default function useInternalChatData() {
  const store = useStore();

  // Estado reativo
  const messages = ref([]);
  const rooms = ref({});
  const currentRoom = ref(null);
  const isLoading = ref(false);
  const isConnected = ref(false);
  const messagesMeta = ref({});
  const unreadCounts = ref({});
  const dmRoomForUser = ref({}); // userId -> roomId mapping for direct chats

  // ActionCable
  let subscription = null;
  let consumer = null;
  const { isInternalChatOpen } = useInternalChat();

  const roomKey = (type, roomId) => `${String(type)}:${String(roomId ?? 'general')}`;
  const incUnread = (type, roomId) => {
    const key = roomKey(type, roomId);
    unreadCounts.value[key] = (unreadCounts.value[key] || 0) + 1;
  };
  const resetUnread = (type, roomId) => {
    const key = roomKey(type, roomId);
    if (unreadCounts.value[key]) delete unreadCounts.value[key];
  };

  // Atualiza contador total no Vuex para exibir na Sidebar
  watch(
    unreadCounts,
    val => {
      const total = Object.values(val || {}).reduce((sum, n) => sum + (Number(n) || 0), 0);
      try {
        store.commit('internalChat/SET_UNREAD_TOTAL', total);
      } catch (e) {
        // módulo pode não estar registrado em ambientes antigos
      }
    },
    { deep: true }
  );

  // Getters
  const currentUser = computed(() => store.getters.getCurrentUser);
  const currentAccountId = computed(() => store.getters.getCurrentAccountId);

  // Carregar salas
  const loadRooms = async () => {
    try {
      isLoading.value = true;
      const response = await internalChatAPI.getRooms();
      const payload = response.data || {};

      rooms.value = {
        general: payload.general || null,
        teams: Array.isArray(payload.teams) ? payload.teams : [],
        direct_messages: Array.isArray(payload.direct_messages) ? payload.direct_messages : [],
      };
    } catch (error) {
      console.error('❌ Failed to load internal chat rooms:', error);
    } finally {
      isLoading.value = false;
    }
  };

  // Carregar mensagens
  const loadMessages = async (roomType, roomId) => {
    try {
      isLoading.value = true;
      const response = await internalChatAPI.getMessages({ roomType, roomId });
      const { data: messageList = [], meta = {} } = response.data || {};
      messages.value = Array.isArray(messageList) ? messageList : [];
      messagesMeta.value = meta;
    } catch (error) {
      console.error('❌ Failed to load messages:', error);
    } finally {
      isLoading.value = false;
    }
  };

  // Adicionar/atualizar mensagem
  const upsertMessage = message => {
    if (!message || !message.id) return;
    
    if (!Array.isArray(messages.value)) {
      messages.value = [];
    }

    const index = messages.value.findIndex(m => m.id === message.id);
    if (index === -1) {
      messages.value.push(message);
    } else {
      messages.value.splice(index, 1, message);
    }
  };

  // Normalizar room
  const normalizeRoom = (room = {}) => {
    const roomType = room.room_type || room.type || 'general';
    const roomId = room.room_id || room.id;
    
    return {
      room_type: roomType,
      room_id: roomId,
      ...room
    };
  };

  // Conectar ao ActionCable
  const connect = () => {
    const user = currentUser.value;
    const accountId = currentAccountId.value;

    if (!user?.id || !user?.pubsub_token || !accountId) {
      console.warn('⚠️ Cannot connect: missing user or account');
      return;
    }

    // Evita conexões duplicadas
    if (subscription) {
      console.log('✅ Already connected');
      return;
    }

    console.log('🔌 Connecting to internal chat...');

    const cable = window.App?.cable || createConsumer('/cable');
    if (!window.App?.cable) {
      consumer = cable;
    }

    subscription = cable.subscriptions.create(
      {
        channel: 'InternalChatChannel',
        account_id: accountId,
        user_id: user.id,
        pubsub_token: user.pubsub_token,
      },
      {
        connected() {
          console.log('✅ Connected to internal chat');
          isConnected.value = true;
        },

        disconnected() {
          console.log('❌ Disconnected from internal chat');
          isConnected.value = false;
        },

        received(data) {
          console.log('📨 Received:', data);

          if (data.type === 'new_message' && data.message) {
            // Só adiciona se estiver na sala correta
            const incomingRoomType = data.chat_type;
            const incomingRoomId = data.message.room_id;

            if (currentRoom.value && isInternalChatOpen.value) {
              const currentRoomType = currentRoom.value.room_type;
              const currentRoomId = currentRoom.value.room_id;
              const matchesType = String(currentRoomType) === String(incomingRoomType);
              const matchesRoom = !currentRoomId || !incomingRoomId || String(currentRoomId) === String(incomingRoomId);

              if (matchesType && matchesRoom) {
                console.log('✅ Adding message to current room');
                upsertMessage(data.message);
                // marcar como lido para essa sala
                resetUnread(incomingRoomType, incomingRoomId);
              } else {
                // incrementar contador da sala destino
                incUnread(incomingRoomType, incomingRoomId);
              }
            } else {
              // Nenhuma sala selecionada: contar como não lida
              incUnread(incomingRoomType, incomingRoomId);
            }

            // Atualiza mapeamento de DMs para exibir badge por agente
            if (data.chat_type === 'direct') {
              const senderId = data.message.sender_id;
              const roomId = data.message.room_id;
              // Atualiza mapeamento reativo para lookup rápido de badge por agente
              if (senderId && roomId) {
                dmRoomForUser.value = { ...dmRoomForUser.value, [String(senderId)]: roomId };
              }
              // Mantém rooms.direct_messages alinhado quando existir
              if (Array.isArray(rooms.value?.direct_messages)) {
                const exists = rooms.value.direct_messages.find(d => String(d.room_id) === String(roomId));
                if (!exists) {
                  const idx = rooms.value.direct_messages.findIndex(d => String(d.id) === String(senderId));
                  const base = idx !== -1 ? rooms.value.direct_messages[idx] : { id: senderId, room_type: 'direct' };
                  const merged = { ...base, id: senderId, room_id: roomId, room_type: 'direct' };
                  if (idx === -1) {
                    rooms.value.direct_messages.push(merged);
                  } else {
                    rooms.value.direct_messages.splice(idx, 1, merged);
                  }
                }
              }
            }
          }
        },
      }
    );
  };

  // Desconectar
  const disconnect = () => {
    console.log('👋 Disconnecting from internal chat...');
    
    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
    }
    
    if (consumer) {
      consumer.disconnect();
      consumer = null;
    }
    
    isConnected.value = false;
  };

  // Enviar mensagem
  const sendMessage = async content => {
    const text = (content || '').trim();
    if (!text || !currentRoom.value) {
      console.warn('⚠️ Cannot send: missing content or room');
      return;
    }

    const normalized = normalizeRoom(currentRoom.value);
    const roomType = normalized.room_type;
    const roomId = normalized.room_id;

    console.log('📤 Sending message:', { roomType, roomId, content: text });

    // Mensagem temporária
    const tempId = `temp-${Date.now()}`;
    const tempMessage = {
      id: tempId,
      content: text,
      sender: currentUser.value,
      sender_id: currentUser.value.id,
      created_at: new Date().toISOString(),
      message_type: 'text',
      chat_type: roomType,
      room_id: roomId,
    };

    upsertMessage(tempMessage);

    try {
      // Enviar para backend
      const response = await internalChatAPI.sendMessage({
        roomType,
        roomId,
        content: text,
      });

      // Remover temp e adicionar mensagem real
      const index = messages.value.findIndex(m => m.id === tempId);
      if (index !== -1) {
        messages.value.splice(index, 1);
      }

      const savedMessage = response.data?.data;
      if (savedMessage) {
        upsertMessage(savedMessage);
        resetUnread(roomType, roomId);
      }

      console.log('✅ Message sent');
      return savedMessage;
    } catch (error) {
      console.error('❌ Failed to send message:', error);
      
      // Remover mensagem temp em caso de erro
      const index = messages.value.findIndex(m => m.id === tempId);
      if (index !== -1) {
        messages.value.splice(index, 1);
      }
    }
  };

  // Criar sala direct
  const createDirectRoom = async targetUserId => {
    try {
      const response = await internalChatAPI.createDirectRoom(targetUserId);
      const room = response.data?.data;
      return room;
    } catch (error) {
      console.error('❌ Failed to create direct room:', error);
      return null;
    }
  };

  // Selecionar sala
  const selectRoom = async room => {
    if (!room) return;

    const normalized = normalizeRoom(room);
    currentRoom.value = normalized;

    console.log('📂 Selected room:', normalized);

    // Carregar mensagens
    const roomType = normalized.room_type;
    const roomId = roomType === 'general' ? null : normalized.room_id;
    
    await loadMessages(roomType, roomId);
    // marcar sala como lida
    resetUnread(roomType, normalized.room_id);

    // Se for direct, garanta o mapeamento userId -> roomId (identifier esperado como userId)
    if (normalized.room_type === 'direct') {
      const userId = normalized.identifier || normalized.chat_id;
      if (userId && normalized.room_id) {
        dmRoomForUser.value = { ...dmRoomForUser.value, [String(userId)]: normalized.room_id };
      }
    }
  };

  // Lifecycle
  onMounted(() => {
    loadRooms();
    // Tenta conectar imediatamente (se store já estiver pronto)
    connect();
  });

  onUnmounted(() => {
    disconnect();
  });

  // Se o usuário/conta ainda não estavam prontos no mount,
  // conecta assim que ambos estiverem disponíveis
  watch(
    [currentUser, currentAccountId],
    () => {
      const user = currentUser.value;
      const accountId = currentAccountId.value;
      if (!subscription && user?.id && user?.pubsub_token && accountId) {
        connect();
      }
    },
    { immediate: false }
  );

  return {
    // Estado
    messages,
    rooms,
    currentRoom,
    isLoading,
    isConnected,
    unreadCounts,
    dmRoomForUser,

    // Métodos
    loadRooms,
    loadMessages,
    sendMessage,
    createDirectRoom,
    selectRoom,
    disconnect,
    // Helpers
    resetUnread,

    // Computed
    currentUser,
    currentAccountId,
  };
}
