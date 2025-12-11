<script setup>
import { ref, computed, onBeforeUnmount, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';
import QRCode from 'qrcode';

import { useAlert } from 'dashboard/composables';
import PageHeader from '../../SettingsSubPageHeader.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import zaphubChannel from 'dashboard/api/channel/zaphubChannel';

const { t } = useI18n();
const store = useStore();
const route = useRoute();
const router = useRouter();

const channelName = ref('');
const webhookUrl = ref('');
const isCreatingSession = ref(false);
const qrCodeData = ref(null);
const sessionId = ref(null);
const status = ref('pending');
const errorMessage = ref(null);
const hasHandledConnection = ref(false);

const validationState = { channelName };
const rules = { channelName: { required } };
const v$ = useVuelidate(rules, validationState);

let statusCheckIntervalId = null;

const isConnected = computed(() => status.value === 'connected');
const showQrCode = computed(
  () => Boolean(qrCodeData.value) && !isConnected.value
);
const showForm = computed(
  () => !qrCodeData.value && !isConnected.value && !isCreatingSession.value
);
const accountId = computed(() => route.params.accountId);

const buildErrorMessage = error => {
  const baseMessage =
    error?.response?.data?.error ||
    error?.response?.data?.message ||
    error?.message ||
    'Unknown error';
  const details = error?.response?.data?.details;
  return details ? `${baseMessage}\n${details}` : baseMessage;
};

const showAlertError = message => {
  useAlert(`${t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.API.ERROR_MESSAGE')}: ${message}`);
};

const normalizeQrImage = async rawCode => {
  if (rawCode.startsWith('data:image')) {
    return rawCode;
  }

  if (rawCode.startsWith('data:text/plain;base64,')) {
    const base64Text = rawCode.split(',')[1];
    const decodedText = window.atob(base64Text);
    return QRCode.toDataURL(decodedText, {
      errorCorrectionLevel: 'M',
      width: 400,
      margin: 1,
    });
  }

  return QRCode.toDataURL(rawCode, {
    errorCorrectionLevel: 'M',
    width: 400,
    margin: 1,
  });
};

const fetchQrCode = async inboxId => {
  try {
    const response = await zaphubChannel.getQrCode(inboxId);
    const qrPayload = response.data?.data;
    const rawQrCode = qrPayload?.qr_code || qrPayload?.qr;

    if (rawQrCode) {
      qrCodeData.value = await normalizeQrImage(rawQrCode);
      status.value = qrPayload?.status || 'qr_generated';
    }
  } catch (error) {
    if (error?.response?.status === 404) {
      setTimeout(() => fetchQrCode(inboxId), 4000);
      return;
    }
    errorMessage.value = buildErrorMessage(error);
  }
};

const redirectToAgentsPage = inboxId => {
  router
    .push({
      name: 'settings_inboxes_add_agents',
      params: {
        accountId: accountId.value,
        page: 'new',
        inbox_id: inboxId,
      },
    })
    .catch(() => {
      router.push({
        name: 'settings_inbox_list',
        params: { accountId: accountId.value },
      });
    });
};

const stopStatusCheck = () => {
  if (statusCheckIntervalId) {
    clearInterval(statusCheckIntervalId);
    statusCheckIntervalId = null;
  }
};

const handleConnectionSuccess = async inboxId => {
  if (hasHandledConnection.value) {
    return;
  }
  hasHandledConnection.value = true;
  stopStatusCheck();

  if (channelName.value && channelName.value !== 'WhatsApp ZapHub') {
    try {
      await store.dispatch('inboxes/updateInbox', {
        id: inboxId,
        name: channelName.value,
      });
    } catch (updateError) {
      // Non-blocking: log and continue redirect
      // eslint-disable-next-line no-console
      console.error('Failed to update inbox name:', updateError);
    }
  }

  useAlert(t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.API.SUCCESS_MESSAGE'));
  redirectToAgentsPage(inboxId);
};

const checkConnectionStatus = async inboxId => {
  try {
    const response = await zaphubChannel.checkStatus(inboxId);
    const statusPayload = response.data?.data;
    if (!statusPayload) {
      return;
    }

    const derivedStatus =
      statusPayload.db_status || statusPayload.status || 'pending';
    status.value = derivedStatus;

    const isConnectedFlag =
      typeof statusPayload.is_connected === 'boolean'
        ? statusPayload.is_connected
        : derivedStatus === 'connected';

    if (isConnectedFlag) {
      await handleConnectionSuccess(inboxId);
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error('ZapHub status check failed:', error);
  }
};

const startStatusCheck = inboxId => {
  stopStatusCheck();
  statusCheckIntervalId = setInterval(() => {
    checkConnectionStatus(inboxId);
  }, 3003);
};

const createSessionAndShowQR = async () => {
  await v$.value.$validate();
  if (v$.value.$invalid) {
    useAlert(t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.API.ERROR_MESSAGE'));
    return;
  }

  errorMessage.value = null;
  isCreatingSession.value = true;
  hasHandledConnection.value = false;

  try {
    const channelResponse = await store.dispatch('inboxes/createChannel', {
      name: channelName.value,
      channel: {
        type: 'zaphub',
        webhook_url: webhookUrl.value,
      },
    });

    sessionId.value = channelResponse.id;
    await zaphubChannel.createSession(channelResponse.id);
    await fetchQrCode(channelResponse.id);
    startStatusCheck(channelResponse.id);
  } catch (error) {
    const message = buildErrorMessage(error);
    errorMessage.value = message;
    showAlertError(message);
  } finally {
    isCreatingSession.value = false;
  }
};

onBeforeUnmount(() => {
  stopStatusCheck();
});

watch(
  () => [isConnected.value, sessionId.value],
  ([connected, inboxId]) => {
    if (connected && inboxId) {
      handleConnectionSuccess(inboxId);
    }
  }
);
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <PageHeader
      :header-title="t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.TITLE')"
      :header-content="t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.DESC')"
    />

    <div v-if="isCreatingSession" class="flex flex-col items-center my-8 p-6">
      <div class="flex items-center space-x-3">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
        <span class="text-lg">
          {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.LOADING.TITLE') }}
        </span>
      </div>
      <p class="text-sm text-gray-600 mt-4">
        {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.LOADING.SUBTITLE') }}
      </p>
    </div>

    <div
      v-if="showForm"
      class="flex flex-col items-center my-8 p-6 bg-white dark:bg-slate-800 border rounded-lg shadow-sm"
    >
      <div class="w-full max-w-md space-y-4">
        <label :class="[{ error: v$.channelName.$error }, 'block text-gray-800 dark:text-gray-200']">
          {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.CHANNEL_NAME.LABEL') }}
          <input
            v-model="channelName"
            type="text"
            :placeholder="
              t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.CHANNEL_NAME.PLACEHOLDER')
            "
            @blur="v$.channelName.$touch"
            class="w-full px-3 py-2 border rounded bg-white text-gray-900 dark:bg-slate-700 dark:text-gray-100"
          />
          <span v-if="v$.channelName.$error" class="message text-red-700 dark:text-red-300">
            {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.CHANNEL_NAME.ERROR') }}
          </span>
        </label>

        <label class="block text-gray-800 dark:text-gray-200">
          {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.WEBHOOK_URL.LABEL') }}
          <input
            v-model="webhookUrl"
            type="text"
            :placeholder="t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.WEBHOOK_URL.PLACEHOLDER')"
            class="w-full px-3 py-2 border rounded bg-white text-gray-900 dark:bg-slate-700 dark:text-gray-100"
          />
          <span class="message text-gray-600 dark:text-gray-300">
            {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.WEBHOOK_URL.SUBTITLE') }}
          </span>
        </label>

        <NextButton
          class="w-full justify-center"
          :is-loading="isCreatingSession"
          @click="createSessionAndShowQR"
        >
          {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.SUBMIT_BUTTON') }}
        </NextButton>
      </div>
    </div>

    <div
      v-if="errorMessage && !isCreatingSession"
      class="my-8 p-6 bg-red-50 border border-red-200 rounded-lg"
    >
      <div class="flex items-start">
        <span class="i-ri-error-warning-fill text-red-600 text-2xl mr-3"></span>
        <div>
          <h3 class="text-lg font-medium text-red-800 mb-2">
            {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.ERROR_BANNER.TITLE') }}
          </h3>
          <p class="text-sm text-red-700 whitespace-pre-wrap">
            {{ errorMessage }}
          </p>
          <div class="mt-4">
            <button
              @click="createSessionAndShowQR"
              class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
            >
              {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.ERROR_BANNER.RETRY') }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <div
      v-if="showQrCode"
      class="flex flex-col items-center my-8 p-6 bg-white dark:bg-slate-800 border rounded-lg shadow-sm"
    >
      <h3 class="text-lg font-medium mb-4">
        {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.QR_CODE.TITLE') }}
      </h3>
      <p class="text-sm text-gray-600 dark:text-gray-300 mb-4 text-center">
        {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.QR_CODE.SUBTITLE') }}
      </p>
      <!-- keep QR background white even in dark mode; surrounding panel adapts to dark theme -->
      <div class="bg-white dark:bg-white p-4 border rounded">
        <img :src="qrCodeData" alt="QR Code" class="w-64 h-64" />
      </div>
      <div class="mt-4 flex items-center">
        <span class="inline-block w-2 h-2 bg-yellow-500 rounded-full animate-pulse mr-2"></span>
        <span class="text-sm text-gray-600 dark:text-gray-300">
          {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.QR_CODE.WAITING') }}
        </span>
      </div>
    </div>

    <div
      v-if="isConnected"
      class="flex flex-col items-center my-8 p-6 bg-green-50 border border-green-200 rounded-lg"
    >
      <div class="flex items-center mb-2">
        <span class="i-ri-checkbox-circle-fill text-green-600 text-2xl mr-2"></span>
        <h3 class="text-lg font-medium text-green-800">
          {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.CONNECTED.TITLE') }}
        </h3>
      </div>
      <p class="text-sm text-green-700">
        {{ t('INBOX_MGMT.ADD.ZAPHUB_CHANNEL.CONNECTED.MESSAGE') }}
      </p>
    </div>
  </div>
</template>
