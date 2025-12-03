class CoachMessage < AccountRecord
  belongs_to :role_play_session

  validates :role, presence: true, inclusion: { in: %w[user assistant system] }
  validates :content, presence: true

  scope :ordered, -> { order(created_at: :asc) }
end

