<script>
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import AddCannedModal from 'dashboard/routes/dashboard/settings/canned/AddCanned.vue';
import { useSnakeCase } from 'dashboard/composables/useTransformKeys';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import { conversationUrl, frontendURL } from '../../../helper/URLHelper';
import {
  ACCOUNT_EVENTS,
  CONVERSATION_EVENTS,
} from '../../../helper/AnalyticsHelper/events';
import MenuItem from '../../../components/widgets/conversation/contextMenu/menuItem.vue';
import { useTrack } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    AddCannedModal,
    MenuItem,
    ContextMenu,
    NextButton,
  },
  props: {
    message: {
      type: Object,
      required: true,
    },
    isOpen: {
      type: Boolean,
      default: false,
    },
    enabledOptions: {
      type: Object,
      default: () => ({}),
    },
    contextMenuPosition: {
      type: Object,
      default: () => ({}),
    },
    hideButton: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['open', 'close', 'replyTo'],
  setup() {
    const { getPlainText } = useMessageFormatter();

    return {
      getPlainText,
    };
  },
  data() {
    return {
      isCannedResponseModalOpen: false,
      showDeleteModal: false,
      showEditModal: false,
      editedContent: '',
    };
  },
  computed: {
    ...mapGetters({
      getAccount: 'accounts/getAccount',
      currentAccountId: 'getCurrentAccountId',
    }),
    plainTextContent() {
      return this.getPlainText(this.messageContent);
    },
    conversationId() {
      return this.message.conversation_id ?? this.message.conversationId;
    },
    messageId() {
      return this.message.id;
    },
    messageContent() {
      return this.message.content;
    },
    contentAttributes() {
      return useSnakeCase(
        this.message.content_attributes ?? this.message.contentAttributes
      );
    },
  },
  methods: {
    async copyLinkToMessage() {
      const fullConversationURL =
        window.chatwootConfig.hostURL +
        frontendURL(
          conversationUrl({
            id: this.conversationId,
            accountId: this.currentAccountId,
          })
        );
      await copyTextToClipboard(
        `${fullConversationURL}?messageId=${this.messageId}`
      );
      useAlert(this.$t('CONVERSATION.CONTEXT_MENU.LINK_COPIED'));
      this.handleClose();
    },
    async handleCopy() {
      await copyTextToClipboard(this.plainTextContent);
      useAlert(this.$t('CONTACT_PANEL.COPY_SUCCESSFUL'));
      this.handleClose();
    },
    showCannedResponseModal() {
      useTrack(ACCOUNT_EVENTS.ADDED_TO_CANNED_RESPONSE);
      this.isCannedResponseModalOpen = true;
    },
    hideCannedResponseModal() {
      this.isCannedResponseModalOpen = false;
      this.handleClose();
    },
    handleOpen(e) {
      this.$emit('open', e);
    },
    handleClose(e) {
      this.$emit('close', e);
    },
    handleTranslate() {
      const { locale } = this.getAccount(this.currentAccountId);
      this.$store.dispatch('translateMessage', {
        conversationId: this.conversationId,
        messageId: this.messageId,
        targetLanguage: locale || 'en',
      });
      useTrack(CONVERSATION_EVENTS.TRANSLATE_A_MESSAGE);
      this.handleClose();
    },
    handleReplyTo() {
      this.$emit('replyTo', this.message);
      this.handleClose();
    },
    openDeleteModal() {
      this.handleClose();
      this.showDeleteModal = true;
    },
    async confirmDeletion() {
      try {
        await this.$store.dispatch('deleteMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
        });
        useAlert(this.$t('CONVERSATION.SUCCESS_DELETE_MESSAGE'));
        this.handleClose();
      } catch (error) {
        useAlert(this.$t('CONVERSATION.FAIL_DELETE_MESSSAGE'));
      }
    },
    closeDeleteModal() {
      this.showDeleteModal = false;
    },
    openEditModal() {
      this.handleClose();
      this.editedContent = this.plainTextContent;
      this.showEditModal = true;
    },
    closeEditModal() {
      this.showEditModal = false;
      this.editedContent = '';
    },
    async confirmEdit() {
      if (!this.editedContent || this.editedContent.trim() === '') {
        useAlert(this.$t('CONVERSATION.EDIT_MESSAGE.EMPTY_CONTENT'));
        return;
      }

      try {
        await this.$store.dispatch('editMessage', {
          conversationId: this.conversationId,
          messageId: this.messageId,
          content: this.editedContent.trim(),
        });
        useAlert(this.$t('CONVERSATION.EDIT_MESSAGE.SUCCESS'));
        this.closeEditModal();
      } catch (error) {
        useAlert(this.$t('CONVERSATION.EDIT_MESSAGE.FAIL'));
      }
    },
  },
};
</script>

<template>
  <div class="context-menu">
    <!-- Add To Canned Responses -->
    <woot-modal
      v-if="isCannedResponseModalOpen && enabledOptions['cannedResponse']"
      v-model:show="isCannedResponseModalOpen"
      :on-close="hideCannedResponseModal"
    >
      <AddCannedModal
        :response-content="plainTextContent"
        :on-close="hideCannedResponseModal"
      />
    </woot-modal>
    <!-- Confirm Deletion -->
    <woot-delete-modal
      v-if="showDeleteModal && enabledOptions['delete']"
      v-model:show="showDeleteModal"
      class="context-menu--delete-modal"
      :on-close="closeDeleteModal"
      :on-confirm="confirmDeletion"
      :title="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.TITLE')"
      :message="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.MESSAGE')"
      :confirm-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.DELETE')"
      :reject-text="$t('CONVERSATION.CONTEXT_MENU.DELETE_CONFIRMATION.CANCEL')"
    />
    <!-- Edit Message Modal -->
    <woot-modal
      v-if="showEditModal && enabledOptions['edit']"
      v-model:show="showEditModal"
      :on-close="closeEditModal"
      :size="'medium'"
    >
      <div class="edit-message-modal">
        <h3 class="modal-title">
          {{ $t('CONVERSATION.CONTEXT_MENU.EDIT_MESSAGE') }}
        </h3>
        <div class="modal-content">
          <textarea
            v-model="editedContent"
            class="edit-message-textarea"
            :placeholder="$t('CONVERSATION.EDIT_MESSAGE.PLACEHOLDER')"
            rows="5"
          />
        </div>
        <div class="modal-footer">
          <NextButton
            variant="smooth"
            color-scheme="secondary"
            @click="closeEditModal"
          >
            {{ $t('CONVERSATION.CONTEXT_MENU.CANCEL') }}
          </NextButton>
          <NextButton
            variant="smooth"
            color-scheme="primary"
            @click="confirmEdit"
          >
            {{ $t('CONVERSATION.CONTEXT_MENU.SAVE') }}
          </NextButton>
        </div>
      </div>
    </woot-modal>
    <NextButton
      v-if="!hideButton"
      ghost
      slate
      sm
      icon="i-lucide-ellipsis-vertical"
      class="invisible group-hover/context-menu:visible"
      @click="handleOpen"
    />
    <ContextMenu
      v-if="isOpen && !isCannedResponseModalOpen"
      :x="contextMenuPosition.x"
      :y="contextMenuPosition.y"
      @close="handleClose"
    >
      <div class="menu-container">
        <MenuItem
          v-if="enabledOptions['replyTo']"
          :option="{
            icon: 'arrow-reply',
            label: $t('CONVERSATION.CONTEXT_MENU.REPLY_TO'),
          }"
          variant="icon"
          @click.stop="handleReplyTo"
        />
        <MenuItem
          v-if="enabledOptions['copy']"
          :option="{
            icon: 'clipboard',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY'),
          }"
          variant="icon"
          @click.stop="handleCopy"
        />
        <MenuItem
          v-if="enabledOptions['translate']"
          :option="{
            icon: 'translate',
            label: $t('CONVERSATION.CONTEXT_MENU.TRANSLATE'),
          }"
          variant="icon"
          @click.stop="handleTranslate"
        />
        <hr />
        <MenuItem
          v-if="enabledOptions['copyLink']"
          :option="{
            icon: 'link',
            label: $t('CONVERSATION.CONTEXT_MENU.COPY_PERMALINK'),
          }"
          variant="icon"
          @click.stop="copyLinkToMessage"
        />
        <MenuItem
          v-if="enabledOptions['cannedResponse']"
          :option="{
            icon: 'comment-add',
            label: $t('CONVERSATION.CONTEXT_MENU.CREATE_A_CANNED_RESPONSE'),
          }"
          variant="icon"
          @click.stop="showCannedResponseModal"
        />
        <hr v-if="enabledOptions['edit'] || enabledOptions['delete']" />
        <MenuItem
          v-if="enabledOptions['edit']"
          :option="{
            icon: 'edit',
            label: $t('CONVERSATION.CONTEXT_MENU.EDIT'),
          }"
          variant="icon"
          @click.stop="openEditModal"
        />
        <MenuItem
          v-if="enabledOptions['delete']"
          :option="{
            icon: 'delete',
            label: $t('CONVERSATION.CONTEXT_MENU.DELETE'),
          }"
          variant="icon"
          @click.stop="openDeleteModal"
        />
      </div>
    </ContextMenu>
  </div>
</template>

<style lang="scss" scoped>
.menu-container {
  @apply p-1 bg-n-background shadow-xl rounded-md;

  hr:first-child {
    @apply hidden;
  }

  hr {
    @apply m-1 border-b border-solid border-n-strong;
  }
}

.context-menu--delete-modal {
  ::v-deep {
    .modal-container {
      @apply max-w-[30rem];

      h2 {
        @apply font-medium text-base;
      }
    }
  }
}

.edit-message-modal {
  @apply p-4;

  .modal-title {
    @apply text-lg font-semibold mb-4;
  }

  .modal-content {
    @apply mb-4;

    .edit-message-textarea {
      @apply w-full p-3 border border-n-slate-7 rounded-md resize-none;
      @apply focus:outline-none focus:ring-2 focus:ring-n-slate-9;
    }
  }

  .modal-footer {
    @apply flex justify-end gap-2;
  }
}
</style>
