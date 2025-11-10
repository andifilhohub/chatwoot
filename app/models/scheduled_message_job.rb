# == Schema Information
#
# Table name: scheduled_message_jobs
#
#  id            :bigint           not null, primary key
#  dispatched_at :datetime
#  error_message :text
#  metadata      :jsonb            not null
#  scheduled_at  :datetime
#  status        :string
#  timezone      :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  job_id        :string
#  message_id    :bigint           not null
#
# Indexes
#
#  index_scheduled_message_jobs_on_message_id    (message_id)
#  index_scheduled_message_jobs_on_scheduled_at  (scheduled_at)
#  index_scheduled_message_jobs_on_status        (status)
#
# Foreign Keys
#
#  fk_rails_...  (message_id => messages.id)
#
class ScheduledMessageJob < ApplicationRecord
  STATUSES = {
    scheduled: 'scheduled',
    processing: 'processing',
    sent: 'sent',
    cancelled: 'cancelled',
    failed: 'failed'
  }.freeze

  belongs_to :message

  enum status: STATUSES

  validates :scheduled_at, presence: true
  validates :status, presence: true

  scope :ordered, -> { order(scheduled_at: :asc) }
  scope :upcoming, -> { where(status: STATUSES[:scheduled]).where('scheduled_at >= ?', Time.current) }
end
