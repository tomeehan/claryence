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
    # Knowledge corpus
    knowledge = Knowledge.active.order(created_at: :desc).pluck(:content).compact.reject(&:blank?).join("\n\n")

    # Transcript of the role play (full)
    transcript = session.chat_messages.ordered.map do |m|
      who = (m.role == "user") ? "Manager" : (m.role == "assistant" ? "Role Play AI" : "System")
      "#{who}: #{m.content}"
    end.join("\n\n")

    # Coaching system prompt
    system_prompt = <<~SYS.strip
      You are Clary, an expert leadership coach.
      You are talking to the human Manager who just completed a role play.
      Your job is to help them reflect and improve using concise, practical coaching.

      Use the provided Knowledge when it clearly applies; otherwise, do not force it.
      Always ground your coaching with 1–2 very short, concrete examples from the transcript.
      - Quote brief phrases (5–12 words) or paraphrase precisely.
      - Attribute examples to "Manager" or "Role Play AI" so it’s clear who said what.
      - Do not paste long passages; keep quotes short.

      Keep a supportive, direct tone. Prefer short paragraphs or brief lists when appropriate.
      Do not role-play the other character; you are the coach speaking to the Manager.
    SYS

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
