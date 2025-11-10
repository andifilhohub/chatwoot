import ScheduledMessagesIndex from './pages/ScheduledMessagesIndex.vue';

export const routes = [
  {
    path: 'scheduled-messages',
    name: 'scheduled_messages_index',
    meta: {
      permissions: ['administrator', 'agent', 'custom_role'],
    },
    component: ScheduledMessagesIndex,
  },
];
