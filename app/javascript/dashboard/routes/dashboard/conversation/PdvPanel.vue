<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import PdvProductList from './PdvProductList.vue';
import PdvCheckout from './PdvCheckout.vue';
import InovafarmaLogo from 'dashboard/assets/images/inovafarma.svg';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { LocalStorage } from 'shared/helpers/localStorage';

const props = defineProps({
  conversationId: {
    type: [String, Number],
    required: true,
  },
  inboxId: {
    type: [String, Number],
    required: true,
  },
  contactId: {
    type: [String, Number],
    required: true,
  },
});

const store = useStore();
const currentAccountId = useMapGetter('getCurrentAccountId');

const isInovaFarmaEnabled = computed(() => {
  return store.getters['accounts/isInovaFarmaEnabled'](currentAccountId.value);
});
const isPdvEnabled = computed(() => {
  const pdvFlag = window.globalConfig?.ENABLE_PDV;
  return pdvFlag !== false && pdvFlag !== 'false';
});

// Sistema de carrinho por conversa
const CART_STORAGE_KEY = 'pdv_carts_by_conversation';
const carts = ref(LocalStorage.get(CART_STORAGE_KEY) || {});

// Estados do carrinho: 'closed' | 'floating'
const cartState = ref('closed');

// Carrinho da conversa atual (computed baseado no conversationId)
const cart = computed({
  get: () => carts.value[props.conversationId] || [],
  set: (newCart) => {
    carts.value[props.conversationId] = newCart;
    // Salvar no localStorage
    LocalStorage.set(CART_STORAGE_KEY, carts.value);
  }
});

// Watch para resetar estado do painel ao trocar de conversa
watch(() => props.conversationId, (newId, oldId) => {
  if (newId !== oldId) {
    // Fechar painel ao trocar de conversa
    cartState.value = 'closed';
    
    // Garantir que o carrinho da nova conversa existe
    if (!carts.value[newId]) {
      carts.value[newId] = [];
    }
  }
}, { immediate: true });

const activeTabName = computed(() => {
  return 'PDV.PRODUCTS';
});

const toggleCart = () => {
  cartState.value = cartState.value === 'closed' ? 'floating' : 'closed';
};

const closeCart = () => {
  cartState.value = 'closed';
};

const addToCart = product => {
  const currentCart = cart.value;
  const existingItem = currentCart.find(item => item.id === product.id);

  if (existingItem) {
    existingItem.quantity += 1;
  } else {
    currentCart.push({
      ...product,
      quantity: 1,
      customPrice: product.price, // Preço editável para esta venda
      itemDiscount: 0, // Desconto individual em %
    });
  }
  
  // Atualizar o carrinho (triggering o setter do computed)
  cart.value = [...currentCart];
};

const removeFromCart = productId => {
  cart.value = cart.value.filter(item => item.id !== productId);
};

const updateQuantity = (productId, quantity) => {
  const currentCart = cart.value;
  const item = currentCart.find(item => item.id === productId);
  if (item) {
    if (quantity <= 0) {
      removeFromCart(productId);
    } else {
      item.quantity = quantity;
      cart.value = [...currentCart];
    }
  }
};

const updateItemPrice = (productId, newPrice) => {
  const currentCart = cart.value;
  const item = currentCart.find(item => item.id === productId);
  if (item) {
    item.customPrice = Math.max(0, newPrice);
    cart.value = [...currentCart];
  }
};

const updateItemDiscount = (productId, discount) => {
  const currentCart = cart.value;
  const item = currentCart.find(item => item.id === productId);
  if (item) {
    item.itemDiscount = Math.min(100, Math.max(0, discount));
    cart.value = [...currentCart];
  }
};

const clearCart = () => {
  cart.value = [];
};

const cartItemsCount = computed(() => {
  return cart.value.reduce((total, item) => total + item.quantity, 0);
});

const cartTotal = computed(() => {
  return cart.value.reduce(
    (total, item) => total + item.price * item.quantity,
    0
  );
});

const { updateUISettings } = useUISettings();

const closePdvPanel = () => {
  updateUISettings({ is_pdv_panel_open: false });
};

const contactSupport = () => {
  window.open('mailto:suporte@geniuscloud.com.br?subject=Integração Inova Farma', '_blank');
};

const formatPrice = price => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(price);
};

// Posicionamento do carrinho (drag and drop)
const CART_POSITION_KEY = 'pdv_cart_position';
const cartPanelRef = ref(null);
const isDragging = ref(false);
const dragOffset = ref({ x: 0, y: 0 });

// Carregar posição salva ou usar padrão
const cartPosition = ref(
  LocalStorage.get(CART_POSITION_KEY) || { 
    bottom: 24, 
    right: 24 
  }
);

const startDrag = (event) => {
  // Apenas arrastar pelo header, não pelos botões
  if (event.target.closest('button') || event.target.closest('.no-drag')) {
    return;
  }
  
  isDragging.value = true;
  
  const rect = cartPanelRef.value.getBoundingClientRect();
  dragOffset.value = {
    x: event.clientX - rect.left,
    y: event.clientY - rect.top,
  };
  
  document.addEventListener('mousemove', onDrag);
  document.addEventListener('mouseup', stopDrag);
};

const onDrag = (event) => {
  if (!isDragging.value) return;
  
  const viewportWidth = window.innerWidth;
  const viewportHeight = window.innerHeight;
  const panelWidth = cartPanelRef.value.offsetWidth;
  const panelHeight = cartPanelRef.value.offsetHeight;
  
  // Calcular nova posição baseada no mouse
  let newRight = viewportWidth - event.clientX - (panelWidth - dragOffset.value.x);
  let newBottom = viewportHeight - event.clientY - (panelHeight - dragOffset.value.y);
  
  // Limitar aos bounds da viewport (com margem de 16px)
  newRight = Math.max(16, Math.min(viewportWidth - panelWidth - 16, newRight));
  newBottom = Math.max(16, Math.min(viewportHeight - panelHeight - 16, newBottom));
  
  cartPosition.value = {
    right: newRight,
    bottom: newBottom,
  };
};

const stopDrag = () => {
  if (isDragging.value) {
    isDragging.value = false;
    // Salvar posição no localStorage
    LocalStorage.set(CART_POSITION_KEY, cartPosition.value);
    
    document.removeEventListener('mousemove', onDrag);
    document.removeEventListener('mouseup', stopDrag);
  }
};

const cartPanelStyle = computed(() => ({
  right: `${cartPosition.value.right}px`,
  bottom: `${cartPosition.value.bottom}px`,
}));

</script>

<template>
  <div class="relative flex flex-col h-full w-full bg-n-solid-1">
    <!-- Header -->
    <div class="flex items-center justify-between p-4 border-b border-n-weak bg-n-solid-1 z-20">
      <div class="flex items-center gap-3">
        <img :src="InovafarmaLogo" alt="Inovafarma" class="h-16 w-auto" />
        <h2 class="text-xl font-bold text-n-text">{{ $t(activeTabName) }}</h2>
      </div>
      <Button
        v-tooltip="$t('GENERAL.CLOSE')"
        icon="i-lucide-x"
        ghost
        sm
        @click="closePdvPanel"
      />
    </div>

    <!-- Conteúdo com blur quando desabilitado -->
    <div
      class="flex-1 overflow-hidden relative flex flex-col"
      :class="{ 'blur-sm pointer-events-none': !isPdvEnabled || !isInovaFarmaEnabled }"
    >
      <!-- Lista de Produtos (ocupa tudo) -->
      <div class="flex-1 overflow-hidden flex flex-col">
        <PdvProductList @add-to-cart="addToCart" />
      </div>

      <!-- Botão Flutuante do Carrinho (Badge) -->
      <button
        v-if="cart.length > 0"
        class="fixed bottom-6 right-6 z-30 group"
        :class="{
          'opacity-50': cartState === 'floating'
        }"
        @click="toggleCart"
      >
        <div class="relative">
          <!-- Badge principal -->
          <div
            class="flex items-center gap-3 px-5 py-3.5 bg-gradient-to-r from-n-brand to-n-brand/80 hover:from-n-brand hover:to-n-brand text-white rounded-full shadow-xl hover:shadow-2xl transition-all duration-200 transform hover:scale-105"
          >
            <span class="i-ph-shopping-cart-bold text-2xl" />
            <div class="flex flex-col items-start">
              <span class="text-xs font-medium opacity-90">Carrinho</span>
              <span class="text-base font-bold">{{ formatPrice(cartTotal) }}</span>
            </div>
            <!-- Contador de itens -->
            <span
              class="px-2.5 py-1 bg-white text-n-brand text-sm font-bold rounded-full"
            >
              {{ cartItemsCount }}
            </span>
          </div>
          
          <!-- Pulse animation quando carrinho está fechado -->
          <span
            v-if="cartState === 'closed'"
            class="absolute inset-0 rounded-full bg-n-brand opacity-75 animate-ping"
          />
        </div>
      </button>

      <!-- Painel Flutuante do Carrinho -->
      <transition
        enter-active-class="transition-all duration-300 ease-out"
        leave-active-class="transition-all duration-200 ease-in"
        enter-from-class="scale-95 opacity-0"
        enter-to-class="scale-100 opacity-100"
        leave-from-class="scale-100 opacity-100"
        leave-to-class="scale-95 opacity-0"
      >
        <div
          v-if="cartState === 'floating' && cart.length > 0"
          ref="cartPanelRef"
          :style="cartPanelStyle"
          class="fixed z-40 w-[1040px] max-w-[95vw] min-w-[320px] sm:min-w-[360px] h-[70vh] max-h-[85vh] min-h-[360px] resize overflow-auto bg-white dark:bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak flex flex-col"
          :class="{ 'cursor-move': isDragging, 'select-none': isDragging }"
        >
          <!-- Header do carrinho flutuante (área de drag) -->
          <div 
            class="cart-drag-handle flex items-center justify-between px-5 py-4 border-b border-n-weak bg-gradient-to-r from-n-brand/5 to-transparent cursor-grab active:cursor-grabbing"
            @mousedown="startDrag"
          >
            <div class="flex items-center gap-3">
              <span class="i-lucide-grip-vertical text-lg text-n-text-subtle/50" />
              <span class="i-ph-shopping-cart-bold text-2xl text-n-brand" />
              <div>
                <h3 class="font-bold text-base text-n-text">Carrinho de Vendas</h3>
                <p class="text-xs text-n-text-subtle">{{ cartItemsCount }} {{ cartItemsCount === 1 ? 'item' : 'itens' }}</p>
              </div>
            </div>
            <div class="flex items-center gap-2 no-drag">
              <Button
                v-tooltip="'Fechar'"
                icon="i-lucide-x"
                ghost
                sm
                @click="closeCart"
              />
            </div>
          </div>

          <!-- Conteúdo do carrinho (scroll independente) -->
          <div class="flex-1 overflow-y-auto">
            <PdvCheckout
              :cart="cart"
              :conversation-id="conversationId"
              :inbox-id="inboxId"
              :contact-id="contactId"
              @update-quantity="updateQuantity"
              @update-item-price="updateItemPrice"
              @update-item-discount="updateItemDiscount"
              @remove-from-cart="removeFromCart"
              @clear-cart="clearCart"
            />
          </div>
        </div>
      </transition>

      <!-- Backdrop escuro (apenas visual, não fecha ao clicar) -->
      <transition
        enter-active-class="transition-opacity duration-300"
        leave-active-class="transition-opacity duration-200"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div
          v-if="cartState === 'floating'"
          class="fixed inset-0 bg-black/10 dark:bg-black/20 z-35 pointer-events-none"
        />
      </transition>
    </div>

    <!-- Tela de bloqueio quando PDV está desativado -->
    <div
      v-if="!isPdvEnabled"
      class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/80 backdrop-blur-sm z-10"
    >
      <div class="max-w-md mx-4 text-center">
        <div class="mb-6 flex justify-center">
          <img
            :src="InovafarmaLogo"
            alt="Inovafarma"
            class="h-24 w-auto opacity-50"
          />
        </div>
        <h2
          class="text-2xl font-bold mb-4 text-slate-900 dark:text-slate-100"
        >
          {{ $t('PDV.BLOCKED.TITLE') }}
        </h2>
        <p class="text-base text-slate-600 dark:text-slate-400 mb-6">
          {{ $t('PDV.BLOCKED.DESCRIPTION') }}
        </p>
        <div
          class="bg-woot-50 dark:bg-woot-900/20 border-2 border-woot-200 dark:border-woot-800 rounded-lg p-4"
        >
          <p class="text-sm text-slate-700 dark:text-slate-300">
            {{ $t('PDV.BLOCKED.SUBTEXT') }}
          </p>
        </div>
      </div>
    </div>

    <!-- Tela de bloqueio quando Inova Farma não está ativado -->
    <div
      v-else-if="!isInovaFarmaEnabled"
      class="absolute inset-0 flex items-center justify-center bg-white/80 dark:bg-slate-900/80 backdrop-blur-sm z-10"
    >
      <div class="max-w-md mx-4 text-center">
        <div class="mb-6 flex justify-center">
          <img
            :src="InovafarmaLogo"
            alt="Inovafarma"
            class="h-24 w-auto opacity-50"
          />
        </div>
        <h2
          class="text-2xl font-bold mb-4 text-slate-900 dark:text-slate-100"
        >
          {{ $t('PDV.INTEGRATION_NOT_ENABLED.TITLE') }}
        </h2>
        <p class="text-base text-slate-600 dark:text-slate-400 mb-6">
          {{ $t('PDV.INTEGRATION_NOT_ENABLED.DESCRIPTION') }}
        </p>
        <div
          class="bg-woot-50 dark:bg-woot-900/20 border-2 border-woot-200 dark:border-woot-800 rounded-lg p-4 mb-6"
        >
          <p class="text-sm text-slate-700 dark:text-slate-300">
            {{ $t('PDV.INTEGRATION_NOT_ENABLED.BENEFITS') }}
          </p>
        </div>
        <Button
          variant="solid"
          woot
          size="large"
          icon="i-lucide-mail"
          class="w-full"
          @click="contactSupport"
        >
          {{ $t('PDV.INTEGRATION_NOT_ENABLED.CONTACT_SUPPORT') }}
        </Button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Smooth drag transition quando não está arrastando */
.fixed:not(.cursor-move) {
  transition: right 0.15s ease-out, bottom 0.15s ease-out;
}

/* Estilo do header arrastável */
.cart-drag-handle {
  user-select: none;
}

.cart-drag-handle:hover {
  background: linear-gradient(to right, rgb(var(--color-woot-50) / 0.08), transparent);
}

.cart-drag-handle:active {
  cursor: grabbing !important;
}
</style>
