class RolePlaySessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role_play, only: [:new, :create]
  before_action :set_session, only: [:show]

  def new
    @session = RolePlaySession.new
  end

  def create
    @session = current_account.role_play_sessions.new(
      role_play: @role_play,
      account_user: current_account_user,
      status: "active",
      system_prompt: build_system_prompt
    )

    if @session.save
      # Generate initial AI greeting to start the role play
      GenerateInitialMessageJob.perform_later(@session.id)
      redirect_to role_play_session_path(@session)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
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
    # Combine global prompt with role play specific instructions
    prompt = "You are Clary, an AI coach helping a manager practice leadership skills through realistic role play.\n\n"
    prompt += "IMPORTANT STYLE GUIDELINES:\n"
    prompt += "- Be conversational and natural, like a real person talking\n"
    prompt += "- Keep responses SHORT - typically 1-3 sentences unless you need to elaborate\n"
    prompt += "- Don't list things with bullet points in conversation - speak naturally\n"
    prompt += "- React authentically to what the manager says - show genuine emotion and personality\n"
    prompt += "- Don't be overly formal or robotic - use contractions, casual language where appropriate\n"
    prompt += "- Let the conversation flow naturally - don't try to hit every point at once\n\n"
    prompt += @role_play.llm_instructions.to_plain_text if @role_play.llm_instructions.present?
    prompt += "\n\nWhen the conversation starts, YOU must initiate the role play. Greet the manager naturally in character (2-3 sentences max) and let the conversation unfold organically from there."
    prompt
  end

  def current_account_user
    current_user.account_users.find_by(account: current_account)
  end
end
