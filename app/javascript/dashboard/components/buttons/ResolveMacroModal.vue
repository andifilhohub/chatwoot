<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { CONVERSATION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';
import { useTrack } from 'dashboard/composables';
import wootConstants from 'dashboard/constants/globals';

import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const emit = defineEmits(['resolve', 'close']);

const store = useStore();
const { t } = useI18n();
const { accountScopedUrl } = useAccount();
const { uiSettings } = useUISettings();

const show = defineModel('show', { type: Boolean, default: false });
const isResolving = ref(false);
const executingMacroId = ref(null);

const macros = useMapGetter('macros/getMacros');
const uiFlags = useMapGetter('macros/getUIFlags');

const MACROS_ORDER_KEY = 'macros_display_order';

const orderedMacros = computed(() => {
  const savedOrder = uiSettings.value?.[MACROS_ORDER_KEY] ?? [];
  const currentMacros = macros.value ?? [];

  if (!savedOrder.length || !currentMacros.length) {
    return currentMacros;
  }

  const orderMap = new Map(savedOrder.map((id, index) => [id, index]));

  return [...currentMacros].sort((a, b) => {
    const aPos = orderMap.get(a.id) ?? Infinity;
    const bPos = orderMap.get(b.id) ?? Infinity;
    return aPos - bPos;
  });
});

const closeModal = () => {
  show.value = false;
  emit('close');
};

const resolveWithoutMacro = () => {
  isResolving.value = true;
  emit('resolve');
  closeModal();
};

const executeMacroAndResolve = async macro => {
  try {
    executingMacroId.value = macro.id;
    await store.dispatch('macros/execute', {
      macroId: macro.id,
      conversationIds: [props.conversationId],
    });
    useTrack(CONVERSATION_EVENTS.EXECUTED_A_MACRO);
    useAlert(t('MACROS.EXECUTE.EXECUTED_SUCCESSFULLY'));

    // Resolve conversation after executing macro
    await store.dispatch('toggleStatus', {
      conversationId: props.conversationId,
      status: wootConstants.STATUS_TYPE.RESOLVED,
    });

    useAlert(t('CONVERSATION.CHANGE_STATUS'));
    closeModal();
  } catch (error) {
    useAlert(t('MACROS.ERROR'));
  } finally {
    executingMacroId.value = null;
  }
};

onMounted(() => {
  store.dispatch('macros/get');
});
</script>

<template>
  <Modal v-model:show="show" :on-close="closeModal">
    <div class="flex flex-col w-full h-full">
      <div
        class="flex items-center justify-between px-8 py-4 border-b border-n-weak"
      >
        <h2 class="text-xl font-semibold text-n-slate-12">
          {{ $t('CONVERSATION.RESOLVE_MODAL.TITLE') }}
        </h2>
      </div>

      <div class="flex-1 px-8 py-6 overflow-y-auto">
        <p class="mb-4 text-sm text-n-slate-11">
          {{ $t('CONVERSATION.RESOLVE_MODAL.DESCRIPTION') }}
        </p>

        <!-- Loading state -->
        <div
          v-if="uiFlags.isFetching"
          class="flex items-center justify-center gap-2 py-8"
        >
          <Spinner class="size-5" />
          <span class="text-sm text-n-slate-11">
            {{ $t('MACROS.LOADING') }}
          </span>
        </div>

        <!-- Empty state -->
        <div
          v-else-if="!macros.length"
          class="flex flex-col items-center justify-center py-8"
        >
          <p class="mb-3 text-sm text-n-slate-11">
            {{ $t('MACROS.LIST.404') }}
          </p>
          <router-link :to="accountScopedUrl('settings/macros')">
            <Button
              faded
              xs
              icon="i-lucide-plus"
              :label="$t('MACROS.HEADER_BTN_TXT')"
              @click="closeModal"
            />
          </router-link>
        </div>

        <!-- Macros list -->
        <div v-else class="space-y-2">
          <button
            v-for="macro in orderedMacros"
            :key="macro.id"
            type="button"
            class="flex items-center justify-between w-full px-4 py-3 text-left transition-colors rounded-lg hover:bg-n-slate-3 dark:hover:bg-n-slate-9"
            :disabled="executingMacroId !== null"
            @click="executeMacroAndResolve(macro)"
          >
            <div class="flex-1 min-w-0">
              <p class="font-medium text-n-slate-12">{{ macro.name }}</p>
              <p
                v-if="macro.actions?.length"
                class="text-xs text-n-slate-11 mt-0.5"
              >
                {{ macro.actions.length }}
                {{
                  macro.actions.length === 1
                    ? $t('MACROS.LIST.ACTION')
                    : $t('MACROS.LIST.ACTIONS')
                }}
              </p>
            </div>
            <div class="flex items-center gap-2">
              <Spinner v-if="executingMacroId === macro.id" class="size-4" />
              <i v-else class="text-lg i-lucide-play text-n-slate-11" />
            </div>
          </button>
        </div>
      </div>

      <div
        class="flex items-center justify-end gap-3 px-8 py-4 border-t border-n-weak"
      >
        <Button
          :label="$t('CONVERSATION.RESOLVE_MODAL.CANCEL')"
          color="slate"
          ghost
          @click="closeModal"
        />
        <Button
          :label="$t('CONVERSATION.RESOLVE_MODAL.RESOLVE_WITHOUT_MACRO')"
          color="primary"
          :is-loading="isResolving"
          @click="resolveWithoutMacro"
        />
      </div>
    </div>
  </Modal>
</template>
