import IntegrahubProductsAPI from '../../api/integrahubProducts';

export const state = {
  items: [],
  pagination: { page: 1, limit: 40, count: 0 },
  uiFlags: {
    isFetching: false,
  },
  error: null,
};

export const getters = {
  allProducts: ($state) => $state.items,
  productsPagination: ($state) => $state.pagination,
  productsUIFlags: ($state) => $state.uiFlags,
};

export const actions = {
  fetch: async ({ commit }, { q, limit = 40, page = 1 } = {}) => {
    commit('SET_UI_FLAG', { isFetching: true });
    commit('SET_ERROR', null);
    try {
      const res = await IntegrahubProductsAPI.search({ q, limit, page });
      // Expected payload: { items, pagination: { page, limit, count } }
      const payload = res.data || {};
      const rawItems = payload.items || payload.data || [];
      // normalize items to the shape used by the PDV component
      const normalized = (rawItems || []).map((it) => ({
        id: it.productId || it.id || it.product_id,
        name: it.title || it.name || (it.rawJson && it.rawJson.title) || '',
        sku: (it.rawJson && it.rawJson.sku) || it.sku || it.productId || it.id,
        price: Number(it.price || (it.rawJson && it.rawJson.price) || 0),
        stock: Number(it.stock || (it.rawJson && it.rawJson.stock) || 0),
        brand: it.brand || (it.rawJson && it.rawJson.brand) || null,
        category: it.category || it.brand || (it.rawJson && it.rawJson.category) || null,
        raw: it.rawJson || it,
      }));

      commit('SET_ITEMS', normalized);
      commit('SET_PAGINATION', (payload.pagination || { page, limit, count: (payload.count || normalized.length) }));
    } catch (e) {
      commit('SET_ITEMS', []);
      commit('SET_PAGINATION', { page: 1, limit: 40, count: 0 });
      commit('SET_ERROR', e?.response?.data || { message: e.message });
    } finally {
      commit('SET_UI_FLAG', { isFetching: false });
    }
  },
};

export const mutations = {
  SET_ITEMS($state, items) {
    $state.items = items;
  },
  SET_PAGINATION($state, pagination) {
    $state.pagination = pagination;
  },
  SET_UI_FLAG($state, uiFlag) {
    $state.uiFlags = { ...$state.uiFlags, ...uiFlag };
  },
  SET_ERROR($state, error) {
    $state.error = error;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
