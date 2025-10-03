# Internal Chat API Documentation

Esta documentação detalha todos os endpoints disponíveis para o sistema de Internal Chat do Chatwoot.

## Base URL
```
/api/v1/accounts/{account_id}/internal_chat
```

## Autenticação
Todas as requisições devem incluir o token de autenticação do usuário no header:
```
Authorization: Bearer {api_access_token}
```

---

## 1. Rooms Endpoints

### GET /rooms
Lista todas as salas disponíveis para o usuário atual.

**Response:**
```json
{
  "rooms": {
    "general": {
      "id": "general",
      "name": "Chat Geral",
      "type": "general",
      "description": "Conversas gerais da equipe"
    },
    "teams": [
      {
        "id": 1,
        "name": "Equipe de Vendas",
        "type": "team",
        "member_count": 5,
        "description": "Equipe"
      }
    ],
    "direct_messages": [
      {
        "id": 2,
        "name": "João Silva",
        "email": "joao@empresa.com",
        "avatar_url": "https://...",
        "availability_status": "online",
        "last_seen_at": "2024-10-02T10:30:00Z"
      }
    ]
  }
}
```

### POST /rooms
Cria uma nova sala de chat direto.

**Request Body:**
```json
{
  "target_user_id": 123
}
```

**Response:**
```json
{
  "data": {
    "id": 456,
    "type": "direct",
    "name": "Direct Chat",
    "participants": [
      {
        "id": 1,
        "name": "Usuario Atual",
        "email": "atual@empresa.com"
      },
      {
        "id": 123,
        "name": "Usuario Alvo",
        "email": "alvo@empresa.com"
      }
    ]
  }
}
```

---

## 2. Messages Endpoints

### GET /messages/general
Busca mensagens do chat geral.

**Query Parameters:**
- `page`: Número da página (default: 1)
- `per_page`: Itens por página (default: 20)
- `before_id`: ID da mensagem para paginação (busca mensagens anteriores)

**Response:**
```json
{
  "data": [
    {
      "id": 456,
      "content": "Olá pessoal!",
      "sender": {
        "id": 2,
        "name": "João Silva",
        "avatar_url": null
      },
      "sender_id": 2,
      "created_at": "2024-10-02T10:30:00Z",
      "message_type": "text",
      "chat_type": "general",
      "room_id": 1
    }
  ],
  "meta": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 45,
    "room_id": 1
  }
}
```

### GET /messages/:room_type/:room_id
Busca mensagens de uma sala específica.

**URL Parameters:**
- `room_type`: Tipo da sala (`direct`, `team`, `general`)
- `room_id`: ID da sala ou do usuário (para chat direto)

**Query Parameters:**
- `page`: Número da página (default: 1)
- `per_page`: Itens por página (default: 20)
- `before_id`: ID da mensagem para paginação

**Examples:**
```
GET /messages/direct/2        # Chat direto com usuário ID 2
GET /messages/team/5          # Chat da equipe ID 5
GET /messages/general/1       # Chat geral
```

**Response:**
```json
{
  "data": [
    {
      "id": 789,
      "content": "Como está o projeto?",
      "sender": {
        "id": 1,
        "name": "Usuário Atual",
        "avatar_url": null
      },
      "sender_id": 1,
      "created_at": "2024-10-02T11:15:00Z",
      "message_type": "text",
      "chat_type": "direct",
      "room_id": 123
    },
    {
      "id": 790,
      "content": "Está indo bem, obrigado!",
      "sender": {
        "id": 2,
        "name": "João Silva",
        "avatar_url": null
      },
      "sender_id": 2,
      "created_at": "2024-10-02T11:16:00Z",
      "message_type": "text",
      "chat_type": "direct",
      "room_id": 123
    }
  ],
  "meta": {
    "current_page": 1,
    "per_page": 20,
    "total_count": 15,
    "room_id": 123
  }
}
```

### POST /send_message
Envia uma mensagem via HTTP (atualmente apenas retorna 200 OK, a funcionalidade real é via WebSocket).

**Request Body:**
```json
{
  "message": {
    "content": "Olá!",
    "room_type": "direct", 
    "room_id": "2"
  }
}
```

**Response:**
```
Status: 200 OK
(Corpo vazio)
```

---

## 3. WebSocket (Action Cable)

### Conexão
```javascript
// Conectar ao canal
const cable = ActionCable.createConsumer(`ws://localhost:3000/cable?user_id=${userId}&account_id=${accountId}&pubsub_token=${token}`);

const subscription = cable.subscriptions.create({
  channel: "InternalChatChannel",
  user_id: userId,
  account_id: accountId,
  pubsub_token: token
}, {
  connected() {
    console.log("Conectado ao Internal Chat");
  },
  
  disconnected() {
    console.log("Desconectado do Internal Chat");
  },
  
  received(data) {
    console.log("Mensagem recebida:", data);
    // data.type === 'new_message'
    // data.message contém os dados da mensagem
  }
});
```

### Envio de Mensagens
```javascript
// Enviar mensagem para chat geral
subscription.send({
  content: "Olá pessoal!",
  chat_type: "general"
});

// Enviar mensagem para chat direto
subscription.send({
  content: "Oi João!",
  chat_type: "direct",
  recipient_id: 2
});

// Enviar mensagem para equipe
subscription.send({
  content: "Reunião às 14h",
  chat_type: "team",
  team_id: 5
});
```

### Formato de Mensagens Recebidas
```json
{
  "type": "new_message",
  "chat_type": "direct",
  "chat_id": "2",
  "message": {
    "id": 891,
    "content": "Olá!",
    "sender": {
      "id": 2,
      "name": "João Silva",
      "avatar_url": null
    },
    "sender_id": 2,
    "recipient_id": 1,
    "team_id": null,
    "chat_type": "direct",
    "created_at": "2024-10-02T12:00:00Z",
    "message_type": "text"
  },
  "timestamp": "2024-10-02T12:00:00Z"
}
```

---

## 4. Estrutura do Banco de Dados

### Tabelas Principais

#### gc_internal_chat_rooms
- `id`: Primary key
- `account_id`: FK para accounts
- `team_id`: FK para teams (nullable)
- `room_type`: enum (general=0, team=1, direct=2)
- `name`: Nome da sala
- `slug`: Identificador único
- `direct_key`: Chave única para chats diretos (formato: "direct-{user1_id}-{user2_id}")
- `description`: Descrição da sala
- `created_at`, `updated_at`

#### gc_internal_chat_messages
- `id`: Primary key
- `account_id`: FK para accounts
- `room_id`: FK para gc_internal_chat_rooms
- `sender_id`: FK para users
- `content`: Conteúdo da mensagem
- `message_type`: Tipo da mensagem (default: 'text')
- `deleted_at`: Soft delete
- `created_at`, `updated_at`

#### gc_internal_chat_memberships
- `id`: Primary key
- `room_id`: FK para gc_internal_chat_rooms
- `user_id`: FK para users
- `created_at`, `updated_at`

---

## 5. Lógica de Salas (Rooms)

### Chat Geral
- Tipo: `general`
- Uma sala por conta
- Todos os usuários da conta têm acesso
- Criada automaticamente quando necessário

### Chat de Equipe
- Tipo: `team`
- Uma sala por equipe
- Apenas membros da equipe têm acesso
- Associada ao `team_id`

### Chat Direto
- Tipo: `direct`
- Uma sala por par de usuários
- `direct_key` garante unicidade: "direct-{menor_id}-{maior_id}"
- Memberships definem os participantes

---

## 6. Autenticação e Autorização

### HTTP Endpoints
- Requer token de autenticação do usuário
- Usa `Current.user` e `Current.account`
- Verifica acesso às salas baseado no tipo

### WebSocket
- Usa `pubsub_token` para autenticação
- Parâmetros: `user_id`, `account_id`, `pubsub_token`
- Suporta tanto User quanto SuperAdmin

---

## 7. Tratamento de Erros

### Códigos de Status HTTP
- `200`: Sucesso
- `401`: Não autorizado
- `404`: Recurso não encontrado
- `422`: Dados inválidos

### Logs
- Logs detalhados para debugging
- Identificação por emojis para facilitar leitura
- Tratamento especial para erros STI (Single Table Inheritance)

---

## 8. Paginação

### Parâmetros
- `page`: Página atual (1-based)
- `per_page`: Itens por página (máximo recomendado: 50)
- `before_id`: Para paginação cronológica reversa

### Estratégia
- Mensagens são carregadas das mais recentes para as mais antigas
- `before_id` permite carregar mensagens anteriores
- Ideal para implementar scroll infinito

---

## 9. Performance e Otimizações

### Queries Otimizadas
- Uso de `includes` para evitar N+1 queries
- Queries diretas via `ActiveRecord::Base.connection.exec_query` para evitar problemas STI
- Índices em `room_id`, `sender_id`, `created_at`

### Cache
- Salas são criadas uma vez e reutilizadas
- `direct_key` evita duplicação de salas diretas

### Limits
- Paginação padrão: 20 mensagens
- Broadcast apenas para usuários da conta
- Soft delete para mensagens