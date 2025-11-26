class GenerateInitialMessageJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = RolePlaySession.find(session_id)

    # Build messages with system prompt
    messages = [
      {role: "system", content: session.system_prompt},
      {role: "user", content: "Hello"}
    ]

    # Get AI's initial greeting
    openai = OpenaiService.new
    response = openai.chat_completion(
      messages,
      model: "gpt-4o",
      temperature: 0.9,
      top_p: 0.9,
      presence_penalty: 0.2,
      frequency_penalty: 0.2,
      max_tokens: 140
    )

    # Save the assistant's greeting message
    assistant_message = session.chat_messages.create!(
      role: "assistant",
      content: response[:content],
      account_id: session.account_id,
      token_count: response[:tokens]
    )

    # Broadcast to any connected clients
    ChatChannel.broadcast_to(session, {
      type: "assistant_complete",
      message: {
        id: assistant_message.id,
        role: "assistant",
        content: assistant_message.content,
        created_at: assistant_message.created_at
      }
    })
  rescue => e
    Rails.logger.error("GenerateInitialMessageJob error: #{e.message}")
  end
end
