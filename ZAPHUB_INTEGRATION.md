# Integração Chatwoot + ZapHub WhatsApp API# ZapHub WhatsApp Integration - Guia de Implementação



Guia completo para conectar o Chatwoot com a API ZapHub e gerenciar conversas do WhatsApp.## Visão Geral



---Este documento descreve a integração do ZapHub WhatsApp API com o Chatwoot. A integração permite conectar WhatsApp ao Chatwoot usando a API do ZapHub, que fornece uma interface completa para enviar e receber mensagens WhatsApp.



## 📋 Índice## Arquitetura



- [Visão Geral](#visão-geral)### Componentes Backend

- [Pré-requisitos](#pré-requisitos)

- [Configuração](#configuração)1. **Model: `Channel::Zaphub`** (`app/models/channel/zaphub.rb`)

- [Endpoints da API](#endpoints-da-api)   - Gerencia a configuração do canal ZapHub

- [Fluxo de Integração](#fluxo-de-integração)   - Campos: `api_key`, `base_url`, `session_id`, `webhook_url`, `qr_code_data`, `status`

- [Troubleshooting](#troubleshooting)   - Métodos: `create_session`, `fetch_qr_code`, `check_status`



---2. **Service: `Zaphub::SessionService`** (`app/services/zaphub/session_service.rb`)

   - Comunica com a API do ZapHub

## 🎯 Visão Geral   - Métodos:

     - `create_session`: Cria uma nova sessão WhatsApp

Esta integração permite que o **Chatwoot** gerencie conversas do WhatsApp através da **API ZapHub**, que utiliza a biblioteca Baileys para conexão oficial com o WhatsApp Web.     - `fetch_qr_code`: Obtém o QR code para conexão

     - `check_status`: Verifica status da conexão

### Arquitetura:     - `send_message`: Envia mensagens via ZapHub



```3. **Service: `Zaphub::SendOnZaphubService`** (`app/services/zaphub/send_on_zaphub_service.rb`)

WhatsApp ←→ ZapHub API (Baileys) ←→ Chatwoot   - Envia mensagens do Chatwoot para WhatsApp via ZapHub

```   - Suporta tipos: text, image, video, audio, document



**Fluxo:**4. **Controller: `Api::V1::Accounts::Channels::ZaphubChannelsController`**

1. Chatwoot cria uma sessão no ZapHub   - Endpoints para gerenciar canais ZapHub:

2. ZapHub gera QR Code para autenticação     - `POST /api/v1/accounts/:account_id/channels/zaphub_channels/:id/create_session`

3. WhatsApp conecta via QR Code     - `GET /api/v1/accounts/:account_id/channels/zaphub_channels/:id/qr_code`

4. Mensagens são sincronizadas bidirecionalmente via webhooks     - `GET /api/v1/accounts/:account_id/channels/zaphub_channels/:id/status`

     - `POST /api/v1/accounts/:account_id/channels/zaphub_channels/:id/disconnect`

---

5. **Webhook Controller: `Public::Api::V1::Zaphub::CallbacksController`**

## ✅ Pré-requisitos   - Recebe eventos do ZapHub

   - Endpoint: `POST /webhooks/zaphub/:channel_id`

### No Servidor ZapHub:   - Processa eventos: message, presence, receipt, reaction, call, group



- ✅ Node.js 18+ instalado6. **Listener: `ZaphubEventsListener`** (`app/listeners/zaphub_events_listener.rb`)

- ✅ PostgreSQL rodando   - Escuta eventos `message_created` e envia automaticamente para ZapHub

- ✅ Redis rodando

- ✅ ZapHub API rodando (ex: `http://localhost:3000`)### Componentes Frontend



### No Chatwoot:1. **API Client** (`app/javascript/dashboard/api/channel/zaphubChannel.js`)

   - Cliente JavaScript para comunicação com API ZapHub

- ✅ Chatwoot instalado e configurado   - Métodos: `createSession`, `getQrCode`, `checkStatus`, `disconnect`

- ✅ Variáveis de ambiente configuradas (`.env`):

2. **Vue Component: Zaphub.vue** (`app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Zaphub.vue`)

```bash   - Interface para configuração do canal

ZAPHUB_API_KEY=sua-chave-api-aqui   - Exibe QR code para conexão

ZAPHUB_BASE_URL=http://localhost:3000   - Monitora status da conexão

```

3. **Channel Registration**

---   - Adicionado em `ChannelFactory.vue` e `ChannelList.vue`

   - Tradução em `inboxMgmt.json`

## 🚀 Configuração

## Fluxo de Conexão WhatsApp

### 1. Configurar Variáveis de Ambiente

```

Edite o arquivo `.env` do Chatwoot:1. Usuário clica em "ZapHub WhatsApp" na lista de canais

2. Preenche formulário com:

```bash   - Channel Name (nome da inbox)

# ZapHub WhatsApp Integration   - API Key (chave de autenticação do ZapHub)

ZAPHUB_API_KEY=sua-chave-secreta-aqui-xyz123   - Base URL (URL da API ZapHub, ex: http://localhost:3000/api/v1)

ZAPHUB_BASE_URL=http://localhost:3000   - Webhook URL (opcional)

```3. Sistema cria inbox e canal ZapHub

4. Backend chama ZapHub API para criar sessão

**⚠️ Importante:**5. QR Code é gerado e exibido na tela

- `ZAPHUB_API_KEY`: Chave de autenticação da API ZapHub6. Usuário escaneia QR code com WhatsApp

- `ZAPHUB_BASE_URL`: URL base da API ZapHub (sem barra no final)7. Sistema verifica status a cada 3 segundos

8. Quando conectado, redireciona para adicionar agentes

### 2. Reiniciar Chatwoot```



```bash## Fluxo de Mensagens

# Parar processos

overmind stop### Recebimento (ZapHub → Chatwoot)



# Limpar cache Redis (opcional)```

redis-cli FLUSHALL1. Mensagem chega no WhatsApp

2. ZapHub envia webhook para /webhooks/zaphub/:channel_id

# Iniciar novamente3. CallbacksController processa o evento

overmind start -f Procfile.dev4. Sistema cria/encontra contato pelo número de telefone

```5. Sistema cria/encontra conversação

6. Mensagem é criada no Chatwoot

### 3. Criar Canal WhatsApp no Chatwoot7. Anexos são baixados e salvos (se houver)

```

1. Login no Chatwoot como administrador

2. Vá em **Settings** → **Inboxes**### Envio (Chatwoot → ZapHub)

3. Clique em **Add Inbox**

4. Selecione **ZapHub**```

5. O QR Code aparecerá automaticamente1. Agente envia mensagem no Chatwoot

6. Escaneie com WhatsApp2. Event 'message_created' é disparado

7. Aguarde conexão automática3. ZaphubEventsListener captura o evento

4. SendOnZaphubService processa a mensagem

---5. Payload é montado conforme tipo (text, image, etc)

6. Requisição POST enviada para ZapHub API

## 📡 Endpoints da API ZapHub7. ZapHub envia para WhatsApp

8. source_id é atualizado com ID da mensagem

### Base URL```



Todas as requisições usam a base URL configurada em `ZAPHUB_BASE_URL`.## Tipos de Mensagens Suportadas



Segundo a documentação oficial do ZapHub, os endpoints seguem o padrão:### Envio

- ✅ **Text**: Mensagens de texto simples

```- ✅ **Image**: Imagens com caption opcional

{ZAPHUB_BASE_URL}/api/v1/*- ✅ **Video**: Vídeos com caption opcional

```- ✅ **Audio**: Áudios como PTT (push-to-talk)

- ✅ **Document**: Documentos (PDF, DOC, etc)

### 1. **Criar Sessão**

### Recebimento

**Endpoint:**- ✅ **Text**: Mensagens de texto

```- ✅ **Image**: Imagens com download automático

POST /api/v1/sessions- ✅ **Video**: Vídeos com download automático

```- ✅ **Audio**: Áudios com download automático

- ✅ **Document**: Documentos com download automático

**Headers:**- ✅ **Location**: Localização (convertida para texto)

```- ✅ **Contact**: Contato vCard (convertida para texto)

Content-Type: application/json- 📋 **Reaction**: Reações (logged, não processadas)

Authorization: Bearer {ZAPHUB_API_KEY}- 📋 **Presence**: Typing indicators (logged, não processadas)

```- 📋 **Receipt**: Confirmações de leitura (logged, atualiza status)

- 📋 **Call**: Eventos de chamadas (logged, não processadas)

**Body:**- 📋 **Group**: Eventos de grupos (logged, não processadas)

```json

{## Configuração

  "label": "Chatwoot - Atendimento",

  "webhook_url": "https://seu-chatwoot.com/webhooks/zaphub/:channel_id"### Variáveis de Ambiente

}

```Adicione ao `.env`:



**Resposta:**```bash

```json# URL pública do Chatwoot para webhooks

{FRONTEND_URL=https://seu-chatwoot.com

  "success": true,```

  "data": {

    "id": "6137713e-97d9-4045-8b6f-857378719571",### Base de Dados

    "label": "Chatwoot - Atendimento",

    "status": "initializing",A tabela `channel_zaphub` possui os seguintes campos:

    "webhook_url": "https://seu-chatwoot.com/webhooks/zaphub/:channel_id",

    "created_at": "2025-11-15T02:30:00.000Z"```ruby

  },t.integer :account_id, null: false

  "message": "Session created successfully. Initialization in progress."t.string :api_key              # Chave API do ZapHub

}t.string :base_url             # URL base da API ZapHub

```t.string :session_id           # ID da sessão criada no ZapHub

t.string :webhook_url          # URL do webhook (opcional)

### 2. **Obter QR Code**t.text :qr_code_data           # Dados do QR code (base64 image)

t.string :status               # pending|qr_generated|connected|disconnected|error

**Endpoint:**t.jsonb :additional_attributes # Atributos extras

```t.datetime :connected_at       # Data/hora da conexão

GET /api/v1/sessions/:session_id/qr?format=data_url```

```

## Testando a Integração

**Headers:**

```### 1. Criar Canal ZapHub

Authorization: Bearer {ZAPHUB_API_KEY}

``````bash

# Via Rails Console

**Parâmetros Query:**account = Account.first

- `format=data_url`: Retorna QR Code em base64 (data:image/png;base64,...)channel = Channel::Zaphub.create!(

  account: account,

**Resposta:**  api_key: 'test-api-key-12345',

```json  base_url: 'http://localhost:3000/api/v1'

{)

  "success": true,

  "data": {inbox = Inbox.create!(

    "qr_code": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAASwAAAEs...",  account: account,

    "generated_at": "2025-11-15T02:30:05.000Z"  name: 'WhatsApp ZapHub Test',

  }  channel: channel

})

``````



### 3. **Verificar Status da Sessão**### 2. Criar Sessão e Obter QR Code



**Endpoint:**```bash

```# Via Rails Console

GET /api/v1/sessions/:session_id/statuschannel.create_session

```channel.fetch_qr_code

puts channel.qr_code_data  # Base64 image data

**Headers:**```

```

Authorization: Bearer {ZAPHUB_API_KEY}### 3. Testar Webhook

```

```bash

**Resposta (Conectado):**# Simular recebimento de mensagem

```jsoncurl -X POST http://localhost:3000/webhooks/zaphub/1 \

{  -H "Content-Type: application/json" \

  "success": true,  -d '{

  "data": {    "type": "message",

    "id": "6137713e-97d9-4045-8b6f-857378719571",    "data": {

    "status": "connected",      "id": "msg-12345",

    "is_connected": true,      "from": "5511999999999@s.whatsapp.net",

    "phone_number": "5511999999999",      "fromMe": false,

    "connected_at": "2025-11-15T02:30:10.000Z",      "pushName": "João Silva",

    "last_seen": "2025-11-15T02:35:00.000Z"      "type": "text",

  }      "text": "Olá, preciso de ajuda!"

}    }

```  }'

```

**Status possíveis:**

- `initializing`: Sessão sendo criada### 4. Enviar Mensagem

- `qr_generated`: QR Code disponível

- `connected`: WhatsApp conectado```bash

- `disconnected`: Desconectado# Via Rails Console

message = Message.create!(

### 4. **Enviar Mensagem**  account: inbox.account,

  inbox: inbox,

**Endpoint:**  conversation: conversation,

```  message_type: :outgoing,

POST /api/v1/sessions/:session_id/messages  content: 'Olá! Como posso ajudar?'

```)



**Headers:**# Mensagem será enviada automaticamente pelo listener

``````

Content-Type: application/json

Authorization: Bearer {ZAPHUB_API_KEY}## Estrutura de Arquivos

```

```

**Body:**app/

```json├── models/

{│   └── channel/

  "to": "5511999999999@s.whatsapp.net",│       └── zaphub.rb                              # Model do canal

  "type": "text",├── services/

  "text": "Olá! Como posso ajudar?"│   └── zaphub/

}│       ├── session_service.rb                     # Comunicação com API

```│       └── send_on_zaphub_service.rb             # Envio de mensagens

├── controllers/

**Resposta:**│   ├── api/v1/accounts/channels/

```json│   │   └── zaphub_channels_controller.rb         # API de gerenciamento

{│   └── public/api/v1/zaphub/

  "success": true,│       └── callbacks_controller.rb               # Webhook receiver

  "data": {├── listeners/

    "id": "msg-12345",│   └── zaphub_events_listener.rb                 # Event listener

    "status": "queued",└── dispatchers/

    "message_type": "text",    └── async_dispatcher.rb                       # Registra listener

    "to": "5511999999999@s.whatsapp.net",

    "queued_at": "2025-11-15T02:30:00.000Z"app/javascript/dashboard/

  }├── api/channel/

}│   └── zaphubChannel.js                          # API client JS

```├── routes/dashboard/settings/inbox/

│   ├── channels/

### 5. **Tipos de Mensagem Suportados**│   │   └── Zaphub.vue                           # Componente de configuração

│   ├── ChannelFactory.vue                        # Registro do canal

#### Texto:│   └── ChannelList.vue                          # Lista de canais

```json└── i18n/locale/en/

{    └── inboxMgmt.json                           # Traduções

  "to": "5511999999999@s.whatsapp.net",

  "type": "text",db/migrate/

  "text": "Olá!"└── 20251115015022_create_channel_zaphub.rb      # Migration

}

```config/

└── routes.rb                                     # Rotas adicionadas

#### Imagem:```

```json

{## API ZapHub - Referência

  "to": "5511999999999@s.whatsapp.net",

  "type": "image",### Criar Sessão

  "image": {```http

    "url": "https://exemplo.com/imagem.jpg",POST {{base_url}}/sessions

    "caption": "Legenda da imagem"Authorization: Bearer {{api_key}}

  }Content-Type: application/json

}

```{

  "label": "Chatwoot - Inbox Name",

#### Documento:  "webhookUrl": "https://chatwoot.com/webhooks/zaphub/123"

```json}

{```

  "to": "5511999999999@s.whatsapp.net",

  "type": "document",### Obter QR Code

  "document": {```http

    "url": "https://exemplo.com/doc.pdf",GET {{base_url}}/sessions/{{session_id}}/qr

    "fileName": "documento.pdf",Authorization: Bearer {{api_key}}

    "mimetype": "application/pdf"```

  }

}### Verificar Status

``````http

GET {{base_url}}/sessions/{{session_id}}/status

#### Áudio/Nota de Voz:Authorization: Bearer {{api_key}}

```json```

{

  "to": "5511999999999@s.whatsapp.net",### Enviar Mensagem de Texto

  "type": "audio",```http

  "audio": {POST {{base_url}}/sessions/{{session_id}}/messages

    "url": "https://exemplo.com/audio.mp3",Authorization: Bearer {{api_key}}

    "ptt": trueContent-Type: application/json

  }

}{

```  "messageId": "msg-123",

  "to": "5511999999999@s.whatsapp.net",

---  "type": "text",

  "text": "Olá!"

## 🔄 Fluxo de Integração Completo}

```

### 1. Usuário Clica em "ZapHub" no Chatwoot

### Enviar Imagem

```javascript```http

// app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Zaphub.vuePOST {{base_url}}/sessions/{{session_id}}/messages

Authorization: Bearer {{api_key}}

mounted() {Content-Type: application/json

  this.createSessionAndShowQR();

}{

```  "messageId": "msg-124",

  "to": "5511999999999@s.whatsapp.net",

### 2. Frontend Cria Canal e Chama Backend  "type": "image",

  "image": {

```javascript    "url": "https://example.com/image.jpg",

async createSessionAndShowQR() {    "caption": "Veja esta imagem"

  // Criar canal no Chatwoot  }

  const zaphubChannel = await this.$store.dispatch('inboxes/createChannel', {}

    name: 'WhatsApp ZapHub',```

    channel: { type: 'zaphub' }

  });## Próximos Passos



  this.sessionId = zaphubChannel.id;### Melhorias Futuras



  // Criar sessão no ZapHub API1. **Suporte a Templates WhatsApp**

  await zaphubChannel.createSession(zaphubChannel.id);   - Implementar envio de templates aprovados

     - Interface para gerenciar templates

  // Buscar QR Code

  await this.fetchQrCode(zaphubChannel.id);2. **Grupos WhatsApp**

     - Suporte para conversas em grupo

  // Iniciar polling de status (a cada 3 segundos)   - Gerenciamento de participantes

  this.startStatusCheck(zaphubChannel.id);

}3. **Reações e Receipts**

```   - Processar reações de emoji

   - Atualizar status de mensagens (lido/entregue)

### 3. Backend Cria Sessão no ZapHub

4. **Presença e Typing**

```ruby   - Exibir quando contato está digitando

# app/models/channel/zaphub.rb   - Enviar presença do agente



def create_session5. **Chamadas**

  response = Zaphub::SessionService.new(self).create_session   - Notificar sobre chamadas recebidas

  update!(   - Histórico de chamadas

    session_id: response['id'],

    status: 'qr_generated'## Troubleshooting

  )

  response### QR Code não aparece

end- Verificar se `api_key` e `base_url` estão corretos

```- Verificar logs: `tail -f log/development.log | grep ZapHub`

- Testar endpoint manualmente com curl

```ruby

# app/services/zaphub/session_service.rb### Mensagens não são recebidas

- Verificar se webhook está configurado no ZapHub

def create_session- Verificar URL do webhook: `{{FRONTEND_URL}}/webhooks/zaphub/{{channel_id}}`

  response = make_request(- Verificar logs do CallbacksController

    :post,

    '/api/v1/sessions',  # ✅ Endpoint correto### Mensagens não são enviadas

    {- Verificar se ZaphubEventsListener está registrado

      label: "Chatwoot - #{channel.inbox&.name || 'Inbox'}",- Verificar status da sessão: `channel.check_status`

      webhook_url: webhook_callback_url  # ✅ snake_case- Verificar logs do SendOnZaphubService

    }

  )### Erro de autenticação

  response['data'] || response  # ✅ Retorna 'data' da resposta- Verificar validade da `api_key`

end- Verificar se sessão ainda está ativa no ZapHub

```

## Suporte

### 4. Frontend Busca QR Code

Para problemas ou dúvidas:

```javascript1. Verificar logs do Rails: `log/development.log`

async fetchQrCode(inboxId) {2. Verificar console do navegador para erros de JavaScript

  const response = await zaphubChannel.getQrCode(inboxId);3. Testar endpoints da API ZapHub diretamente

  // ZapHub retorna qr_code em response.data.qr_code4. Verificar status da sessão no ZapHub

  const qrCode = response.data?.qr_code || response.data?.qr;

  if (qrCode) {## Referências

    this.qrCodeData = qrCode; // data:image/png;base64,...

    this.status = 'qr_generated';- Documentação ZapHub API: Ver `ZapHub_Messages_Collection.json`

  }- Chatwoot Channel Documentation

}- WhatsApp Business API Documentation

```

```ruby
# app/services/zaphub/session_service.rb

def fetch_qr_code
  return unless channel.session_id

  # ✅ Endpoint correto com parâmetro format=data_url
  response = make_request(:get, "/api/v1/sessions/#{channel.session_id}/qr?format=data_url")
  response['data'] || response
end
```

### 5. Frontend Exibe QR Code + Campo Nome

```vue
<template>
  <div v-if="showQrCode" class="qr-container">
    <!-- Campo para definir nome da caixa -->
    <input 
      v-model="channelName" 
      placeholder="Nome da Caixa" 
      type="text"
    />
    
    <!-- QR Code em base64 -->
    <img :src="qrCodeData" alt="QR Code" />
    
    <p>📱 Escaneie com WhatsApp</p>
    <p class="text-sm">Aguardando conexão...</p>
  </div>
</template>
```

### 6. Polling de Status (3 em 3 segundos)

```javascript
startStatusCheck(inboxId) {
  this.statusCheckInterval = setInterval(async () => {
    await this.checkConnectionStatus(inboxId);
  }, 3000);
}

async checkConnectionStatus(inboxId) {
  const response = await zaphubChannel.checkStatus(inboxId);
  this.status = response.data.status;
  
  if (this.status === 'connected') {
    this.stopStatusCheck();
    
    // Atualizar nome da inbox se usuário preencheu
    if (this.channelName && this.channelName !== 'WhatsApp ZapHub') {
      await this.$store.dispatch('inboxes/updateInbox', {
        id: inboxId,
        name: this.channelName
      });
    }
    
    // Mostrar mensagem de sucesso
    useAlert('WhatsApp conectado com sucesso!');
    
    // Redirecionar automaticamente após 2 segundos
    setTimeout(() => {
      router.replace({
        name: 'settings_inboxes_add_agents',
        params: { inbox_id: inboxId }
      });
    }, 2000);
  }
}
```

### 7. Backend Verifica Status no ZapHub

```ruby
# app/models/channel/zaphub.rb

def check_status
  response = Zaphub::SessionService.new(self).check_status
  api_status = response['status']
  
  # Map ZapHub status to internal status
  new_status = case api_status
               when 'connected'
                 'connected'
               when 'initializing', 'qr_generated'
                 'qr_generated'
               when 'disconnected'
                 'disconnected'
               else
                 'pending'
               end
  
  if new_status == 'connected' && status != 'connected'
    update!(status: new_status, connected_at: Time.current)
  else
    update!(status: new_status)
  end
  
  response
end
```

### 8. Usuário Escaneia QR Code

**Sequência de eventos:**

1. 📱 Usuário abre WhatsApp no celular
2. 📷 WhatsApp escaneia QR Code exibido
3. ✅ ZapHub API detecta autenticação
4. 🔄 Status muda de `qr_generated` → `connected`
5. 🔍 Chatwoot detecta no próximo polling (3s)
6. 💾 Chatwoot salva nome da inbox
7. 🎉 Mensagem de sucesso exibida
8. 🚀 Redirecionamento automático para adicionar agentes

---

## 🔔 Webhooks (Mensagens Recebidas)

### Endpoint do Chatwoot

```
POST /webhooks/zaphub/:channel_id
```

### Payload de Mensagem Recebida

```json
{
  "event": "message.received",
  "session_id": "6137713e-97d9-4045-8b6f-857378719571",
  "timestamp": "2025-11-15T02:30:00.000Z",
  "data": {
    "message_id": "3EB0C431C72FE708E4B1",
    "from": "5511999999999@s.whatsapp.net",
    "to": "5511888888888@s.whatsapp.net",
    "type": "text",
    "text": "Olá, preciso de ajuda!",
    "timestamp": 1731629400000,
    "from_me": false
  }
}
```

### Eventos Disponíveis

- `message.received`: Nova mensagem recebida
- `message.sent`: Mensagem enviada
- `message.delivered`: Mensagem entregue
- `message.read`: Mensagem lida
- `message.reaction`: Reação adicionada
- `presence.update`: Digitando, online, offline
- `call.offer`: Chamada recebida

---

## 🛠️ Troubleshooting

### ❌ QR Code não aparece

**Verificar:**
```bash
# 1. Checar se ZapHub está rodando
curl http://localhost:3000/api/v1/health

# 2. Verificar variáveis de ambiente
cat .env | grep ZAPHUB

# 3. Ver logs do Chatwoot
tail -f log/development.log

# 4. Testar endpoint diretamente
curl http://localhost:3000/api/v1/sessions \
  -H "Authorization: Bearer $ZAPHUB_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"label": "Teste"}'
```

### ❌ "Unauthorized" ao criar sessão

**Causas:**
1. `ZAPHUB_API_KEY` incorreto ou vazio
2. ZapHub API requer autenticação mas chave não foi configurada
3. Chatwoot não foi reiniciado após alterar `.env`

**Solução:**
```bash
# 1. Verificar se variável está setada
echo $ZAPHUB_API_KEY

# 2. Verificar no .env
cat .env | grep ZAPHUB_API_KEY

# 3. Reiniciar Chatwoot
overmind stop
overmind start -f Procfile.dev

# 4. Testar autenticação diretamente
curl http://localhost:3000/api/v1/health \
  -H "Authorization: Bearer sua-chave-aqui"
```

### ❌ QR Code expira

**Comportamento:**
- QR Code expira em **60 segundos**
- Após expiração, ZapHub gera novo QR automaticamente

**Solução:**
1. Recarregue a página no Chatwoot
2. Novo QR Code será gerado automaticamente
3. Escaneie rapidamente (dentro de 60s)

### ❌ Mensagens não chegam no Chatwoot

**Verificar:**
```bash
# 1. Confirmar webhook_url está configurado no ZapHub
SESSION_ID="cole-session-id-aqui"
curl "http://localhost:3000/api/v1/sessions/$SESSION_ID/status" \
  -H "Authorization: Bearer $ZAPHUB_API_KEY" | jq '.data.webhook_url'

# 2. Testar endpoint do webhook manualmente
CHANNEL_ID="cole-channel-id-aqui"
curl -X POST "http://seu-chatwoot.com/webhooks/zaphub/$CHANNEL_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "message.received",
    "data": {
      "from": "5511999999999@s.whatsapp.net",
      "text": "Teste",
      "type": "text"
    }
  }'

# 3. Ver logs do ZapHub
tail -f logs/app.log | grep webhook
```

### ❌ Sessão desconecta frequentemente

**Causas comuns:**
- WhatsApp Web aberto em outro dispositivo
- Problemas de rede no servidor ZapHub
- Múltiplas sessões com mesmo número

**Solução:**
1. Fechar WhatsApp Web em outros dispositivos
2. Verificar estabilidade da conexão do servidor
3. Recriar sessão no Chatwoot

```bash
# Verificar última vez online
curl "http://localhost:3000/api/v1/sessions/$SESSION_ID/status" | jq '.data.last_seen'
```

---

## 📚 Arquivos da Integração

### Backend

```
app/
├── models/
│   └── channel/
│       └── zaphub.rb                     # Model do canal ZapHub
├── services/
│   └── zaphub/
│       ├── session_service.rb            # Cliente HTTP para API ZapHub
│       └── send_on_zaphub_service.rb     # Serviço de envio
├── controllers/
│   └── api/v1/accounts/
│       ├── channels/
│       │   └── zaphub_channels_controller.rb  # API endpoints
│       └── callbacks_controller.rb            # Webhook receiver
└── listeners/
    └── zaphub_events_listener.rb         # Event listener

db/migrate/
└── *_create_channel_zaphub.rb            # Migration
```

### Frontend

```
app/javascript/dashboard/
├── routes/dashboard/settings/inbox/channels/
│   └── Zaphub.vue                        # Componente de setup
├── api/channel/
│   └── zaphubChannel.js                  # API client
└── i18n/locale/en/
    └── inboxMgmt.json                    # Traduções
```

### Rotas

```ruby
# config/routes.rb

namespace :api do
  namespace :v1 do
    namespace :accounts do
      namespace :channels do
        resource :zaphub_channels, only: [:create] do
          member do
            post :create_session
            get :qr_code
            get :status
            post :disconnect
          end
        end
      end
    end
  end
end

# Webhook público (sem autenticação)
post 'webhooks/zaphub/:channel_id', to: 'api/v1/accounts/callbacks#zaphub'
```

---

## 🔐 Segurança em Produção

### 1. HTTPS Obrigatório

```nginx
# nginx.conf

server {
    listen 443 ssl http2;
    server_name seu-chatwoot.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 2. API Key Forte

```bash
# Gerar API key segura
ZAPHUB_API_KEY=$(openssl rand -hex 32)
echo "ZAPHUB_API_KEY=$ZAPHUB_API_KEY" >> .env
```

### 3. Firewall

```bash
# Permitir apenas tráfego entre Chatwoot ↔ ZapHub
sudo ufw allow from IP_DO_ZAPHUB to any port 3000
sudo ufw allow from IP_DO_CHATWOOT to any port 443
```

### 4. Rate Limiting

```ruby
# config/initializers/rack_attack.rb

Rack::Attack.throttle('zaphub/webhook', limit: 100, period: 60) do |req|
  req.ip if req.path.start_with?('/webhooks/zaphub')
end
```

### 5. Webhook Validation (Futuro)

```ruby
# Validar assinatura HMAC dos webhooks
def valid_webhook_signature?(payload, signature)
  expected = OpenSSL::HMAC.hexdigest('SHA256', ENV['ZAPHUB_WEBHOOK_SECRET'], payload)
  ActiveSupport::SecurityUtils.secure_compare(expected, signature)
end
```

---

## 📊 Monitoramento

### Logs

```bash
# Chatwoot
tail -f log/development.log | grep -i zaphub

# ZapHub
tail -f logs/app.log
tail -f logs/workers.log
tail -f logs/events.log
```

### Métricas

```ruby
# Verificar sessões ativas
Channel::Zaphub.where(status: 'connected').count

# Mensagens nas últimas 24h
Message.where(inbox_id: zaphub_inbox_ids)
       .where('created_at > ?', 24.hours.ago)
       .count
```

---

## 🎯 Checklist de Deploy

- [ ] Variáveis de ambiente configuradas (`ZAPHUB_API_KEY`, `ZAPHUB_BASE_URL`)
- [ ] ZapHub API rodando e acessível
- [ ] PostgreSQL e Redis configurados
- [ ] Migrations executadas (`rails db:migrate`)
- [ ] HTTPS configurado (Produção)
- [ ] Firewall configurado
- [ ] Logs e monitoramento ativos
- [ ] Webhook URL acessível publicamente
- [ ] Teste de envio/recebimento de mensagens

---

## 📞 Suporte

**Problemas?** Verifique os logs:

```bash
# Chatwoot
tail -f log/development.log

# ZapHub
tail -f logs/app.log
tail -f logs/workers.log
```

**Endpoints de Teste:**

```bash
# Health Check ZapHub
curl http://localhost:3000/api/v1/health

# Listar Sessões
curl http://localhost:3000/api/v1/sessions \
  -H "Authorization: Bearer $ZAPHUB_API_KEY"

# Status de Sessão Específica
curl "http://localhost:3000/api/v1/sessions/$SESSION_ID/status" \
  -H "Authorization: Bearer $ZAPHUB_API_KEY"
```

---

**ZapHub + Chatwoot** = ❤️ Atendimento WhatsApp Profissional

*Última atualização: 15 de Novembro de 2025*
*Documentação baseada na API oficial ZapHub v1.0.0*
