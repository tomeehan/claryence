class CreateRolePlaySessions < ActiveRecord::Migration[8.1]
  def change
    create_table :role_play_sessions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :account_user, null: false, foreign_key: true
      t.references :role_play, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :duration_seconds
      t.string :status
      t.text :system_prompt
      t.integer :session_number

      t.timestamps
    end
  end
end
