import { ref } from 'vue';

// Estado global compartilhado
const isInternalChatOpen = ref(false);

export function useInternalChat() {
  const openInternalChat = () => {
    console.log('🚀 openInternalChat called');
    isInternalChatOpen.value = true;
  };

  const closeInternalChat = () => {
    console.log('🚀 closeInternalChat called');
    isInternalChatOpen.value = false;
  };

  const toggleInternalChat = () => {
    console.log('🎯 toggleInternalChat called, current state:', isInternalChatOpen.value);
    isInternalChatOpen.value = !isInternalChatOpen.value;
    console.log('🎯 new state:', isInternalChatOpen.value);
  };

  return {
    isInternalChatOpen,
    openInternalChat,
    closeInternalChat,
    toggleInternalChat,
  };
}
