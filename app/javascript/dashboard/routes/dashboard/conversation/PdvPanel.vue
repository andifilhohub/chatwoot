<script setup>
import { ref, computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import PdvProductList from './PdvProductList.vue';
import PdvCheckout from './PdvCheckout.vue';
import InovafarmaLogo from 'dashboard/assets/images/inovafarma.svg';
import { useUISettings } from 'dashboard/composables/useUISettings';

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

// Modo: 'products' ou 'checkout'
const currentMode = ref('products');
const cart = ref([]);

const switchToProducts = () => {
  currentMode.value = 'products';
};

const switchToCheckout = () => {
  currentMode.value = 'checkout';
};

const addToCart = (product) => {
  const existingItem = cart.value.find(item => item.id === product.id);
  
  if (existingItem) {
    existingItem.quantity += 1;
  } else {
    cart.value.push({
      ...product,
      quantity: 1,
    });
  }
  
  // Mudar automaticamente para checkout ao adicionar produto
  currentMode.value = 'checkout';
};

const removeFromCart = (productId) => {
  cart.value = cart.value.filter(item => item.id !== productId);
};

const updateQuantity = (productId, quantity) => {
  const item = cart.value.find(item => item.id === productId);
  if (item) {
    if (quantity <= 0) {
      removeFromCart(productId);
    } else {
      item.quantity = quantity;
    }
  }
};

const clearCart = () => {
  cart.value = [];
};

const cartItemsCount = computed(() => {
  return cart.value.reduce((total, item) => total + item.quantity, 0);
});

const { updateUISettings } = useUISettings();

const closePdvPanel = () => {
  updateUISettings({ is_pdv_panel_open: false });
};
</script>

<template>
  <div class="flex flex-col h-full w-full">
    <!-- Header -->
    <div class="flex items-center justify-between p-4 border-b border-n-weak">
      <img 
        :src="InovafarmaLogo" 
        alt="Inovafarma" 
        class="h-16 w-auto"
      />
      <div class="flex gap-2">
        <Button
          :variant="currentMode === 'products' ? 'solid' : 'ghost'"
          slate
          sm
          icon="i-ph-package-bold"
          @click="switchToProducts"
        >
          {{ $t('PDV.PRODUCTS') }}
        </Button>
        <Button
          :variant="currentMode === 'checkout' ? 'solid' : 'ghost'"
          slate
          sm
          icon="i-ph-shopping-cart-bold"
          :badge="cartItemsCount > 0 ? cartItemsCount : null"
          @click="switchToCheckout"
        >
          {{ $t('PDV.CHECKOUT') }}
        </Button>
        <Button
          v-tooltip="$t('GENERAL.CLOSE')"
          icon="i-lucide-x"
          ghost
          sm
          @click="closePdvPanel"
        />
      </div>
    </div>

    <!-- Conteúdo -->
    <div class="flex-1 overflow-hidden">
      <PdvProductList
        v-if="currentMode === 'products'"
        @add-to-cart="addToCart"
      />
      <PdvCheckout
        v-else-if="currentMode === 'checkout'"
        :cart="cart"
        :conversation-id="conversationId"
        :inbox-id="inboxId"
        :contact-id="contactId"
        @update-quantity="updateQuantity"
        @remove-from-cart="removeFromCart"
        @clear-cart="clearCart"
      />
    </div>
  </div>
</template>
