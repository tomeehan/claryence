class CategoryResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :name
  attribute :created_at, index: true, form: false
  attribute :updated_at, form: false

  # Associations
  attribute :role_plays, form: false

  def self.display_name(record)
    record.name
  end

  def self.default_sort_column
    "name"
  end

  def self.default_sort_direction
    "asc"
  end
end

