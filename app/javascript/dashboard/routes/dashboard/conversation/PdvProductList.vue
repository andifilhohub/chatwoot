<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useStore } from 'vuex';

const emit = defineEmits(['add-to-cart']);

// Vuex store-backed products
const store = useStore();
const page = ref(1);
const limit = ref(40);
const totalCount = ref(0);

const searchQuery = ref('');
const selectedCategory = ref('all');

const categories = computed(() => {
  const cats = new Set((store.state.integrahubProducts?.items || []).map((p) => p.category).filter(Boolean));
  return ['all', ...Array.from(cats)];
});

const filteredProducts = computed(() => {
  let items = store.state.integrahubProducts?.items || [];
  if (selectedCategory.value !== 'all') {
    items = items.filter((p) => p.category === selectedCategory.value);
  }
  return items;
});

const fetchProducts = async () => {
  // dispatch to vuex module; module uses ApiClient to call backend
  await store.dispatch('integrahubProducts/fetch', {
    q: searchQuery.value || undefined,
    limit: limit.value,
    page: page.value,
  });
  const pagination = store.state.integrahubProducts?.pagination || {};
  totalCount.value = pagination.count || 0;
};

const loading = computed(() => store.state.integrahubProducts?.uiFlags?.isFetching);

let debounceTimer = null;
watch(searchQuery, () => {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    page.value = 1;
    fetchProducts();
  }, 350);
});

watch(selectedCategory, () => {
  // category filtering is client-side, but re-fetch in case API supports category in q
  page.value = 1;
  fetchProducts();
});

onMounted(() => {
  fetchProducts();
});

const formatPrice = (price) => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(price);
};

const handleAddToCart = (product) => {
  emit('add-to-cart', product);
};
</script>

<template>
  <div class="flex flex-col h-full">
    <!-- Busca e Filtros -->
    <div class="p-4 space-y-3 border-b border-n-weak">
      <Input
        v-model="searchQuery"
        :placeholder="$t('PDV.SEARCH_PRODUCTS')"
        icon="i-ph-magnifying-glass-bold"
      />
      
      <div class="flex gap-2 overflow-x-auto">
        <Button
          v-for="category in categories"
          :key="category"
          :variant="selectedCategory === category ? 'solid' : 'ghost'"
          sm
          slate
          @click="selectedCategory = category"
        >
          {{ category === 'all' ? $t('PDV.ALL_CATEGORIES') : category }}
        </Button>
      </div>
    </div>

    <!-- Lista de Produtos -->
    <div class="flex-1 overflow-y-auto p-4 space-y-3">
      <div
          v-if="!loading && filteredProducts.length === 0"
        class="flex flex-col items-center justify-center h-full text-center py-8"
      >
        <span class="text-4xl mb-2">📦</span>
        <p class="text-n-text-subtle">
          {{ $t('PDV.NO_PRODUCTS_FOUND') }}
        </p>
      </div>

        <div v-if="loading" class="flex items-center justify-center py-8">
          <span>Loading...</span>
        </div>

      <div
        v-for="product in filteredProducts"
        :key="product.id"
        class="bg-n-solid-1 rounded-lg p-4 border border-n-weak hover:border-n-brand transition-colors"
      >
        <div class="flex gap-3">
          <!-- Imagem do Produto -->
          <div class="w-16 h-16 bg-n-solid-2 rounded flex items-center justify-center flex-shrink-0">
            <span class="text-2xl">📦</span>
          </div>

          <!-- Informações do Produto -->
          <div class="flex-1 min-w-0">
            <h4 class="font-semibold text-n-text truncate">
              {{ product.name }}
            </h4>
            <p class="text-xs text-n-text-subtle">
              SKU: {{ product.sku }}
            </p>
            <div class="flex items-center justify-between mt-2">
              <span class="text-lg font-bold text-n-brand">
                {{ formatPrice(product.price) }}
              </span>
              <span
                class="text-xs px-2 py-1 rounded"
                :class="
                  product.stock > 5
                    ? 'bg-green-100 text-green-800'
                    : product.stock > 0
                      ? 'bg-yellow-100 text-yellow-800'
                      : 'bg-red-100 text-red-800'
                "
              >
                {{ product.stock }} em estoque
              </span>
            </div>
          </div>
        </div>

        <!-- Botão Adicionar -->
        <Button
          class="w-full mt-3"
          sm
          :disabled="product.stock === 0"
          @click="handleAddToCart(product)"
        >
          <span class="i-ph-shopping-cart-bold mr-2" />
          {{ product.stock > 0 ? $t('PDV.ADD_TO_CART') : $t('PDV.OUT_OF_STOCK') }}
        </Button>
      </div>
    </div>
  </div>
</template>
