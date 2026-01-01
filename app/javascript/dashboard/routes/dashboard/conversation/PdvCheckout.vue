<script setup>
import { ref, computed } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  cart: {
    type: Array,
    required: true,
  },
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

const emit = defineEmits([
  'update-quantity',
  'update-item-price',
  'update-item-discount',
  'remove-from-cart',
  'clear-cart',
]);

const store = useStore();
const isProcessing = ref(false);
const isSendingQuote = ref(false);
const paymentMethod = ref('money');
const discount = ref(0);
const notes = ref('');

const subtotal = computed(() => {
  return props.cart.reduce((total, item) => {
    // Use customPrice if available, otherwise fallback to price
    const itemPrice = item.customPrice || item.price;
    const itemDiscount = item.itemDiscount || 0;
    const discountedPrice = itemPrice * (1 - itemDiscount / 100);
    return total + discountedPrice * item.quantity;
  }, 0);
});

const discountAmount = computed(() => {
  return (subtotal.value * discount.value) / 100;
});

const total = computed(() => {
  return subtotal.value - discountAmount.value;
});

const formatPrice = price => {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(price);
};

const updateItemQuantity = (productId, newQuantity) => {
  emit('update-quantity', productId, newQuantity);
};

const updateItemPrice = (productId, newPrice) => {
  emit('update-item-price', productId, newPrice);
};

const updateItemDiscount = (productId, newDiscount) => {
  emit('update-item-discount', productId, newDiscount);
};

const removeItem = productId => {
  emit('remove-from-cart', productId);
};

const clearCart = () => {
  emit('clear-cart');
};

const sendQuote = async () => {
  if (props.cart.length === 0) {
    useAlert('Carrinho vazio! Adicione produtos antes de enviar o orçamento.');
    return;
  }

  isSendingQuote.value = true;

  try {
    // Formatar mensagem de orçamento
    let quoteMessage = '*CARRINHO:*\n\n';
    
    // Listar produtos
    quoteMessage += '*Produtos:*\n';
    props.cart.forEach((item, index) => {
      const itemPrice = item.customPrice || item.price;
      const itemDiscount = item.itemDiscount || 0;
      const discountedPrice = itemPrice * (1 - itemDiscount / 100);
      
      quoteMessage += `${index + 1}. ${item.name}\n`;
      quoteMessage += `   • Quantidade: ${item.quantity}\n`;
      
      // Show original price if custom price is different
      if (item.customPrice && item.customPrice !== item.price) {
        quoteMessage += `   • Preço original: ${formatPrice(item.price)}\n`;
        quoteMessage += `   • Preço especial: ${formatPrice(item.customPrice)}\n`;
      } else {
        quoteMessage += `   • Valor unitário: ${formatPrice(itemPrice)}\n`;
      }
      
      // Show item discount if applied
      if (itemDiscount > 0) {
        quoteMessage += `   • Desconto no item: ${itemDiscount}%\n`;
        quoteMessage += `   • Valor c/ desconto: ${formatPrice(discountedPrice)}\n`;
      }
      
      quoteMessage += `   • Subtotal: ${formatPrice(discountedPrice * item.quantity)}\n\n`;
    });

    // Totais
    quoteMessage += '━━━━━━━━━━━━━━━━━━━\n';
    quoteMessage += `*Subtotal:* ${formatPrice(subtotal.value)}\n`;
    
    if (discount.value > 0) {
      quoteMessage += `*Desconto (${discount.value}%):* -${formatPrice(discountAmount.value)}\n`;
    }
    
    quoteMessage += `*TOTAL:* ${formatPrice(total.value)}\n`;
    quoteMessage += '━━━━━━━━━━━━━━━━━━━\n\n';

    // Observações
    if (notes.value) {
      quoteMessage += `*Observações:*\n${notes.value}\n\n`;
    }

    // Enviar mensagem para o draft do editor de mensagens
    const draftKey = `draft-${props.conversationId}-REPLY`;
    
    console.log('[PDV] Salvando orçamento no draft:', {
      key: draftKey,
      conversationId: props.conversationId,
      messageLength: quoteMessage.length,
    });
    
    // Salvar no store
    await store.dispatch('draftMessages/set', {
      key: draftKey,
      message: quoteMessage,
    });
    
    console.log('[PDV] Draft salvo, verificando store:', store.getters['draftMessages/get'](draftKey));

    // Forçar o ReplyBox a recarregar o draft usando um evento customizado
    // Dispara um evento que o ReplyBox pode ouvir para atualizar
    console.log('[PDV] Emitindo evento load-draft-message');
    emitter.emit('load-draft-message', {
      conversationId: props.conversationId,
      replyType: 'REPLY', // Usar maiúscula para bater com REPLY_EDITOR_MODES.REPLY
    });

    useAlert('Orçamento adicionado ao campo de mensagem. Revise e envie.');
    
  } catch (error) {
    console.error('Erro ao preparar orçamento:', error);
    useAlert('Erro ao preparar orçamento. Tente novamente.');
  } finally {
    isSendingQuote.value = false;
  }
};

const finalizeSale = async () => {
  if (props.cart.length === 0) {
    useAlert('Carrinho vazio!');
    return;
  }

  isProcessing.value = true;

  try {
    // Aqui você fará a integração com seu ERP
    const salePayload = {
      conversation_id: props.conversationId,
      inbox_id: props.inboxId,
      contact_id: props.contactId,
      items: props.cart.map(item => ({
        product_id: item.id,
        product_name: item.name,
        sku: item.sku,
        quantity: item.quantity,
        original_price: item.price,
        custom_price: item.customPrice || item.price,
        item_discount_percent: item.itemDiscount || 0,
        unit_price: (item.customPrice || item.price) * (1 - (item.itemDiscount || 0) / 100),
        total_price: ((item.customPrice || item.price) * (1 - (item.itemDiscount || 0) / 100)) * item.quantity,
      })),
      subtotal: subtotal.value,
      discount_percent: discount.value,
      discount_amount: discountAmount.value,
      total: total.value,
      payment_method: paymentMethod.value,
      notes: notes.value,
      created_at: new Date().toISOString(),
    };

    console.log('Enviando venda para ERP:', salePayload);

    // Simular chamada API
    await new Promise(resolve => setTimeout(resolve, 1000));

    // TODO: Fazer requisição real para o ERP
    // await axios.post('/api/erp/sales', salePayload);

    useAlert('Venda finalizada com sucesso!');
    clearCart();
    discount.value = 0;
    notes.value = '';
    paymentMethod.value = 'money';
  } catch (error) {
    console.error('Erro ao finalizar venda:', error);
    useAlert('Erro ao finalizar venda. Tente novamente.');
  } finally {
    isProcessing.value = false;
  }
};
</script>

<template>
  <div class="flex flex-col h-full">
    <!-- Carrinho -->
    <div class="flex-1 overflow-y-auto p-4 space-y-3">
      <div
        v-if="cart.length === 0"
        class="flex flex-col items-center justify-center h-full text-center py-8"
      >
        <span class="text-4xl mb-2">🛒</span>
        <p class="text-n-text-subtle">
          {{ $t('PDV.EMPTY_CART') }}
        </p>
      </div>

      <div v-else class="space-y-3">
        <div
          v-for="item in cart"
          :key="item.id"
          class="bg-n-solid-1 rounded-lg p-3 border border-n-weak"
        >
          <div class="flex items-start justify-between mb-3">
            <div class="flex-1 min-w-0">
              <h4 class="font-semibold text-n-text text-sm truncate">
                {{ item.name }}
              </h4>
              <p class="text-xs text-n-text-subtle">
                Preço original: {{ formatPrice(item.price) }} / un
              </p>
            </div>
            <Button
              ghost
              danger
              xs
              icon="i-ph-trash-bold"
              @click="removeItem(item.id)"
            />
          </div>

          <!-- Price & Discount Controls -->
          <div class="grid grid-cols-2 gap-2 mb-3">
            <div>
              <label class="text-xs text-n-text-subtle mb-1 block">
                Preço (R$)
              </label>
              <Input
                :model-value="item.customPrice || item.price"
                type="number"
                step="0.01"
                min="0"
                size="xs"
                @update:model-value="updateItemPrice(item.id, parseFloat($event) || 0)"
              />
            </div>
            <div>
              <label class="text-xs text-n-text-subtle mb-1 block">
                Desconto (%)
              </label>
              <Input
                :model-value="item.itemDiscount || 0"
                type="number"
                min="0"
                max="100"
                size="xs"
                @update:model-value="updateItemDiscount(item.id, parseFloat($event) || 0)"
              />
            </div>
          </div>

          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <Button
                ghost
                xs
                icon="i-ph-minus-bold"
                @click="updateItemQuantity(item.id, item.quantity - 1)"
              />
              <span class="text-sm font-medium px-2">{{ item.quantity }}</span>
              <Button
                ghost
                xs
                icon="i-ph-plus-bold"
                @click="updateItemQuantity(item.id, item.quantity + 1)"
              />
            </div>
            <div class="text-right">
              <span
                v-if="(item.itemDiscount > 0) || (item.customPrice && item.customPrice !== item.price)"
                class="block text-xs text-n-text-subtle line-through"
              >
                {{ formatPrice(item.price * item.quantity) }}
              </span>
              <span class="font-bold text-n-brand">
                {{
                  formatPrice(
                    ((item.customPrice || item.price) *
                      (1 - (item.itemDiscount || 0) / 100)) *
                      item.quantity
                  )
                }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Resumo e Finalização -->
    <div
      v-if="cart.length > 0"
      class="border-t border-n-weak p-4 space-y-4 bg-n-solid-1"
    >
      <!-- Desconto -->
      <div class="space-y-2">
        <label class="text-sm font-medium text-n-text">
          {{ $t('PDV.DISCOUNT') }} (%)
        </label>
        <Input
          v-model.number="discount"
          type="number"
          min="0"
          max="100"
          :placeholder="$t('PDV.DISCOUNT_PLACEHOLDER')"
        />
      </div>

      <!-- Forma de Pagamento -->
      <div class="space-y-2">
        <label class="text-sm font-medium text-n-text">
          {{ $t('PDV.PAYMENT_METHOD') }}
        </label>
        <select
          v-model="paymentMethod"
          class="w-full px-3 py-2 rounded border border-n-weak bg-n-background text-n-text"
        >
          <option value="money">Dinheiro</option>
          <option value="credit">Cartão de Crédito</option>
          <option value="debit">Cartão de Débito</option>
          <option value="pix">PIX</option>
        </select>
      </div>

      <!-- Observações -->
      <div class="space-y-2">
        <label class="text-sm font-medium text-n-text">
          {{ $t('PDV.NOTES') }}
        </label>
        <textarea
          v-model="notes"
          :placeholder="$t('PDV.NOTES_PLACEHOLDER')"
          class="w-full px-3 py-2 rounded border border-n-weak bg-n-background text-n-text resize-none"
          rows="2"
        />
      </div>

      <!-- Totais -->
      <div class="space-y-2 pt-4 border-t border-n-weak">
        <div class="flex justify-between text-sm">
          <span class="text-n-text-subtle">{{ $t('PDV.SUBTOTAL') }}</span>
          <span class="text-n-text">{{ formatPrice(subtotal) }}</span>
        </div>
        <div v-if="discount > 0" class="flex justify-between text-sm">
          <span class="text-n-text-subtle">
            {{ $t('PDV.DISCOUNT') }} ({{ discount }}%)
          </span>
          <span class="text-green-600">
            -{{ formatPrice(discountAmount) }}
          </span>
        </div>
        <div
          class="flex justify-between text-lg font-bold pt-2 border-t border-n-weak"
        >
          <span class="text-n-text">{{ $t('PDV.TOTAL') }}</span>
          <span class="text-n-brand">{{ formatPrice(total) }}</span>
        </div>
      </div>

      <!-- Botões de Ação -->
      <div class="space-y-2">
        <Button
          class="w-full"
          variant="outline"
          slate
          :loading="isSendingQuote"
          :disabled="isProcessing"
          @click="sendQuote"
        >
          <span class="i-ph-file-text-bold mr-2" />
          {{ $t('PDV.SEND_QUOTE') }}
        </Button>
        <Button class="w-full" :loading="isProcessing" :disabled="isSendingQuote" @click="finalizeSale">
          <span class="i-ph-check-circle-bold mr-2" />
          {{ $t('PDV.FINALIZE_SALE') }}
        </Button>
        <Button
          class="w-full"
          ghost
          danger
          :disabled="isProcessing || isSendingQuote"
          @click="clearCart"
        >
          <span class="i-ph-trash-bold mr-2" />
          {{ $t('PDV.CLEAR_CART') }}
        </Button>
      </div>
    </div>
  </div>
</template>
