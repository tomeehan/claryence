class Knowledge < ApplicationRecord
  has_rich_text :content

  scope :active, -> { where(active: true) }

  validates :content, presence: true

  def content_plain_text
    content.to_plain_text
  end
end
