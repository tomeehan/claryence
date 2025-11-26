class ChatChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info "ChatChannel#subscribed - session_id: #{params[:session_id]}, user: #{current_user.id}, account: #{current_account.id}"
    session = RolePlaySession.find(params[:session_id])
    # Basic authorization - check account
    if session.account_id == current_account.id
      Rails.logger.info "ChatChannel subscription authorized for session #{session.id}"
      stream_for session
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

    # Create user message
    user_message = session.chat_messages.create!(
      role: "user",
      content: data["content"],
      account_id: session.account_id
    )

    # Broadcast user message immediately
    ChatChannel.broadcast_to(session, {
      type: "user_message",
      message: {
        id: user_message.id,
        role: "user",
        content: user_message.content,
        created_at: user_message.created_at
      }
    })

    # Trigger a quick conversation review immediately so feedback starts streaming
    ConversationReviewJob.perform_later(session.id)

    # Get conversation history
    messages = session.chat_messages.ordered.map do |msg|
      {role: msg.role, content: msg.content}
    end

    # Add system prompt if present
    Rails.logger.info "System prompt present: #{session.system_prompt.present?}"
    Rails.logger.info "System prompt (first 100 chars): #{session.system_prompt&.first(100)}"
    messages.unshift({role: "system", content: session.system_prompt}) if session.system_prompt.present?
    Rails.logger.info "Messages being sent to OpenAI: #{messages.length} messages"
    Rails.logger.info "First message role: #{messages.first[:role]}" if messages.any?

    # Stream AI response
    ai_content = ""
    openai = OpenaiService.new

    # Broadcast streaming start
    ChatChannel.broadcast_to(session, {
      type: "assistant_start"
    })

    begin
      openai.chat_completion_stream(
        messages,
        model: "gpt-4o",
        temperature: 0.95,
        top_p: 0.9,
        presence_penalty: 0.2,
        frequency_penalty: 0.2
      ) do |chunk|
        ai_content += chunk
        ChatChannel.broadcast_to(session, {
          type: "assistant_chunk",
          content: chunk
        })
      end

      # Save complete AI response
      assistant_message = session.chat_messages.create!(
        role: "assistant",
        content: ai_content,
        account_id: session.account_id
      )

      # Broadcast completion
      ChatChannel.broadcast_to(session, {
        type: "assistant_complete",
        message: {
          id: assistant_message.id,
          role: "assistant",
          content: assistant_message.content,
          created_at: assistant_message.created_at
        }
      })

      # Trigger updated review after assistant reply (final pass)
      ConversationReviewJob.perform_later(session.id)
    rescue => e
      Rails.logger.error("OpenAI Error: #{e.message}")
      ChatChannel.broadcast_to(session, {
        type: "error",
        message: "Sorry, there was an error processing your message. Please try again."
      })
    end
  end
end
