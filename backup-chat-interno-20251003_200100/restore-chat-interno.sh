#!/bin/bash
# Script de Restauração do Chat Interno
# Uso: ./restore-chat-interno.sh

echo "🔄 Restaurando arquivos do Chat Interno..."

# Diretório base do backup
BACKUP_DIR="backup-chat-interno-20251003_200100"
WORKSPACE_DIR="/home/anderson/workspace/chatwoot-v4"

# Verificar se o backup existe
if [ ! -d "$WORKSPACE_DIR/$BACKUP_DIR" ]; then
    echo "❌ Erro: Pasta de backup não encontrada: $BACKUP_DIR"
    exit 1
fi

echo "📁 Backup encontrado: $BACKUP_DIR"

# Criar diretórios necessários se não existirem
echo "📂 Criando estrutura de diretórios..."
mkdir -p "$WORKSPACE_DIR/app/GeniusCloud-modify/app/javascript/dashboard/api"
mkdir -p "$WORKSPACE_DIR/app/GeniusCloud-modify/app/javascript/dashboard/composables"
mkdir -p "$WORKSPACE_DIR/app/GeniusCloud-modify/app/javascript/dashboard/components/internal-chat"

# Restaurar arquivos
echo "📥 Restaurando arquivos..."

# API Client
cp "$WORKSPACE_DIR/$BACKUP_DIR/GeniusCloud-modify/app/javascript/dashboard/api/internalChat.js" \
   "$WORKSPACE_DIR/app/GeniusCloud-modify/app/javascript/dashboard/api/"
echo "✅ API Client restaurado"

# Composables
cp "$WORKSPACE_DIR/$BACKUP_DIR/GeniusCloud-modify/app/javascript/dashboard/composables/useInternalChat.js" \
   "$WORKSPACE_DIR/app/GeniusCloud-modify/app/javascript/dashboard/composables/"
echo "✅ Composable básico restaurado"

# Componentes
cp "$WORKSPACE_DIR/$BACKUP_DIR/GeniusCloud-modify/app/javascript/dashboard/components/internal-chat/InternalChatMessageList.vue" \
   "$WORKSPACE_DIR/app/GeniusCloud-modify/app/javascript/dashboard/components/internal-chat/"
echo "✅ Componente de lista de mensagens restaurado"

cp "$WORKSPACE_DIR/$BACKUP_DIR/GeniusCloud-modify/app/javascript/dashboard/components/internal-chat/InternalChatPanelActionCable.vue" \
   "$WORKSPACE_DIR/app/GeniusCloud-modify/app/javascript/dashboard/components/internal-chat/"
echo "✅ Componente principal restaurado"

echo ""
echo "🎉 Restauração concluída!"
echo ""
echo "📋 Arquivos restaurados:"
echo "  - app/GeniusCloud-modify/app/javascript/dashboard/api/internalChat.js"
echo "  - app/GeniusCloud-modify/app/javascript/dashboard/composables/useInternalChat.js"
echo "  - app/GeniusCloud-modify/app/javascript/dashboard/components/internal-chat/InternalChatMessageList.vue"
echo "  - app/GeniusCloud-modify/app/javascript/dashboard/components/internal-chat/InternalChatPanelActionCable.vue"
echo ""
echo "⚠️  Ainda precisa criar:"
echo "  - app/GeniusCloud-modify/app/javascript/dashboard/composables/useInternalChatData.js"
echo ""
echo "🔗 Para mais detalhes, veja: $BACKUP_DIR/README-BACKUP.md"