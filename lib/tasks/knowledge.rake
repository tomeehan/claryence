require 'yaml'

namespace :knowledge do
  desc "Seed Knowledge items from db/seed_data/knowledge.yml (idempotent). Use LIMIT=100 to cap."
  task seed_defaults: :environment do
    path = Rails.root.join('db/seed_data/knowledge.yml')
    items = if File.exist?(path)
      YAML.load_file(path) || []
    else
      [
        "Focus feedback on specific behaviors and their impact, not on the person's character. Tie observations to concrete examples, describe the effect on outcomes, and propose next steps.",
        "Ask one clear question at a time. Avoid stacking multiple questions in a single turn.",
        "Build psychological safety: acknowledge feelings, validate concerns, and show curiosity before offering suggestions.",
        "Summarize and align before closing: restate agreements, ownership, deadlines, and check‑in cadence.",
        "Calibrate tone and length to the moment. Prefer 1–3 concise sentences in live conversation."
      ]
    end

    limit = ENV['LIMIT']&.to_i
    items = items.first(limit) if limit && limit > 0

    created = 0
    activated = 0
    items.each do |raw|
      content = raw.to_s.strip
      next if content.blank?
      record = Knowledge.find_or_create_by!(content: content)
      created += 1 if record.previous_changes.key?('id')
      if record.active != true
        record.update!(active: true)
        activated += 1
      end
    end

    puts "Seeded Knowledge. File: #{path.exist? ? 'present' : 'missing (used defaults)'}; processed: #{items.size}, created: #{created}, activated: #{activated}, total: #{Knowledge.count}."
  end
end
