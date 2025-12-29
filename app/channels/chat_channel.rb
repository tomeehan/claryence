class ChatChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "ChatChannel#subscribed - session_id: #{params[:session_id]}, user: #{current_user.id}, account: #{current_account.id}"
    session = RolePlaySession.find(params[:session_id])
    # Basic authorization - check account
    if session.account_id == current_account.id
      Rails.logger.info "ChatChannel subscription authorized for session #{session.id}"
      stream_for session
      # Note: Setup phase intro is generated synchronously by the controller
      # Only auto-start for role_play and debrief phases (handled by transition_phase)
    else
      Rails.logger.warn "ChatChannel subscription rejected - account mismatch"
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def send_message(data)
    Rails.logger.info "ChatChannel#send_message - data: #{data.inspect}"
    session = RolePlaySession.find(params[:session_id])
    unless session.account_id == current_account.id
      Rails.logger.warn "ChatChannel#send_message rejected - account mismatch"
      return
    end

    # Create user message with current phase
    user_message = session.chat_messages.create!(
      role: "user",
      content: data["content"],
      phase: session.phase,
      account_id: session.account_id
    )

    # Broadcast user message immediately
    ChatChannel.broadcast_to(session, {
      type: "user_message",
      message: message_payload(user_message)
    })

    # Trigger conversation review only for admins during role_play phase
    ConversationReviewJob.perform_later(session.id) if current_user.admin? && session.role_play_phase?

    # Build messages for current phase context
    messages = build_messages_for_phase(session)

    # Stream AI response
    stream_ai_response(session, messages)
  end

  # Handle phase transitions via WebSocket
  def transition_phase(data)
    session = RolePlaySession.find(params[:session_id])
    return unless session.account_id == current_account.id

    target_phase = data["phase"]
    Rails.logger.info "ChatChannel#transition_phase - transitioning to #{target_phase}"

    case target_phase
    when "role_play"
      session.transition_to_role_play!
    when "debrief"
      session.transition_to_debrief!
    else
      Rails.logger.warn "Invalid phase transition requested: #{target_phase}"
      return
    end

    # Broadcast phase change
    ChatChannel.broadcast_to(session, {
      type: "phase_changed",
      phase: session.phase
    })

    # Generate intro message for the new phase
    generate_phase_intro(session)
  end

  # Starts the conversation with an opening assistant message for the current phase
  def start_conversation(_data = nil)
    session = RolePlaySession.find(params[:session_id])
    return unless session.account_id == current_account.id

    # Only start if no prior messages exist for this phase
    return if session.chat_messages.where(phase: session.phase).exists?

    generate_phase_intro(session)
  end

  private

  def generate_phase_intro(session)
    case session.phase
    when "setup"
      generate_setup_message(session)
    when "role_play"
      generate_role_play_message(session)
    when "debrief"
      generate_debrief_message(session)
    end
  end

  def generate_setup_message(session)
    messages = [
      {role: "system", content: session.build_setup_prompt},
      {role: "user", content: "Hello, I'm ready to learn about this scenario."}
    ]

    stream_ai_response_for_intro(session, messages, "setup", max_tokens: 400)
  end

  def generate_role_play_message(session)
    messages = [
      {role: "system", content: session.system_prompt},
      {role: "user", content: "Hello"}
    ]

    stream_ai_response_for_intro(session, messages, "role_play", max_tokens: 280)
  end

  def generate_debrief_message(session)
    # Simple static intro for debrief
    msg = session.chat_messages.create!(
      role: "assistant",
      content: "How do you think that went?",
      phase: "debrief",
      account_id: session.account_id
    )

    ChatChannel.broadcast_to(session, {
      type: "assistant_complete",
      message: message_payload(msg)
    })
  end

  def build_messages_for_phase(session)
    case session.phase
    when "setup"
      build_setup_messages(session)
    when "role_play"
      build_role_play_messages(session)
    when "debrief"
      build_debrief_messages(session)
    end
  end

  def build_setup_messages(session)
    messages = [{role: "system", content: session.build_setup_prompt}]
    session.chat_messages.setup_phase.ordered.each do |msg|
      messages << {role: msg.role, content: msg.content}
    end
    messages
  end

  def build_role_play_messages(session)
    messages = [{role: "system", content: session.system_prompt}] if session.system_prompt.present?
    messages ||= []
    session.chat_messages.role_play_phase.ordered.each do |msg|
      messages << {role: msg.role, content: msg.content}
    end
    messages
  end

  def build_debrief_messages(session)
    messages = [{role: "system", content: session.build_debrief_prompt}]
    session.chat_messages.debrief_phase.ordered.each do |msg|
      messages << {role: msg.role, content: msg.content}
    end
    messages
  end

  def stream_ai_response(session, messages)
    ChatChannel.broadcast_to(session, {type: "assistant_start"})

    ai_content = ""
    openai = OpenaiService.new

    begin
      openai.chat_completion_stream(
        messages,
        model: session.openai_model,
        temperature: temperature_for_phase(session.phase),
        top_p: 0.9,
        presence_penalty: 0.2,
        frequency_penalty: 0.2
      ) do |chunk|
        ai_content += chunk
        ChatChannel.broadcast_to(session, {type: "assistant_chunk", content: chunk})
      end

      # Parse wrapping_up flag from role play responses
      wrapping_up = nil
      clean_content = ai_content

      if session.role_play_phase?
        wrapping_up, clean_content = parse_wrapping_up_flag(ai_content)
      end

      assistant_message = session.chat_messages.create!(
        role: "assistant",
        content: clean_content,
        phase: session.phase,
        account_id: session.account_id
      )

      ChatChannel.broadcast_to(session, {
        type: "assistant_complete",
        message: message_payload(assistant_message),
        wrapping_up: wrapping_up
      })

      # Trigger review after assistant reply for admins during role_play phase
      ConversationReviewJob.perform_later(session.id) if current_user.admin? && session.role_play_phase?
    rescue => e
      Rails.logger.error("OpenAI Error: #{e.message}")
      ChatChannel.broadcast_to(session, {
        type: "error",
        message: "Sorry, there was an error processing your message. Please try again."
      })
    end
  end

  def stream_ai_response_for_intro(session, messages, phase, max_tokens: 400)
    ChatChannel.broadcast_to(session, {type: "assistant_start"})

    ai_content = ""
    openai = OpenaiService.new

    begin
      openai.chat_completion_stream(
        messages,
        model: session.openai_model,
        temperature: temperature_for_phase(phase),
        max_tokens: max_tokens
      ) do |chunk|
        ai_content += chunk
        ChatChannel.broadcast_to(session, {type: "assistant_chunk", content: chunk})
      end

      msg = session.chat_messages.create!(
        role: "assistant",
        content: ai_content,
        phase: phase,
        account_id: session.account_id
      )

      ChatChannel.broadcast_to(session, {
        type: "assistant_complete",
        message: message_payload(msg)
      })
    rescue => e
      Rails.logger.error("OpenAI Error (intro): #{e.message}")
      ChatChannel.broadcast_to(session, {
        type: "error",
        message: "Sorry, there was an error. Please try again."
      })
    end
  end

  def temperature_for_phase(phase)
    case phase
    when "setup" then 0.8
    when "role_play" then 0.95
    when "debrief" then 0.7
    else 0.8
    end
  end

  def parse_wrapping_up_flag(content)
    lines = content.lines
    last_line = lines.last.to_s.strip

    if last_line.start_with?("{") && last_line.include?("wrapping_up")
      begin
        parsed = JSON.parse(last_line)
        wrapping_up = !!parsed["wrapping_up"]
        clean_content = lines[0..-2].join.rstrip
        return [wrapping_up, clean_content]
      rescue JSON::ParserError
        # Fall through if JSON is malformed
      end
    end

    [nil, content]
  end

  def message_payload(message)
    {
      id: message.id,
      role: message.role,
      content: message.content,
      phase: message.phase,
      created_at: message.created_at
    }
  end
end
