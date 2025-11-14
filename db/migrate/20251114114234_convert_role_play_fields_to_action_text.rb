class ConvertRolePlayFieldsToActionText < ActiveRecord::Migration[8.1]
  include ActionView::Helpers::TextHelper

  def up
    # Store old values temporarily
    role_play_data = {}
    RolePlay.find_each do |role_play|
      role_play_data[role_play.id] = {
        description: role_play.description,
        llm_instructions: role_play.llm_instructions,
        recommended_for: role_play.recommended_for
      }
    end

    # Remove old text columns
    remove_column :role_plays, :description, :text
    remove_column :role_plays, :llm_instructions, :text
    remove_column :role_plays, :recommended_for, :text

    # Migrate data to Action Text
    role_play_data.each do |id, data|
      role_play = RolePlay.find(id)
      role_play.description = data[:description]
      role_play.llm_instructions = data[:llm_instructions]
      role_play.recommended_for = data[:recommended_for]
      role_play.save!(validate: false)
    end
  end

  def down
    # Add back the text columns
    add_column :role_plays, :description, :text
    add_column :role_plays, :llm_instructions, :text
    add_column :role_plays, :recommended_for, :text

    # Migrate data back from Action Text
    RolePlay.find_each do |role_play|
      role_play.update_columns(
        description: role_play.description.to_plain_text,
        llm_instructions: role_play.llm_instructions.to_plain_text,
        recommended_for: role_play.recommended_for.to_plain_text
      )
    end
  end
end
