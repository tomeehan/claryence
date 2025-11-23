class ChatMessage < AccountRecord
  belongs_to :role_play_session

  validates :role, presence: true, inclusion: {in: %w[user assistant system]}
  validates :content, presence: true

  scope :user_messages, -> { where(role: "user") }
  scope :assistant_messages, -> { where(role: "assistant") }
  scope :ordered, -> { order(created_at: :asc) }
end
