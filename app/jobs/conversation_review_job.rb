class ConversationReviewJob < ApplicationJob
  queue_as :default

  def perform(session_id)
    session = RolePlaySession.find(session_id)

    messages = ConversationReviewService.build_messages_for(session)
    openai = OpenaiService.new
    # Start streaming the review so it appears quickly
    ChatChannel.broadcast_to(session, { type: "review_start" })

    full_content = ""
    openai.chat_completion_stream(messages, model: "gpt-4o-mini", temperature: 0.2, max_tokens: 120) do |chunk|
      next if chunk.nil? || chunk.empty?
      full_content << chunk
      ChatChannel.broadcast_to(session, { type: "review_chunk", content: chunk })
    end

    # Attempt to parse a trailing JSON status line and remove it from the review text
    wrapping_up = nil
    cleaned_content = full_content.dup
    begin
      last_line = cleaned_content.lines.last.to_s.strip
      if last_line.start_with?("{") && last_line.end_with?("}")
        parsed = JSON.parse(last_line)
        wrapping_up = !!parsed["wrapping_up"] unless parsed.nil?
        cleaned_content = cleaned_content.lines[0..-2].join.rstrip
      end
    rescue JSON::ParserError
      wrapping_up = nil
    end

    ChatChannel.broadcast_to(session, { type: "review_complete", content: cleaned_content })
    unless wrapping_up.nil?
      ChatChannel.broadcast_to(session, { type: "review_status", wrapping_up: wrapping_up })
    end
  end
end
