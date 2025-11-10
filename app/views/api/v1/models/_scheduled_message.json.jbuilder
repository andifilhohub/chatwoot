scheduled_job = message.scheduled_message_job
conversation = message.conversation
contact = conversation&.contact
inbox = message.inbox
sender = message.sender if message.sender.is_a?(User)
schedule_info = message.schedule_info || {}

scheduled_at_time = scheduled_job&.scheduled_at || message.scheduled_at
scheduled_at_iso = scheduled_job&.scheduled_at&.iso8601 || schedule_info['scheduled_at']
scheduled_at_timestamp = if scheduled_at_time
                           scheduled_at_time.to_i
                         elsif schedule_info['scheduled_at'].present?
                           Time.zone.parse(schedule_info['scheduled_at']).to_i
                         end

timezone = scheduled_job&.timezone || schedule_info['scheduled_timezone']
dispatched_at_iso = scheduled_job&.dispatched_at&.iso8601 || schedule_info['dispatched_at']
dispatched_time = dispatched_at_iso ? Time.zone.parse(dispatched_at_iso) : nil
status_value = scheduled_job&.status || message.status

json.id message.id
json.status status_value
json.scheduled_at scheduled_at_timestamp
json.scheduled_at_iso scheduled_at_iso
json.dispatched_at dispatched_time&.to_i
json.timezone timezone
json.error_message scheduled_job&.error_message
json.job_id scheduled_job&.job_id

json.message do
  json.partial! 'api/v1/models/message', message: message
end

json.contact do
  if contact
    json.id contact.id
    json.name contact.name
    json.email contact.email
    json.phone_number contact.phone_number
  end
end

json.inbox do
  if inbox
    json.id inbox.id
    json.name inbox.name
    json.channel_type inbox.channel_type
  end
end

json.agent do
  if sender
    json.id sender.id
    json.name sender.name
    json.avatar_url sender.avatar_url
  end
end

json.attachments_count message.attachments.size
json.created_at message.created_at.to_i
