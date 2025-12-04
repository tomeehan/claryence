class RolePlayResource < Madmin::Resource
  # Scopes
  scope :active

  # Attributes
  attribute :id, form: false
  attribute :name
  attribute :description, :rich_text, index: false
  attribute :llm_instructions, :rich_text, index: false
  attribute :duration_minutes
  attribute :recommended_for, :rich_text, index: false
  attribute :category, index: true
  attribute :active, index: true
  attribute :created_at, index: true, form: false
  attribute :updated_at, form: false

  # Display name
  def self.display_name(record)
    record.name
  end

  # Default sort by created_at (oldest first)
  def self.default_sort_column
    "created_at"
  end

  def self.default_sort_direction
    "asc"
  end
end
