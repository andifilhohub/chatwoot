#!/bin/bash

echo "=== Testando Chat Interno ==="

echo ""
echo "1. Testando endpoint de rooms..."
curl -s -H "Content-Type: application/json" http://localhost:3000/api/v1/accounts/1/internal_chat/rooms | jq .

echo ""
echo "2. Testando criação de sala direta..."
curl -s -X POST -H "Content-Type: application/json" -d '{"target_user_id": 1}' http://localhost:3000/api/v1/accounts/1/internal_chat/create_direct_room | jq .

echo ""
echo "3. Testando envio de mensagem..."
curl -s -X POST -H "Content-Type: application/json" -d '{"message": {"content": "Teste de mensagem", "room_type": "direct", "room_id": "1"}}' http://localhost:3000/api/v1/accounts/1/internal_chat/send_message | jq .

echo ""
echo "4. Testando busca de mensagens..."
curl -s -H "Content-Type: application/json" http://localhost:3000/api/v1/accounts/1/internal_chat/messages/direct/1 | jq .

echo ""
echo "=== Teste concluído ==="