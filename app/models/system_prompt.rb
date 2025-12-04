class SystemPrompt < ApplicationRecord
  has_rich_text :content
  validates :key, presence: true, uniqueness: true
  # Allow presence to be satisfied by either rich text or legacy text column
  validate do
    if !(content.respond_to?(:body) ? content.body&.present? : false) && self[:content].blank?
      errors.add(:content, :blank)
    end
  end

  # Fetch the prompt by key, falling back to the block value if not present
  def self.fetch(key)
    record = find_by(key: key)
    if record.present?
      if record.content.present? && record.content.respond_to?(:to_plain_text)
        return record.content.to_plain_text
      elsif record[:content].present?
        return record[:content].to_s
      end
    end
    block_given? ? yield : nil
  end
end
