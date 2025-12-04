class MigrateSystemPromptToRichText < ActiveRecord::Migration[8.1]
  class SystemPrompt < ActiveRecord::Base
    self.table_name = "system_prompts"
  end

  def up
    SystemPrompt.find_each do |sp|
      body = sp[:content].to_s
      next if body.blank?

      # Convert plain text to HTML: wrap paragraphs in <p> tags
      # Split on double newlines for paragraphs, preserve single newlines with <br>
      html_body = body.split(/\n\n+/).map do |paragraph|
        "<p>#{ERB::Util.html_escape(paragraph).gsub(/\n/, '<br>')}</p>"
      end.join

      ActionText::RichText.find_or_create_by!(record_type: "SystemPrompt", record_id: sp.id, name: "content") do |rt|
        rt.body = html_body
      end
    end
  end

  def down
    ActionText::RichText.where(record_type: "SystemPrompt", name: "content").delete_all
  end
end

