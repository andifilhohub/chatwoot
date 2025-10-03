<template>
  <div class="internal-chat-messages h-full flex flex-col">
    <!-- Loading State -->
    <div v-if="loading" class="flex items-center justify-center py-8">
      <div class="text-sm text-n-slate-10">{{ t('INTERNAL_CHAT.STATE.LOADING_MESSAGES') }}</div>
    </div>

    <!-- Empty State -->
    <div v-else-if="!messages.length" class="flex items-center justify-center py-8">
      <div class="text-center">
        <div class="text-sm text-n-slate-10">{{ t('INTERNAL_CHAT.STATE.EMPTY') }}</div>
      </div>
    </div>

    <!-- Messages -->
    <div v-else class="flex-1 overflow-y-auto space-y-3 p-4">
      <div
        v-for="message in messages"
        :key="message.id"
        class="flex items-start space-x-3"
        :class="{ 'flex-row-reverse space-x-reverse': isOwnMessage(message) }"
      >
        <!-- Avatar -->
        <div class="flex-shrink-0">
          <img
            :src="message.sender.avatar_url || '/assets/default-avatar.png'"
            :alt="message.sender.name"
            class="w-8 h-8 rounded-full"
          />
        </div>

        <!-- Message Content -->
        <div
          class="max-w-xs lg:max-w-md px-4 py-2 rounded-lg"
          :class="isOwnMessage(message) 
            ? 'bg-blue-600 text-white' 
            : 'bg-n-slate-3 text-n-slate-12'"
        >
          <!-- Sender Name (for group chats) -->
          <div
            v-if="!isOwnMessage(message) && showSenderName"
            class="text-xs opacity-70 mb-1"
          >
            {{ message.sender.name }}
          </div>

          <!-- Message Text -->
          <div class="text-sm whitespace-pre-wrap">
            {{ message.content }}
          </div>

          <!-- Timestamp -->
          <div
            class="text-xs mt-1 opacity-60"
            :class="isOwnMessage(message) ? 'text-blue-100' : 'text-n-slate-10'"
          >
            {{ formatTime(message.created_at) }}
          </div>
        </div>
      </div>
    </div>

    <!-- Scroll to bottom button -->
    <div
      v-if="showScrollButton"
      class="absolute bottom-4 right-4"
    >
      <button
        @click="scrollToBottom"
        class="bg-blue-600 text-white p-2 rounded-full shadow-lg hover:bg-blue-700 transition-colors"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
        </svg>
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUpdated, nextTick } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const props = defineProps({
  messages: {
    type: Array,
    default: () => []
  },
  loading: {
    type: Boolean,
    default: false
  },
  currentUserId: {
    type: Number,
    required: true
  },
  showSenderName: {
    type: Boolean,
    default: true
  }
});

const messagesContainer = ref(null);
const showScrollButton = ref(false);

const isOwnMessage = (message) => {
  return message.sender_id === props.currentUserId;
};

const formatTime = (timestamp) => {
  if (!timestamp) return '';
  
  const date = new Date(timestamp);
  const now = new Date();
  
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString('pt-BR', { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  } else {
    return date.toLocaleDateString('pt-BR', { 
      day: '2-digit', 
      month: '2-digit',
      hour: '2-digit', 
      minute: '2-digit' 
    });
  }
};

const scrollToBottom = () => {
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight;
    showScrollButton.value = false;
  }
};

const checkScrollPosition = () => {
  if (messagesContainer.value) {
    const { scrollTop, scrollHeight, clientHeight } = messagesContainer.value;
    const isNearBottom = scrollHeight - scrollTop - clientHeight < 100;
    showScrollButton.value = !isNearBottom && props.messages.length > 0;
  }
};

onMounted(() => {
  nextTick(() => {
    scrollToBottom();
  });
});

onUpdated(() => {
  nextTick(() => {
    if (!showScrollButton.value) {
      scrollToBottom();
    }
  });
});
</script>