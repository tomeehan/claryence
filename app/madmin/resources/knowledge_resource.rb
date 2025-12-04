class KnowledgeResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :summary, index: true, form: false
  attribute :content, :rich_text, index: false
  attribute :active, index: true
  attribute :created_at, index: false, form: false, show: false
  attribute :updated_at, form: false, show: false

  # Display name
  def self.display_name(record)
    "Knowledge ##{record.id}"
  end

  def self.default_sort_column
    "created_at"
  end

  def self.default_sort_direction
    "desc"
  end
end
