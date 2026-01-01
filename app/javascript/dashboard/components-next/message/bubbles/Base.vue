<script setup>
import { computed } from 'vue';

import MessageMeta from '../MessageMeta.vue';

import { emitter } from 'shared/helpers/mitt';
import { useMessageContext } from '../provider.js';
import { useI18n } from 'vue-i18n';

import { BUS_EVENTS } from 'shared/constants/busEvents';
import { MESSAGE_VARIANTS, ORIENTATION, MESSAGE_STATUS } from '../constants';

const props = defineProps({
  hideMeta: { type: Boolean, default: false },
  maxWidth: { type: String, default: null },
});

const {
  variant,
  orientation,
  inReplyTo,
  shouldGroupWithNext,
  status,
  scheduleInfo,
} = useMessageContext();
const { t } = useI18n();

const varaintBaseMap = {
  [MESSAGE_VARIANTS.AGENT]: 'bg-woot-100 dark:bg-woot-700 text-n-slate-12',
  [MESSAGE_VARIANTS.PRIVATE]:
    'bg-n-solid-amber text-n-amber-12 [&_.prosemirror-mention-node]:font-semibold',
  [MESSAGE_VARIANTS.USER]: 'bg-n-slate-4 text-n-slate-12',
  [MESSAGE_VARIANTS.ACTIVITY]: 'bg-n-alpha-1 text-n-slate-11 text-sm',
  [MESSAGE_VARIANTS.BOT]: 'bg-n-solid-iris text-n-slate-12',
  [MESSAGE_VARIANTS.TEMPLATE]: 'bg-n-solid-iris text-n-slate-12',
  [MESSAGE_VARIANTS.ERROR]: 'bg-n-ruby-4 text-n-ruby-12',
  [MESSAGE_VARIANTS.EMAIL]: 'w-full',
  [MESSAGE_VARIANTS.UNSUPPORTED]:
    'bg-n-solid-amber/70 border border-dashed border-n-amber-12 text-n-amber-12',
};

const orientationMap = {
  [ORIENTATION.LEFT]:
    'left-bubble rounded-xl ltr:rounded-bl-sm rtl:rounded-br-sm',
  [ORIENTATION.RIGHT]:
    'right-bubble rounded-xl ltr:rounded-br-sm rtl:rounded-bl-sm',
  [ORIENTATION.CENTER]: 'rounded-md',
};

const flexOrientationClass = computed(() => {
  const map = {
    [ORIENTATION.LEFT]: 'justify-start',
    [ORIENTATION.RIGHT]: 'justify-end',
    [ORIENTATION.CENTER]: 'justify-center',
  };

  return map[orientation.value];
});

const baseOrientationClasses = computed(() => {
  if (variant.value !== MESSAGE_VARIANTS.ACTIVITY) {
    return [orientationMap[orientation.value]];
  }
  return ['rounded-lg'];
});

const scheduledAt = computed(() => scheduleInfo?.value?.scheduledAt);

const isScheduledPending = computed(
  () => status.value === MESSAGE_STATUS.SCHEDULED && scheduledAt.value
);

const isScheduledCompleted = computed(() => {
  if (!scheduledAt.value) return false;
  return [
    MESSAGE_STATUS.SENT,
    MESSAGE_STATUS.DELIVERED,
    MESSAGE_STATUS.READ,
  ].includes(status.value);
});

const messageClass = computed(() => {
  if (isScheduledPending.value) {
    return [
      'bg-n-amber-3 text-n-amber-12 border border-n-amber-6',
      ...baseOrientationClasses.value,
    ];
  }

  if (isScheduledCompleted.value) {
    return [
      'bg-n-teal-3 text-n-slate-12 border border-n-amber-6',
      ...baseOrientationClasses.value,
    ];
  }

  return [varaintBaseMap[variant.value], ...baseOrientationClasses.value];
});

const scrollToMessage = () => {
  emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, {
    messageId: inReplyTo.value.id,
  });
};

const shouldShowMeta = computed(
  () =>
    !props.hideMeta &&
    !shouldGroupWithNext.value &&
    variant.value !== MESSAGE_VARIANTS.ACTIVITY
);

const replyToPreview = computed(() => {
  if (!inReplyTo) return '';

  const { content, attachments } = inReplyTo.value;

  if (content) return content;
  if (attachments?.length) {
    const firstAttachment = attachments[0];
    const fileType = firstAttachment.fileType ?? firstAttachment.file_type;

    return t(`CHAT_LIST.ATTACHMENTS.${fileType}.CONTENT`);
  }

  return t('CONVERSATION.REPLY_MESSAGE_NOT_FOUND');
});
</script>

<template>
  <div
    class="text-sm"
    :class="[
      messageClass,
      {
        'max-w-lg': variant !== MESSAGE_VARIANTS.EMAIL && !props.maxWidth,
      },
    ]"
    :style="props.maxWidth ? { maxWidth: props.maxWidth } : {}"
  >
    <div
      v-if="inReplyTo"
      class="p-2 -mx-1 mb-2 rounded-lg cursor-pointer bg-n-alpha-black1"
      @click="scrollToMessage"
    >
      <span class="break-all line-clamp-2">
        {{ replyToPreview }}
      </span>
    </div>
    <slot />
    <MessageMeta
      v-if="shouldShowMeta"
      :class="[
        flexOrientationClass,
        variant === MESSAGE_VARIANTS.EMAIL ? 'px-3 pb-3' : '',
        variant === MESSAGE_VARIANTS.PRIVATE
          ? 'text-n-amber-12/50'
          : 'text-n-slate-11',
      ]"
      class="mt-2"
    />
  </div>
</template>
