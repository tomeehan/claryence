class ApplicationRecord < ActiveRecord::Base
  # This enables digging by index when used with props_template
  # see https://thoughtbot.github.io/superglue/digging/#index-based-selection
  def self.member_at(index)
    offset(index).limit(1).first
  end

  # This enables digging by attribute when used with props_template
  # see https://thoughtbot.github.io/superglue/digging/#attribute-based-selection
  def self.member_by(attr, value)
    find_by({attr => value})
  end
  primary_abstract_class

  include ActionView::RecordIdentifier

  # Orders results by column and direction
  def self.sort_by_params(column, direction)
    sortable_column = column.presence_in(sortable_columns) || "created_at"
    order(sortable_column => direction)
  end

  # Returns an array of sortable columns on the model
  # Used with the Sortable controller concern
  #
  # Override this method to add/remove sortable columns
  def self.sortable_columns
    @sortable_columns ||= columns.map(&:name)
  end
end
