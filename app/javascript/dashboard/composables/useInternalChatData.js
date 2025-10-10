import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { createConsumer } from '@rails/actioncable';
import { useStore } from 'vuex';
import internalChatAPI from '../api/internalChat';

export default function useInternalChatData() {
  const store = useStore();

  // Estado reativo
  const messages = ref([]);
  const rooms = ref({});
  const currentRoom = ref(null);
  const isLoading = ref(false);
  const isConnected = ref(false);
  const messagesMeta = ref({});

  const RECONNECT_DELAY = 1000;

  // ActionCable connection
  let subscription = null;
  let consumer = null;
  let ownsConsumer = false;
  let reconnectTimer = null;
  let subscriptionKey = null;

  // Getters do store
  const currentUser = computed(() => store.getters.getCurrentUser);
  const currentAccountId = computed(() => store.getters.getCurrentAccountId);

  // Carregar salas de chat
  const loadRooms = async () => {
    try {
      isLoading.value = true;
      const response = await internalChatAPI.getRooms();
      const payload = response.data || {};

      rooms.value = {
        general: payload.general || rooms.value.general || null,
        teams: Array.isArray(payload.teams) ? payload.teams : [],
        direct_messages: Array.isArray(payload.direct_messages) ? payload.direct_messages : [],
      };
    } catch (error) {
      console.error('❌ Failed to load internal chat rooms:', error);
    } finally {
      isLoading.value = false;
      ensureSubscription();
    }
  };

  // Carregar mensagens de uma sala
  const loadMessages = async (roomType, roomId) => {
    try {
      isLoading.value = true;
      const response = await internalChatAPI.getMessages({ roomType, roomId });
      const { data: messageList = [], meta = {} } = response.data || {};
      messages.value = Array.isArray(messageList) ? messageList : [];
      messagesMeta.value = meta;
    } catch (error) {
      console.error('❌ Failed to load internal chat messages:', error);
      console.error('❌ Error details:', error.response?.data);
    } finally {
      isLoading.value = false;
    }
  };

  const ensureMessagesCollection = () => {
    if (!Array.isArray(messages.value)) {
      messages.value = [];
    }
  };

  const upsertMessage = message => {
    if (!message || !message.id) {
      return;
    }

    ensureMessagesCollection();

    const index = messages.value.findIndex(item => item.id === message.id);
    if (index === -1) {
      messages.value.push(message);
    } else {
      messages.value.splice(index, 1, message);
    }
  };

  const typeMapping = {
    0: 'general',
    1: 'team',
    2: 'direct',
  };

  const resolveRoomType = value => {
    if (value === null || value === undefined) return null;
    if (typeof value === 'number') {
      return typeMapping[value] || null;
    }
    return value;
  };

  const normalizeRoom = (room = {}, fallbackType = 'direct') => {
    const rawType = resolveRoomType(room.room_type ?? room.type);
    const roomType = rawType || fallbackType;
    let identifier = room.identifier;

    if (!identifier) {
      if (roomType === 'general') {
        identifier = 'general';
      } else if (roomType === 'team') {
        identifier = room.team_id || room.id;
      } else if (roomType === 'direct') {
        identifier = room.target_user_id || room.id;
      } else {
        identifier = room.id;
      }
    }
    const roomId = room.room_id ?? room.id ?? null;

    return {
      ...room,
      room_type: roomType,
      identifier,
      room_id: roomId,
    };
  };

  const cableURL = () => {
    const { websocketURL = '' } = window.chatwootConfig || {};
    return websocketURL ? `${websocketURL}/cable` : undefined;
  };

  const scheduleReconnect = () => {
    if (reconnectTimer) {
      return;
    }

    reconnectTimer = setTimeout(() => {
      reconnectTimer = null;
      ensureSubscription(true);
    }, RECONNECT_DELAY);
  };

  const ensureSubscription = (force = false) => {
    const accountId = currentAccountId.value;
    if (!accountId) {
      console.warn('⚠️ ensureSubscription: No account ID');
      return;
    }

    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
      reconnectTimer = null;
    }

    const user = currentUser.value;
    if (!user?.id || !user?.pubsub_token) {
      console.warn('⚠️ ensureSubscription: No user or pubsub_token');
      return;
    }

    const key = `${accountId}:${user.id}:${user.pubsub_token}`;
    if (!force && subscription && subscriptionKey === key) {
      console.log('✅ ensureSubscription: Already subscribed with same key');
      return;
    }

    if (subscription) {
      console.log('🔄 ensureSubscription: Unsubscribing old subscription');
      subscription.unsubscribe();
      subscription = null;
    }

    console.log('🔌 ensureSubscription: Creating new subscription', {
      accountId,
      userId: user.id,
      hasPubsubToken: !!user.pubsub_token
    });

    let cable = window.App?.cable;
    if (cable) {
      console.log('✅ Using existing window.App.cable');
      ownsConsumer = false;
    } else {
      if (!consumer) {
        console.log('🔌 Creating new ActionCable consumer');
        consumer = createConsumer(cableURL());
      }
      cable = consumer;
      ownsConsumer = true;
    }

    if (!cable) {
      console.warn('⚠️ No ActionCable consumer available for internal chat');
      return;
    }

    const params = {
      channel: 'InternalChatChannel',
      account_id: accountId,
    };

    params.user_id = user.id;
    params.pubsub_token = user.pubsub_token;

    console.log('📡 Creating subscription with params:', params);

    subscription = cable.subscriptions.create(
      params,
      {
        connected() {
          console.log('✅ Internal chat cable connected');
          isConnected.value = true;
        },

        disconnected() {
          console.log('❌ Internal chat cable disconnected');
          isConnected.value = false;
          subscription = null;
          subscriptionKey = null;
          scheduleReconnect();
        },

        received(data) {
          console.log('📩 Internal chat payload received:', data);
          if (data.type === 'new_message' && data.message) {
            if (!currentRoom.value) {
              console.warn('⚠️ No current room selected, ignoring message');
              return;
            }

            console.log('🔍 Current room:', {
              room_id: currentRoom.value.room_id,
              room_type: currentRoom.value.room_type,
              identifier: currentRoom.value.identifier
            });
            
            console.log('🔍 Incoming message:', {
              room_id: data.message.room_id,
              chat_type: data.chat_type,
              chat_id: data.chat_id
            });

            const incomingRoomId = data.message.room_id;
            const currentRoomId = currentRoom.value.room_id;
            const matchesRoomId = currentRoomId && incomingRoomId
              && String(currentRoomId) === String(incomingRoomId);

            const incomingRoomType = data.chat_type;
            const currentRoomType = currentRoom.value.room_type;
            const matchesRoomType = String(currentRoomType) === String(incomingRoomType);

            console.log('🔍 Match results:', {
              matchesRoomId,
              matchesRoomType,
              incomingRoomType,
              currentRoomType
            });

            // Mensagem só é aceita se:
            // 1. O room_id é o mesmo E o tipo também é o mesmo
            if (matchesRoomId && matchesRoomType) {
              console.log('✅ Message matches current room, adding to UI');
              upsertMessage(data.message);
            } else {
              console.warn('❌ Message does NOT match current room, ignoring');
            }
          }
        },
      },
    );

    subscriptionKey = key;
  };

  // Enviar mensagem
  const sendMessage = async content => {
    const text = (content || '').trim();
    if (!text || !currentRoom.value) {
      console.warn('⚠️ Cannot send message: missing content or room');
      return;
    }

    console.log('📤 Sending message:', {
      content: text,
      currentRoom: currentRoom.value
    });

    const normalizedRoom = normalizeRoom(currentRoom.value);
    const targetRoomId = normalizedRoom.room_id
      || normalizedRoom.id
      || normalizedRoom.identifier;

    console.log('📤 Normalized room:', {
      room_type: normalizedRoom.room_type,
      room_id: normalizedRoom.room_id,
      targetRoomId
    });

    const messageData = {
      roomType: normalizedRoom.room_type,
      roomId: targetRoomId,
      content: text,
    };

    const tempId = `temp-${Date.now()}`;
    const tempMessage = {
      id: tempId,
      content: text,
      sender: {
        id: currentUser.value?.id,
        name: currentUser.value?.name,
        avatar_url: currentUser.value?.avatar_url,
      },
      sender_id: currentUser.value?.id,
      created_at: new Date().toISOString(),
      room_id: normalizedRoom.room_id,
      message_type: 'text',
      temp: true,
    };

    console.log('📤 Adding temp message to UI:', tempId);
    upsertMessage(tempMessage);

    ensureSubscription();

    try {
      console.log('📤 Calling API with:', messageData);
      const response = await internalChatAPI.sendMessage(messageData);
      console.log('📤 API response:', response.data);
      
      const savedMessage = response.data?.data;

      const tempIndex = messages.value.findIndex(message => message.id === tempId);
      if (tempIndex !== -1) {
        console.log('📤 Removing temp message');
        messages.value.splice(tempIndex, 1);
      }

      if (savedMessage) {
        console.log('📤 Adding saved message to UI:', savedMessage.id);
        upsertMessage(savedMessage);
        if (savedMessage.room_id) {
          currentRoom.value = {
            ...normalizedRoom,
            room_id: savedMessage.room_id,
          };
        }
      }

      console.log('✅ Message sent successfully');
      return savedMessage;
    } catch (error) {
      console.error('❌ Failed to send internal chat message:', error);
      const tempIndex = messages.value.findIndex(message => message.id === tempId);
      if (tempIndex !== -1) {
        messages.value.splice(tempIndex, 1);
      }
      return null;
    }
  };

  // Criar sala direta
  const createDirectRoom = async userId => {
    try {
      const response = await internalChatAPI.createDirectRoom(userId);
      
      // A resposta tem estrutura: response.data = {data: {...}}
      const room = response.data?.data || response.data;

      if (room && room.id) {
        const normalizedRoom = normalizeRoom(room, 'direct');
        currentRoom.value = normalizedRoom;
        const targetRoomId = normalizedRoom.room_id
          || normalizedRoom.id
          || normalizedRoom.identifier;

        await loadMessages(normalizedRoom.room_type, targetRoomId);
        if (messagesMeta.value?.room_id) {
          currentRoom.value.room_id = messagesMeta.value.room_id;
        }

        if (Array.isArray(rooms.value?.direct_messages)) {
          const existingIndex = rooms.value.direct_messages.findIndex(item => String(item.id) === String(userId));
          const existingEntry = existingIndex === -1 ? null : rooms.value.direct_messages[existingIndex];

          const identifier = room.target_user_id || userId;

          const partner = (room.participants || []).find(participant => String(participant.id) === String(userId));

          const directEntry = {
            ...existingEntry,
            id: userId,
            room_id: normalizedRoom.room_id,
            room_type: 'direct',
            identifier,
          };

          if (!directEntry.name) {
            directEntry.name = partner?.name || normalizedRoom.name;
          }

          if (!directEntry.email && partner?.email) {
            directEntry.email = partner.email;
          }

          if (existingIndex === -1) {
            rooms.value.direct_messages.push(directEntry);
          } else {
            rooms.value.direct_messages.splice(existingIndex, 1, {
              ...directEntry,
            });
          }
        }

        ensureSubscription();
      } else {
        console.warn('⚠️ createDirectRoom: No valid room data received');
      }

      return currentRoom.value;
    } catch (error) {
      console.error('❌ createDirectRoom error:', error);
      return null;
    }
  };

  // Selecionar sala atual
  const selectRoom = async room => {
    const normalizedRoom = normalizeRoom(room);
    currentRoom.value = normalizedRoom;
    const targetRoomId = normalizedRoom.room_id
      || normalizedRoom.id
      || normalizedRoom.identifier;

    await loadMessages(normalizedRoom.room_type, targetRoomId);
    if (messagesMeta.value?.room_id) {
      currentRoom.value.room_id = messagesMeta.value.room_id;
    }
    ensureSubscription();
  };

  // Desconectar do ActionCable
  const disconnect = () => {
    if (subscription) {
      subscription.unsubscribe();
      subscription = null;
    }
    isConnected.value = false;
    if (consumer && ownsConsumer) {
      consumer.disconnect();
      consumer = null;
      ownsConsumer = false;
    }
    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
      reconnectTimer = null;
    }
    subscriptionKey = null;
  };

  // Lifecycle
  onMounted(() => {
    loadRooms();
  });

  watch(
    [currentUser, currentAccountId],
    ([user, account]) => {
      if (user && account) {
        ensureSubscription();
      } else {
        disconnect();
      }
    },
    { immediate: true },
  );

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
