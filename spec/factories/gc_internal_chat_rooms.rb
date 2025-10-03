FactoryBot.define do
  factory :gc_internal_chat_room, class: 'GeniusCloud::InternalChat::Room' do
    association :account
    room_type { :general }
    name { 'General' }
    slug { SecureRandom.uuid }
  end
end
