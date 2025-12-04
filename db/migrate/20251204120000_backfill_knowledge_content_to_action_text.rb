class BackfillKnowledgeContentToActionText < ActiveRecord::Migration[8.1]
  def up
    # Store old values temporarily using raw SQL to get the column value
    knowledge_data = ActiveRecord::Base.connection.select_all(
      "SELECT id, content FROM knowledges"
    ).to_a.to_h { |row| [row["id"], row["content"]] }

    # Remove old text column
    remove_column :knowledges, :content, :text

    # Migrate data to Action Text
    knowledge_data.each do |id, content|
      next if content.blank?
      knowledge = Knowledge.find(id)
      knowledge.content = plain_text_to_html(content)
      knowledge.save!(validate: false)
    end
  end

  def down
    add_column :knowledges, :content, :text

    # Migrate data back from Action Text
    Knowledge.find_each do |knowledge|
      knowledge.update_columns(
        content: knowledge.content.to_plain_text
      )
    end
  end

  private

  def plain_text_to_html(text)
    # Split on double spaces or double newlines for paragraphs
    paragraphs = text.to_s.strip.split(/(?:\s{2,}|\n{2,})/)
    paragraphs.map { |p| "<p>#{ERB::Util.html_escape(p.strip)}</p>" }.join
  end
end

