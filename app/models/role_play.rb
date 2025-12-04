class RolePlay < ApplicationRecord
  # PaperTrail versioning for audit logging
  has_paper_trail

  # Action Text for rich markdown editing with Lexxy
  has_rich_text :description
  has_rich_text :llm_instructions
  has_rich_text :recommended_for

  # Category relation
  belongs_to :category

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :llm_instructions, presence: true
  validates :duration_minutes, presence: true, numericality: {greater_than: 0, only_integer: true}
  validates :recommended_for, presence: true
  validates :category, presence: true
  validates :active, inclusion: {in: [true, false]}

  # Default scope: order by created_at (oldest first)
  default_scope -> { order(created_at: :asc) }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_category, ->(cat) do
    if cat.is_a?(Category)
      where(category_id: cat.id)
    elsif cat.is_a?(Integer)
      where(category_id: cat)
    elsif cat.respond_to?(:to_s)
      joins(:category).where(categories: { name: cat.to_s })
    else
      all
    end
  end
end
