class AddPhaseToChatMessages < ActiveRecord::Migration[8.1]
  def change
    # Default to 'role_play' so existing messages are correctly categorized
    # New messages will explicitly set their phase based on session.phase
    add_column :chat_messages, :phase, :string, default: "role_play", null: false
    add_index :chat_messages, :phase
  end
end
