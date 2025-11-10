<script setup>
import { computed } from 'vue';
import { messageTimestamp } from 'shared/helpers/timeHelper';

import MessageStatus from './MessageStatus.vue';
import Icon from 'next/icon/Icon.vue';
import { useInbox } from 'dashboard/composables/useInbox';
import { useMessageContext } from './provider.js';

import { MESSAGE_STATUS, MESSAGE_TYPES } from './constants';
import { useI18n } from 'vue-i18n';

const {
  isAFacebookInbox,
  isALineChannel,
  isAPIInbox,
  isASmsInbox,
  isATelegramChannel,
  isATwilioChannel,
  isAWebWidgetInbox,
  isAWhatsAppChannel,
  isAnEmailChannel,
  isAnInstagramChannel,
} = useInbox();

const {
  status,
  isPrivate,
  createdAt,
  sourceId,
  messageType,
  contentAttributes,
  scheduleInfo,
} = useMessageContext();

const { t } = useI18n();

const readableTime = computed(() =>
  messageTimestamp(createdAt.value, 'LLL d, h:mm a')
);

const scheduledTimestamp = computed(() => {
  const iso = scheduleInfo.value?.scheduledAt;
  if (!iso) return null;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return Math.floor(date.getTime() / 1000);
});

const dispatchedTimestamp = computed(() => {
  const iso = scheduleInfo.value?.dispatchedAt;
  if (!iso) return null;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return Math.floor(date.getTime() / 1000);
});

const scheduledTimezone = computed(
  () => scheduleInfo.value?.scheduledTimezone
);

const scheduledLabel = computed(() => {
  if (!scheduledTimestamp.value) return '';
  const base = messageTimestamp(scheduledTimestamp.value, 'LLL d, h:mm a');
  if (!scheduledTimezone.value) {
    return base;
  }
  return `${base} (${scheduledTimezone.value})`;
});

const dispatchedLabel = computed(() => {
  if (!dispatchedTimestamp.value) return '';
  return messageTimestamp(dispatchedTimestamp.value, 'LLL d, h:mm a');
});

const showStatusIndicator = computed(() => {
  if (isPrivate.value) return false;
  // Don't show status for failed messages, we already show error message
  if (status.value === MESSAGE_STATUS.FAILED) return false;
  // Don't show status for deleted messages
  if (contentAttributes.value?.deleted) return false;
  if (status.value === MESSAGE_STATUS.SCHEDULED) return false;

  if (messageType.value === MESSAGE_TYPES.OUTGOING) return true;
  if (messageType.value === MESSAGE_TYPES.TEMPLATE) return true;

  return false;
});

const isSent = computed(() => {
  if (!showStatusIndicator.value) return false;

  // Messages will be marked as sent for the Email channel if they have a source ID.
  if (isAnEmailChannel.value) return !!sourceId.value;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isAFacebookInbox.value ||
    isASmsInbox.value ||
    isATelegramChannel.value ||
    isAnInstagramChannel.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.SENT;
  }

  // All messages will be mark as sent for the Line channel, as there is no source ID.
  if (isALineChannel.value) return true;

  return false;
});

const isDelivered = computed(() => {
  if (!showStatusIndicator.value) return false;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isASmsInbox.value ||
    isAFacebookInbox.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.DELIVERED;
  }
  // All messages marked as delivered for the web widget inbox and API inbox once they are sent.
  if (isAWebWidgetInbox.value || isAPIInbox.value) {
    return status.value === MESSAGE_STATUS.SENT;
  }
  if (isALineChannel.value) {
    return status.value === MESSAGE_STATUS.DELIVERED;
  }

  return false;
});

const isRead = computed(() => {
  if (!showStatusIndicator.value) return false;

  if (
    isAWhatsAppChannel.value ||
    isATwilioChannel.value ||
    isAFacebookInbox.value ||
    isAnInstagramChannel.value
  ) {
    return sourceId.value && status.value === MESSAGE_STATUS.READ;
  }

  if (isAWebWidgetInbox.value || isAPIInbox.value) {
    return status.value === MESSAGE_STATUS.READ;
  }

  return false;
});

const statusToShow = computed(() => {
  if (isRead.value) return MESSAGE_STATUS.READ;
  if (isDelivered.value) return MESSAGE_STATUS.DELIVERED;
  if (isSent.value) return MESSAGE_STATUS.SENT;

  return MESSAGE_STATUS.PROGRESS;
});

const shouldShowScheduleMeta = computed(() => !!scheduledTimestamp.value);

const scheduleMetaText = computed(() => {
  if (!scheduledTimestamp.value) return '';
  if (
    status.value === MESSAGE_STATUS.SCHEDULED ||
    (!dispatchedTimestamp.value && status.value === MESSAGE_STATUS.PROGRESS)
  ) {
    return t('CONVERSATION.REPLYBOX.SCHEDULE.META_PENDING', {
      datetime: scheduledLabel.value,
    });
  }

  if (dispatchedTimestamp.value) {
    return t('CONVERSATION.REPLYBOX.SCHEDULE.META_SENT', {
      scheduledAt: scheduledLabel.value,
      sentAt: dispatchedLabel.value,
    });
  }

  return t('CONVERSATION.REPLYBOX.SCHEDULE.META_PENDING', {
    datetime: scheduledLabel.value,
  });
});

const scheduleMetaColorClass = computed(() => {
  if (!scheduledTimestamp.value) return '';
  if (status.value === MESSAGE_STATUS.SCHEDULED) {
    return 'text-n-amber-11';
  }
  if (dispatchedTimestamp.value) {
    return 'text-n-teal-11';
  }
  return 'text-n-slate-11';
});
</script>

<template>
  <div class="text-xs flex flex-col gap-1">
    <div
      v-if="shouldShowScheduleMeta"
      class="flex items-center gap-1.5"
      :class="scheduleMetaColorClass"
    >
      <Icon icon="i-ph-calendar" class="size-3" />
      <span class="leading-none">{{ scheduleMetaText }}</span>
    </div>
    <div class="flex items-center gap-1.5 text-n-slate-11">
      <div class="inline">
        <time class="inline">{{ readableTime }}</time>
      </div>
      <Icon v-if="isPrivate" icon="i-lucide-lock-keyhole" class="size-3" />
      <MessageStatus v-if="showStatusIndicator" :status="statusToShow" />
    </div>
  </div>
</template>

`
