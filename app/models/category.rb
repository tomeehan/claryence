class Category < ApplicationRecord
  has_many :role_plays, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true

  default_scope -> { order(name: :asc) }
end

