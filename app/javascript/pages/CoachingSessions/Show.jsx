import React, { useEffect, useRef, useState } from "react";
import { useSelector } from "react-redux";
import { createConsumer } from "@rails/actioncable";

function Markdown({ text }) {
  // Minimal inline renderer (bold, italics, code) for parity with role play page
  const renderInline = (content, keyPrefix = "") => {
    const nodes = [];
    let key = 0;
    const parts = (content || "").split(/(`+)([^`]+?)\1/g);
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (i % 3 === 2) {
        nodes.push(
          <code key={`${keyPrefix}code-${key++}`} className="px-1 py-0.5 rounded bg-gray-200 text-gray-900">{part}</code>,
        );
      } else if (i % 3 === 1) {
        continue;
      } else {
        const boldSplit = part.split(/\*\*(.+?)\*\*/g);
        for (let j = 0; j < boldSplit.length; j++) {
          if (j % 2 === 1) {
            nodes.push(<strong key={`${keyPrefix}b-${key++}`}>{boldSplit[j]}</strong>);
          } else {
            const italSplit = boldSplit[j].split(/\*(.+?)\*/g);
            for (let k = 0; k < italSplit.length; k++) {
              if (k % 2 === 1) nodes.push(<em key={`${keyPrefix}i-${key++}`}>{italSplit[k]}</em>);
              else if (italSplit[k]) nodes.push(<span key={`${keyPrefix}s-${key++}`}>{italSplit[k]}</span>);
            }
          }
        }
      }
    }
    return nodes;
  };

  return <div className="space-y-2">{renderInline(text)}</div>;
}

export default function Show() {
  const currentPageKey = useSelector((state) => state.superglue.currentPageKey);
  const page = useSelector((state) => state.pages[currentPageKey]);
  const data = page?.data || {};

  const [messages, setMessages] = useState(data.messages || []);
  const [input, setInput] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const [streamingContent, setStreamingContent] = useState("");
  const [skipStreamingDisplay, setSkipStreamingDisplay] = useState(false);
  const [pendingAssistantMessage, setPendingAssistantMessage] = useState(null);
  const messagesEndRef = useRef(null);
  const scrollContainerRef = useRef(null);
  const channelRef = useRef(null);
  const textareaRef = useRef(null);
  const revealTimerRef = useRef(null);
  const lastTickRef = useRef(null);
  const carryRef = useRef(0);
  const streamBufferRef = useRef("");
  const [streamBuffer, setStreamBuffer] = useState("");
  const assistantDoneRef = useRef(false);
  const pendingAssistantMessageRef = useRef(null);
  const streamingContentRef = useRef("");

  const CHARS_PER_SECOND = 50; // fixed reveal speed

  const setStreamBufferSync = (val) => {
    streamBufferRef.current = val;
    setStreamBuffer(val);
  };

  useEffect(() => { pendingAssistantMessageRef.current = pendingAssistantMessage; }, [pendingAssistantMessage]);
  useEffect(() => { streamingContentRef.current = streamingContent; }, [streamingContent]);

  useEffect(() => {
    const cable = createConsumer();
    const channel = cable.subscriptions.create(
      { channel: "CoachChannel", session_id: data.session_id },
      {
        received(payload) {
          switch (payload.type) {
            case "user_message":
              setMessages((prev) => [...prev, payload.message]);
              break;
            case "assistant_start":
              setSkipStreamingDisplay(false);
              setIsStreaming(true);
              setStreamingContent("");
              setStreamBufferSync("");
              setPendingAssistantMessage(null);
              autoScrollRef.current = true;
              requestAnimationFrame(() => {
                programmaticScrollRef.current = true;
                messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
                setTimeout(() => { programmaticScrollRef.current = false; }, 0);
              });
              break;
            case "assistant_chunk":
              setStreamBufferSync((streamBufferRef.current || "") + (payload.content || ""));
              break;
            case "assistant_complete":
              setIsStreaming(false);
              setMessages((prev) => [...prev, payload.message]);
              setStreamingContent("");
              setStreamBufferSync("");
              setPendingAssistantMessage(null);
              break;
            case "error":
              setIsStreaming(false);
              setStreamingContent("");
              alert(payload.message || "Error");
              break;
          }
        },
      },
    );

    channelRef.current = channel;
    return () => channel.unsubscribe();
  }, [data.session_id]);

  const autoScrollRef = useRef(true);
  const [showJumpLatest, setShowJumpLatest] = useState(false);
  const LOCK_DISTANCE = 4;
  const BREAK_DISTANCE = 80;
  const programmaticScrollRef = useRef(false);
  const userScrollUpRef = useRef(false);
  const touchStartYRef = useRef(null);

  useEffect(() => {
    if (autoScrollRef.current) {
      const el = scrollContainerRef.current;
      if (el) {
        programmaticScrollRef.current = true;
        el.scrollTop = el.scrollHeight;
        requestAnimationFrame(() => { programmaticScrollRef.current = false; });
      }
    } else {
      setShowJumpLatest(true);
    }
  }, [messages, streamingContent]);

  const lastScrollTopRef = useRef(0);
  const handleScroll = () => {
    const el = scrollContainerRef.current;
    if (!el) return;
    const distanceFromBottom = el.scrollHeight - el.clientHeight - el.scrollTop;
    const atBottom = distanceFromBottom <= LOCK_DISTANCE;
    if (atBottom) {
      autoScrollRef.current = true;
      setShowJumpLatest(false);
    } else if (!programmaticScrollRef.current) {
      if (userScrollUpRef.current || distanceFromBottom > BREAK_DISTANCE) {
        autoScrollRef.current = false;
        setShowJumpLatest(true);
      }
    }
    userScrollUpRef.current = false;
  };

  useEffect(() => {
    const startTimer = () => {
      if (revealTimerRef.current) return;
      lastTickRef.current = performance.now();
      carryRef.current = 0;
      revealTimerRef.current = setInterval(() => {
        const now = performance.now();
        const dt = (now - lastTickRef.current) / 1000;
        lastTickRef.current = now;
        const desired = CHARS_PER_SECOND * dt + carryRef.current;
        const n = Math.floor(desired);
        carryRef.current = desired - n;
        if (n > 0) {
          const prevBuf = streamBufferRef.current || "";
          if (prevBuf.length > 0) {
            const take = Math.min(n, prevBuf.length);
            const head = prevBuf.slice(0, take);
            const tail = prevBuf.slice(take);
            setStreamingContent((prev) => (prev || "") + head);
            setStreamBufferSync(tail);
          }
        }
        if (!isStreaming && (streamBufferRef.current || "").length === 0) {
          clearInterval(revealTimerRef.current);
          revealTimerRef.current = null;
        }
      }, 50);
    };
    if (isStreaming) startTimer();
    return () => { if (revealTimerRef.current) { clearInterval(revealTimerRef.current); revealTimerRef.current = null; } };
  }, [isStreaming]);

  const autoResize = () => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = Math.min(el.scrollHeight, 200) + "px";
  };

  const sendMessage = () => {
    if (!input.trim() || isStreaming) return;
    if (channelRef.current) {
      channelRef.current.perform("send_message", { content: input });
      setInput("");
      requestAnimationFrame(() => autoResize());
      autoScrollRef.current = true;
      requestAnimationFrame(() => {
        programmaticScrollRef.current = true;
        messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
        setTimeout(() => { programmaticScrollRef.current = false; }, 0);
      });
    }
  };

  const handleSubmit = (e) => { e.preventDefault(); sendMessage(); };
  const handleKeyDown = (e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); sendMessage(); } };

  return (
    <div className="fixed inset-0 flex flex-col bg-purple-50 overflow-hidden">
      <div className="shrink-0 bg-white border-b border-gray-200 px-4 py-3 md:px-6 md:py-4">
        <div className="flex items-center justify-between">
          <h1 className="text-xl md:text-2xl font-semibold text-gray-900">Clary</h1>
          <a href="/" className="px-3 py-1.5 md:px-4 md:py-2 text-sm font-medium rounded-lg text-gray-700 bg-white border border-gray-300 hover:bg-gray-50">Exit</a>
        </div>
      </div>

      <div className="flex-1 flex min-h-0">
        <div className="flex flex-col w-full min-h-0">
          <div
            ref={scrollContainerRef}
            onScroll={handleScroll}
            onWheel={(e) => { if (e.deltaY < 0) userScrollUpRef.current = true; }}
            onTouchStart={(e) => { touchStartYRef.current = e.touches?.[0]?.clientY ?? null; }}
            onTouchMove={(e) => {
              const y = e.touches?.[0]?.clientY;
              if (touchStartYRef.current != null && y != null) {
                if (y - touchStartYRef.current > 4) userScrollUpRef.current = true;
              }
            }}
            className="flex-1 overflow-y-auto overflow-x-hidden px-4 py-4 md:px-6"
          >
            <div className="max-w-3xl mx-auto space-y-4">
              {messages.map((message) => (
                <div key={message.id} className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}>
                  <div className={`max-w-[85%] md:max-w-2xl rounded-2xl px-4 py-2 md:py-3 ${message.role === "user" ? "bg-[#6b116e] text-white" : "bg-white text-gray-900 border border-gray-200"}`}>
                    <div className="whitespace-pre-wrap break-words text-[15px] md:text-base leading-6">
                      <Markdown text={message.content} />
                    </div>
                  </div>
                </div>
              ))}

              {isStreaming && (
                <div className="flex justify-start">
                  <div className="max-w-[85%] md:max-w-2xl rounded-2xl px-4 py-2 md:py-3 bg-white text-gray-900 border border-gray-200">
                    <div className="whitespace-pre-wrap break-words text-[15px] md:text-base leading-6">{streamingContent}</div>
                    <div className="mt-1 text-xs text-gray-400">Typing…</div>
                  </div>
                </div>
              )}

              {showJumpLatest && (
                <div className="sticky bottom-2 flex justify-center pointer-events-none">
                  <button
                    type="button"
                    onClick={() => {
                      programmaticScrollRef.current = true;
                      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
                      setTimeout(() => { programmaticScrollRef.current = false; }, 0);
                      autoScrollRef.current = true;
                      setShowJumpLatest(false);
                    }}
            className="pointer-events-auto px-3 py-1.5 text-sm rounded-full bg-gray-800 text-white shadow hover:bg-gray-700"
                  >
                    Jump to latest
                  </button>
                </div>
              )}
              <div ref={messagesEndRef} />
            </div>
          </div>

          <div className="shrink-0 bg-white border-t border-gray-200 px-4 py-3 md:px-6 md:py-4">
            <div className="max-w-3xl mx-auto">
              <form onSubmit={handleSubmit} className="flex gap-2 md:gap-3">
                <textarea
                  ref={textareaRef}
                  rows={1}
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onInput={autoResize}
                  onKeyDown={handleKeyDown}
                  disabled={isStreaming}
                  placeholder="Type your message..."
                  className="flex-1 px-3 py-2 md:px-4 md:py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#1a365d] disabled:bg-gray-100 disabled:cursor-not-allowed resize-none overflow-y-auto max-h-32 leading-6 text-base"
                />
                <button type="submit" disabled={!input.trim() || isStreaming} className="px-4 py-2 md:px-6 md:py-3 bg-[#6b116e] text-white rounded-lg font-medium hover:bg-[#571056] focus:outline-none focus:ring-2 focus:ring-[#6b116e] disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors">
                  {isStreaming ? "..." : "Send"}
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
