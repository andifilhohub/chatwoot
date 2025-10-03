import { ref } from 'vue';

export function useInternalChat() {
  const isInternalChatOpen = ref(false);

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
    toggleInternalChat,
  };
}
