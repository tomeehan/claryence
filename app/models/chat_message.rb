class ChatMessage < AccountRecord
  PHASES = %w[setup role_play debrief].freeze

  belongs_to :role_play_session

  validates :role, presence: true, inclusion: {in: %w[user assistant system]}
  validates :content, presence: true
  validates :phase, inclusion: {in: PHASES}

  scope :user_messages, -> { where(role: "user") }
  scope :assistant_messages, -> { where(role: "assistant") }
  scope :ordered, -> { order(created_at: :asc) }
  scope :setup_phase, -> { where(phase: "setup") }
  scope :role_play_phase, -> { where(phase: "role_play") }
  scope :debrief_phase, -> { where(phase: "debrief") }
end
