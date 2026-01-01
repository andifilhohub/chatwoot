<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  content: {
    type: String,
    required: true,
  },
});

const contactData = computed(() => {
  const lines = props.content.split('\n').filter(line => line.trim());

  let name = '';
  let phones = [];

  lines.forEach(line => {
    const nameMatch = line.match(/\*Nome:\*\s*(.+)/i);
    if (nameMatch) {
      name = nameMatch[1].trim();
    }

    const phoneMatch = line.match(/\*N[uú]mero.*:\*\s*(.+)/i);
    if (phoneMatch) {
      phones.push(phoneMatch[1].trim());
    }
  });

  return { name, phones };
});

const initials = computed(() => {
  if (!contactData.value.name) return '?';

  const words = contactData.value.name.split(' ').filter(w => w.length > 0);
  if (words.length === 1) return words[0][0].toUpperCase();

  return (words[0][0] + words[words.length - 1][0]).toUpperCase();
});

const primaryPhone = computed(() => {
  return contactData.value.phones[0] || '';
});

const handleAddContact = () => {
  // TODO: Implementar lógica para adicionar contato
};

const handleSendMessage = () => {
  if (primaryPhone.value) {
    // TODO: Implementar lógica para enviar mensagem
  }
};
</script>

<template>
  <div class="inline-block max-w-sm">
    <div
      class="rounded-2xl border-2 border-slate-200/60 dark:border-slate-700/60 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm overflow-hidden shadow-sm"
    >
      <!-- Contact Info Section -->
      <div class="p-4 flex items-start gap-3">
        <!-- Avatar -->
        <div
          class="flex-shrink-0 size-12 rounded-full bg-gradient-to-br from-woot-500 to-woot-600 dark:from-woot-600 dark:to-woot-700 flex items-center justify-center text-white font-bold text-base shadow-md ring-2 ring-white/50 dark:ring-slate-900/50"
        >
          {{ initials }}
        </div>

        <!-- Info -->
        <div class="flex-1 min-w-0 pt-0.5">
          <div class="flex items-center gap-2 mb-2">
            <Icon
              icon="i-lucide-user"
              class="size-4 text-slate-500 dark:text-slate-400"
            />
            <span
              class="font-semibold text-slate-900 dark:text-slate-100 text-base truncate"
            >
              {{ contactData.name || 'Contato' }}
            </span>
          </div>

          <div v-if="contactData.phones.length > 0" class="space-y-1.5">
            <div
              v-for="(phone, index) in contactData.phones"
              :key="index"
              class="flex items-center gap-2 text-sm text-slate-600 dark:text-slate-300"
            >
              <Icon icon="i-lucide-phone" class="size-3.5 flex-shrink-0" />
              <span class="font-mono text-xs">{{ phone }}</span>
            </div>
          </div>

          <p
            v-else
            class="text-xs text-slate-500 dark:text-slate-400 italic mt-1"
          >
            {{ $t('CONVERSATION.CONTACT_CARD.NO_PHONE') }}
          </p>
        </div>
      </div>

      <!-- Action Buttons -->
      <div
        class="grid grid-cols-2 gap-0 border-t border-slate-200/60 dark:border-slate-700/60"
      >
        <button
          type="button"
          class="flex items-center justify-center gap-2 px-4 py-3 text-sm font-medium text-woot-600 dark:text-woot-400 hover:bg-slate-100/80 dark:hover:bg-slate-700/50 transition-colors border-r border-slate-200/60 dark:border-slate-700/60"
          @click="handleAddContact"
        >
          <Icon icon="i-lucide-user-plus" class="size-4" />
          <span>{{ $t('CONVERSATION.CONTACT_CARD.ADD_CONTACT') }}</span>
        </button>

        <button
          type="button"
          class="flex items-center justify-center gap-2 px-4 py-3 text-sm font-medium text-woot-600 dark:text-woot-400 hover:bg-slate-100/80 dark:hover:bg-slate-700/50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          :disabled="!primaryPhone"
          @click="handleSendMessage"
        >
          <Icon icon="i-lucide-message-circle" class="size-4" />
          <span>{{ $t('CONVERSATION.CONTACT_CARD.SEND_MESSAGE') }}</span>
        </button>
      </div>
    </div>
  </div>
</template>
