import React, { useState, useEffect, useRef } from 'react'
import { useSelector } from 'react-redux'
import { createConsumer } from '@rails/actioncable'

export default function Show() {
  const currentPageKey = useSelector((state) => state.superglue.currentPageKey)
  const page = useSelector((state) => state.pages[currentPageKey])
  const data = page?.data || {}

  const [messages, setMessages] = useState(data.messages || [])
  const [input, setInput] = useState('')
  const [isStreaming, setIsStreaming] = useState(false)
  const [streamingContent, setStreamingContent] = useState('')
  const messagesEndRef = useRef(null)
  const channelRef = useRef(null)

  useEffect(() => {
    // Initialize Action Cable
    const cable = createConsumer()
    const channel = cable.subscriptions.create(
      {
        channel: 'ChatChannel',
        session_id: data.session_id
      },
      {
        connected() {},
        disconnected() {},
        received(data) {
          switch (data.type) {
            case 'user_message':
              setMessages(prev => [...prev, data.message])
              break

            case 'assistant_start':
              setIsStreaming(true)
              setStreamingContent('')
              break

            case 'assistant_chunk':
              setStreamingContent(prev => prev + data.content)
              break

            case 'assistant_complete':
              setIsStreaming(false)
              setStreamingContent('')
              setMessages(prev => [...prev, data.message])
              break

            case 'error':
              setIsStreaming(false)
              setStreamingContent('')
              alert(data.message)
              break
          }
        }
      }
    )

    channelRef.current = channel

    return () => {
      channel.unsubscribe()
    }
  }, [data.session_id])

  useEffect(() => {
    // Auto-scroll to bottom
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages, streamingContent])

  const handleSubmit = (e) => {
    e.preventDefault()
    if (!input.trim() || isStreaming) return

    if (channelRef.current) {
      channelRef.current.perform('send_message', { content: input })
      setInput('')
    }
  }

  return (
    <div className="flex flex-col h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white border-b border-gray-200 px-6 py-4">
        <div className="flex items-center justify-between">
          <h1 className="text-2xl font-semibold text-gray-900">Clary</h1>
          <a
            href="/role_plays"
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
          >
            Exit Chat
          </a>
        </div>
      </div>

      {/* Messages Container */}
      <div className="flex-1 overflow-y-auto px-6 py-4">
        <div className="max-w-3xl mx-auto space-y-6">
          {messages.length === 0 && !isStreaming && (
            <div className="text-center py-12 text-gray-500">
              <p className="text-lg">No messages yet. Start the conversation!</p>
            </div>
          )}

          {messages.map((message) => (
            <div
              key={message.id}
              className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-2xl rounded-lg px-4 py-3 ${
                  message.role === 'user'
                    ? 'bg-blue-600 text-white'
                    : 'bg-white text-gray-900 border border-gray-200'
                }`}
              >
                <div className="whitespace-pre-wrap">{message.content}</div>
              </div>
            </div>
          ))}

          {/* Streaming message */}
          {isStreaming && streamingContent && (
            <div className="flex justify-start">
              <div className="max-w-2xl rounded-lg px-4 py-3 bg-white text-gray-900 border border-gray-200">
                <div className="whitespace-pre-wrap">{streamingContent}</div>
                <div className="mt-2 flex items-center text-gray-500 text-sm">
                  <div className="animate-pulse">●</div>
                  <span className="ml-2">AI is typing...</span>
                </div>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>
      </div>

      {/* Input Form */}
      <div className="bg-white border-t border-gray-200 px-6 py-4">
        <div className="max-w-3xl mx-auto">
          <form onSubmit={handleSubmit} className="flex gap-3">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              disabled={isStreaming}
              placeholder="Type your message..."
              className="flex-1 px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
            />
            <button
              type="submit"
              disabled={!input.trim() || isStreaming}
              className="px-6 py-3 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
            >
              {isStreaming ? 'Sending...' : 'Send'}
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
