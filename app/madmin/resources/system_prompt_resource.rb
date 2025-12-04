class SystemPromptResource < Madmin::Resource
  # Attributes
  attribute :id, form: false
  attribute :key, form: false, index: true
  attribute :content, index: false
  attribute :created_at, form: false, index: false
  attribute :updated_at, form: false

  # Filters
  # filter :key
end
