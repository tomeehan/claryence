class User < ApplicationRecord
  has_prefix_id :user

  include Accounts
  include Agreements
  include Authenticatable
  include Mentions
  include Notifiable
  include Searchable
  # Theme preferences removed

  has_one_attached :avatar
  has_person_name

  validates :avatar, resizable_image: true
  validates :name, presence: true
end
