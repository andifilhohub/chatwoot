# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public::Api::V1::Zaphub::CallbacksController', type: :request do
  let(:account) { create(:account) }
  let!(:channel) { Channel::Zaphub.create!(account: account, status: 'connected') }
  let!(:inbox) { account.inboxes.create!(name: 'ZapHub Inbox', channel: channel) }
  let(:contact_jid) { '5511999999999@s.whatsapp.net' }
  let(:attachment_io) { Tempfile.new(['zaphub-spec', '.jpg']) }
  let(:attachment_payload) do
    attachment_io.rewind
    {
      io: attachment_io,
      filename: 'stubbed.jpg',
      content_type: 'image/jpeg',
      file_type: 'image'
    }
  end

  before do
    allow(Zaphub::MediaAttachmentService).to receive(:new).and_wrap_original do |_original, **kwargs|
      service = instance_double(Zaphub::MediaAttachmentService)
      allow(service).to receive(:call) do
        kwargs[:type] == 'image' ? attachment_payload : nil
      end
      service
    end
  end

  after do
    attachment_io.close!
  end

  describe 'POST /webhooks/zaphub/:channel_id' do
    it 'marks outbound events as outgoing messages' do
      payload = {
        type: 'message',
        event: 'message.sent',
        data: {
          message_id: 'msg-outgoing-1',
          from: contact_jid,
          to: '5511888888888@s.whatsapp.net',
          type: 'text',
          text: 'Ola!'
        }
      }

      expect do
        post zaphub_callback_path(channel_id: channel.id),
             params: payload.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      end.to change(Message, :count).by(1)

      message = Message.last
      expect(message).to be_outgoing
      expect(message.source_id).to eq 'msg-outgoing-1'
      expect(message.content).to eq 'Ola!'
    end

    it 'marks inbound events as incoming messages' do
      payload = {
        type: 'message',
        event: 'message.received',
        data: {
          message_id: 'msg-incoming-1',
          from: contact_jid,
          type: 'text',
          text: 'Oi!',
          from_me: false
        }
      }

      expect do
        post zaphub_callback_path(channel_id: channel.id),
             params: payload.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      end.to change(Message, :count).by(1)

      message = Message.last
      expect(message).to be_incoming
      expect(message.sender).to be_present
    end

    it 'stores attachments for media messages' do
      payload = {
        type: 'message',
        event: 'message.received',
        data: {
          message_id: 'msg-media-1',
          from: contact_jid,
          type: 'image',
          image: {
            url: 'https://example.com/image.enc'
          }
        }
      }

      expect do
        post zaphub_callback_path(channel_id: channel.id),
             params: payload.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      end.to change(Attachment, :count).by(1)

      message = Message.last
      expect(message.attachments.count).to eq 1
      expect(message.attachments.first).to be_image
    end

    context 'group conversations' do
      let(:group_chat_id) { '5544332211-123456789@g.us' }
      let(:participant_jid) { '5511999999999@s.whatsapp.net' }

      def group_payload(message_id, overrides = {})
        {
          type: 'message',
          event: 'message.received',
          data: {
            message_id: message_id,
            chatId: group_chat_id,
            chatName: 'Grupo Chatwoot',
            groupId: group_chat_id,
            isGroup: true,
            from: participant_jid,
            participant: participant_jid,
            type: 'text',
            text: "Mensagem #{message_id}"
          }.merge(overrides)
        }
      end

      it 'creates a conversation per chatId and reuses it for new messages' do
        expect do
          post zaphub_callback_path(channel_id: channel.id),
               params: group_payload('group-msg-1').to_json,
               headers: { 'CONTENT_TYPE' => 'application/json' }
        end.to change(Message, :count).by(1)
          .and change(ContactInbox, :count).by(1)
          .and change(Conversation, :count).by(1)

        contact_inbox = ContactInbox.last
        expect(contact_inbox.source_id).to eq group_chat_id
        expect(contact_inbox.contact.identifier).to eq group_chat_id

        conversation = Conversation.last

        post zaphub_callback_path(channel_id: channel.id),
             params: group_payload('group-msg-2',
                                   from: '5511888888888@s.whatsapp.net',
                                   participant: '5511888888888@s.whatsapp.net',
                                   text: 'Outra mensagem').to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(Conversation.count).to eq 1
        expect(Message.last.conversation_id).to eq conversation.id
      end
    end

    context 'receipt events' do
      let(:contact) { create(:contact, account: account) }
      let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
      let(:conversation) do
        create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
      end
      let!(:message) do
        create(
          :message,
          account: account,
          inbox: inbox,
          conversation: conversation,
          message_type: :outgoing,
          status: :sent,
          source_id: 'msg-receipt-1'
        )
      end

      it 'marks a message as delivered' do
        payload = {
          type: 'message',
          event: 'message.delivered',
          data: {
            messageId: message.source_id,
            status: 'delivered'
          }
        }

        post zaphub_callback_path(channel_id: channel.id),
             params: payload.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(message.reload).to be_delivered
      end

      it 'marks a message as read when receipt batch is provided' do
        payload = {
          type: 'message.receipt.update',
          event: 'message.receipt.update',
          data: {
            receipts: [
              {
                messageId: message.source_id,
                status: 'read'
              }
            ]
          }
        }

        post zaphub_callback_path(channel_id: channel.id),
             params: payload.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(message.reload).to be_read
      end
    end
  end
end
