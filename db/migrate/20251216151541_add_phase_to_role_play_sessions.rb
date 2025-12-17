class AddPhaseToRolePlaySessions < ActiveRecord::Migration[8.1]
  def change
    add_column :role_play_sessions, :phase, :string, default: "setup", null: false
    add_index :role_play_sessions, :phase
  end
end
