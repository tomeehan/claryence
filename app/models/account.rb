class Account < ApplicationRecord
  has_prefix_id :acct

  include Billing
  include Domains
  include Transfer
  include Types

  # Role play chat associations
  has_many :role_play_sessions, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
end
