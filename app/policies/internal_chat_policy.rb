# frozen_string_literal: true

class InternalChatPolicy < ApplicationPolicy
  def show?
    user.agent?
  end

  def create?
    user.agent?
  end

  def send_message?
    user.agent?
  end
end