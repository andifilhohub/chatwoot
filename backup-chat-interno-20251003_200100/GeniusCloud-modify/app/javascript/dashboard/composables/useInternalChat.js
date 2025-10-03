import { ref, computed } from 'vue';
import { useStore } from 'vuex';

const isInternalChatOpen = ref(false);

export function useInternalChat() {
  const store = useStore();

  const openInternalChat = () => {
    isInternalChatOpen.value = true;
  };

  const closeInternalChat = () => {
    isInternalChatOpen.value = false;
  };

  const toggleInternalChat = () => {
    isInternalChatOpen.value = !isInternalChatOpen.value;
  };

  return {
    isInternalChatOpen,
    openInternalChat,
    closeInternalChat,
    toggleInternalChat
  };
}