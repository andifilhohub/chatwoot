<script setup>
import { ref, watch, computed } from 'vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  messagePrefix: {
    type: String,
    default: '',
  },
  enableMessagePrefix: {
    type: Boolean,
    default: false,
  },
  userName: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['updatePrefix']);

const prefix = ref(props.messagePrefix);
const enabled = ref(props.enableMessagePrefix);

watch(
  () => props.messagePrefix ?? '',
  newValue => {
    prefix.value = newValue;
  },
  { immediate: true }
);

watch(
  () => props.enableMessagePrefix,
  newValue => {
    enabled.value = newValue;
  },
  { immediate: true }
);

const previewText = computed(() => {
  if (!enabled.value || !prefix.value) {
    return '';
  }
  
  // Substitui a variável {agentName} pelo nome do usuário
  const prefixWithName = prefix.value.replace(/\{agent_name\}/gi, props.userName || 'Agent');
  return `${prefixWithName}\n\nOlá, tudo bem?`;
});

const updatePrefix = () => {
  emit('updatePrefix', {
    message_prefix: prefix.value,
    enable_message_prefix: enabled.value,
  });
};
</script>

<template>
  <form class="flex flex-col gap-6" @submit.prevent="updatePrefix()">
    <!-- Toggle para habilitar/desabilitar -->
    <div class="flex items-start gap-3">
      <input
        id="enable-prefix"
        v-model="enabled"
        type="checkbox"
        class="mt-1 size-4 rounded border-n-slate-7 text-woot-600 focus:ring-woot-500"
      />
      <div class="flex-1">
        <label
          for="enable-prefix"
          class="text-sm font-medium text-n-slate-12 cursor-pointer"
        >
          {{ $t('PROFILE_SETTINGS.FORM.MESSAGE_PREFIX_SECTION.ENABLE') }}
        </label>
        <p class="text-xs text-n-slate-11 mt-1">
          {{ $t('PROFILE_SETTINGS.FORM.MESSAGE_PREFIX_SECTION.ENABLE_HELP') }}
        </p>
      </div>
    </div>

    <!-- Input do prefixo -->
    <div v-if="enabled" class="flex flex-col gap-2">
      <label
        for="message-prefix-input"
        class="text-sm font-medium text-n-slate-12"
      >
        {{ $t('PROFILE_SETTINGS.FORM.MESSAGE_PREFIX.LABEL') }}
      </label>
      <textarea
        id="message-prefix-input"
        v-model="prefix"
        rows="2"
        class="w-full px-3 py-2 border border-n-slate-7 rounded-lg focus:outline-none focus:ring-2 focus:ring-woot-500 focus:border-transparent resize-none"
        :placeholder="$t('PROFILE_SETTINGS.FORM.MESSAGE_PREFIX.PLACEHOLDER')"
      />
      <p class="text-xs text-n-slate-11">
        {{ $t('PROFILE_SETTINGS.FORM.MESSAGE_PREFIX.HELP') }}
      </p>

      <!-- Preview -->
      <div v-if="previewText" class="mt-2">
        <label class="text-sm font-medium text-n-slate-12 mb-2 block">
          {{ $t('PROFILE_SETTINGS.FORM.MESSAGE_PREFIX.PREVIEW') }}
        </label>
        <div
          class="p-3 bg-n-slate-2 dark:bg-n-slate-3 rounded-lg border border-n-slate-6 text-sm text-n-slate-12 whitespace-pre-wrap font-mono"
        >
          {{ previewText }}
        </div>
      </div>
    </div>

    <!-- Botão salvar -->
    <div>
      <NextButton
        type="submit"
        :label="$t('PROFILE_SETTINGS.FORM.MESSAGE_PREFIX_SECTION.BTN_TEXT')"
      />
    </div>
  </form>
</template>
