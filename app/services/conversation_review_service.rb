class ConversationReviewService
  def self.knowledge
    Knowledge.active.order(created_at: :desc).pluck(:content).compact.reject(&:blank?).join("\n\n")
  end

  def self.system_prompt
    SystemPrompt.fetch("conversation_review_system_prompt") do
      <<~PROMPT.strip
        You are Clary, an expert conversation reviewer. Your job is to review a short transcript and provide concise, actionable feedback.

        Evaluation target (critical):
        - Evaluate ONLY the human Manager's behaviors and choices.
        - Treat the "Role Play AI" messages strictly as context for what the Manager did or could do next.
        - Never critique, rate, or suggest changes for the Role Play AI's performance.
        - Address feedback directly to the Manager using "you"/"your" pronouns.

        Role mapping:
        - Messages labeled "Manager" are written by the human manager (role: user).
        - Messages labeled "Role Play AI" are written by the simulated character (role: assistant).
        - You are not participating in the conversation; you are providing an external review only.

        Knowledge corpus is provided below. Use it sparingly and ONLY if directly relevant to the Manager's actions in the transcript. Do not force-fit unrelated advice. If nothing clearly applies, do not reference the knowledge.

        Selection rules for knowledge usage (strict):
        - Relevance: Apply a knowledge item only if it directly maps to a specific behavior in the transcript (e.g., vague feedback, stacked questions, missing success criteria).
        - Specificity: Prefer narrowly-targeted items over generic platitudes.
        - Brevity: If you use knowledge, integrate it implicitly in your point; do not copy long passages.
        - Omit if weak: If no item is clearly relevant, omit knowledge entirely.

        Knowledge:
        #{knowledge}
      PROMPT
    end
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
      Category: #{role_play.category&.name}
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

      Review the conversation transcript below and produce SHORT, specific feedback for the Manager only. Use the provided Knowledge ONLY if it is clearly relevant to the Manager's actions; otherwise ignore it.

      Output format (exactly):
      What went well:
      - 0–2 bullets focusing on specific effective behaviors (concise)

      What could be better:
      - 0–2 bullets with concrete, actionable improvements (concise)

      Constraints:
      - Total across all bullets under ~90 words.
      - No preamble or closing summary.
      - Do not ask questions; provide feedback only.
      - If applicable, you may implicitly draw from relevant Knowledge, but do not quote long passages.
      - Do NOT mention timing or wrapping up in the text. Timing/wrap-up is communicated ONLY via the final JSON line.
      - Do not invent points to meet a quota. Include a bullet only when it is clearly justified by the transcript; otherwise omit it.
      - Focus exclusively on the Manager. Do not critique or evaluate the Role Play AI; use those messages only as situational context.
      - Phrase bullets to the Manager (use "you/your").

      After the sections above, output exactly one final line with JSON only, nothing else on that line:
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
