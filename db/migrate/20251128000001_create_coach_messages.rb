class CreateCoachMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :coach_messages do |t|
      t.references :role_play_session, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.integer :token_count

      t.timestamps
    end
  end
end

