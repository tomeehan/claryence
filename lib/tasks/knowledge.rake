namespace :knowledge do
  desc "Seed default Knowledge items (idempotent)"
  task seed_defaults: :environment do
    items = [
      <<~TXT.strip,
        Focus feedback on specific behaviors and their impact, not on the person's character. Tie observations to concrete examples, describe the effect on the team or outcomes, and propose next steps. Keep it short and direct.
      TXT
      <<~TXT.strip,
        Ask one clear question at a time. Avoid stacking multiple questions in a single turn. Let the other person think and respond before adding more detail or context.
      TXT
      <<~TXT.strip,
        Build psychological safety: acknowledge feelings, validate legitimate concerns, and show curiosity. Use openers like "Help me understand..." or "What feels hardest right now?" to invite honest dialogue.
      TXT
      <<~TXT.strip,
        Summarize and align before closing: restate what you heard, confirm agreements, and clarify ownership, deadlines, and check‑in cadence. Ensure both sides share the same definition of success.
      TXT
      <<~TXT.strip,
        Calibrate tone and length to the moment. Prefer 1–3 concise sentences, natural language, and plain words. Avoid lists and corporate jargon in live conversation.
      TXT
    ]

    created = 0
    items.each do |content|
      record = Knowledge.find_or_create_by!(content: content)
      if record.saved_changes?
        created += 1
      end
      record.update!(active: true) if record.active != true
    end

    puts "Seeded Knowledge defaults. Total: #{Knowledge.count}, newly created: #{created}."
  end
end

