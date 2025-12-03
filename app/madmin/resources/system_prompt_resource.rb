class SystemPromptResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :key
  attribute :content, index: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  # Filters
  # filter :key
end

