# 📚 Arquitetura Completa do Chat Interno - Chatwoot

## 📋 Índice
1. [Visão Geral](#visão-geral)
2. [Arquitetura de Dados](#arquitetura-de-dados)
3. [Fluxo Frontend → Backend](#fluxo-frontend--backend)
4. [Fluxo de Mensagens em Tempo Real](#fluxo-de-mensagens-em-tempo-real)
5. [Componentes Detalhados](#componentes-detalhados)
6. [Diagramas de Sequência](#diagramas-de-sequência)

---

## 🎯 Visão Geral

O **Chat Interno** é um sistema de comunicação em tempo real dentro do Chatwoot que permite:
- 💬 Chat geral da conta (todos os agentes)
- 👥 Chats de equipe (apenas membros do time)
- 🔒 Conversas diretas 1:1 entre agentes

**Stack Tecnológico:**
- **Frontend**: Vue 3 (Composition API) + ActionCable Client
- **Backend**: Rails 7 + ActionCable + PostgreSQL
- **Real-time**: WebSocket via ActionCable
- **Persistência**: PostgreSQL

---

## 🗄️ Arquitetura de Dados

### Modelos Principais

#### 1. `GcInternalChatRoom`
Representa uma sala de chat (general, team ou direct).

```ruby
# app/models/gc_internal_chat_room.rb

class GcInternalChatRoom < ApplicationRecord
  belongs_to :account
  belongs_to :team, optional: true
  has_many :gc_internal_chat_memberships
  has_many :gc_internal_chat_messages
  has_many :users, through: :gc_internal_chat_memberships

  enum room_type: {
    general: 0,   # Chat geral da conta
    team: 1,      # Chat de equipe
    direct: 2     # Conversa direta 1:1
  }
end
```

**Campos importantes:**
- `room_type`: Tipo da sala (0=general, 1=team, 2=direct)
- `account_id`: Conta à qual a sala pertence
- `team_id`: ID do time (apenas para room_type=team)
- `direct_key`: Chave única para salas diretas (ex: "1-5" para users 1 e 5)
- `slug`: Identificador único (ex: "general", "team-5", "direct-1-5")
- `metadata`: JSON com dados extras

**Índices únicos garantem:**
- ✅ Uma sala general por conta
- ✅ Uma sala por time por conta
- ✅ Uma sala direct por par de usuários

#### 2. `GcInternalChatMessage`
Representa uma mensagem enviada em uma sala.

```ruby
# app/models/gc_internal_chat_message.rb

class GcInternalChatMessage < ApplicationRecord
  belongs_to :room, class_name: 'GcInternalChatRoom'
  belongs_to :account
  belongs_to :sender, class_name: 'User'
  belongs_to :edited_by, optional: true
  belongs_to :deleted_by, optional: true

  scope :active, -> { where(deleted_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
end
```

**Campos importantes:**
- `content`: Texto da mensagem
- `sender_id`: Quem enviou
- `room_id`: Em qual sala foi enviada
- `account_id`: Conta (para queries otimizadas)
- `deleted_at`: Soft delete
- `edited_at`: Se foi editada

#### 3. `GcInternalChatMembership`
Relaciona usuários e salas (tabela de junção).

```ruby
class GcInternalChatMembership < ApplicationRecord
  belongs_to :user
  belongs_to :room, class_name: 'GcInternalChatRoom'
end
```

---

## 🔄 Fluxo Frontend → Backend

### 📊 Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                        FRONTEND (Vue 3)                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  InternalChatPanelActionCable.vue                    │   │
│  │  - Interface do chat (UI)                             │   │
│  │  - Lista de salas (sidebar)                           │   │
│  │  - Área de mensagens                                  │   │
│  │  - Input para enviar mensagens                        │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                         │
│                     ↓                                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  useInternalChatData.js (Composable)                 │   │
│  │  - Gerencia estado reativo                           │   │
│  │  - Conecta ao WebSocket                              │   │
│  │  - Envia/recebe mensagens                            │   │
│  │  - Faz chamadas HTTP via API                         │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                         │
│                     ↓                                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  internalChat.js (API Client)                        │   │
│  │  - axios.get('/internal_chat/rooms')                 │   │
│  │  - axios.post('/internal_chat/send_message')         │   │
│  │  - axios.get('/internal_chat/messages/:type/:id')    │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                         │
└─────────────────────┼─────────────────────────────────────────┘
                      │
                      │ HTTP/HTTPS
                      ↓
┌─────────────────────────────────────────────────────────────┐
│                    BACKEND (Rails 7)                         │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  InternalChatController (HTTP API)                   │   │
│  │  GET  /api/v1/accounts/:id/internal_chat/rooms       │   │
│  │  POST /api/v1/accounts/:id/internal_chat/send_message│   │
│  │  GET  /api/v1/accounts/:id/internal_chat/messages/...│   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                         │
│                     ↓                                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Models (ActiveRecord)                                │   │
│  │  - GcInternalChatRoom                                 │   │
│  │  - GcInternalChatMessage                              │   │
│  │  - GcInternalChatMembership                           │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                         │
│                     ↓                                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         PostgreSQL Database                           │   │
│  │  - gc_internal_chat_rooms                             │   │
│  │  - gc_internal_chat_messages                          │   │
│  │  - gc_internal_chat_memberships                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
└───────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              REAL-TIME (WebSocket / ActionCable)             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Frontend                    Backend                          │
│  ┌────────────┐             ┌──────────────────┐            │
│  │ ActionCable│◄──WebSocket─►│InternalChatChannel│           │
│  │  Consumer  │             │  (ActionCable)   │            │
│  └────────────┘             └──────────────────┘            │
│       ↑                              │                        │
│       │                              ↓                        │
│       │                     ActionCable.server.broadcast()   │
│       │                              │                        │
│       └──────────────────────────────┘                        │
│              Recebe mensagens em tempo real                   │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

---

## 🚀 Fluxo Detalhado: Enviar Mensagem

### Passo 1: Usuário Digita e Clica em "Enviar"

**Arquivo:** `InternalChatPanelActionCable.vue`
**Localização:** `app/javascript/dashboard/components/internal-chat/`

```vue
<!-- Template - Botão de enviar -->
<button @click="sendMessageAction" type="submit">
  Enviar
</button>

<!-- Script -->
<script setup>
const sendMessageAction = async () => {
  console.log('🚀 sendMessageAction called!');
  
  if (!messageInput.value.trim()) return;
  
  const messageContent = messageInput.value.trim();
  messageInput.value = ''; // Limpa input imediatamente
  
  // Chama o composable
  await sendMessage(messageContent);
};
</script>
```

**O que acontece:**
1. ✅ Valida se mensagem não está vazia
2. ✅ Limpa o input imediatamente (UX responsiva)
3. ✅ Chama função `sendMessage()` do composable

---

### Passo 2: Composable Processa o Envio

**Arquivo:** `useInternalChatData.js`
**Localização:** `app/javascript/dashboard/composables/`

```javascript
const sendMessage = async content => {
  const text = content.trim();
  
  // 1. Normaliza a sala atual
  const normalizedRoom = normalizeRoom(currentRoom.value);
  const targetRoomId = normalizedRoom.room_id 
    || normalizedRoom.id 
    || normalizedRoom.identifier;

  // 2. Cria mensagem temporária (otimistic update)
  const tempId = `temp-${Date.now()}`;
  const tempMessage = {
    id: tempId,
    content: text,
    sender: currentUser.value,
    sender_id: currentUser.value?.id,
    created_at: new Date().toISOString(),
    room_id: normalizedRoom.room_id,
    temp: true  // Flag para identificar como temporária
  };
  
  // 3. Adiciona temp message na UI imediatamente
  upsertMessage(tempMessage);
  
  // 4. Envia para o backend via HTTP
  try {
    const response = await internalChatAPI.sendMessage({
      roomType: normalizedRoom.room_type,
      roomId: targetRoomId,
      content: text
    });
    
    const savedMessage = response.data?.data;
    
    // 5. Remove mensagem temporária
    const tempIndex = messages.value.findIndex(m => m.id === tempId);
    if (tempIndex !== -1) {
      messages.value.splice(tempIndex, 1);
    }
    
    // 6. Adiciona mensagem real do servidor
    if (savedMessage) {
      upsertMessage(savedMessage);
    }
    
    return savedMessage;
  } catch (error) {
    // Remove temp message em caso de erro
    messages.value = messages.value.filter(m => m.id !== tempId);
  }
};
```

**O que acontece:**
1. ✅ **Optimistic Update**: Adiciona mensagem na UI antes de confirmar com servidor
2. ✅ Envia para servidor via HTTP POST
3. ✅ Remove mensagem temporária
4. ✅ Adiciona mensagem real com ID do banco
5. ❌ Se falhar, remove mensagem temporária

**Vantagens do Optimistic Update:**
- Interface instantânea (não espera resposta do servidor)
- Usuário vê mensagem imediatamente
- Se falhar, reverte automaticamente

---

### Passo 3: API Client Faz Requisição HTTP

**Arquivo:** `internalChat.js`
**Localização:** `app/javascript/dashboard/api/`

```javascript
class InternalChatAPI extends ApiClient {
  sendMessage({ roomType, roomId, content }) {
    const payload = {
      message: {
        content,
        room_type: roomType,
        room_id: roomId,
      },
    };

    return axios.post(`${this.url}/send_message`, payload)
      .catch(error => {
        console.error('❌ Internal chat API error:', error);
        throw error;
      });
  }
}
```

**URL gerada:**
```
POST /api/v1/accounts/1/internal_chat/send_message
```

**Payload enviado:**
```json
{
  "message": {
    "content": "Olá, como vai?",
    "room_type": "direct",
    "room_id": 5
  }
}
```

---

### Passo 4: Controller Recebe e Persiste

**Arquivo:** `internal_chat_controller.rb`
**Localização:** `app/controllers/api/v1/accounts/`

```ruby
def send_message
  # 1. Extrai parâmetros
  content = params.dig(:message, :content)
  room_type = params.dig(:message, :room_type) || 'general'
  room_id = params.dig(:message, :room_id) || 'general'
  
  Rails.logger.info "📤 Sending message: '#{content}' to #{room_type}/#{room_id}"
  
  # 2. Encontra ou cria a sala
  room = find_or_create_room(room_type, room_id)
  return render json: { errors: ['Room not found'] }, status: :not_found unless room
  
  # 3. Cria mensagem no banco
  message = GcInternalChatMessage.create!(
    room_id: room.id,
    account_id: Current.account.id,
    sender_id: Current.user.id,
    content: content
  )
  
  Rails.logger.info "✅ Message created: ##{message.id}"
  
  # 4. Serializa mensagem
  serialized_message = {
    id: message.id,
    content: message.content,
    sender: {
      id: message.sender.id,
      name: message.sender.name,
      avatar_url: message.sender.avatar_url
    },
    sender_id: message.sender.id,
    created_at: message.created_at.iso8601,
    message_type: 'text',
    chat_type: room_type,
    chat_id: room_id,
    room_id: room.id
  }
  
  # 5. Faz broadcast via ActionCable
  channel_name = determine_broadcast_channel(room_type, room_id)
  
  ActionCable.server.broadcast(
    channel_name,
    {
      type: 'new_message',
      message: serialized_message,
      chat_type: room_type,
      chat_id: room_id,
      timestamp: message.created_at.iso8601
    }
  )
  
  Rails.logger.info "📡 Message broadcasted to #{channel_name}"
  
  # 6. Retorna mensagem para o cliente
  render json: { data: serialized_message }, status: :created
end
```

**O que acontece:**
1. ✅ Valida parâmetros
2. ✅ Encontra ou cria sala (se não existir)
3. ✅ **Persiste mensagem no PostgreSQL**
4. ✅ Serializa mensagem para JSON
5. ✅ **Faz broadcast via WebSocket** (ActionCable)
6. ✅ Retorna mensagem para o cliente HTTP

**Canais de Broadcast:**
```ruby
def determine_broadcast_channel(room_type, room_id)
  case room_type.to_s
  when 'team'
    # Canal específico do time
    "internal_chat_#{Current.account.id}_team_#{room_id}"
  else
    # Canal geral (general e direct)
    "internal_chat_#{Current.account.id}"
  end
end
```

**Exemplos de canais:**
- General: `internal_chat_1`
- Direct: `internal_chat_1`
- Team 5: `internal_chat_1_team_5`
- Team 8: `internal_chat_1_team_8`

---

## ⚡ Fluxo de Mensagens em Tempo Real (WebSocket)

### Como Funciona o ActionCable

ActionCable é o sistema de WebSocket do Rails que permite comunicação bidirecional em tempo real.

### Passo 1: Cliente Conecta ao WebSocket

**Arquivo:** `useInternalChatData.js`

```javascript
const ensureSubscription = (force = false) => {
  const accountId = currentAccountId.value;
  const user = currentUser.value;
  
  // Cria consumer do ActionCable
  let cable = window.App?.cable;
  if (!cable) {
    consumer = createConsumer(cableURL());
    cable = consumer;
  }
  
  // Parâmetros da subscription
  const params = {
    channel: 'InternalChatChannel',
    account_id: accountId,
    user_id: user.id,
    pubsub_token: user.pubsub_token  // Para autenticação
  };
  
  // Cria subscription
  subscription = cable.subscriptions.create(params, {
    // Callback quando conecta
    connected() {
      console.log('✅ Internal chat cable connected');
      isConnected.value = true;
    },
    
    // Callback quando desconecta
    disconnected() {
      console.log('❌ Internal chat cable disconnected');
      isConnected.value = false;
      scheduleReconnect();  // Tenta reconectar
    },
    
    // Callback quando recebe mensagem
    received(data) {
      console.log('📩 Message received:', data);
      
      // Verifica se mensagem é da sala atual
      if (messageMatchesCurrentRoom(data)) {
        upsertMessage(data.message);  // Adiciona na UI
      }
    }
  });
};
```

**URL do WebSocket:**
```
ws://localhost:3000/cable
```

**Autenticação:**
- Envia `pubsub_token` único do usuário
- Server valida token e identifica usuário

---

### Passo 2: Server Aceita Conexão

**Arquivo:** `internal_chat_channel.rb`
**Localização:** `app/channels/`

```ruby
class InternalChatChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "✅ Subscription attempt"
    Rails.logger.info "👤 User: #{current_user&.id}"
    Rails.logger.info "🏢 Account: #{current_account&.id}"
    
    # Rejeita se não autenticado
    unless current_user && current_account
      Rails.logger.error "❌ Rejected: missing user or account"
      reject
      return
    end
    
    # Inscreve no canal geral (para general e direct)
    stream_from general_stream_name
    Rails.logger.info "🔌 Subscribed to: #{general_stream_name}"
    
    # Inscreve nos canais de cada time que o usuário é membro
    user_teams = current_user.teams.where(account_id: current_account.id)
    user_teams.each do |team|
      team_stream = team_stream_name(team.id)
      stream_from team_stream
      Rails.logger.info "🔌 Subscribed to team: #{team_stream}"
    end
    
    Rails.logger.info "✅ Total: 1 general + #{user_teams.count} teams"
  end
  
  def unsubscribed
    Rails.logger.info "👋 Unsubscribed"
  end
  
  private
  
  def current_user
    @current_user ||= begin
      if params[:pubsub_token].present?
        User.find_by(pubsub_token: params[:pubsub_token])
      end
    end
  end
  
  def current_account
    @current_account ||= current_user.accounts.find_by(id: params[:account_id])
  end
  
  def general_stream_name
    "internal_chat_#{current_account.id}"
  end
  
  def team_stream_name(team_id)
    "internal_chat_#{current_account.id}_team_#{team_id}"
  end
end
```

**O que acontece:**
1. ✅ Valida autenticação via `pubsub_token`
2. ✅ Identifica usuário e conta
3. ✅ Inscreve em múltiplos canais:
   - 1 canal geral: `internal_chat_1`
   - N canais de time: `internal_chat_1_team_5`, `internal_chat_1_team_8`, etc.
4. ✅ Mantém conexão WebSocket ativa

**Exemplo de inscrições:**
```
User ID 10, Account ID 1, Member of Teams [5, 8]

Canais inscritos:
- internal_chat_1 (general + direct)
- internal_chat_1_team_5
- internal_chat_1_team_8
```

---

### Passo 3: Broadcast de Mensagem

Quando alguém envia mensagem (via HTTP POST), o controller faz:

```ruby
# No controller
ActionCable.server.broadcast(
  "internal_chat_1_team_5",  # Canal específico
  {
    type: 'new_message',
    message: { id: 123, content: "Hello", ... },
    chat_type: 'team',
    chat_id: 5
  }
)
```

**O que acontece:**
1. ✅ ActionCable server envia para **todos os clientes** inscritos no canal `internal_chat_1_team_5`
2. ✅ Apenas membros do Team 5 recebem (por estarem inscritos)
3. ✅ Outros usuários não recebem (não inscritos no canal)

---

### Passo 4: Cliente Recebe Mensagem

**Arquivo:** `useInternalChatData.js`

```javascript
received(data) {
  console.log('📩 Payload received:', data);
  
  if (data.type === 'new_message' && data.message) {
    // Verifica se está na sala correta
    if (!currentRoom.value) return;
    
    const incomingRoomId = data.message.room_id;
    const currentRoomId = currentRoom.value.room_id;
    
    // Match por room_id
    const matchesRoomId = currentRoomId && incomingRoomId
      && String(currentRoomId) === String(incomingRoomId);
    
    // Match por identifier (para general)
    const matchesIdentifier = currentRoom.value.identifier 
      && data.chat_id
      && String(currentRoom.value.identifier) === String(data.chat_id);
    
    // Match para general
    const matchesGeneral = currentRoom.value.room_type === 'general'
      && data.chat_type === 'general';
    
    // Se match, adiciona na UI
    if (matchesRoomId || matchesIdentifier || matchesGeneral) {
      console.log('✅ Message matches current room');
      upsertMessage(data.message);
    } else {
      console.warn('❌ Message does NOT match current room');
    }
  }
}
```

**O que acontece:**
1. ✅ Recebe payload via WebSocket
2. ✅ Verifica se é tipo `new_message`
3. ✅ Compara sala atual com sala da mensagem
4. ✅ Se match, adiciona na UI via `upsertMessage()`
5. ❌ Se não match, ignora (usuário está em outra sala)

**Função `upsertMessage`:**
```javascript
const upsertMessage = message => {
  if (!message || !message.id) return;
  
  // Garante que messages é array
  ensureMessagesCollection();
  
  // Procura se mensagem já existe (por ID)
  const index = messages.value.findIndex(item => item.id === message.id);
  
  if (index === -1) {
    // Não existe: adiciona no final
    messages.value.push(message);
  } else {
    // Existe: substitui (para edições)
    messages.value.splice(index, 1, message);
  }
};
```

---

### Passo 5: UI Atualiza Automaticamente

**Arquivo:** `InternalChatPanelActionCable.vue`

```javascript
// Watch inteligente: observa apenas o LENGTH do array
let previousLength = 0;

watch(() => messages.value.length, (newLength) => {
  // Só faz scroll se array cresceu
  if (newLength > previousLength && newLength > 0) {
    nextTick(() => {
      if (messageContainer.value) {
        messageContainer.value.scrollTop = messageContainer.value.scrollHeight;
      }
    });
  }
  previousLength = newLength;
});
```

**O que acontece:**
1. ✅ Vue detecta mudança em `messages` (reatividade)
2. ✅ Re-renderiza lista de mensagens
3. ✅ Watch detecta aumento no `length`
4. ✅ Faz scroll automático para o final
5. ✅ Usuário vê nova mensagem instantaneamente

**Por que observar apenas `length`?**
- ❌ `watch(messages)` dispara em **qualquer mudança** (muito pesado)
- ✅ `watch(() => messages.value.length)` dispara **apenas quando adiciona/remove**
- ✅ Performance muito melhor (não re-renderiza sidebar)

---

## 📊 Diagrama de Sequência Completo

### Cenário: User A envia mensagem para User B (Direct Chat)

```
User A (Browser)          Frontend           API Client        Backend Controller      Database        ActionCable        User B (Browser)
     │                        │                   │                    │                    │                │                     │
     │ 1. Click "Send"        │                   │                    │                    │                │                     │
     ├────────────────────────>│                   │                    │                    │                │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │ 2. Create temp msg│                    │                    │                │                     │
     │                        ├──────────────────>│                    │                    │                │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │ 3. Show temp msg  │                    │                    │                │                     │
     │<────────────────────────┤                   │                    │                    │                │                     │
     │  (Optimistic Update)   │                   │                    │                    │                │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │                   │ 4. POST /send_message                  │                │                     │
     │                        │                   ├───────────────────>│                    │                │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │                   │                    │ 5. Create message  │                │                     │
     │                        │                   │                    ├───────────────────>│                │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │                   │                    │ 6. Message saved   │                │                     │
     │                        │                   │                    │<───────────────────┤                │                     │
     │                        │                   │                    │ (with ID)          │                │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │                   │                    │ 7. Broadcast       │                │                     │
     │                        │                   │                    ├───────────────────────────────────>│                     │
     │                        │                   │                    │ channel: internal_chat_1           │                     │
     │                        │                   │                    │ data: {type: 'new_message', ...}   │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │                   │ 8. HTTP Response   │                    │                │                     │
     │                        │                   │<───────────────────┤                    │                │                     │
     │                        │                   │ { data: { id: 123, ... } }              │                │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │ 9. Remove temp    │                    │                    │                │                     │
     │                        │<──────────────────┤                    │                    │                │                     │
     │                        │ 10. Add real msg  │                    │                    │                │                     │
     │                        │                   │                    │                    │                │                     │
     │                        │                   │                    │                    │ 11. WebSocket Push                  │
     │                        │                   │                    │                    │                ├────────────────────>│
     │                        │                   │                    │                    │                │  (User B receives)  │
     │                        │                   │                    │                    │                │                     │
     │                        │ 12. WebSocket Push│                    │                    │                │                     │
     │<───────────────────────────────────────────────────────────────────────────────────────┤              │                     │
     │  (User A receives own message via WebSocket)                   │                    │                │                     │
     │                        │                   │                    │                    │                │                     │
     │ 13. UI updates         │                   │                    │                    │                │  14. UI updates     │
     │  (both users see msg)  │                   │                    │                    │                │                     │
```

**Tempo total:** ~100-300ms (depende da latência de rede)

**Pontos importantes:**
1. **Optimistic Update (passo 3)**: Usuário vê mensagem instantaneamente
2. **Persistência (passo 5-6)**: Mensagem salva no banco com ID único
3. **Broadcast (passo 7)**: Envia para todos via WebSocket
4. **Dupla entrega (passos 11-12)**: Ambos recebem via WebSocket
5. **Deduplicação**: Frontend ignora mensagem duplicada (já tem com mesmo ID)

---

## 🔐 Segurança e Isolamento

### Isolamento por Account

Cada canal inclui `account_id`:
```ruby
"internal_chat_#{account_id}"
"internal_chat_#{account_id}_team_#{team_id}"
```

**Garante que:**
- ✅ Users da Account 1 não recebem mensagens da Account 2
- ✅ Mesmo que tenham mesmo `team_id`, o canal é diferente

### Isolamento por Team

Canais de time são separados:
```ruby
"internal_chat_1_team_5"  # Team 5
"internal_chat_1_team_8"  # Team 8
```

**Garante que:**
- ✅ Apenas membros do Team 5 se inscrevem no canal `_team_5`
- ✅ Mensagens do Team 5 não vão para Team 8

### Autenticação WebSocket

```ruby
def current_user
  @current_user ||= User.find_by(
    id: params[:user_id],
    pubsub_token: params[:pubsub_token]
  )
end
```

**Garante que:**
- ✅ Token único por usuário (`pubsub_token`)
- ✅ Impossível se passar por outro usuário
- ✅ Se token inválido, conexão é rejeitada

---

## 🎨 Componentes Detalhados

### 1. InternalChatPanelActionCable.vue

**Responsabilidades:**
- Renderiza interface do chat
- Gerencia estado local (input, sala selecionada)
- Delega lógica complexa para composable

**Estrutura:**
```vue
<template>
  <!-- Sidebar com lista de salas -->
  <div class="sidebar">
    <div @click="selectChat('general')">General</div>
    <div v-for="team in teams" @click="selectChat('team', team.id)">
      {{ team.name }}
    </div>
    <div v-for="user in users" @click="selectChat('direct', user.id)">
      {{ user.name }}
    </div>
  </div>
  
  <!-- Área de mensagens -->
  <div class="messages" ref="messageContainer">
    <div v-for="message in messages" :key="message.id">
      {{ message.content }}
    </div>
  </div>
  
  <!-- Input -->
  <form @submit.prevent="sendMessageAction">
    <textarea v-model="messageInput" />
    <button type="submit">Send</button>
  </form>
</template>
```

**Estado local:**
```javascript
const messageInput = ref('');              // Texto digitado
const selectedChatType = ref('general');   // Tipo da sala atual
const selectedChatId = ref(null);          // ID da sala atual
const messageContainer = ref(null);        // Ref do div de mensagens
```

**Dados do composable:**
```javascript
const {
  messages,        // Array reativo de mensagens
  rooms,           // Salas disponíveis
  isLoading,       // Estado de carregamento
  sendMessage,     // Função para enviar
  loadRooms,       // Carrega lista de salas
  selectRoom,      // Troca de sala
} = useInternalChatData();
```

---

### 2. useInternalChatData.js (Composable)

**Responsabilidades:**
- Gerencia estado global do chat
- Conecta ao WebSocket
- Faz chamadas HTTP
- Sincroniza mensagens

**Estado reativo:**
```javascript
const messages = ref([]);           // Mensagens da sala atual
const rooms = ref({});              // Salas disponíveis
const currentRoom = ref(null);      // Sala selecionada
const isLoading = ref(false);       // Loading state
const isConnected = ref(false);     // WebSocket conectado?
```

**Funções principais:**
```javascript
loadRooms()              // Carrega lista de salas
loadMessages(type, id)   // Carrega mensagens de uma sala
sendMessage(content)     // Envia mensagem
selectRoom(room)         // Troca de sala
ensureSubscription()     // Conecta ao WebSocket
upsertMessage(message)   // Adiciona/atualiza mensagem
```

**Lifecycle:**
```javascript
onMounted(() => {
  loadRooms();           // Carrega salas ao montar
});

onUnmounted(() => {
  disconnect();          // Desconecta WebSocket ao desmontar
});

watch([currentUser, currentAccountId], () => {
  ensureSubscription();  // Reconecta se user/account mudar
});
```

---

### 3. internalChat.js (API Client)

**Responsabilidades:**
- Abstrai chamadas HTTP
- Lida com erros
- Formata payloads

**Endpoints:**
```javascript
getRooms()                         // GET  /internal_chat/rooms
getMessages({ roomType, roomId })  // GET  /internal_chat/messages/:type/:id
sendMessage({ roomType, roomId, content })  // POST /internal_chat/send_message
createDirectRoom(targetUserId)     // POST /internal_chat/create_direct_room
```

---

## 🐛 Debugging

### Logs do Frontend

```javascript
console.log('📤 Sending message:', messageData);
console.log('📩 Payload received:', data);
console.log('✅ Message matches current room');
console.log('❌ Message does NOT match current room');
```

**Como ver:**
1. Abra DevTools (F12)
2. Aba "Console"
3. Filtre por emojis: `📤` `📩` `✅` `❌`

### Logs do Backend

```ruby
Rails.logger.info "📤 Sending message: '#{content}' to #{room_type}/#{room_id}"
Rails.logger.info "✅ Message created: ##{message.id}"
Rails.logger.info "📡 Broadcasting to channel: #{channel_name}"
Rails.logger.info "🔌 Subscribed to: #{stream_name}"
```

**Como ver:**
```bash
tail -f log/development.log | grep "📤\|✅\|📡\|🔌"
```

### Debug WebSocket

**Ver conexões ativas:**
```ruby
# Rails console
ActionCable.server.connections.count
```

**Ver subscribers de um canal:**
```bash
redis-cli
PUBSUB NUMSUB internal_chat_1
PUBSUB NUMSUB internal_chat_1_team_5
```

---

## 🚨 Problemas Comuns

### 1. Mensagens não aparecem em tempo real

**Possíveis causas:**
- ❌ WebSocket não conectado
- ❌ Canal errado (mismatch entre sender e receiver)
- ❌ Filtro de sala bloqueando mensagem

**Como debugar:**
```javascript
// No console do navegador
console.log(isConnected.value);  // Deve ser true
console.log(subscription);        // Deve existir
```

**Verificar canal no servidor:**
```bash
# Log deve mostrar:
🔌 Subscribed to: internal_chat_1
📡 Broadcasting to channel: internal_chat_1
```

### 2. Sidebar recarregando ao enviar mensagem

**Causa:**
- ❌ `watch(messages)` com `deep: true`
- ❌ Computed props dependendo de `messages` inteiro

**Solução:**
```javascript
// ❌ ERRADO
watch(messages, () => { ... }, { deep: true });

// ✅ CORRETO
watch(() => messages.value.length, () => { ... });
```

### 3. Mensagem aparece duplicada

**Causa:**
- Usuário recebe por HTTP response E WebSocket

**Solução:**
- `upsertMessage()` já faz deduplicação por ID
- Se mensagem com mesmo ID existe, substitui ao invés de adicionar

---

## 📈 Performance

### Otimizações Implementadas

1. **Optimistic Update**
   - Mensagem aparece instantaneamente
   - Não espera resposta do servidor
   - Reverte em caso de erro

2. **Watch Inteligente**
   - Observa apenas `messages.value.length`
   - Não observa objeto inteiro (deep watch)
   - Performance muito melhor

3. **Canais Separados por Time**
   - Broadcasts só para membros relevantes
   - Evita tráfego desnecessário
   - Escalável para muitos times

4. **Reconnect Automático**
   - Se WebSocket cai, tenta reconectar em 1s
   - Usuário não precisa recarregar página

5. **Lazy Loading de Mensagens**
   - Carrega apenas últimas 50 mensagens
   - Pode implementar scroll infinito depois

---

## 🔮 Melhorias Futuras

### Features Pendentes

1. **Typing Indicators**
   ```ruby
   # Backend
   def typing
     broadcast_to_room(current_room, {
       type: 'user_typing',
       user_id: current_user.id,
       user_name: current_user.name
     })
   end
   ```

2. **Read Receipts**
   - Marcar mensagens como lidas
   - Mostrar "visto por X pessoas"

3. **Notificações Desktop**
   ```javascript
   if (Notification.permission === 'granted') {
     new Notification('New message', {
       body: message.content,
       icon: sender.avatar_url
     });
   }
   ```

4. **Upload de Arquivos**
   - Anexar imagens/documentos
   - Preview de imagens
   - Upload direto para storage

5. **Edição/Deleção de Mensagens**
   - Já tem campos no banco: `edited_at`, `deleted_at`
   - Implementar UI e lógica

6. **Busca de Mensagens**
   - Full-text search no PostgreSQL
   - Filtro por data, autor, sala

7. **Mensagens Não Lidas**
   - Counter de mensagens não lidas por sala
   - Badge na sidebar

---

## 📚 Referências

- **ActionCable Docs**: https://guides.rubyonrails.org/action_cable_overview.html
- **Vue Composition API**: https://vuejs.org/guide/extras/composition-api-faq.html
- **Rails WebSocket**: https://edgeguides.rubyonrails.org/action_cable_overview.html

---

## 🎯 Conclusão

O Chat Interno do Chatwoot é um sistema robusto que combina:

- ✅ **Performance**: Optimistic updates + Watch inteligente
- ✅ **Real-time**: ActionCable com canais separados
- ✅ **Segurança**: Isolamento por account e autenticação WebSocket
- ✅ **Escalabilidade**: Canais separados por contexto (team, direct, general)
- ✅ **UX**: Interface responsiva e feedback instantâneo

A arquitetura permite crescimento futuro sem grandes refatorações!
