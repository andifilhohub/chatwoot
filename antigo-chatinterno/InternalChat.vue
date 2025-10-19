<script>
export default {
  data() {
    return {
      username: '',
      newMessage: '',
      messages: [],
      isLoggedIn: false,
      user: { id: '', name: '', color: '' },
      websocket: null,
      colors: [
        'cadetblue',
        'darkgoldenrod',
        'cornflowerblue',
        'darkkhaki',
        'hotpink',
        'gold',
      ],
    };
  },
  methods: {
    closeInternalChatPanel() {
      this.$emit('close');
    },
    getRandomColor() {
      const randomIndex = Math.floor(Math.random() * this.colors.length);
      return this.colors[randomIndex];
    },
    scrollScreen() {
      this.$nextTick(() => {
        const chatMessages = this.$refs.chatMessages;
        chatMessages.scrollTop = chatMessages.scrollHeight;
      });
    },
    processMessage({ data }) {
      const { userId, userName, userColor, content } = JSON.parse(data);

      const message = {
        text: content,
        sender: userId === this.user.id ? null : userName,
        color: userColor,
      };

      this.messages.push(message);
      this.scrollScreen();
    },
    handleLogin() {
      this.user.id = crypto.randomUUID();
      this.user.name = this.username;
      this.user.color = this.getRandomColor();

      this.isLoggedIn = true;
      this.initializeWebSocket();
    },
    initializeWebSocket() {
      this.websocket = new WebSocket('ws://localhost:8080');
      this.websocket.onmessage = this.processMessage;
    },
    handleSendMessage() {
      const message = {
        userId: this.user.id,
        userName: this.user.name,
        userColor: this.user.color,
        content: this.newMessage,
      };

      this.websocket.send(JSON.stringify(message));
      this.newMessage = '';
    },
  },
};
</script>

<template>
  <div class="modal-mask">
    <div
      v-on-clickaway="closeInternalChatPanel"
      class="flex-col h-[90vh] w-[32.5rem] flex justify-between z-10 rounded-md shadow-md absolute bg-white dark:bg-slate-800 left-14 rtl:left-auto rtl:right-14"
    >
      <div
        class="flex flex-row items-center justify-between w-full px-6 pt-5 pb-3 border-b border-solid border-slate-50 dark:border-slate-700"
      >
        <div class="flex items-center">
          <span class="text-xl font-bold text-slate-800 dark:text-slate-100">
            {{ $t('INTERNAL_PAGE.UNREAD_INTERNAL.TITLE') }}
          </span>
          <span
            v-if="totalUnreadNotifications"
            class="px-2 py-1 ml-2 mr-2 font-semibold rounded-md text-slate-700 dark:text-slate-200 text-xxs bg-slate-50 dark:bg-slate-700"
          />
        </div>
        <div class="flex gap-2">
          <woot-button
            color-scheme="secondary"
            variant="link"
            size="tiny"
            icon="dismiss"
            @click="closeInternalChatPanel"
          />
        </div>
      </div>
      <div
        class="flex flex-row items-center justify-between w-full h-full border-b border-solid border-slate-50 dark:border-slate-700"
      >
        <div
          class="chat-messages flex-grow overflow-y-auto bg-gray-50 dark:bg-slate-800 p-4 rounded-t-md"
        >
          <!-- Mensagens vão aparecer aqui -->
          <div
            class="message-received bg-white dark:bg-slate-700 p-3 rounded-lg mb-4"
          >
            <p class="text-gray-700 dark:text-gray-200" />
          </div>
          <div
            class="message-sent bg-blue-500 text-white p-3 rounded-lg mb-4 self-end"
          >
            <p />
          </div>
        </div>
      </div>
      <div
        class="form-message w-full flex items-center bg-white dark:bg-slate-900 border-t border-slate-50 dark:border-slate-700"
      >
        <input
          type="text"
          class="flex-grow px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:bg-slate-700 dark:text-white mt-16"
        />
        <button
          class="ml-4 bg-blue-500 text-white rounded-full p-3 hover:bg-blue-600 transition"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-5 w-5"
            viewBox="0 0 20 20"
            fill="currentColor"
          >
            <path
              d="M2.94 15.44a.75.75 0 00.94.06L14.8 10l-10.9-5.5a.75.75 0 00-1.14.69v11a.75.75 0 001.28.44z"
            />
            |
          </svg>
        </button>
      </div>
    </div>
  </div>
</template>
