# Sistema de PDV (Ponto de Venda) - Chatwoot

## Visão Geral

Este sistema de PDV foi integrado ao Chatwoot para permitir que agentes realizem vendas diretamente durante conversas com clientes. O sistema mantém o contexto completo da conversa, permitindo que as vendas sejam rastreadas e associadas corretamente ao cliente e ao agente.

## Arquitetura

### Componentes Principais

1. **SidepanelSwitch.vue** - Botões de controle dos painéis laterais
   - Adiciona botão de carrinho de compras abaixo do botão de contato
   - Controla abertura/fechamento do painel PDV
   - Localização: `app/javascript/dashboard/components-next/Conversation/SidepanelSwitch.vue`

2. **PdvSidebar.vue** - Container do painel lateral
   - Wrapper responsivo similar ao ConversationSidebar
   - Gerencia click outside para fechar em telas pequenas
   - Localização: `app/javascript/dashboard/components/widgets/conversation/PdvSidebar.vue`

3. **PdvPanel.vue** - Componente principal do PDV
   - Gerencia dois modos: visualização de produtos e checkout
   - Mantém estado do carrinho de compras
   - Passa contexto da conversa (conversation_id, inbox_id, contact_id)
   - Localização: `app/javascript/dashboard/routes/dashboard/conversation/PdvPanel.vue`

4. **PdvProductList.vue** - Lista de produtos
   - Busca e filtros de produtos
   - Categorização
   - Controle de estoque
   - Adicionar produtos ao carrinho
   - Localização: `app/javascript/dashboard/routes/dashboard/conversation/PdvProductList.vue`

5. **PdvCheckout.vue** - Finalização de venda
   - Visualização do carrinho
   - Controle de quantidade
   - Aplicação de descontos
   - Seleção de forma de pagamento
   - Observações da venda
   - Totalização
   - Localização: `app/javascript/dashboard/routes/dashboard/conversation/PdvCheckout.vue`

### Fluxo de Dados

```
InboxView
  └── SidepanelSwitch (controle de abertura)
  └── PdvSidebar (quando is_pdv_panel_open = true)
      └── PdvPanel
          ├── PdvProductList (modo: products)
          │   └── Emite: add-to-cart
          └── PdvCheckout (modo: checkout)
              └── Emite: update-quantity, remove-from-cart, clear-cart
```

## Estado UI

O sistema usa `uiSettings` para controlar a visibilidade do painel:

```javascript
{
  is_pdv_panel_open: boolean,  // Controla se o painel PDV está aberto
  is_contact_sidebar_open: boolean,  // Fecha ao abrir PDV
  is_copilot_panel_open: boolean  // Fecha ao abrir PDV
}
```

## Contexto da Conversa

Cada venda carrega o contexto completo:

```javascript
{
  conversation_id: Number,  // ID da conversa atual
  inbox_id: Number,         // ID da caixa de entrada
  contact_id: Number,       // ID do contato/cliente
  items: Array,             // Produtos no carrinho
  // ... outros dados da venda
}
```

## Integração com ERP

### Payload de Venda

Quando uma venda é finalizada, o seguinte payload é gerado:

```javascript
{
  conversation_id: 123,
  inbox_id: 456,
  contact_id: 789,
  items: [
    {
      product_id: 1,
      product_name: "Produto X",
      sku: "PROD-001",
      quantity: 2,
      unit_price: 99.90,
      total_price: 199.80
    }
  ],
  subtotal: 199.80,
  discount_percent: 10,
  discount_amount: 19.98,
  total: 179.82,
  payment_method: "credit",
  notes: "Cliente solicitou entrega rápida",
  created_at: "2025-11-22T10:30:00Z"
}
```

### Endpoint de Integração

Para integrar com seu ERP, você precisa:

1. Criar um endpoint backend em Rails:
   ```ruby
   # config/routes.rb
   post '/api/v1/erp/sales', to: 'erp/sales#create'
   ```

2. Implementar o controller:
   ```ruby
   # app/controllers/api/v1/erp/sales_controller.rb
   class Api::V1::Erp::SalesController < ApplicationController
     def create
       # Receber payload do PDV
       # Validar dados
       # Enviar para seu ERP
       # Retornar resposta
     end
   end
   ```

3. Atualizar o PdvCheckout.vue para fazer a requisição real:
   ```javascript
   // Em PdvCheckout.vue, método finalizeSale()
   await axios.post('/api/v1/erp/sales', salePayload);
   ```

## Produtos

### Dados Mockados

Atualmente, o sistema usa dados mockados em `PdvProductList.vue`:

```javascript
const products = ref([
  {
    id: 1,
    name: 'Produto Exemplo 1',
    sku: 'PROD-001',
    price: 99.90,
    stock: 10,
    image: null,
    category: 'Categoria A',
  }
]);
```

### Integração Real

Para usar produtos reais do seu ERP:

1. Criar API endpoint para listar produtos:
   ```ruby
   # config/routes.rb
   get '/api/v1/erp/products', to: 'erp/products#index'
   ```

2. Atualizar PdvProductList.vue:
   ```javascript
   import { ref, onMounted } from 'vue';
   import axios from 'axios';
   
   const products = ref([]);
   
   onMounted(async () => {
     const response = await axios.get('/api/v1/erp/products');
     products.value = response.data;
   });
   ```

## Traduções

As traduções estão em:
- `app/javascript/dashboard/i18n/locale/en/pdv.json`
- `app/javascript/dashboard/i18n/locale/pt_BR/pdv.json`

Para adicionar novos idiomas, replique a estrutura em outros arquivos de locale.

## Estilos e Ícones

- **Ícone do botão**: `i-ph-shopping-cart-bold` (Phosphor Icons)
- **Framework CSS**: Tailwind CSS
- **Componentes**: Sistema de design interno do Chatwoot

## Personalização

### Adicionar novos campos ao checkout

Edite `PdvCheckout.vue` e adicione os campos necessários no formulário e no `salePayload`.

### Customizar lista de produtos

Edite `PdvProductList.vue` para adicionar filtros adicionais, ordenação, etc.

### Modificar formas de pagamento

No `PdvCheckout.vue`, edite o select de `paymentMethod`:

```vue
<select v-model="paymentMethod">
  <option value="money">Dinheiro</option>
  <option value="credit">Cartão de Crédito</option>
  <!-- Adicione mais opções aqui -->
</select>
```

## Próximos Passos

1. [ ] Implementar conexão real com ERP
2. [ ] Adicionar histórico de vendas
3. [ ] Implementar impressão de recibo
4. [ ] Adicionar gráficos e relatórios de vendas
5. [ ] Suporte para múltiplos impostos
6. [ ] Integração com gateway de pagamento
7. [ ] Notificações de estoque baixo
8. [ ] Sistema de comissões para agentes

## Suporte

Para dúvidas ou problemas, consulte a documentação do Chatwoot ou abra uma issue.
