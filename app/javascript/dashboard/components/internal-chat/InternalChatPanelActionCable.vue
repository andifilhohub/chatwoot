<template>
  <div
    v-if="isInternalChatOpen"
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
    @click="closeInternalChat"
  >
    <!-- Tailwind safelist for status colors -->
    <span class="hidden bg-green-500 bg-yellow-500 bg-gray-400" aria-hidden="true"></span>
    <div
      class="bg-n-solid-1 rounded-2xl shadow-2xl w-[900px] max-w-[95vw] h-[700px] max-h-[90vh] flex overflow-hidden border border-n-weak"
      @click.stop
    >
      <!-- Sidebar -->
      <div class="w-80 min-w-[320px] max-w-[320px] bg-n-solid-2 border-r border-n-weak flex flex-col">
        <div class="px-6 py-4 border-b border-n-weak h-[84px] flex items-center">
          <div>
            <h3 class="text-lg font-semibold text-n-slate-12 leading-6">
              {{ $t('INTERNAL_CHAT.ROOMS.TITLE') }}
            </h3>
            <p class="text-sm text-n-slate-10 mt-1 leading-5">
              {{ $t('INTERNAL_CHAT.ROOMS.TYPE.GENERAL') }}
            </p>
          </div>
        </div>

        <div v-if="loading" class="flex-1 flex items-center justify-center">
          <div class="text-center">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-woot-600 mx-auto"></div>
            <p class="text-sm text-n-slate-10 mt-2">{{ $t('INTERNAL_CHAT.STATE.LOADING_ROOMS') }}</p>
          </div>
        </div>

        <!-- Chat Categories -->
        <div v-else class="flex-1 overflow-y-auto p-4 space-y-4">
          <!-- General Chat -->
          <div class="space-y-2">
            <h4 class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide px-2">
              {{ $t('INTERNAL_CHAT.ROOMS.GENERAL') }}
            </h4>
            <div
              @click="selectChatMethod('general')"
              class="flex items-center p-3 rounded-xl cursor-pointer transition-all duration-200 group hover:shadow-md"
              :class="
                selectedChatType === 'general'
                  ? 'bg-woot-600 text-white shadow-lg' 
                  : 'bg-n-solid-3 hover:bg-n-solid-4 text-n-slate-12 hover:scale-[1.02]'
              "
            >
              <div class="w-10 h-10 bg-green-500 rounded-full flex items-center justify-center text-white text-sm font-medium mr-3 shadow-inner">
                #
              </div>
              <div class="flex-1">
                <div class="font-medium">{{ $t('INTERNAL_CHAT.ROOMS.GENERAL') }}</div>
                <div class="text-sm opacity-70">{{ $t('INTERNAL_CHAT.ROOMS.TYPE.GENERAL') }}</div>
              </div>
              <div v-if="selectedChatType !== 'general'" class="w-2 h-2 bg-green-400 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"></div>
            </div>
          </div>

          <!-- Team Chats -->
          <div class="space-y-2">
            <h4 class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide px-2">
              {{ $t('INTERNAL_CHAT.ROOMS.TEAMS') }}
            </h4>
            <div v-if="teamChats.length > 0">
              <div v-for="team in teamChats" :key="team.id">
                <div
                  @click="selectChatMethod('team', team.id)"
                  class="flex items-center p-3 rounded-xl cursor-pointer transition-all duration-200 group hover:shadow-md"
                  :class="
                    selectedChatType === 'team' && selectedChatId === team.id
                      ? 'bg-woot-600 text-white shadow-lg'
                      : 'bg-n-solid-3 hover:bg-n-solid-4 text-n-slate-12 hover:scale-[1.02]'
                  "
                >
                  <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white text-sm font-medium mr-3 shadow-inner">
                    {{ team.name.charAt(0).toUpperCase() }}
                  </div>
                  <div class="flex-1">
                    <div class="font-medium">{{ team.name }}</div>
                    <div class="text-sm opacity-70">
                      <span class="text-xs text-n-slate-10">
                        {{ team.member_count || 0 }} {{ (team.member_count || 0) === 1 ? 'member' : 'members' }}
                      </span>
                    </div>
                  </div>
                  <div v-if="selectedChatType !== 'team' || selectedChatId !== team.id" class="w-2 h-2 bg-blue-400 rounded-full opacity-0 group-hover:opacity-100 transition-opacity"></div>
                </div>
              </div>
            </div>
            <div v-else class="px-3 py-2 text-center text-n-slate-10 text-sm italic">
              {{ $t('INTERNAL_CHAT.ROOMS.NO_TEAMS') }}
            </div>
          </div>

          <!-- Direct Messages -->
          <div class="space-y-2">
            <h4 class="text-xs font-semibold text-n-slate-10 uppercase tracking-wide px-2">
              {{ $t('INTERNAL_CHAT.ROOMS.DIRECT') }}
            </h4>
            <div v-if="directMessages.length > 0" class="space-y-2 max-h-80 overflow-y-auto pr-2">
              <div v-for="agent in directMessages" :key="agent.id">
                <div
                  @click="selectChatMethod('direct', agent.id)"
                  class="flex items-center p-3 rounded-xl cursor-pointer transition-all duration-200 group hover:shadow-md mb-1"
                  :class="
                    selectedChatType === 'direct' && selectedChatId === agent.id
                      ? 'bg-woot-600 text-white shadow-lg'
                      : 'bg-n-solid-3 hover:bg-n-solid-4 text-n-slate-12 hover:scale-[1.02]'
                  "
                >
                  <div class="relative mr-3">
                    <div v-if="agent.avatar_url" class="w-10 h-10 rounded-full overflow-hidden shadow-md">
                      <img :src="agent.avatar_url" 
                           :alt="agent.name" 
                           class="w-full h-full object-cover">
                    </div>
                    <div v-else class="w-10 h-10 rounded-full bg-woot-600 flex items-center justify-center text-white font-semibold shadow-md">
                      {{ getInitials(agent.name) }}
                    </div>
                    <div :class="[
                      'absolute -bottom-1 -right-1 w-3 h-3 rounded-full border-2',
                      selectedChatType === 'direct' && selectedChatId === agent.id ? 'border-white' : 'border-n-solid-3',
                      getStatusColor(agent.availability_status)
                    ]"></div>
                  </div>
                  <div class="flex-1 min-w-0">
                    <div class="font-medium truncate">{{ agent.name }}</div>
                    <div class="text-sm opacity-70 truncate">
                      {{ getStatusText(agent.availability_status) }}
                      <span v-if="agent.availability_status !== 'online' && agent.last_seen_at" class="ml-1">
                        • {{ formatLastSeen(agent.last_seen_at) }}
                      </span>
                    </div>
                  </div>
                  <div v-if="selectedChatType !== 'direct' || selectedChatId !== agent.id" :class="[
                    'w-2 h-2 rounded-full opacity-0 group-hover:opacity-100 transition-opacity',
                    getStatusColor(agent.availability_status)
                  ]"></div>
                </div>
              </div>
            </div>
            <div v-else class="px-3 py-2 text-center text-n-slate-10 text-sm italic">
              {{ $t('INTERNAL_CHAT.STATE.NO_DIRECT_ROOMS') }}
            </div>
          </div>
        </div>
      </div>

      <!-- Main Chat Area -->
      <div class="flex-1 flex flex-col">
        <!-- Header do chat principal -->
        <div class="flex-none flex items-center justify-between p-4 border-b border-n-weak h-[84px]">
          <div class="flex items-center space-x-3" v-if="currentChat">
            <div class="flex-shrink-0">
              <div v-if="selectedChatType === 'direct'" class="relative">
                <div v-if="currentChat.avatar_url" class="w-10 h-10 rounded-full overflow-hidden shadow-md">
                  <img :src="currentChat.avatar_url" 
                       :alt="currentChat.name" 
                       class="w-full h-full object-cover">
                </div>
                <div v-else class="w-10 h-10 rounded-full bg-woot-600 flex items-center justify-center text-white font-semibold shadow-md">
                  {{ getInitials(currentChat.name) }}
                </div>
                <div :class="[
                  'absolute -bottom-1 -right-1 w-4 h-4 rounded-full border-2 border-white',
                  getStatusColor(currentChat.availability_status)
                ]"></div>
              </div>
              <div v-else class="w-10 h-10 rounded-full bg-woot-600 flex items-center justify-center shadow-md">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                </svg>
              </div>
            </div>
            <div class="min-w-0 flex-1">
              <h3 class="text-lg font-medium text-n-slate-12 truncate">{{ currentChat.name }}</h3>
              <p v-if="selectedChatType === 'direct'" class="text-sm text-n-slate-10">
                {{ getStatusText(currentChat.availability_status) }}
                <span v-if="currentChat.availability_status !== 'online' && currentChat.last_seen_at" class="ml-1">
                  • {{ formatLastSeen(currentChat.last_seen_at) }}
                </span>
              </p>
              <p v-else-if="selectedChatType === 'team'" class="text-sm text-n-slate-10">
                {{ currentChat?.member_count || 0 }} {{ (currentChat?.member_count || 0) === 1 ? 'member' : 'members' }}
              </p>
              <p v-else class="text-sm text-n-slate-10">
                {{ currentChat.description }}
              </p>
            </div>
          </div>
          
          <button
            @click="closeInternalChat"
            class="p-2 text-n-slate-8 hover:text-n-slate-12 hover:bg-n-solid-3 rounded-lg transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Área de mensagens -->
        <div class="flex-1 overflow-y-scroll p-4 space-y-4" ref="messageContainer" style="height: 500px; max-height: 500px;">
          <div v-if="messages.length === 0" class="flex-1 flex items-center justify-center">
            <div class="text-center">
              <div class="w-16 h-16 mx-auto mb-4 bg-n-solid-3 rounded-full flex items-center justify-center">
                <svg class="w-8 h-8 text-n-slate-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
                </svg>
              </div>
              <h3 class="text-lg font-medium text-n-slate-12 mb-2">{{ $t('INTERNAL_CHAT.ROOMS.NO_ROOM_SELECTED') }}</h3>
              <p class="text-n-slate-10">{{ $t('INTERNAL_CHAT.STATE.EMPTY') }}</p>
            </div>
          </div>

          <!-- Mensagens -->
          <div v-for="message in messages" :key="message.id" 
               :class="[
                 'flex',
                 message.sender_id === currentUser?.id
                   ? 'justify-end' 
                   : 'justify-start'
               ]">
            
            <!-- Mensagem de outros usuários (lado esquerdo) -->
            <div v-if="message.sender_id !== currentUser?.id"
                 class="flex space-x-3 max-w-[70%]">
              <div class="flex-shrink-0">
                <div v-if="message.sender?.avatar_url" class="w-8 h-8 rounded-full overflow-hidden shadow-sm">
                  <img :src="message.sender.avatar_url" 
                       :alt="message.sender.name" 
                       class="w-full h-full object-cover"
                       @error="$event.target.style.display = 'none'">
                </div>
                <div v-else class="w-8 h-8 rounded-full flex items-center justify-center text-white text-sm font-medium shadow-sm"
                     :style="{ backgroundColor: getAvatarColor(message.sender?.name || 'Unknown') }">
                  {{ getInitials(message.sender?.name || 'Unknown') }}
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center space-x-2 mb-1">
                  <span class="text-sm font-medium text-n-slate-12">{{ message.sender?.name || 'Unknown' }}</span>
                  <span class="text-xs text-n-slate-10">{{ formatTime(message.created_at) }}</span>
                </div>
                <div class="bg-n-solid-3 rounded-2xl rounded-tl-md px-4 py-3 shadow-sm">
                  <p class="text-sm text-n-slate-12 whitespace-pre-wrap">{{ message.content }}</p>
                </div>
              </div>
            </div>

            <!-- Mensagem própria (lado direito) -->
            <div v-else class="flex space-x-3 max-w-[70%] flex-row-reverse">
              <div class="flex-shrink-0">
                <div v-if="currentUser.avatar_url" class="w-8 h-8 rounded-full overflow-hidden shadow-sm">
                  <img :src="currentUser.avatar_url" 
                       :alt="currentUser.name" 
                       class="w-full h-full object-cover"
                       @error="$event.target.style.display = 'none'">
                </div>
                <div v-else class="w-8 h-8 rounded-full bg-woot-600 flex items-center justify-center text-white text-sm font-medium shadow-sm">
                  {{ getInitials(currentUser.name) }}
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center space-x-2 mb-1 flex-row-reverse">
                  <span class="text-sm font-medium text-n-slate-12">{{ t('INTERNAL_CHAT.YOU') }}</span>
                  <span class="text-xs text-n-slate-8">{{ formatTime(message.created_at) }}</span>
                </div>
                <div class="bg-woot-600 rounded-2xl rounded-tr-md px-4 py-3 shadow-sm">
                  <div class="text-sm text-white whitespace-pre-wrap">{{ message.content }}</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Input de mensagem -->
        <div class="flex-none border-t border-n-weak p-4">
          <form @submit.prevent="sendMessageAction" class="flex items-center space-x-3">
            <div class="flex-1">
              <textarea
                v-model="messageInput"
                :placeholder="$t('INTERNAL_CHAT.PLACEHOLDER.NEW_MESSAGE')"
                class="w-full px-4 py-3 border border-n-weak rounded-lg resize-none focus:outline-none focus:ring-2 focus:ring-woot-600 focus:border-transparent bg-n-solid-1 text-n-slate-12"
                rows="1"
                @keydown.enter="handleKeydown"
                style="height: 48px; line-height: 1.5; box-sizing: border-box; resize: none;"
              ></textarea>
            </div>
            
            <div class="flex items-center space-x-2" style="height: 48px;">
              <button
                type="button"
                class="flex items-center justify-center px-3 text-n-slate-8 hover:text-woot-600 transition-colors"
                style="height: 48px; box-sizing: border-box;"
                title="Anexar arquivo"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
                </svg>
              </button>
              
              <button
                type="submit"
                :disabled="!messageInput.trim()"
                class="flex items-center justify-center px-4 bg-woot-600 text-white rounded-lg hover:bg-woot-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                style="height: 48px; box-sizing: border-box;"
                title="Enviar mensagem"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/>
                </svg>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useInternalChat } from '../../composables/useInternalChat.js';
import useInternalChatData from '../../composables/useInternalChatData.js';

const { t } = useI18n();
const store = useStore();
const { isInternalChatOpen, closeInternalChat } = useInternalChat();

// Usar o composable de dados
const { 
  messages,
  rooms,
  currentRoom,
  isLoading,
  isConnected,
  newMessage,
  loadRooms,
  loadMessages,
  sendMessage,
  createDirectRoom,
  selectRoom,
  disconnect,
  currentUser,
  currentAccountId
} = useInternalChatData();

// Estado local do componente
const messageContainer = ref(null);
const messageInput = ref('');
const selectedChatType = ref('general');
const selectedChatId = ref(null);
const loading = computed(() => isLoading.value);

// Dados computados
const directMessages = computed(() => {
  return store.getters['agents/getAgents'] || [];
});

const teamChats = computed(() => {
  return store.getters['teams/getTeams'] || [];
});

const generalChat = computed(() => ({
  id: 'general',
  name: t('INTERNAL_CHAT.ROOMS.GENERAL'),
  description: t('INTERNAL_CHAT.ROOMS.TYPE.GENERAL')
}));

const currentChat = computed(() => {
  if (selectedChatType.value === 'general') {
    return generalChat.value;
  } else if (selectedChatType.value === 'team' && selectedChatId.value) {
    return teamChats.value.find(team => team.id === selectedChatId.value);
  } else if (selectedChatType.value === 'direct' && selectedChatId.value) {
    return directMessages.value.find(agent => agent.id === selectedChatId.value);
  }
  return null;
});

// Funções auxiliares
const selectChatMethod = async (type, id = null) => {
  console.log(`🎯 Selecting chat: ${type}, id: ${id}`);
  selectedChatType.value = type;
  selectedChatId.value = id;
  
  if (type === 'direct' && id) {
    // Criar ou encontrar sala direta
    const room = await createDirectRoom(id);
    if (room) {
      await selectRoom(room);
    }
  } else if (type === 'general') {
    // Carregar sala geral (implementar conforme necessário)
    // Por enquanto, apenas simular
    const generalRoom = { id: 'general', name: 'General Chat' };
    await selectRoom(generalRoom);
  }
};

const getStatusColor = (status) => {
  switch (status) {
    case 'online': return 'bg-green-500';
    case 'busy': return 'bg-yellow-500';
    case 'offline': return 'bg-gray-400';
    default: return 'bg-gray-400';
  }
};

const getStatusText = (status) => {
  switch (status) {
    case 'online': return 'Online';
    case 'busy': return 'Busy';
    case 'offline': return 'Offline';
    default: return 'Unknown';
  }
};

const formatTime = (timestamp) => {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  if (isNaN(date.getTime())) {
    return timestamp.toString();
  }
  return date.toLocaleTimeString('pt-BR', { 
    hour: '2-digit', 
    minute: '2-digit' 
  });
};

const getAvatarColor = (name) => {
  if (!name) return '#6B7280'; // gray-500
  
  const colors = [
    '#EF4444', // red-500
    '#F97316', // orange-500  
    '#F59E0B', // amber-500
    '#EAB308', // yellow-500
    '#84CC16', // lime-500
    '#22C55E', // green-500
    '#10B981', // emerald-500
    '#14B8A6', // teal-500
    '#06B6D4', // cyan-500
    '#0EA5E9', // sky-500
    '#3B82F6', // blue-500
    '#6366F1', // indigo-500
    '#8B5CF6', // violet-500
    '#A855F7', // purple-500
    '#D946EF', // fuchsia-500
    '#EC4899', // pink-500
    '#F43F5E'  // rose-500
  ];
  
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = name.charCodeAt(i) + ((hash << 5) - hash);
  }
  
  return colors[Math.abs(hash) % colors.length];
};

const getInitials = (name) => {
  if (!name) return '?';
  const words = name.split(' ').filter(word => word.length > 0);
  if (words.length === 1) {
    return words[0].charAt(0).toUpperCase();
  }
  return (words[0].charAt(0) + words[words.length - 1].charAt(0)).toUpperCase();
};

const sendMessageAction = async () => {
  if (!messageInput.value.trim()) return;

  const messageContent = messageInput.value.trim();
  
  console.log('📤 Sending message:', {
    content: messageContent,
    currentUserId: currentUser.value?.id,
    selectedChatType: selectedChatType.value,
    selectedChatId: selectedChatId.value
  });
  
  // Limpa o input imediatamente
  messageInput.value = '';

  // Chama a função do composable
  await sendMessage(messageContent);
  
  // Scroll para baixo após enviar
  nextTick(() => {
    if (messageContainer.value) {
      messageContainer.value.scrollTop = messageContainer.value.scrollHeight;
    }
  });
};

const handleKeydown = (event) => {
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    sendMessageAction();
  }
};

const formatLastSeen = (timestamp) => {
  if (!timestamp) return '';
  const date = new Date(timestamp);
  const now = new Date();
  const diffMs = now - date;
  const diffMins = Math.floor(diffMs / (1000 * 60));
  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
  
  if (diffMins < 1) return 'agora mesmo';
  if (diffMins < 60) return `${diffMins}m atrás`;
  if (diffHours < 24) return `${diffHours}h atrás`;
  if (diffDays < 7) return `${diffDays}d atrás`;
  
  return date.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });
};

onMounted(() => {
  console.log('🚀 Internal Chat component mounted');
  console.log('🚀 isInternalChatOpen initial state:', isInternalChatOpen.value);
  loadRooms();
});

onUnmounted(() => {
  console.log('🔄 Internal Chat component unmounted');
  disconnect();
});
</script>
