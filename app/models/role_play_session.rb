class RolePlaySession < AccountRecord
  belongs_to :account_user
  belongs_to :role_play
  has_many :chat_messages, dependent: :destroy

  validates :status, inclusion: {in: %w[active completed abandoned]}, allow_nil: true

  before_create :set_started_at
  before_create :set_session_number

  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }

  def complete!
    update!(
      status: "completed",
      completed_at: Time.current,
      duration_seconds: (Time.current - started_at).to_i
    )
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  def set_session_number
    self.session_number ||= RolePlaySession.where(
      account_id: account_id,
      account_user: account_user,
      role_play: role_play
    ).count + 1
  end
end
