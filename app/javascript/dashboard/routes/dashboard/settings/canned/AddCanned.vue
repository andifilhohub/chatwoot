<script>
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import { mapGetters } from 'vuex';
import { DirectUpload } from 'activestorage';
import FileUpload from 'vue-upload-component';
import { uploadFile } from 'dashboard/helper/uploadHelper';
import { checkFileSizeLimit, formatBytes } from 'shared/helpers/FileHelper';
import { MAXIMUM_FILE_UPLOAD_SIZE } from 'shared/constants/messages';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Modal from '../../../../components/Modal.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';

export default {
  name: 'AddCanned',
  components: {
    NextButton,
    Modal,
    WootMessageEditor,
    FileUpload,
  },
  props: {
    responseContent: {
      type: String,
      default: '',
    },
    onClose: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      shortCode: '',
      content: this.responseContent || '',
      addCanned: {
        showLoading: false,
        message: '',
      },
      attachments: [],
      pendingUploads: 0,
      maxFileSize: MAXIMUM_FILE_UPLOAD_SIZE,
      show: true,
    };
  },
  validations: {
    shortCode: {
      required,
      minLength: minLength(2),
    },
    content: {
      required,
    },
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      currentUser: 'getCurrentUser',
      globalConfig: 'globalConfig/get',
    }),
    maxFileSizeBytes() {
      return this.maxFileSize * 1024 * 1024;
    },
  },
  beforeUnmount() {
    this.attachments.forEach(attachment => {
      if (attachment?.file_url?.startsWith('blob:')) {
        URL.revokeObjectURL(attachment.file_url);
      }
    });
  },
  methods: {
    resetForm() {
      this.attachments.forEach(attachment => {
        if (attachment?.file_url?.startsWith('blob:')) {
          URL.revokeObjectURL(attachment.file_url);
        }
      });
      this.shortCode = '';
      this.content = '';
      this.attachments = [];
      this.v$.shortCode.$reset();
      this.v$.content.$reset();
    },
    formatSize(size) {
      return formatBytes(size || 0, 0);
    },
    serializeAttachments() {
      return this.attachments.map(attachment => {
        if (attachment.isPersisted) {
          return { blob_id: attachment.blob_id };
        }

        return { signed_id: attachment.signed_id };
      });
    },
    applyCannedAttachments(attachments = []) {
      attachments.forEach(attachment => {
        const isPersisted = Boolean(attachment?.blob_id);
        const formatted = {
          blob_id: attachment?.blob_id,
          signed_id: isPersisted ? undefined : attachment?.signed_id,
          filename: attachment?.filename,
          byte_size: attachment?.byte_size,
          file_type: attachment?.file_type,
          file_url: attachment?.file_url,
          isPersisted,
        };

        const exists = this.attachments.some(existing => {
          if (formatted.signed_id && existing.signed_id) {
            return existing.signed_id === formatted.signed_id;
          }
          if (formatted.blob_id && existing.blob_id) {
            return Number(existing.blob_id) === Number(formatted.blob_id);
          }
          return false;
        });

        if (!exists) {
          this.attachments.push(formatted);
        }
      });
    },
    removeAttachment(index) {
      const [removed] = this.attachments.splice(index, 1);
      if (removed?.file_url?.startsWith('blob:')) {
        URL.revokeObjectURL(removed.file_url);
      }
    },
    uploadFromDirectUpload(file) {
      this.pendingUploads += 1;
      const upload = new DirectUpload(
        file.file,
        `/api/v1/accounts/${this.accountId}/canned_responses/direct_uploads`,
        {
          directUploadWillCreateBlobWithXHR: xhr => {
            xhr.setRequestHeader(
              'api_access_token',
              this.currentUser.access_token
            );
          },
        }
      );

      upload.create((error, blob) => {
        if (error) {
          useAlert(error);
          this.pendingUploads = Math.max(this.pendingUploads - 1, 0);
        } else {
          const exists = this.attachments.some(
            attachment => attachment.signed_id === blob.signed_id
          );
          if (exists) {
            this.pendingUploads = Math.max(this.pendingUploads - 1, 0);
            return;
          }

          this.attachments.push({
            blob_id: blob.id,
            signed_id: blob.signed_id,
            filename: blob.filename,
            byte_size: blob.byte_size,
            file_type: blob.content_type,
            file_url: URL.createObjectURL(file.file),
            isPersisted: false,
          });
          this.pendingUploads = Math.max(this.pendingUploads - 1, 0);
        }
      });
    },
    async uploadViaBackend(file) {
      this.pendingUploads += 1;
      try {
        const { blobId, signedId, fileUrl } = await uploadFile(
          file.file,
          this.accountId
        );

        const exists = this.attachments.some(
          attachment => attachment.signed_id === signedId
        );
        if (exists) {
          this.pendingUploads = Math.max(this.pendingUploads - 1, 0);
          return;
        }

        this.attachments.push({
          blob_id: Number(blobId),
          signed_id: signedId,
          filename: file.file.name,
          byte_size: file.file.size,
          file_type: file.file.type,
          file_url: fileUrl,
          isPersisted: false,
        });
        this.pendingUploads = Math.max(this.pendingUploads - 1, 0);
      } catch (error) {
        useAlert(
          error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE')
        );
        this.pendingUploads = Math.max(this.pendingUploads - 1, 0);
      }
    },
    handleAttachmentUpload(file) {
      const files = Array.isArray(file) ? file : [file];

      files.forEach(fileItem => {
        if (!fileItem || !fileItem.file) return;

        if (!checkFileSizeLimit(fileItem, this.maxFileSize)) {
          useAlert(
            this.$t('CONVERSATION.FILE_SIZE_LIMIT', {
              MAXIMUM_SUPPORTED_FILE_UPLOAD_SIZE: this.maxFileSize,
            })
          );
          return;
        }

        if (this.globalConfig.directUploadsEnabled) {
          this.uploadFromDirectUpload(fileItem);
        } else {
          this.uploadViaBackend(fileItem);
        }
      });
    },
    addCannedResponse() {
      if (this.pendingUploads > 0) {
        useAlert(this.$t('CONVERSATION.FILE_UPLOAD_IN_PROGRESS'));
        return;
      }
      // Show loading on button
      this.addCanned.showLoading = true;
      // Make API Calls
      this.$store
        .dispatch('createCannedResponse', {
          short_code: this.shortCode,
          content: this.content,
          uploaded_files: this.serializeAttachments(),
        })
        .then(() => {
          // Reset Form, Show success message
          this.addCanned.showLoading = false;
          useAlert(this.$t('CANNED_MGMT.ADD.API.SUCCESS_MESSAGE'));
          this.resetForm();
          this.onClose();
        })
        .catch(error => {
          this.addCanned.showLoading = false;
          const errorMessage =
            error?.message || this.$t('CANNED_MGMT.ADD.API.ERROR_MESSAGE');
          useAlert(errorMessage);
        });
    },
  },
};
</script>

<template>
  <Modal v-model:show="show" :on-close="onClose">
    <div class="flex flex-col h-auto overflow-auto">
      <woot-modal-header
        :header-title="$t('CANNED_MGMT.ADD.TITLE')"
        :header-content="$t('CANNED_MGMT.ADD.DESC')"
      />
      <form class="flex flex-col w-full" @submit.prevent="addCannedResponse()">
        <div class="w-full">
          <label :class="{ error: v$.shortCode.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.SHORT_CODE.LABEL') }}
            <input
              v-model="shortCode"
              type="text"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.SHORT_CODE.PLACEHOLDER')"
              @blur="v$.shortCode.$touch"
            />
          </label>
        </div>

        <div class="w-full">
          <label :class="{ error: v$.content.$error }">
            {{ $t('CANNED_MGMT.ADD.FORM.CONTENT.LABEL') }}
          </label>
          <div class="editor-wrap">
            <WootMessageEditor
              v-model="content"
              class="message-editor [&>div]:px-1"
              :class="{ editor_warning: v$.content.$error }"
              enable-variables
              :enable-canned-responses="false"
              :placeholder="$t('CANNED_MGMT.ADD.FORM.CONTENT.PLACEHOLDER')"
              @blur="v$.content.$touch"
              @apply-canned-attachments="applyCannedAttachments"
            />
          </div>
        </div>
        <div class="w-full space-y-2">
          <label>
            {{ $t('CANNED_MGMT.FORM.ATTACHMENTS.LABEL') }}
          </label>
          <FileUpload
            input-id="cannedResponseAttachment"
            :multiple="true"
            :drop="true"
            :size="maxFileSizeBytes"
            @input-file="handleAttachmentUpload"
          >
            <NextButton
              icon="i-ph-paperclip"
              slate
              faded
              sm
              :label="$t('CANNED_MGMT.FORM.ATTACHMENTS.ADD')"
            />
          </FileUpload>
          <div
            v-if="attachments.length"
            class="flex flex-col gap-1 rounded-md border border-n-weak p-2"
          >
            <div
              v-for="(attachment, index) in attachments"
              :key="`${attachment.filename}-${index}`"
              class="flex items-center justify-between gap-2"
            >
              <div class="flex flex-col">
                <span class="text-sm font-medium">{{
                  attachment.filename
                }}</span>
                <span class="text-xs text-n-weak">
                  {{ formatSize(attachment.byte_size) }}
                </span>
              </div>
              <NextButton
                ghost
                slate
                xs
                icon="i-lucide-x"
                @click.prevent="removeAttachment(index)"
              />
            </div>
          </div>
        </div>
        <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
          <NextButton
            faded
            slate
            type="reset"
            :label="$t('CANNED_MGMT.ADD.CANCEL_BUTTON_TEXT')"
            @click.prevent="onClose"
          />
          <NextButton
            type="submit"
            :label="$t('CANNED_MGMT.ADD.FORM.SUBMIT')"
            :disabled="
              v$.content.$invalid ||
              v$.shortCode.$invalid ||
              addCanned.showLoading ||
              pendingUploads > 0
            "
            :is-loading="addCanned.showLoading"
          />
        </div>
      </form>
    </div>
  </Modal>
</template>

<style scoped lang="scss">
::v-deep {
  .ProseMirror-menubar {
    @apply hidden;
  }

  .ProseMirror-woot-style {
    @apply min-h-[12.5rem];

    p {
      @apply text-base;
    }
  }
}
</style>
