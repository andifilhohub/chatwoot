<script setup>
import { ref, computed, watch } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { emitter } from 'shared/helpers/mitt';
import IntegrahubSalesAPI from 'dashboard/api/integrahubSales';
import { useMapGetter } from 'dashboard/composables/store';

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
const currentAccountId = useMapGetter('getCurrentAccountId');
const isProcessing = ref(false);
const isSendingQuote = ref(false);
const paymentMethod = ref('money');
const discount = ref(0);
const notes = ref('');
const customerName = ref('');
const customerCpf = ref('');
const ecommerceType = ref('GENIUS CLOUD');
const saleCode = ref(String(props.conversationId || ''));
const saleDate = ref('');
const deliveryDate = ref('');
const deliveryContactName = ref('');
const deliveryChangeFor = ref(0);
const deliveryFee = ref(0);
const deliveryPhone = ref('');
const deliveryMobile = ref('');
const deliveryAllowWhatsApp = ref(false);
const deliveryAddressLine = ref('');
const deliveryAddressNumber = ref('');
const deliveryAddressComplement = ref('');
const deliveryAddressZip = ref('');
const deliveryAddressReference = ref('');
const deliveryAddressNeighborhood = ref('');
const deliveryAddressCity = ref('');
const deliveryAddressState = ref('');
const deliveryAddressRecipient = ref('');
const paymentNsu = ref('');
const paymentCardBrand = ref('');
const paymentDueDate = ref('');
const showDeliveryDetails = ref(false);

const currentAccount = computed(() => {
  const accountFromRecords = store.getters['accounts/getAccount']?.(
    currentAccountId.value
  );
  return accountFromRecords || store.getters.getCurrentAccount || {};
});
const currentContact = computed(
  () => store.getters['contacts/getContact'](props.contactId) || {}
);
const currentContactAddress = computed(() => {
  const attributes = currentContact.value?.additional_attributes || {};
  const address = attributes.address || {};
  return {
    line: address.line || attributes.address_line || '',
    number: address.number || attributes.address_number || '',
    complement: address.complement || attributes.address_complement || '',
    neighborhood: address.neighborhood || attributes.address_neighborhood || '',
    zip: address.zip || attributes.address_zip || '',
    state: address.state || attributes.address_state || '',
    reference: address.reference || attributes.address_reference || '',
    recipient: address.recipient || attributes.address_recipient || '',
  };
});
const hasContactAddress = computed(() => {
  const address = currentContactAddress.value || {};
  return Object.values(address).some(value => String(value || '').trim() !== '');
});
const shouldShowAddressFields = computed(
  () => !hasContactAddress.value || !isAddressComplete.value
);
const requiredAddressFields = computed(() => ({
  line: deliveryAddressLine.value,
  number: deliveryAddressNumber.value,
  zip: deliveryAddressZip.value,
  neighborhood: deliveryAddressNeighborhood.value,
  city: deliveryAddressCity.value,
  state: deliveryAddressState.value,
  recipient: deliveryAddressRecipient.value,
}));
const isAddressComplete = computed(() =>
  Object.values(requiredAddressFields.value).every(
    value => String(value || '').trim() !== ''
  )
);
const missingAddressFields = computed(() => {
  const labels = {
    line: 'Endereço',
    number: 'Número',
    zip: 'CEP',
    neighborhood: 'Bairro',
    city: 'Cidade',
    state: 'Estado',
    recipient: 'Destinatário',
  };

  return Object.entries(requiredAddressFields.value)
    .filter(([, value]) => String(value || '').trim() === '')
    .map(([key]) => labels[key]);
});

const toDatetimeLocalValue = date => {
  const pad = value => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(
    date.getDate()
  )}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
};

const toIsoString = value => {
  if (!value) return new Date().toISOString();
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? new Date().toISOString() : parsed.toISOString();
};

const paymentTypeByMethod = method => {
  const mapping = {
    money: 'D',
    credit: 'C',
    debit: 'D',
    pix: 'P',
  };
  return mapping[method] || 'D';
};

const paymentFormLabel = computed(() => {
  const labels = {
    money: 'Dinheiro',
    credit: 'Cartão Crédito',
    debit: 'Cartão Débito',
    pix: 'PIX',
  };
  return labels[paymentMethod.value] || 'Dinheiro';
});

watch(currentContact, contact => {
  if (!customerName.value) customerName.value = contact?.name || '';
  if (!deliveryContactName.value) {
    deliveryContactName.value = contact?.name || '';
  }
  if (!deliveryPhone.value) {
    deliveryPhone.value = contact?.phone_number || '';
  }
  if (!deliveryMobile.value) {
    deliveryMobile.value = contact?.phone_number || '';
  }
  if (!deliveryAddressRecipient.value) {
    deliveryAddressRecipient.value = contact?.name || '';
  }
  if (!deliveryAddressLine.value) {
    deliveryAddressLine.value = currentContactAddress.value?.line || '';
  }
  if (!deliveryAddressNumber.value) {
    deliveryAddressNumber.value = currentContactAddress.value?.number || '';
  }
  if (!deliveryAddressComplement.value) {
    deliveryAddressComplement.value =
      currentContactAddress.value?.complement || '';
  }
  if (!deliveryAddressNeighborhood.value) {
    deliveryAddressNeighborhood.value =
      currentContactAddress.value?.neighborhood || '';
  }
  if (!deliveryAddressZip.value) {
    deliveryAddressZip.value = currentContactAddress.value?.zip || '';
  }
  if (!deliveryAddressState.value) {
    deliveryAddressState.value = currentContactAddress.value?.state || '';
  }
  if (!deliveryAddressReference.value) {
    deliveryAddressReference.value =
      currentContactAddress.value?.reference || '';
  }
  if (!deliveryAddressRecipient.value) {
    deliveryAddressRecipient.value =
      currentContactAddress.value?.recipient || '';
  }
  if (!customerCpf.value) {
    customerCpf.value = contact?.additional_attributes?.cpf || '';
  }
  if (!deliveryAddressCity.value) {
    deliveryAddressCity.value = contact?.additional_attributes?.city || '';
  }
  if (
    !saleCode.value ||
    saleCode.value === String(props.conversationId || '')
  ) {
    const contactId = contact?.id || props.contactId || 'contact';
    const conversationId = props.conversationId || 'conv';
    saleCode.value = `GC-${contactId}-${conversationId}-${Date.now()}`;
  }
}, { immediate: true });


const setDefaultDates = () => {
  const now = new Date();
  const localValue = toDatetimeLocalValue(now);
  if (!deliveryDate.value) deliveryDate.value = localValue;
  if (!paymentDueDate.value) paymentDueDate.value = localValue;
};

setDefaultDates();

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

  if (!currentAccount.value?.cnpj) {
    if (currentAccountId.value) {
      await store.dispatch('accounts/get');
    }
    if (!currentAccount.value?.cnpj) {
      useAlert('CNPJ da conta não encontrado. Atualize o CNPJ para finalizar a venda.');
      return;
    }
  }

  if (!isAddressComplete.value) {
    const missing = missingAddressFields.value.join(', ');
    useAlert(
      `Campos obrigatórios do endereço faltando: ${missing || 'verifique os dados'}.`
    );
    return;
  }

  isProcessing.value = true;

  try {
    // Aqui você fará a integração com seu ERP
    saleDate.value = toDatetimeLocalValue(new Date());

    const salePayload = {
      cnpjEmpresa: currentAccount.value?.cnpj || '',
      codigoVendaOnLine: saleCode.value || String(props.conversationId || ''),
      dataVenda: toIsoString(saleDate.value),
      nomeCliente: customerName.value || currentContact.value?.name || '',
      cpfCliente:
        customerCpf.value ||
        currentContact.value?.additional_attributes?.cpf ||
        '',
      tipoDeEcommerce: 'GENIUS CLOUD',
      entrega: {
        dataAgendamento: toIsoString(deliveryDate.value),
        contato: deliveryContactName.value || customerName.value || 'CONSUMIDOR',
        trocoPara: Number(deliveryChangeFor.value) || 0,
        taxa: Number(deliveryFee.value) || 0,
        telefone: deliveryPhone.value || '',
        celular: deliveryMobile.value || '',
        permitirEnvioMensagemWhatsApp: false,
        endereco: {
          endereco: deliveryAddressLine.value || '',
          numero: deliveryAddressNumber.value || '',
          complemento: deliveryAddressComplement.value || '',
          cep: deliveryAddressZip.value || '',
          referencia: deliveryAddressReference.value || '',
          bairro: deliveryAddressNeighborhood.value || '',
          cidade: deliveryAddressCity.value || '',
          estado: deliveryAddressState.value || '',
          destinatario: deliveryAddressRecipient.value || '',
        },
      },
      produtos: props.cart.map(item => ({
        codigoProduto: item.sku || item.id,
        nomeProduto: item.name,
        quantidade: item.quantity,
        unidade: item.unit || 'un',
        valorUnitario: Number(item.customPrice || item.price || 0),
        descontoUnitario: Number(item.itemDiscount || 0),
      })),
      pagamentos: [
        {
          tipo: paymentTypeByMethod(paymentMethod.value),
          nsu: paymentNsu.value || '',
          bandeiraCartao: paymentCardBrand.value || '',
          receberNaEntrega: true,
          formaPagamento: paymentFormLabel.value,
          valor: Number(total.value || 0),
          dataVencimento: toIsoString(paymentDueDate.value),
        },
      ],
    };

    console.log('Enviando venda para ERP:', salePayload);

    await IntegrahubSalesAPI.create({ payload: salePayload });

    useAlert('Venda finalizada com sucesso!');
    clearCart();
    discount.value = 0;
    notes.value = '';
    paymentMethod.value = 'money';
    paymentNsu.value = '';
    paymentCardBrand.value = '';
    saleCode.value = `GC-${props.contactId || 'contact'}-${props.conversationId || 'conv'}-${Date.now()}`;
    customerName.value = currentContact.value?.name || '';
    customerCpf.value = currentContact.value?.additional_attributes?.cpf || '';
    deliveryContactName.value = currentContact.value?.name || '';
    deliveryPhone.value = currentContact.value?.phone_number || '';
    deliveryMobile.value = currentContact.value?.phone_number || '';
    deliveryAddressLine.value = currentContactAddress.value?.line || '';
    deliveryAddressNumber.value = currentContactAddress.value?.number || '';
    deliveryAddressComplement.value =
      currentContactAddress.value?.complement || '';
    deliveryAddressZip.value = currentContactAddress.value?.zip || '';
    deliveryAddressReference.value =
      currentContactAddress.value?.reference || '';
    deliveryAddressNeighborhood.value =
      currentContactAddress.value?.neighborhood || '';
    deliveryAddressCity.value =
      currentContact.value?.additional_attributes?.city || '';
    deliveryAddressState.value = currentContactAddress.value?.state || '';
    deliveryAddressRecipient.value =
      currentContactAddress.value?.recipient ||
      currentContact.value?.name ||
      '';
    deliveryChangeFor.value = 0;
    deliveryFee.value = 0;
    deliveryAllowWhatsApp.value = false;
    setDefaultDates();
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
    <div
      v-if="cart.length === 0"
      class="flex flex-col items-center justify-center h-full text-center py-8"
    >
      <span class="text-4xl mb-2">🛒</span>
      <p class="text-n-text-subtle">
        {{ $t('PDV.EMPTY_CART') }}
      </p>
    </div>

    <div v-else class="flex flex-col lg:flex-row h-full">
      <!-- Carrinho -->
      <div class="flex-1 min-w-0 overflow-y-auto p-4 space-y-3">
        <div class="space-y-3">
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
        class="w-full lg:w-[360px] xl:w-[420px] border-t border-n-weak lg:border-t-0 lg:border-l p-4 space-y-4 bg-n-solid-1 overflow-y-auto"
      >
      <!-- Dados da Venda -->
      <div class="space-y-2">
        <h4 class="text-sm font-semibold text-n-text">
          {{ $t('PDV.SALE_DETAILS') }}
        </h4>
        <div class="grid grid-cols-1 gap-2">
          <div class="space-y-2">
            <label class="text-sm font-medium text-n-text">
              {{ $t('PDV.SALE_CODE') }}
            </label>
            <Input v-model="saleCode" :placeholder="$t('PDV.SALE_CODE_PLACEHOLDER')" disabled />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium text-n-text">
              {{ $t('PDV.CUSTOMER_NAME') }}
            </label>
            <Input v-model="customerName" :placeholder="$t('PDV.CUSTOMER_NAME_PLACEHOLDER')" />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium text-n-text">
              {{ $t('PDV.CUSTOMER_CPF') }}
            </label>
            <Input v-model="customerCpf" :placeholder="$t('PDV.CUSTOMER_CPF_PLACEHOLDER')" />
          </div>
        </div>
      </div>

      <!-- Entrega -->
      <div class="space-y-2">
        <button
          type="button"
          class="w-full flex items-center justify-between text-left"
          @click="showDeliveryDetails = !showDeliveryDetails"
        >
          <h4 class="text-sm font-semibold text-n-text">
            {{ $t('PDV.DELIVERY_DETAILS') }}
          </h4>
          <span
            class="i-lucide-chevron-down text-base text-n-slate-11 transition-transform"
            :class="{ 'rotate-180': showDeliveryDetails }"
          />
        </button>
        <div v-if="showDeliveryDetails" class="grid grid-cols-1 gap-2">
          <div class="space-y-2">
            <label class="text-sm font-medium text-n-text">
              {{ $t('PDV.DELIVERY_DATE') }}
            </label>
            <Input v-model="deliveryDate" type="datetime-local" />
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium text-n-text">
              {{ $t('PDV.DELIVERY_CONTACT') }}
            </label>
            <Input v-model="deliveryContactName" :placeholder="$t('PDV.DELIVERY_CONTACT_PLACEHOLDER')" />
          </div>
          <div class="grid grid-cols-2 gap-2">
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.DELIVERY_CHANGE_FOR') }}
              </label>
              <Input v-model.number="deliveryChangeFor" type="number" min="0" step="0.01" />
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.DELIVERY_FEE') }}
              </label>
              <Input v-model.number="deliveryFee" type="number" min="0" step="0.01" />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-2">
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.DELIVERY_PHONE') }}
              </label>
              <Input v-model="deliveryPhone" :placeholder="$t('PDV.DELIVERY_PHONE_PLACEHOLDER')" />
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.DELIVERY_MOBILE') }}
              </label>
              <Input v-model="deliveryMobile" :placeholder="$t('PDV.DELIVERY_MOBILE_PLACEHOLDER')" />
            </div>
          </div>
          <label class="flex items-center gap-2 text-sm text-n-text opacity-60">
            <input v-model="deliveryAllowWhatsApp" type="checkbox" class="h-4 w-4 rounded border-n-weak text-n-brand" disabled />
            {{ $t('PDV.DELIVERY_ALLOW_WHATSAPP') }}
          </label>
        </div>
      </div>

      <!-- Endereco -->
      <div v-if="showDeliveryDetails && shouldShowAddressFields" class="space-y-2">
        <h4 class="text-sm font-semibold text-n-text">
          {{ $t('PDV.DELIVERY_ADDRESS') }}
        </h4>
        <div class="grid grid-cols-1 gap-2">
          <div class="grid grid-cols-2 gap-2">
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.ADDRESS_LINE') }}
              </label>
              <Input v-model="deliveryAddressLine" :placeholder="$t('PDV.ADDRESS_LINE_PLACEHOLDER')" />
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.ADDRESS_NUMBER') }}
              </label>
              <Input v-model="deliveryAddressNumber" :placeholder="$t('PDV.ADDRESS_NUMBER_PLACEHOLDER')" />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-2">
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.ADDRESS_COMPLEMENT') }}
              </label>
              <Input v-model="deliveryAddressComplement" :placeholder="$t('PDV.ADDRESS_COMPLEMENT_PLACEHOLDER')" />
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.ADDRESS_ZIP') }}
              </label>
              <Input v-model="deliveryAddressZip" :placeholder="$t('PDV.ADDRESS_ZIP_PLACEHOLDER')" />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-2">
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.ADDRESS_REFERENCE') }}
              </label>
              <Input v-model="deliveryAddressReference" :placeholder="$t('PDV.ADDRESS_REFERENCE_PLACEHOLDER')" />
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.ADDRESS_NEIGHBORHOOD') }}
              </label>
              <Input v-model="deliveryAddressNeighborhood" :placeholder="$t('PDV.ADDRESS_NEIGHBORHOOD_PLACEHOLDER')" />
            </div>
          </div>
          <div class="grid grid-cols-2 gap-2">
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.ADDRESS_CITY') }}
              </label>
              <Input v-model="deliveryAddressCity" :placeholder="$t('PDV.ADDRESS_CITY_PLACEHOLDER')" />
            </div>
            <div class="space-y-2">
              <label class="text-sm font-medium text-n-text">
                {{ $t('PDV.ADDRESS_STATE') }}
              </label>
              <Input v-model="deliveryAddressState" :placeholder="$t('PDV.ADDRESS_STATE_PLACEHOLDER')" />
            </div>
          </div>
          <div class="space-y-2">
            <label class="text-sm font-medium text-n-text">
              {{ $t('PDV.ADDRESS_RECIPIENT') }}
            </label>
            <Input v-model="deliveryAddressRecipient" :placeholder="$t('PDV.ADDRESS_RECIPIENT_PLACEHOLDER')" />
          </div>
        </div>
      </div>

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
  </div>
</template>
