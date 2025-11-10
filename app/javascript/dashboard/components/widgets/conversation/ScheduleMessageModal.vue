<script setup>
import { ref, watch, computed } from 'vue';
import DatePicker from 'vue-datepicker-next';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  show: {
    type: Boolean,
    default: false,
  },
  scheduledAt: {
    type: String,
    default: null,
  },
  timezone: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'confirm', 'clear']);

const { t } = useI18n();

const localDateTime = ref(null);
const errorMessage = ref('');

const resolvedTimezone = computed(
  () => props.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'
);

const initialize = () => {
  errorMessage.value = '';
  if (props.scheduledAt) {
    const parsed = new Date(props.scheduledAt);
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
  }
);

watch(
  () => props.scheduledAt,
  () => {
    if (!props.show) {
      initialize();
    }
  }
);

const disablePastDates = date => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return date < today;
};

const handleClose = () => {
  errorMessage.value = '';
  emit('close');
};

const handleConfirm = () => {
  if (!localDateTime.value) {
    errorMessage.value = t(
      'CONVERSATION.REPLYBOX.SCHEDULE.MODAL.ERROR_REQUIRED'
    );
    return;
  }

  const now = new Date();
  if (localDateTime.value.getTime() <= now.getTime()) {
    errorMessage.value = t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.ERROR_PAST');
    return;
  }

  emit('confirm', {
    scheduledAt: localDateTime.value.toISOString(),
    timezone: resolvedTimezone.value,
  });
  errorMessage.value = '';
};

const handleClear = () => {
  emit('clear');
  errorMessage.value = '';
};

const timezoneLabel = computed(() =>
  t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.TIMEZONE_LABEL', {
    timezone: resolvedTimezone.value,
  })
);

const canClear = computed(() => !!props.scheduledAt);
</script>

<template>
  <woot-modal :show="show" @close="handleClose">
    <woot-modal-header
      :header-title="$t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.TITLE')"
      :header-content="$t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.DESCRIPTION')"
    />
    <div class="px-6 py-5 flex flex-col gap-4">
      <DatePicker
        v-model:value="localDateTime"
        type="datetime"
        :disabled-date="disablePastDates"
        :placeholder="$t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.PLACEHOLDER')"
        :editable="false"
        :clearable="false"
        input-class="w-full"
      />
      <p class="text-xs text-n-slate-11">
        {{ timezoneLabel }}
      </p>
      <p v-if="errorMessage" class="text-xs text-n-amber-11">
        {{ errorMessage }}
      </p>
      <div class="flex justify-end gap-2">
        <NextButton
          v-if="canClear"
          faded
          slate
          :label="$t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.CLEAR')"
          @click="handleClear"
        />
        <NextButton
          faded
          slate
          :label="$t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.CANCEL')"
          @click="handleClose"
        />
        <NextButton
          :label="$t('CONVERSATION.REPLYBOX.SCHEDULE.MODAL.APPLY')"
          @click="handleConfirm"
        />
      </div>
    </div>
  </woot-modal>
</template>
