json.data do
  json.id @room.id
  json.type @room.room_type
  json.name @room.name
  json.room_type @room.room_type
  json.participants @room.users.map { |user| { id: user.id, name: user.name } }
end