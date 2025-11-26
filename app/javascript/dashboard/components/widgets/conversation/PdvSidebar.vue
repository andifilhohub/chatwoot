<script setup>
import { computed } from 'vue';
import PdvPanel from 'dashboard/routes/dashboard/conversation/PdvPanel.vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useWindowSize } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import wootConstants from 'dashboard/constants/globals';

defineProps({
  currentChat: {
    required: true,
    type: Object,
  },
});

const { uiSettings, updateUISettings } = useUISettings();
const { width: windowWidth } = useWindowSize();

const activeTab = computed(() => {
  const { is_pdv_panel_open: isPdvPanelOpen } = uiSettings.value;

  if (isPdvPanelOpen) {
    return 0;
  }
  return null;
});

const isSmallScreen = computed(
  () => windowWidth.value < wootConstants.SMALL_SCREEN_BREAKPOINT
);

const closePdvPanel = () => {
  if (isSmallScreen.value && uiSettings.value?.is_pdv_panel_open) {
    updateUISettings({
      is_contact_sidebar_open: false,
      is_copilot_panel_open: false,
      is_pdv_panel_open: false,
    });
  }
};
</script>

<template>
  <div
    v-on-click-outside="() => closePdvPanel()"
    class="bg-n-background h-full overflow-hidden flex flex-col fixed top-0 z-40 w-full max-w-sm transition-transform duration-300 ease-in-out ltr:right-0 rtl:left-0 md:static md:w-[320px] md:min-w-[320px] ltr:border-l rtl:border-r border-n-weak 2xl:min-w-[360px] 2xl:w-[360px] shadow-lg md:shadow-none"
    :class="[
      {
        'md:flex': activeTab === 0,
        'md:hidden': activeTab !== 0,
      },
    ]"
  >
    <div class="flex flex-1 overflow-auto">
      <PdvPanel
        v-show="activeTab === 0"
        :conversation-id="currentChat.id"
        :inbox-id="currentChat.inbox_id"
        :contact-id="currentChat.meta?.sender?.id"
      />
    </div>
  </div>
</template>
