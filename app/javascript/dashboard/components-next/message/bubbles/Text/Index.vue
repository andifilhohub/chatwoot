<script setup>
import { computed, ref } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import ContactCard from './ContactCard.vue';
import LocationCard from './LocationCard.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';

const { content, attachments, contentAttributes, messageType } =
  useMessageContext();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const renderContent = computed(() => {
  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    return translationContent.value;
  }

  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isContactMessage = computed(() => {
  // Check by content_attributes flag first
  if (
    contentAttributes.value?.whatsapp_message_type === 'contactMessage' ||
    contentAttributes.value?.whatsappMessageType === 'contactMessage'
  ) {
    return true;
  }

  // Fallback: detect by content pattern (contains "**Contato:**" and "*Nome:*")
  const text = content.value || '';
  const hasContactHeader = /\*\*Contato:\*\*/i.test(text);
  const hasNameField = /\*Nome:\*/i.test(text);

  return hasContactHeader && hasNameField;
});

const isLocationMessage = computed(() => {
  // Check by content_attributes flag first
  if (
    contentAttributes.value?.whatsapp_message_type === 'locationMessage' ||
    contentAttributes.value?.whatsappMessageType === 'locationMessage' ||
    contentAttributes.value?.whatsapp_message_type === 'liveLocationMessage' ||
    contentAttributes.value?.whatsappMessageType === 'liveLocationMessage'
  ) {
    return true;
  }

  // Fallback: detect by content pattern (contains location coordinates)
  const text = content.value || '';
  const hasLocationHeader = /\*\*Localização:\*\*/i.test(text);
  const hasLatitude = /\*Latitud[e]?:\*/i.test(text);
  const hasLongitude = /\*Longitud[e]?:\*/i.test(text);

  return hasLocationHeader && hasLatitude && hasLongitude;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

// Contact message detection is active via isContactMessage computed

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <ContactCard v-else-if="isContactMessage" :content="renderContent" />
      <LocationCard v-else-if="isLocationMessage" :content="renderContent" />
      <FormattedContent v-else-if="renderContent" :content="renderContent" />
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
