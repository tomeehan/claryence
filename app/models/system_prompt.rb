class SystemPrompt < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :content, presence: true

  # Fetch the prompt by key, falling back to the block value if not present
  def self.fetch(key)
    record = find_by(key: key)
    return record.content if record&.content.present?
    block_given? ? yield : nil
  end
end

