class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages do |t|
      t.references :role_play_session, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :role
      t.text :content
      t.integer :token_count

      t.timestamps
    end
  end
end
