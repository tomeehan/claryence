class OpenaiService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV["OPENAI_API_KEY"] || Rails.application.credentials.dig(:openai, :api_key),
      log_errors: true
    )
  end

  def chat_completion_stream(messages, &block)
    @client.chat(
      parameters: {
        model: "gpt-4o",
        messages: messages,
        temperature: 0.8,
        stream: proc do |chunk, _bytesize|
          delta = chunk.dig("choices", 0, "delta", "content")
          block.call(delta) if delta
        end
      }
    )
  end

  def chat_completion(messages)
    response = @client.chat(
      parameters: {
        model: "gpt-4-turbo",
        messages: messages,
        temperature: 0.8
      }
    )

    {
      content: response.dig("choices", 0, "message", "content"),
      tokens: response.dig("usage", "total_tokens")
    }
  end
end
