class OpenaiService
  def initialize
    @client = OpenAI::Client.new(
      access_token: ENV["OPENAI_API_KEY"] || Rails.application.credentials.dig(:openai, :api_key),
      log_errors: true
    )
  end

  def chat_completion_stream(messages, model: "gpt-4o", temperature: 0.8, max_tokens: nil, top_p: nil, presence_penalty: nil, frequency_penalty: nil, &block)
    params = {
      model: model,
      messages: messages,
      temperature: temperature,
      stream: proc do |chunk, _bytesize|
        delta = chunk.dig("choices", 0, "delta", "content")
        block.call(delta) if delta
      end
    }
    params[:top_p] = top_p if top_p
    params[:presence_penalty] = presence_penalty if presence_penalty
    params[:frequency_penalty] = frequency_penalty if frequency_penalty
    params[:max_tokens] = max_tokens if max_tokens
    @client.chat(parameters: params)
  end

  def chat_completion(messages, model: "gpt-4-turbo", temperature: 0.8, max_tokens: nil, top_p: nil, presence_penalty: nil, frequency_penalty: nil)
    params = {
      model: model,
      messages: messages,
      temperature: temperature
    }
    params[:top_p] = top_p if top_p
    params[:presence_penalty] = presence_penalty if presence_penalty
    params[:frequency_penalty] = frequency_penalty if frequency_penalty
    params[:max_tokens] = max_tokens if max_tokens
    response = @client.chat(parameters: params)

    {
      content: response.dig("choices", 0, "message", "content"),
      tokens: response.dig("usage", "total_tokens")
    }
  end
end
