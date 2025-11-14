class RolePlay < ApplicationRecord
  # PaperTrail versioning for audit logging
  has_paper_trail

  # Category enum
  enum :category, {
    communication: 0,
    team_management: 1,
    conflict_resolution: 2,
    performance_management: 3,
    leadership_development: 4
  }

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
  scope :by_category, ->(category) { where(category: category) }
end
