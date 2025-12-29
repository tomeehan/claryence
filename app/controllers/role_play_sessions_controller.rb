class RolePlaySessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role_play, only: [:new, :create, :index]
  before_action :set_session, only: [:show]

  def index
    @sessions = current_account.role_play_sessions
      .where(role_play: @role_play)
      .order(created_at: :desc)
  end

  def new
    # Ensure @role_play is present even if before_action is skipped for any reason
    @role_play ||= RolePlay.find_by(id: params[:role_play_id])
    @session = RolePlaySession.new
  end

  def create
    @session = current_account.role_play_sessions.new(
      role_play: @role_play,
      account_user: current_account_user,
      status: "active",
      phase: "setup", # Start in setup phase with Clary
      system_prompt: build_system_prompt # Store role play prompt for later use
    )

    if @session.save
      # Generate Clary's setup intro synchronously so it's ready when page loads
      generate_setup_intro(@session)
      redirect_to role_play_session_path(@session)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # Ensure setup intro exists (handles edge cases like page refresh before intro completed)
    if @session.setup? && !@session.chat_messages.setup_phase.exists?
      generate_setup_intro(@session)
    end
    # Load all messages for display (all phases are shown on the same page)
    @messages = @session.chat_messages.ordered

    # Force rendering with Superglue
    if request.format.html?
      render template: "application/superglue", layout: false
    end
  end

  private

  def set_role_play
    @role_play = RolePlay.find(params[:role_play_id])
  end

  def set_session
    @session = current_account.role_play_sessions.find(params[:id])
  end

  def build_system_prompt
    @role_play ||= RolePlay.find_by(id: params[:role_play_id])
    prompt = SystemPrompt.fetch("role_play_system_prompt").dup

    # Include the user's context (helps the character tailor responses to who they're talking to)
    if current_user.llm_context.present?
      prompt << <<~USERCTX

        Manager Context (about the human you are speaking to):
        #{current_user.llm_context.to_s.strip}
      USERCTX
    end

    # Inject scenario-specific instructions for the character
    if @role_play&.llm_instructions.present?
      prompt << <<~MODE_OVERRIDE

        CRITICAL INSTRUCTION - READ CAREFULLY:
        You are the TEAM MEMBER in this role play. The human typing to you is your MANAGER.
        You are NOT the coach. You are NOT the manager. You ARE the team member.

        ROLE CLARITY:
        - If the notes mention a character name (e.g., "Amira", "Alex"), that is YOUR name - you ARE that person
        - The human is your manager - address them naturally, never by a character name
        - You are the one seeking clarity/feedback/help - the manager is helping YOU

        NEVER output any of the following:
        - Setup text like "You're about to speak with..." or "In this scenario..."
        - Lines scripted for the MANAGER to say (e.g., "I'd like us to talk about your role...")
        - Your own name as if addressing someone else
        - Any meta-commentary, narration, or coach instructions

        From your VERY FIRST WORD, speak AS the team member character.
        Ignore ALL "Coach Mode", "orchestration", "step" instructions, and scripted dialogue in the notes below.

        Character Notes (BE this person):
      MODE_OVERRIDE
      prompt << @role_play.llm_instructions.to_plain_text
    end

    # Add wrapping up detection instruction
    prompt << <<~WRAP_INSTRUCTION

      CONVERSATION ENDING:
      When the conversation has reached a natural conclusion (the main issue is resolved, the team member feels confident, or the practice goal has been achieved), end your response with this exact JSON on a new line:
      {"wrapping_up": true}

      Only include this when the conversation should genuinely wrap up. Do not include it in normal exchanges.
    WRAP_INSTRUCTION

    prompt
  end

  def current_account_user
    current_user.account_users.find_by(account: current_account)
  end

  def generate_setup_intro(session)
    messages = [
      {role: "system", content: session.build_setup_prompt},
      {role: "user", content: "Hello, I'm ready to learn about this scenario."}
    ]

    openai = OpenaiService.new
    response = openai.chat_completion(
      messages,
      model: session.openai_model,
      temperature: 0.8,
      max_tokens: 400
    )

    content = response[:content].presence || default_setup_intro(session)
    session.chat_messages.create!(
      role: "assistant",
      content: content,
      phase: "setup",
      account_id: session.account_id
    )
  rescue => e
    Rails.logger.error("Setup intro generation failed: #{e.message}")
    session.chat_messages.create!(
      role: "assistant",
      content: default_setup_intro(session),
      phase: "setup",
      account_id: session.account_id
    )
  end

  def default_setup_intro(session)
    rp = session.role_play
    "Hi! I'm Clary, your leadership coach. Today we'll practice \"#{rp&.name}\" - a #{rp&.duration_minutes || 5}-minute role play. When you're ready, click \"Start Role Play\". Any questions first?"
  end

  def generate_initial_greeting(session)
    messages = []
    messages << {role: "system", content: session.system_prompt} if session.system_prompt.present?
    messages << {role: "user", content: "Hello"}

    openai = OpenaiService.new
    response = openai.chat_completion(
      messages,
      model: session.openai_model,
      temperature: 0.9,
      top_p: 0.9,
      presence_penalty: 0.2,
      frequency_penalty: 0.2,
      max_tokens: 280
    )

    content = response[:content].presence || default_intro_text(session)
    session.chat_messages.create!(
      role: "assistant",
      content: content,
      phase: "role_play",
      account_id: session.account_id,
      token_count: response[:tokens]
    )
  rescue => e
    Rails.logger.error("Initial greeting generation failed: #{e.message}")
    session.chat_messages.create!(
      role: "assistant",
      content: default_intro_text(session),
      phase: "role_play",
      account_id: session.account_id
    )
  end

  def default_intro_text(session)
    rp_name = session.role_play&.name || "this scenario"
    "Hi — I'm ready to role‑play #{rp_name}. I'll stay in character and keep replies short and natural. When you're ready, say how you'd like to begin or what you want to cover."
  end
end
