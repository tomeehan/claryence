class CoachingSessionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_session

  def show
    ensure_intro_message!
    @messages = @session.coach_messages.ordered

    # Render via Superglue-like page bootstrap with a distinct component id
    if request.format.html?
      render template: "coaching_sessions/superglue", layout: false
    end
  end

  private

  def set_session
    @session = current_account.role_play_sessions.find(params[:id])
  end

  def ensure_intro_message!
    return if @session.coach_messages.exists?
    @session.coach_messages.create!(
      role: "assistant",
      content: "How do you think that went?",
      account_id: @session.account_id
    )
  end
end

