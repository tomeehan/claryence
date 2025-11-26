class ConversationReviewService
  def self.knowledge
    Knowledge.active.order(created_at: :desc).pluck(:content).compact.reject(&:blank?).join("\n\n")
  end

  def self.system_prompt
    <<~PROMPT.strip
      You are Clary. You are an AI coach. You are reviewing this conversation and marking feedback against this knowlegde.

      Role mapping:
      - Messages labeled "Manager" are written by the human manager (role: user).
      - Messages labeled "Role Play AI" are written by the simulated character (role: assistant).
      - You are not participating in the conversation; you are providing an external review.

      You will be provided additional context about the role play scenario and a transcript with timestamps.

      Knowledge:
      #{knowledge}
    PROMPT
  end

  def self.build_messages_for(session)
    role_play = session.role_play

    # Build concise role play context (excluding llm_instructions)
    description_text = role_play.description&.to_plain_text.to_s.strip
    recommended_text = role_play.recommended_for&.to_plain_text.to_s.strip
    description_snippet = description_text[0, 300]
    recommended_snippet = recommended_text[0, 200]

    elapsed_minutes = if session.started_at.present?
      ((Time.current - session.started_at) / 60.0).round
    else
      nil
    end

    role_play_context = <<~CTX
      Name: #{role_play.name}
      Category: #{role_play.category}
      Target Duration (minutes): #{role_play.duration_minutes}
      Description (snippet): #{description_snippet}
      Recommended For (snippet): #{recommended_snippet}
      Session Started At (UTC): #{session.started_at&.utc&.iso8601}
      Elapsed Minutes (approx): #{elapsed_minutes}
      Message Count: #{session.chat_messages.count}
    CTX

    # Limit to the most recent messages to reduce latency
    recent_messages = session.chat_messages.ordered.last(12)
    transcript = recent_messages.map do |m|
      label = case m.role
              when "user" then "Manager"
              when "assistant" then "Role Play AI"
              else "System"
              end
      ts = m.created_at.utc.strftime('%Y-%m-%d %H:%M UTC')
      "[#{ts}] #{label}: #{m.content}"
    end.join("\n\n")

    review_instruction = <<~TXT
      Context of the role play you are reviewing:
      #{role_play_context}

      Review the conversation transcript below and provide feedback:
      - Provide specific, constructive feedback for the manager.
      - Reference the Knowledge if applicable.
      - Be concise and actionable.
      - Do not ask follow-up questions; output a review only.
      - Keep it SHORT: at most 3 bullet points, total under 80 words.
      - Include one bullet about session duration: considering the target duration and elapsed minutes, clearly state whether it's time to wrap up.
      - No preamble or closing summary; output bullets only, followed by one machine-readable JSON line.

      After the bullets, output exactly one line with JSON only, nothing else on that line:
      {"wrapping_up": true} if the session should wrap up now based on target duration and elapsed time; otherwise {"wrapping_up": false}.

      Conversation transcript:
      #{transcript}
    TXT

    [
      { role: "system", content: system_prompt },
      { role: "user", content: review_instruction.strip }
    ]
  end
end
