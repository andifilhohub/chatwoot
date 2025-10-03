json.messages @messages do |message|
  json.id message[:id]
  json.content message[:content]
  json.created_at message[:created_at]
  json.timestamp message[:created_at]
  json.message_type message[:message_type]
  json.chat_type message[:chat_type]
  json.team_id message[:team_id]
  json.recipient_id message[:recipient_id]
  
  json.sender do
    json.id message[:sender][:id]
    json.name message[:sender][:name]
    json.avatar_url message[:sender][:avatar_url]
  end
  
  json.sender_id message[:sender_id]
end

json.has_more @messages.count == 50