module Madmin
  class KnowledgesController < Madmin::ResourceController
    def create
      super
      generate_summary if @record.persisted?
    end

    def update
      super
      generate_summary if @record.errors.empty?
    end

    private

    def generate_summary
      content_text = @record.content.to_plain_text
      return if content_text.blank?

      response = OpenaiService.new.chat_completion(
        [
          {role: "system", content: "You are a helpful assistant. Summarize the following text in 5-10 words. Return only the summary, nothing else."},
          {role: "user", content: content_text}
        ],
        model: "gpt-4o-mini",
        temperature: 0.3,
        max_tokens: 50
      )

      @record.update_column(:summary, response[:content]&.strip)
    end
  end
end

