class Knowledge < ApplicationRecord
  scope :active, -> { where(active: true) }
end
