class CoachChannel < ApplicationCable::Channel
  def subscribed
    session = RolePlaySession.find(params[:session_id])
    if session.account_id == current_account.id
      stream_for session
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def send_message(data)
    session = RolePlaySession.find(params[:session_id])
    return unless session.account_id == current_account.id

    user_message = session.coach_messages.create!(
      role: "user",
      content: data["content"],
      account_id: session.account_id
    )

    CoachChannel.broadcast_to(session, {
      type: "user_message",
      message: {
        id: user_message.id,
        role: "user",
        content: user_message.content,
        created_at: user_message.created_at
      }
    })

    messages = build_messages(session)

    ai_content = ""
    openai = OpenaiService.new

    CoachChannel.broadcast_to(session, { type: "assistant_start" })
    begin
      openai.chat_completion_stream(
        messages,
        model: "gpt-4o",
        temperature: 0.8,
        top_p: 0.9,
        presence_penalty: 0.1,
        frequency_penalty: 0.1
      ) do |chunk|
        ai_content += chunk
        CoachChannel.broadcast_to(session, { type: "assistant_chunk", content: chunk })
      end

      assistant_message = session.coach_messages.create!(
        role: "assistant",
        content: ai_content,
        account_id: session.account_id
      )

      CoachChannel.broadcast_to(session, {
        type: "assistant_complete",
        message: {
          id: assistant_message.id,
          role: "assistant",
          content: assistant_message.content,
          created_at: assistant_message.created_at
        }
      })
    rescue => e
      Rails.logger.error("CoachChannel error: #{e.message}")
      CoachChannel.broadcast_to(session, { type: "error", message: "There was an error. Please try again." })
    end
  end

  private

  def build_messages(session)
    # Knowledge corpus (rich text or legacy), joined as plain text
    knowledge = Knowledge.active.order(created_at: :desc).map { |k| k.content_plain_text }.reject(&:blank?).join("\n\n")

    # Transcript of the role play (full)
    transcript = session.chat_messages.ordered.map do |m|
      who = (m.role == "user") ? "Manager" : (m.role == "assistant" ? "Role Play AI" : "System")
      "#{who}: #{m.content}"
    end.join("\n\n")

    # Coaching system prompt from database
    system_prompt = SystemPrompt.find_by(key: "clary_soul")&.content&.to_plain_text || "You are Clary, an expert leadership coach."

    # Coach chat history
    coach_history = session.coach_messages.ordered.map { |m| { role: m.role, content: m.content } }

    # Base messages with context about transcript + knowledge
    context_block = <<~CTX
      Transcript (full):
      #{transcript}

      Knowledge (use only if relevant):
      #{knowledge}

      Coaching requirement: When offering guidance, include 1–2 short, specific examples from the transcript (quoted or tightly paraphrased) to illustrate your point.
    CTX

    [
      { role: "system", content: system_prompt },
      { role: "user", content: context_block.strip }
    ] + coach_history
  end
end
