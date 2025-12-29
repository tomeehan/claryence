class AddModelToRolePlaySessions < ActiveRecord::Migration[8.1]
  def change
    add_column :role_play_sessions, :model, :string
  end
end
