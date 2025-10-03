FactoryBot.define do
  factory :gc_internal_chat_message, class: 'GeniusCloud::InternalChat::Message' do
    association :room, factory: :gc_internal_chat_room
    account { room.account }
    sender { association :user, account: account }
    content { 'Sample message' }
  end
end
