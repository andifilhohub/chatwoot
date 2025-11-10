<script setup>
import { ref, reactive, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { debounce } from '@chatwoot/utils';
import { useAccount } from 'dashboard/composables/useAccount';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import ScheduledMessagesAPI from 'dashboard/api/scheduledMessages';
import ScheduledMessageEditModal from 'dashboard/components/scheduled-messages/ScheduledMessageEditModal.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { frontendURL } from 'dashboard/helper/URLHelper';
import { format } from 'date-fns';

const { t } = useI18n();
const { accountId } = useAccount();
const store = useStore();
const route = useRoute();
const router = useRouter();

const messages = ref([]);
const meta = ref({ total_count: 0, total_pages: 1, current_page: 1 });
const isLoading = ref(false);
const isEditModalOpen = ref(false);
const selectedScheduledMessage = ref(null);
const showFilters = ref(false);
const expandedMessageId = ref(null);

const filters = reactive({
  search: route.query.search || '',
  status: route.query.status || '',
  agentId: route.query.agent_id ? Number(route.query.agent_id) : null,
  inboxId: route.query.inbox_id ? Number(route.query.inbox_id) : null,
  scheduledFrom: route.query.scheduled_from || '',
  scheduledTo: route.query.scheduled_to || '',
  createdFrom: route.query.created_from || '',
  createdTo: route.query.created_to || '',
});

const pagination = reactive({
  page: Number(route.query.page) || 1,
  perPage: Number(route.query.per_page) || 25,
});

const statusOptions = [
  { value: '', label: t('SCHEDULED_MESSAGES.ALL_STATUSES') },
  { value: 'scheduled', label: t('SCHEDULED_MESSAGES.STATUS.SCHEDULED') },
  { value: 'processing', label: t('SCHEDULED_MESSAGES.STATUS.PROCESSING') },
  { value: 'sent', label: t('SCHEDULED_MESSAGES.STATUS.SENT') },
  { value: 'cancelled', label: t('SCHEDULED_MESSAGES.STATUS.CANCELLED') },
  { value: 'failed', label: t('SCHEDULED_MESSAGES.STATUS.FAILED') },
];

const hasActiveFilters = computed(
  () =>
    Boolean(
      filters.status ||
        filters.agentId ||
        filters.inboxId ||
        filters.scheduledFrom ||
        filters.scheduledTo ||
        filters.createdFrom ||
        filters.createdTo
    )
);

const agents = useMapGetter('agents/getAgents');
const inboxes = useMapGetter('inboxes/getInboxes');

const searchHandler = debounce(() => {
  pagination.page = 1;
  updateRouteQuery();
  fetchMessages();
}, 300);

const handleSearchInput = value => {
  filters.search = value;
  searchHandler();
};

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('inboxes/get');
  fetchMessages();
});

const buildParams = () => {
  const params = {
    page: pagination.page,
    per_page: pagination.perPage,
  };

  if (filters.search) params.q = filters.search;
  if (filters.status) params.status = filters.status;
  if (filters.agentId) params.agent_id = filters.agentId;
  if (filters.inboxId) params.inbox_id = filters.inboxId;
  if (filters.scheduledFrom) params.scheduled_from = filters.scheduledFrom;
  if (filters.scheduledTo) params.scheduled_to = filters.scheduledTo;
  if (filters.createdFrom) params.created_from = filters.createdFrom;
  if (filters.createdTo) params.created_to = filters.createdTo;

  return params;
};

const updateRouteQuery = () => {
  const query = {
    page: pagination.page,
    per_page: pagination.perPage,
  };

  if (filters.search) query.search = filters.search;
  if (filters.status) query.status = filters.status;
  if (filters.agentId) query.agent_id = filters.agentId;
  if (filters.inboxId) query.inbox_id = filters.inboxId;
  if (filters.scheduledFrom) query.scheduled_from = filters.scheduledFrom;
  if (filters.scheduledTo) query.scheduled_to = filters.scheduledTo;
  if (filters.createdFrom) query.created_from = filters.createdFrom;
  if (filters.createdTo) query.created_to = filters.createdTo;

  router.replace({ query });
};

const fetchMessages = async () => {
  isLoading.value = true;
  try {
    const { data } = await ScheduledMessagesAPI.list(buildParams());
    messages.value = data.data || [];
    meta.value = data.meta || { total_count: 0, total_pages: 1, current_page: 1 };
  } catch (error) {
    useAlert(t('SCHEDULED_MESSAGES.ERRORS.FETCH'));
  } finally {
    isLoading.value = false;
  }
};

const applyFilters = () => {
  pagination.page = 1;
  updateRouteQuery();
  fetchMessages();
  closeFilters();
};

const resetFilters = () => {
  filters.search = '';
  filters.status = '';
  filters.agentId = null;
  filters.inboxId = null;
  filters.scheduledFrom = '';
  filters.scheduledTo = '';
  filters.createdFrom = '';
  filters.createdTo = '';
  applyFilters();
};

const goToPage = page => {
  const maxPages = meta.value?.total_pages || 1;
  if (page < 1 || page > maxPages) return;
  pagination.page = page;
  updateRouteQuery();
  fetchMessages();
};

const formatTimestamp = timestamp => {
  if (!timestamp) return '—';
  const date = new Date(Number(timestamp) * 1000);
  if (Number.isNaN(date.getTime())) return '—';
  const formatted = format(date, 'MMM d, yyyy h:mm a');
  return formatted;
};

const resolveTimezone = () => null;

const formatCreatedAt = timestamp => {
  if (!timestamp) return '—';
  const value = Number(timestamp);
  if (Number.isNaN(value)) return '—';
  return format(new Date(value * 1000), 'MMM d, yyyy h:mm a');
};

const resolveScheduledTimestamp = scheduledMessage => {
  if (scheduledMessage.scheduled_at) {
    return scheduledMessage.scheduled_at;
  }

  const info = scheduledMessage.message?.schedule_info;
  if (info?.scheduled_at) {
    const parsed = Date.parse(info.scheduled_at);
    if (!Number.isNaN(parsed)) {
      return Math.floor(parsed / 1000);
    }
  }

  return null;
};

const statusLabel = status => {
  if (!status) return t('SCHEDULED_MESSAGES.STATUS.SCHEDULED');
  const key = status.toUpperCase();
  return t(`SCHEDULED_MESSAGES.STATUS.${key}`);
};

const statusClass = status => {
  const map = {
    scheduled: 'bg-n-amber-3 text-n-amber-12 border-n-amber-6',
    processing: 'bg-n-blue-3 text-n-blue-12 border-n-blue-6',
    sent: 'bg-n-teal-3 text-n-teal-12 border-n-amber-6',
    cancelled: 'bg-n-slate-3 text-n-slate-11 border-n-slate-6',
    failed: 'bg-n-ruby-4 text-n-ruby-12 border-n-ruby-8',
  };
  return map[status] || 'bg-n-slate-3 text-n-slate-11 border-n-slate-6';
};

const conversationLink = message => {
  const conversationDisplayId = message.message?.conversation_id;
  return frontendURL(
    `accounts/${accountId}/conversations/${conversationDisplayId}`
  );
};

const canEdit = status => ['scheduled', 'processing'].includes(status);

const handleEdit = scheduledMessage => {
  selectedScheduledMessage.value = scheduledMessage;
  isEditModalOpen.value = true;
};

const handleEditSubmit = async ({ content, scheduledAt, timezone }) => {
  if (!selectedScheduledMessage.value) return;
  try {
    const { data } = await ScheduledMessagesAPI.update(
      selectedScheduledMessage.value.id,
      {
        content,
        scheduled_at: scheduledAt,
        scheduled_timezone: timezone,
      }
    );
    store.dispatch('conversations/updateMessage', data);
    useAlert(t('SCHEDULED_MESSAGES.SUCCESS.UPDATE'));
    closeEditModal();
    fetchMessages();
  } catch (error) {
    useAlert(t('SCHEDULED_MESSAGES.ERRORS.UPDATE'));
  }
};

const handleCancelSchedule = async scheduledMessage => {
  if (!scheduledMessage) return;
  const confirmed = window.confirm(t('SCHEDULED_MESSAGES.CONFIRM_DELETE'));
  if (!confirmed) return;

  try {
    const { data } = await ScheduledMessagesAPI.delete(scheduledMessage.id);
    if (data) {
      store.dispatch('conversations/updateMessage', data);
    }
    useAlert(t('SCHEDULED_MESSAGES.SUCCESS.DELETE'));
    fetchMessages();
  } catch (error) {
    useAlert(t('SCHEDULED_MESSAGES.ERRORS.DELETE'));
  }
};

const totalCount = computed(() => meta.value?.total_count || 0);
const totalPages = computed(() => meta.value?.total_pages || 1);
const hasResults = computed(() => totalCount.value > 0);

const openFilters = () => {
  showFilters.value = true;
};

const closeFilters = () => {
  showFilters.value = false;
};

const toggleCard = id => {
  expandedMessageId.value = expandedMessageId.value === id ? null : id;
};

const isExpanded = id => expandedMessageId.value === id;

const closeEditModal = () => {
  isEditModalOpen.value = false;
  selectedScheduledMessage.value = null;
};
</script>

<template>
  <div class="flex flex-col h-full w-full">
    <header
      class="sticky top-0 z-10 border-b border-n-weak/80 bg-n-background/95 backdrop-blur"
    >
      <div class="mx-auto flex w-full max-w-[60rem] flex-col gap-4 px-6 py-4">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex flex-col gap-1">
            <h1 class="text-xl font-semibold text-n-slate-12">
              {{ t('SCHEDULED_MESSAGES.TITLE') }}
            </h1>
            <p class="text-sm text-n-slate-11">
              {{ t('SCHEDULED_MESSAGES.DESCRIPTION') }}
            </p>
          </div>
          <div class="flex w-full flex-col gap-3 sm:w-auto sm:flex-row sm:items-center">
            <Input
              class="w-full sm:w-72"
              :model-value="filters.search"
              type="search"
              :placeholder="t('SCHEDULED_MESSAGES.FILTERS.SEARCH_PLACEHOLDER')"
              :custom-input-class="[
                'h-10 [&:not(.focus)]:!border-transparent bg-n-alpha-2 dark:bg-n-solid-1 ltr:!pl-9 rtl:!pr-9',
              ]"
              @update:model-value="handleSearchInput"
            >
              <template #prefix>
                <span
                  class="absolute top-1/2 size-4 -translate-y-1/2 text-n-slate-11 i-lucide-search ltr:left-3 rtl:right-3"
                />
              </template>
            </Input>
            <div class="flex items-center gap-2">
              <NextButton
                ghost
                slate
                size="sm"
                :icon="showFilters ? 'i-lucide-filter-x' : 'i-lucide-list-filter'"
                @click="openFilters"
              >
                <span class="inline-flex items-center gap-2">
                  {{
                    showFilters
                      ? t('SCHEDULED_MESSAGES.FILTERS.HIDE_PANEL')
                      : t('SCHEDULED_MESSAGES.FILTERS.SHOW_PANEL')
                  }}
                  <span
                    v-if="hasActiveFilters"
                    class="h-2 w-2 rounded-full bg-n-brand"
                  />
                </span>
              </NextButton>
            </div>
          </div>
        </div>
      </div>
    </header>
    <transition name="fade">
      <div
        v-if="showFilters"
        class="fixed inset-0 z-40 flex items-center justify-center bg-black/40 backdrop-blur-sm px-4"
        @click="closeFilters"
      >
        <div
          class="w-full max-w-4xl rounded-2xl border border-n-weak bg-n-solid-1 shadow-2xl"
          @click.stop
        >
          <header class="flex items-center justify-between border-b border-n-weak px-6 py-4">
            <div>
              <h2 class="text-lg font-semibold text-n-slate-12">
                {{ t('SCHEDULED_MESSAGES.FILTERS_TITLE') || 'Filtrar mensagens agendadas' }}
              </h2>
              <p class="text-sm text-n-slate-11">
                {{ t('SCHEDULED_MESSAGES.FILTERS_SUBTITLE') || 'Refine a lista usando os filtros abaixo.' }}
              </p>
            </div>
            <button
              class="rounded-full p-2 text-n-slate-10 hover:text-n-slate-12 hover:bg-n-solid-3 transition-colors"
              @click="closeFilters"
            >
              <span class="i-lucide-x size-5" />
            </button>
          </header>
          <div class="max-h-[65vh] overflow-y-auto px-6 py-5">
            <div class="grid gap-5 md:grid-cols-2">
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold uppercase text-n-slate-10">
                  {{ t('SCHEDULED_MESSAGES.FILTERS.STATUS') }}
                </label>
                <select
                  v-model="filters.status"
                  class="rounded-xl border border-n-weak bg-transparent px-3 py-2 text-sm focus:border-n-brand focus:outline-none"
                >
                  <option
                    v-for="status in statusOptions"
                    :key="status.value || 'all'"
                    :value="status.value"
                  >
                    {{ status.label }}
                  </option>
                </select>
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold uppercase text-n-slate-10">
                  {{ t('SCHEDULED_MESSAGES.FILTERS.AGENT') }}
                </label>
                <select
                  v-model="filters.agentId"
                  class="rounded-xl border border-n-weak bg-transparent px-3 py-2 text-sm focus:border-n-brand focus:outline-none"
                >
                  <option :value="null">—</option>
                  <option
                    v-for="agent in agents"
                    :key="agent.id"
                    :value="agent.id"
                  >
                    {{ agent.name }}
                  </option>
                </select>
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold uppercase text-n-slate-10">
                  {{ t('SCHEDULED_MESSAGES.FILTERS.INBOX') }}
                </label>
                <select
                  v-model="filters.inboxId"
                  class="rounded-xl border border-n-weak bg-transparent px-3 py-2 text-sm focus:border-n-brand focus:outline-none"
                >
                  <option :value="null">—</option>
                  <option
                    v-for="inbox in inboxes"
                    :key="inbox.id"
                    :value="inbox.id"
                  >
                    {{ inbox.name }}
                  </option>
                </select>
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold uppercase text-n-slate-10">
                  {{ t('SCHEDULED_MESSAGES.FILTERS.SCHEDULED_FROM') }}
                </label>
                <input
                  v-model="filters.scheduledFrom"
                  class="rounded-xl border border-n-weak bg-transparent px-3 py-2 text-sm focus:border-n-brand focus:outline-none"
                  type="date"
                />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold uppercase text-n-slate-10">
                  {{ t('SCHEDULED_MESSAGES.FILTERS.SCHEDULED_TO') }}
                </label>
                <input
                  v-model="filters.scheduledTo"
                  class="rounded-xl border border-n-weak bg-transparent px-3 py-2 text-sm focus:border-n-brand focus:outline-none"
                  type="date"
                />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold uppercase text-n-slate-10">
                  {{ t('SCHEDULED_MESSAGES.FILTERS.CREATED_FROM') }}
                </label>
                <input
                  v-model="filters.createdFrom"
                  class="rounded-xl border border-n-weak bg-transparent px-3 py-2 text-sm focus:border-n-brand focus:outline-none"
                  type="date"
                />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold uppercase text-n-slate-10">
                  {{ t('SCHEDULED_MESSAGES.FILTERS.CREATED_TO') }}
                </label>
                <input
                  v-model="filters.createdTo"
                  class="rounded-xl border border-n-weak bg-transparent px-3 py-2 text-sm focus:border-n-brand focus:outline-none"
                  type="date"
                />
              </div>
            </div>
          </div>
          <footer class="flex flex-wrap items-center justify-end gap-3 border-t border-n-weak px-6 py-4">
            <NextButton
              faded
              slate
              :label="t('SCHEDULED_MESSAGES.FILTERS.RESET')"
              @click="resetFilters"
            />
            <NextButton
              :label="t('SCHEDULED_MESSAGES.FILTERS.APPLY')"
              @click="applyFilters"
            />
          </footer>
        </div>
      </div>
    </transition>
    <section class="flex-1 overflow-auto">
      <div v-if="isLoading" class="flex h-full items-center justify-center">
        <Spinner />
      </div>
      <div v-else-if="!hasResults" class="flex h-full flex-col items-center justify-center gap-2">
        <h3 class="text-lg font-medium text-n-slate-12">
          {{ t('SCHEDULED_MESSAGES.EMPTY.TITLE') }}
        </h3>
        <p class="text-sm text-n-slate-11">
          {{ t('SCHEDULED_MESSAGES.EMPTY.DESCRIPTION') }}
        </p>
      </div>
      <div v-else class="px-6 py-4">
        <div class="mx-auto flex w-full max-w-[60rem] flex-col gap-4">
          <CardLayout
            v-for="scheduledMessage in messages"
            :key="scheduledMessage.id"
          >
            <div class="flex w-full flex-col gap-4">
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div class="flex min-w-0 flex-1 items-center gap-3">
                  <Avatar
                    :name="scheduledMessage.contact?.name || '—'"
                    :src="scheduledMessage.contact?.avatar_url || ''"
                    :size="48"
                    rounded-full
                  />
                  <div class="min-w-0 flex flex-1 flex-col gap-0.5">
                    <div class="flex min-w-0 items-center gap-2">
                      <p class="truncate text-base font-semibold text-n-slate-12">
                        {{ scheduledMessage.contact?.name || '—' }}
                      </p>
                    </div>
                    <p class="truncate text-sm text-n-slate-11">
                      {{
                        scheduledMessage.contact?.email ||
                          scheduledMessage.contact?.phone_number ||
                          '—'
                      }}
                    </p>
                  </div>
                </div>
                <div class="flex items-center gap-2">
                  <span
                    class="inline-flex items-center rounded-full border px-3 py-1 text-xs font-medium"
                    :class="statusClass(scheduledMessage.status)"
                  >
                    {{ statusLabel(scheduledMessage.status) }}
                  </span>
                  <NextButton
                    icon="i-lucide-chevron-down"
                    color="slate"
                    ghost
                    size="xs"
                    class="transition-transform"
                    :class="{ 'rotate-180': isExpanded(scheduledMessage.id) }"
                    @click.stop="toggleCard(scheduledMessage.id)"
                  />
                </div>
              </div>

              <div
                :class="[
                  'w-full rounded-2xl border border-n-weak/60 bg-n-solid-1 px-4 py-3',
                  isExpanded(scheduledMessage.id) ? '' : 'max-h-32 overflow-hidden',
                ]"
              >
                <p class="text-sm text-n-slate-12 whitespace-pre-wrap line-clamp-5">
                  {{ scheduledMessage.message?.content || '—' }}
                </p>
              </div>

              <transition name="fade">
                <div
                  v-if="isExpanded(scheduledMessage.id)"
                  class="flex flex-col gap-4 border-t border-n-weak pt-4"
                >
                  <div class="grid gap-4 text-sm text-n-slate-12 md:grid-cols-2 lg:grid-cols-4">
                    <div class="flex flex-col gap-1">
                      <span class="text-xs font-semibold uppercase text-n-slate-10">
                        {{ t('SCHEDULED_MESSAGES.TABLE.SCHEDULED_FOR') }}
                      </span>
                      <span>
                        {{ formatTimestamp(resolveScheduledTimestamp(scheduledMessage)) }}
                      </span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-xs font-semibold uppercase text-n-slate-10">
                        {{ t('SCHEDULED_MESSAGES.TABLE.INBOX') }}
                      </span>
                      <span>{{ scheduledMessage.inbox?.name || '—' }}</span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-xs font-semibold uppercase text-n-slate-10">
                        {{ t('SCHEDULED_MESSAGES.TABLE.AGENT') }}
                      </span>
                      <span>{{ scheduledMessage.message?.sender?.name || '—' }}</span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-xs font-semibold uppercase text-n-slate-10">
                        {{ t('SCHEDULED_MESSAGES.TABLE.ATTACHMENTS') }}
                      </span>
                      <span>{{ scheduledMessage.attachments_count || 0 }}</span>
                    </div>
                    <div class="flex flex-col gap-1">
                      <span class="text-xs font-semibold uppercase text-n-slate-10">
                        {{ t('SCHEDULED_MESSAGES.TABLE.RECURRENCE') }}
                      </span>
                      <span>—</span>
                    </div>
                  </div>

                  <div class="flex flex-wrap items-center justify-between gap-3 border-t border-n-weak pt-4">
                    <div class="flex flex-col gap-1 text-sm text-n-slate-12">
                      <span class="text-xs font-semibold uppercase text-n-slate-10">
                        {{ t('SCHEDULED_MESSAGES.TABLE.CREATED_AT') }}
                      </span>
                      <span>
                        {{ formatCreatedAt(scheduledMessage.message?.created_at) }}
                      </span>
                    </div>
                    <div class="flex flex-wrap gap-2">
                      <NextButton
                        size="sm"
                        variant="link"
                        :label="t('SCHEDULED_MESSAGES.ACTIONS.VIEW')"
                        :href="conversationLink(scheduledMessage)"
                        target="_blank"
                      />
                      <NextButton
                        v-if="canEdit(scheduledMessage.status)"
                        size="sm"
                        variant="link"
                        :label="t('SCHEDULED_MESSAGES.ACTIONS.EDIT')"
                        @click="handleEdit(scheduledMessage)"
                      />
                      <NextButton
                        v-if="canEdit(scheduledMessage.status)"
                        size="sm"
                        variant="link"
                        :label="t('SCHEDULED_MESSAGES.ACTIONS.DELETE')"
                        @click="handleCancelSchedule(scheduledMessage)"
                      />
                    </div>
                  </div>
                </div>
              </transition>
            </div>
          </CardLayout>
        </div>
      </div>
    </section>
    <footer v-if="hasResults" class="flex items-center justify-between border-t border-n-weak px-6 py-3 text-sm">
      <span class="text-n-slate-11">
        {{ totalCount }}
        {{ totalCount === 1 ? 'item' : 'items' }}
      </span>
      <div class="flex items-center gap-2">
        <NextButton
          faded
          slate
          size="sm"
          :disabled="pagination.page === 1"
          @click="goToPage(pagination.page - 1)"
        >
          ‹
        </NextButton>
        <span>
          {{ pagination.page }} / {{ totalPages }}
        </span>
        <NextButton
          faded
          slate
          size="sm"
          :disabled="pagination.page >= totalPages"
          @click="goToPage(pagination.page + 1)"
        >
          ›
        </NextButton>
      </div>
    </footer>

    <ScheduledMessageEditModal
      v-if="isEditModalOpen"
      :show="isEditModalOpen"
      :scheduled-message="selectedScheduledMessage"
      @close="closeEditModal"
      @submit="handleEditSubmit"
    />
  </div>
</template>
