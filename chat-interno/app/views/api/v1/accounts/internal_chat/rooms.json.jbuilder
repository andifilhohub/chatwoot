json.rooms do
  json.general @rooms[:general]
  json.teams @rooms[:teams]
  json.direct_messages @rooms[:direct_messages]
end