<script setup>
import { computed, ref, getCurrentInstance } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Icon from 'next/icon/Icon.vue';
import { useMessageContext } from '../../provider.js';

const props = defineProps({
  content: {
    type: String,
    required: true,
  },
});

const store = useStore();
const { conversationId, inboxId } = useMessageContext();
const instance = getCurrentInstance();
const t = instance.proxy.$t;

const isCreating = ref(false);

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

// Normaliza o número de telefone para o formato E.164
const normalizePhoneNumber = (phone) => {
  if (!phone) return '';
  
  // Remove todos os caracteres que não são números ou +
  let normalized = phone.replace(/[^\d+]/g, '');
  
  // Se não começar com +, adiciona +
  if (!normalized.startsWith('+')) {
    normalized = `+${normalized}`;
  }
  
  return normalized;
};

const handleAddContact = async () => {
  if (!contactData.value.name || !primaryPhone.value) {
    useAlert(t('CONVERSATION.CONTACT_CARD.MISSING_INFO'));
    return;
  }

  if (isCreating.value) return;

  isCreating.value = true;

  try {
    const normalizedPhone = normalizePhoneNumber(primaryPhone.value);
    
    const contactParams = {
      name: contactData.value.name,
      phoneNumber: normalizedPhone,
      inboxId: inboxId.value,
    };

    const contact = await store.dispatch('contacts/create', contactParams);
    
    if (contact?.id) {
      useAlert(t('CONVERSATION.CONTACT_CARD.CONTACT_CREATED'));
    }
  } catch (error) {
    // Trata erro de contato duplicado
    if (error.name === 'DuplicateContactException') {
      const attributes = error.data || [];
      if (attributes.includes('phone_number')) {
        useAlert(t('CONVERSATION.CONTACT_CARD.PHONE_EXISTS'));
      } else if (attributes.includes('email')) {
        useAlert(t('CONVERSATION.CONTACT_CARD.EMAIL_EXISTS'));
      } else {
        useAlert(t('CONVERSATION.CONTACT_CARD.CONTACT_EXISTS'));
      }
    } else if (error.message) {
      useAlert(error.message);
    } else {
      useAlert(t('CONVERSATION.CONTACT_CARD.CONTACT_CREATE_ERROR'));
    }
  } finally {
    isCreating.value = false;
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

      <!-- Action Button -->
      <div class="border-t border-slate-200/60 dark:border-slate-700/60">
        <button
          type="button"
          class="flex items-center justify-center gap-2 w-full px-4 py-3 text-sm font-medium text-woot-600 dark:text-woot-400 hover:bg-slate-100/80 dark:hover:bg-slate-700/50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          :disabled="isCreating || !contactData.name || !primaryPhone"
          @click="handleAddContact"
        >
          <Icon icon="i-lucide-user-plus" class="size-4" />
          <span>{{ isCreating ? $t('CONVERSATION.CONTACT_CARD.CREATING') : $t('CONVERSATION.CONTACT_CARD.ADD_CONTACT') }}</span>
        </button>
      </div>
    </div>
  </div>
</template>
