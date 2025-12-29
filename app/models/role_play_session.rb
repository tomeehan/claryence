class RolePlaySession < AccountRecord
  PHASES = %w[setup role_play debrief].freeze

  belongs_to :account_user
  belongs_to :role_play
  has_many :chat_messages, dependent: :destroy
  has_many :coach_messages, dependent: :destroy

  validates :status, inclusion: {in: %w[active completed abandoned]}, allow_nil: true
  validates :phase, inclusion: {in: PHASES}

  before_create :set_started_at
  before_create :set_session_number
  before_create :set_model_from_role_play

  scope :active, -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }

  def openai_model
    model || role_play&.model || "gpt-4o"
  end

  # Phase helper methods
  def setup?
    phase == "setup"
  end

  def role_play_phase?
    phase == "role_play"
  end

  def debrief?
    phase == "debrief"
  end

  # Phase transition methods
  def transition_to_role_play!
    update!(phase: "role_play")
  end

  def transition_to_debrief!
    update!(phase: "debrief")
  end

  def complete!
    update!(
      status: "completed",
      completed_at: Time.current,
      duration_seconds: (Time.current - started_at).to_i
    )
  end

  # Build the appropriate system prompt based on current phase
  def current_system_prompt
    case phase
    when "setup"
      build_setup_prompt
    when "role_play"
      system_prompt # Use the stored role play system prompt
    when "debrief"
      build_debrief_prompt
    end
  end

  # Build the setup phase prompt with scenario details
  def build_setup_prompt
    clary_soul = SystemPrompt.fetch("clary_soul")
    setup_instructions = SystemPrompt.fetch("setup_intro_system_prompt")

    rp = role_play
    description_text = rp.description&.to_plain_text.to_s.strip

    # Extract character info from llm_instructions if present
    # Look for character profile sections (name, role, personality, etc.)
    instructions_text = rp.llm_instructions&.to_plain_text.to_s.strip
    character_summary = extract_character_summary(instructions_text)

    <<~FULL_PROMPT
      #{clary_soul}

      #{setup_instructions}

      SCENARIO DETAILS:
      Name: #{rp.name}
      Category: #{rp.category&.name}
      Duration: #{rp.duration_minutes} minutes

      Description:
      #{description_text}

      #{character_summary.present? ? "Character they will speak with:\n#{character_summary}" : ""}

      IMPORTANT: You are Clary the coach introducing this scenario. Do NOT follow any "Coach Mode" or orchestration instructions from the scenario - that's your job now. Just warmly introduce what the manager will practice and who they'll be speaking with.
    FULL_PROMPT
  end

  # Extract character details from llm_instructions, ignoring orchestration
  def extract_character_summary(instructions)
    return "" if instructions.blank?

    # Look for character profile patterns
    summary_parts = []

    # Try to find character name (look for "• Name:" pattern used in profiles)
    if instructions =~ /•\s*Name:\s*(\w+)/i
      summary_parts << "Name: #{$1}"
    end

    # Try to find role/tenure (look for "Role & Tenure" or similar)
    if instructions =~ /Role\s*[&]\s*Tenure:\s*([^\n•]+)/i
      summary_parts << "Role: #{$1.strip}"
    end

    # Try to find personality
    if instructions =~ /•\s*Personality:\s*([^\n•]+)/i
      summary_parts << "Personality: #{$1.strip}"
    end

    # Try to find emotional state
    if instructions =~ /•\s*Emotional State:\s*([^\n•]+)/i
      summary_parts << "Current state: #{$1.strip}"
    end

    # Try to find worries/concerns
    if instructions =~ /•\s*Worries:\s*([^\n•]+)/i
      summary_parts << "Worries: #{$1.strip}"
    end

    summary_parts.join("\n")
  end

  # Build the debrief phase prompt with transcript context
  def build_debrief_prompt
    clary_soul = SystemPrompt.fetch("clary_soul")

    # Include transcript of the role play for context
    transcript = chat_messages.where(phase: "role_play").ordered.map do |m|
      who = (m.role == "user") ? "Manager" : "Role Play Character"
      "#{who}: #{m.content}"
    end.join("\n\n")

    knowledge = Knowledge.active.order(created_at: :desc).map { |k| k.content_plain_text }.reject(&:blank?).join("\n\n")

    <<~FULL_PROMPT
      #{clary_soul}

      You just observed this role play conversation between a manager and a team member. Now you're debriefing with the manager.

      ROLE PLAY TRANSCRIPT:
      #{transcript}

      #{knowledge.present? ? "COACHING KNOWLEDGE (use only if directly relevant):\n#{knowledge}" : ""}

      Start by asking "How do you think that went?" and let the manager reflect first.
      Then offer specific, encouraging feedback based on what you observed in the transcript.
      Reference specific moments from their conversation to make your feedback concrete and actionable.
    FULL_PROMPT
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

  def set_model_from_role_play
    self.model ||= role_play&.model || "gpt-4o"
  end
end
