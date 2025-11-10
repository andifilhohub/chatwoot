json.data @scheduled_messages do |message|
  json.partial! 'api/v1/models/scheduled_message', message: message
end

json.meta do
  json.current_page @scheduled_messages.current_page
  json.total_pages @scheduled_messages.total_pages
  json.total_count @scheduled_messages.total_count
end
