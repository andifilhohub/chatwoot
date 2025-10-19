export const state = {
  unreadTotal: 0,
};

export const getters = {
  getUnreadTotal: $state => $state.unreadTotal,
  getHasUnread: $state => $state.unreadTotal > 0,
};

export const mutations = {
  SET_UNREAD_TOTAL($state, total) {
    const n = Number(total) || 0;
    $state.unreadTotal = n < 0 ? 0 : n;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  mutations,
};

