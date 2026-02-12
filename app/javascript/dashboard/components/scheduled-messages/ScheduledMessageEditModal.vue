<script setup>
import { ref, watch, computed } from 'vue';
import DatePicker from 'vue-datepicker-next';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  show: { type: Boolean, default: false },
  scheduledMessage: { type: Object, default: null },
});

const emit = defineEmits(['close', 'submit']);

const { t } = useI18n();

const localContent = ref('');
const localDateTime = ref(null);
const errorMessage = ref('');

const messageData = computed(() => props.scheduledMessage?.message || {});
const scheduleInfo = computed(
  () =>
    props.scheduledMessage?.message?.schedule_info ||
    props.scheduledMessage?.message?.scheduleInfo ||
    {}
);

const resolvedTimezone = computed(() => {
  return (
    scheduleInfo.value?.scheduled_timezone ||
    scheduleInfo.value?.scheduledTimezone ||
    props.scheduledMessage?.timezone ||
    Intl.DateTimeFormat().resolvedOptions().timeZone ||
    'UTC'
  );
});

const initialize = () => {
  localContent.value = messageData.value?.content || '';
  errorMessage.value = '';
  const scheduledAt =
    props.scheduledMessage?.scheduled_at_iso ||
    scheduleInfo.value?.scheduled_at ||
    scheduleInfo.value?.scheduledAt;

  if (scheduledAt) {
    const parsed = new Date(scheduledAt);
    localDateTime.value = Number.isNaN(parsed.getTime()) ? null : parsed;
  } else {
    localDateTime.value = null;
  }
};

watch(
  () => props.show,
  show => {
    if (show) {
      initialize();
    }
  },
  { immediate: true }
);

watch(
  () => props.scheduledMessage,
  () => {
    if (props.show) {
      initialize();
    }
  },
  { deep: true }
);

const disablePastDates = date => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return date < today;
};

const handleClose = () => {
  emit('close');
};

const handleSubmit = () => {
  if (!localDateTime.value) {
    errorMessage.value = t('SCHEDULED_MESSAGES.EDIT_MODAL.ERROR_REQUIRED');
    return;
  }

  const now = new Date();
  if (localDateTime.value.getTime() <= now.getTime()) {
    errorMessage.value = t('SCHEDULED_MESSAGES.EDIT_MODAL.ERROR_PAST');
    return;
  }

  emit('submit', {
    content: localContent.value,
    scheduledAt: localDateTime.value.toISOString(),
    timezone: resolvedTimezone.value,
  });
  errorMessage.value = '';
};

const hasAttachments = computed(
  () => (props.scheduledMessage?.message?.attachments || []).length > 0
);
</script>

<template>
  <woot-modal :show="show" @close="handleClose">
    <woot-modal-header
      :header-title="t('SCHEDULED_MESSAGES.EDIT_MODAL.TITLE')"
      :header-content="t('SCHEDULED_MESSAGES.DESCRIPTION')"
    />
    <div class="px-6 py-5 flex flex-col gap-4">
      <div class="flex flex-col gap-2">
        <label
          class="text-xs font-medium uppercase tracking-wide text-n-slate-11"
        >
          {{ t('SCHEDULED_MESSAGES.EDIT_MODAL.CONTENT_LABEL') }}
        </label>
        <textarea
          v-model="localContent"
          rows="5"
          class="w-full resize-y rounded-lg border border-n-weak bg-n-solid-1 px-3 py-2 text-sm focus:border-n-brand focus:outline-none"
        />
        <p v-if="hasAttachments" class="text-xs text-n-slate-11">
          {{ t('SCHEDULED_MESSAGES.EDIT_MODAL.HELP_ATTACHMENTS') }}
        </p>
      </div>
      <div class="flex flex-col gap-2">
        <label
          class="text-xs font-medium uppercase tracking-wide text-n-slate-11"
        >
          {{ t('SCHEDULED_MESSAGES.EDIT_MODAL.SCHEDULE_LABEL') }}
        </label>
        <DatePicker
          v-model:value="localDateTime"
          type="datetime"
          :disabled-date="disablePastDates"
          :editable="false"
          :clearable="false"
          input-class="w-full"
        />
        <p class="text-xs text-n-slate-11">
          {{
            t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.TIMEZONE_LABEL', {
              timezone: resolvedTimezone,
            })
          }}
        </p>
      </div>
      <p v-if="errorMessage" class="text-xs text-n-amber-11">
        {{ errorMessage }}
      </p>
      <div class="flex justify-end gap-2">
        <NextButton
          faded
          slate
          :label="t('SCHEDULED_MESSAGES.EDIT_MODAL.CANCEL')"
          @click="handleClose"
        />
        <NextButton
          :label="t('SCHEDULED_MESSAGES.EDIT_MODAL.SAVE')"
          @click="handleSubmit"
        />
      </div>
    </div>
  </woot-modal>
</template>
