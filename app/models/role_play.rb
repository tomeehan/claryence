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

  # Convenience category scopes for admin filtering
  scope :communication, -> { joins(:category).where(categories: { name: "Communication" }) }
  scope :team_management, -> { joins(:category).where(categories: { name: "Team Management" }) }
  scope :conflict_resolution, -> { joins(:category).where(categories: { name: "Conflict Resolution" }) }
  scope :performance_management, -> { joins(:category).where(categories: { name: "Performance Management" }) }
  scope :leadership_development, -> { joins(:category).where(categories: { name: "Leadership Development" }) }
end
