import React, { useState, useEffect, useRef } from "react";
import { useSelector } from "react-redux";
import { createConsumer } from "@rails/actioncable";

function Markdown({ text }) {
  const renderInline = (content, keyPrefix = "") => {
    const nodes = [];
    let key = 0;
    // Handle inline code first using backticks
    const parts = content.split(/(`+)([^`]+?)\1/g);
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      if (i % 3 === 2) {
        // code content captured in group 2
        nodes.push(
          <code
            key={`${keyPrefix}code-${key++}`}
            className="px-1 py-0.5 rounded bg-gray-200 text-gray-900"
          >
            {part}
          </code>,
        );
      } else if (i % 3 === 1) {
        // the backtick group, skip — handled with group 2
        continue;
      } else {
        // process bold and italics in this plain segment
        let segment = part;
        // Bold: **text**
        const boldSplit = segment.split(/\*\*(.+?)\*\*/g);
        for (let j = 0; j < boldSplit.length; j++) {
          if (j % 2 === 1) {
            nodes.push(
              <strong key={`${keyPrefix}b-${key++}`}>{boldSplit[j]}</strong>,
            );
          } else {
            // Italic: *text*
            const italSplit = boldSplit[j].split(/\*(.+?)\*/g);
            for (let k = 0; k < italSplit.length; k++) {
              if (k % 2 === 1) {
                nodes.push(
                  <em key={`${keyPrefix}i-${key++}`}>{italSplit[k]}</em>,
                );
              } else if (italSplit[k]) {
                nodes.push(
                  <span key={`${keyPrefix}s-${key++}`}>{italSplit[k]}</span>,
                );
              }
            }
          }
        }
      }
    }
    return nodes;
  };

  const parse = (md) => {
    const lines = (md || "").split(/\r?\n/);
    const elements = [];
    let key = 0;
    let inCode = false;
    let codeBuffer = [];
    let para = [];
    let listType = null; // 'ul' or 'ol'
    let listItems = [];

    const flushPara = () => {
      if (para.length) {
        const text = para.join(" ");
        elements.push(
          <p key={`p-${key++}`} className="text-gray-800">
            {renderInline(text, `p${key}-`)}
          </p>,
        );
        para = [];
      }
    };
    const flushList = () => {
      if (listItems.length) {
        const items = listItems.map((t, idx) => (
          <li key={`li-${idx}`} className="ml-4 list-disc">
            {renderInline(t, `li${idx}-`)}
          </li>
        ));
        if (listType === "ul") {
          elements.push(
            <ul key={`ul-${key++}`} className="space-y-1 text-gray-800">
              {items}
            </ul>,
          );
        } else {
          const olItems = listItems.map((t, idx) => (
            <li key={`oli-${idx}`} className="ml-5 list-decimal">
              {renderInline(t, `oli${idx}-`)}
            </li>
          ));
          elements.push(
            <ol key={`ol-${key++}`} className="space-y-1 text-gray-800">
              {olItems}
            </ol>,
          );
        }
        listItems = [];
        listType = null;
      }
    };

    for (const line of lines) {
      // Code fences
      if (line.startsWith("```")) {
        if (inCode) {
          // closing fence
          elements.push(
            <pre
              key={`pre-${key++}`}
              className="bg-gray-900 text-gray-100 p-3 rounded overflow-x-auto"
            >
              <code>{codeBuffer.join("\n")}</code>
            </pre>,
          );
          codeBuffer = [];
          inCode = false;
        } else {
          flushPara();
          flushList();
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        codeBuffer.push(line);
        continue;
      }

      // Headings
      const h = line.match(/^(#{1,6})\s+(.+)$/);
      if (h) {
        flushPara();
        flushList();
        const level = h[1].length;
        const content = h[2];
        const Tag = `h${Math.min(level, 6)}`;
        elements.push(
          React.createElement(
            Tag,
            {
              key: `h-${key++}`,
              className: "font-semibold text-gray-900 mt-2",
            },
            renderInline(content, `h${key}-`),
          ),
        );
        continue;
      }

      // Lists
      const ul = line.match(/^\s*[-*]\s+(.+)$/);
      const ol = line.match(/^\s*\d+\.\s+(.+)$/);
      if (ul) {
        flushPara();
        if (listType && listType !== "ul") flushList();
        listType = "ul";
        listItems.push(ul[1]);
        continue;
      }
      if (ol) {
        flushPara();
        if (listType && listType !== "ol") flushList();
        listType = "ol";
        listItems.push(ol[1]);
        continue;
      }

      // Blank line breaks blocks
      if (/^\s*$/.test(line)) {
        flushPara();
        flushList();
        continue;
      }

      // Paragraph text
      para.push(line.trim());
    }

    flushPara();
    flushList();
    return elements;
  };

  return <div className="space-y-2">{parse(text)}</div>;
}

export default function Show() {
  const currentPageKey = useSelector((state) => state.superglue.currentPageKey);
  const page = useSelector((state) => state.pages[currentPageKey]);
  const data = page?.data || {};

  const [messages, setMessages] = useState(data.messages || []);
  const [input, setInput] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const [streamingContent, setStreamingContent] = useState("");
  // Streaming pacing state for reading-speed reveal
  const [streamBuffer, setStreamBuffer] = useState("");
  // Skip streaming display for the very first assistant message
  const [skipStreamingDisplay, setSkipStreamingDisplay] = useState(false);
  const [assistantDone, setAssistantDone] = useState(false);
  const [pendingAssistantMessage, setPendingAssistantMessage] = useState(null);
  const [review, setReview] = useState("");
  const [wrappingUp, setWrappingUp] = useState(false);
  const messagesEndRef = useRef(null);
  const channelRef = useRef(null);
  const textareaRef = useRef(null);
  const revealTimerRef = useRef(null);
  const lastTickRef = useRef(null);
  const carryRef = useRef(0);
  const streamBufferRef = useRef("");
  const assistantDoneRef = useRef(false);
  const pendingAssistantMessageRef = useRef(null);
  const streamingContentRef = useRef("");
  const startedRef = useRef(false);
  // Approx reading speed: 200 WPM ≈ 16.7 chars/sec
  const READING_WPM = 200;
  const CHARS_PER_SECOND = (READING_WPM * 5) / 60;

  const setStreamBufferSync = (val) => {
    streamBufferRef.current = val;
    setStreamBuffer(val);
  };

  useEffect(() => {
    assistantDoneRef.current = assistantDone;
  }, [assistantDone]);

  useEffect(() => {
    pendingAssistantMessageRef.current = pendingAssistantMessage;
  }, [pendingAssistantMessage]);

  useEffect(() => {
    streamingContentRef.current = streamingContent;
  }, [streamingContent]);

  useEffect(() => {
    // Initialize Action Cable
    const cable = createConsumer();
    const channel = cable.subscriptions.create(
      {
        channel: "ChatChannel",
        session_id: data.session_id,
      },
      {
        connected() {
          // Start conversation on connect if there are no messages yet
          const hasMessages = (data.messages || []).length > 0;
          if (!hasMessages && !startedRef.current) {
            startedRef.current = true;
            try { this.perform("start_conversation", {}); } catch (e) {}
          }
        },
        disconnected() {},
        received(data) {
          switch (data.type) {
            case "user_message":
              setMessages((prev) => [...prev, data.message]);
              break;

            case "assistant_start":
              // If there are no prior messages, don't type out the first message
              setSkipStreamingDisplay((messages?.length || 0) === 0);
              setIsStreaming(true);
              setStreamingContent("");
              setStreamBufferSync("");
              setAssistantDone(false);
              setPendingAssistantMessage(null);
              // Indicate review is queued
              setReview("Reviewing…");
              break;

            case "assistant_chunk":
              if (!skipStreamingDisplay) {
                setStreamBufferSync(
                  (streamBufferRef.current || "") + (data.content || ""),
                );
              }
              break;

            case "assistant_complete":
              if (skipStreamingDisplay) {
                // Instantly show the full first message without typing effect
                setIsStreaming(false);
                setMessages((prev) => [...prev, data.message]);
                setStreamingContent("");
                setStreamBufferSync("");
                setPendingAssistantMessage(null);
                setAssistantDone(false);
                setSkipStreamingDisplay(false);
              } else {
                // Mark done but allow paced reveal to finish before finalizing
                setAssistantDone(true);
                setPendingAssistantMessage(data.message);
              }
              break;

            case "error":
              setIsStreaming(false);
              setStreamingContent("");
              alert(data.message);
              break;

            case "review_update":
              setReview(data.content || "");
              break;

            case "review_start":
              setReview("");
              break;

            case "review_chunk":
              setReview((prev) => (prev || "") + (data.content || ""));
              break;

            case "review_complete":
              setReview(data.content || "");
              break;

            case "review_status":
              setWrappingUp(!!data.wrapping_up);
              break;
          }
        },
      },
    );

    channelRef.current = channel;

    // Fallback: also attempt immediately after subscription
    const hasMessages = (data.messages || []).length > 0;
    if (!hasMessages && !startedRef.current) {
      startedRef.current = true;
      try { channel.perform("start_conversation", {}); } catch (e) {}
    }

    return () => {
      channel.unsubscribe();
    };
  }, [data.session_id]);

  useEffect(() => {
    // Auto-scroll to bottom
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, streamingContent]);

  // Reveal timer to show assistant text at reading speed
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
            const take = Math.min(prevBuf.length, n);
            const head = prevBuf.slice(0, take);
            const tail = prevBuf.slice(take);
            if (head) setStreamingContent((prev) => prev + head);
            setStreamBufferSync(tail);
          }
        }

        // When complete message received and buffer drained, finalize
        if (assistantDoneRef.current) {
          if ((streamBufferRef.current || "").length === 0) {
            clearInterval(revealTimerRef.current);
            revealTimerRef.current = null;
            setIsStreaming(false);
            setMessages((prev) => [
              ...prev,
              pendingAssistantMessageRef.current || {
                id: `temp-${Date.now()}`,
                role: "assistant",
                content: streamingContentRef.current,
              },
            ]);
            setStreamingContent("");
            setPendingAssistantMessage(null);
            setAssistantDone(false);
          }
        }
      }, 50);
    };

    if (isStreaming && !skipStreamingDisplay && !revealTimerRef.current) {
      startTimer();
    }
    if ((!isStreaming || skipStreamingDisplay) && revealTimerRef.current) {
      clearInterval(revealTimerRef.current);
      revealTimerRef.current = null;
    }
    return () => {
      if (revealTimerRef.current) {
        clearInterval(revealTimerRef.current);
        revealTimerRef.current = null;
      }
    };
  }, [isStreaming, skipStreamingDisplay]);

  // Auto-resize textarea up to 4 lines, then allow scroll
  const autoResize = () => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    // Cap at ~4 lines (Tailwind leading-6 ~ 24px; max-h-32 is 128px). Use computed line-height for better accuracy.
    const styles = window.getComputedStyle(el);
    const lineHeight = parseFloat(styles.lineHeight) || 24;
    const paddingTop = parseFloat(styles.paddingTop) || 0;
    const paddingBottom = parseFloat(styles.paddingBottom) || 0;
    const borderTop = parseFloat(styles.borderTopWidth) || 0;
    const borderBottom = parseFloat(styles.borderBottomWidth) || 0;
    const maxHeight =
      lineHeight * 4 + paddingTop + paddingBottom + borderTop + borderBottom;
    const newHeight = Math.min(el.scrollHeight, maxHeight);
    el.style.height = `${newHeight}px`;
    el.style.overflowY = el.scrollHeight > maxHeight ? "auto" : "hidden";
  };

  useEffect(() => {
    autoResize();
  });

  // Ensure reveal timer is cleared on unmount
  useEffect(() => {
    return () => {
      if (revealTimerRef.current) {
        clearInterval(revealTimerRef.current);
        revealTimerRef.current = null;
      }
    };
  }, []);

  const sendMessage = () => {
    if (!input.trim() || isStreaming) return;
    if (channelRef.current) {
      channelRef.current.perform("send_message", { content: input });
      setInput("");
      // Shrink textarea after clearing
      requestAnimationFrame(() => autoResize());
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    sendMessage();
  };

  const handleKeyDown = (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className="fixed inset-0 flex flex-col bg-gray-50 overflow-hidden">
      {/* Header */}
      <div className="shrink-0 bg-white border-b border-gray-200 px-4 py-3 md:px-6 md:py-4">
        <div className="flex items-center justify-between">
          <h1 className="text-xl md:text-2xl font-semibold text-gray-900">Clary</h1>
          <a
            href="/role_plays"
            className={
              `px-3 py-1.5 md:px-4 md:py-2 text-sm font-medium rounded-lg transition-colors ` +
              (wrappingUp
                ? "bg-[#1a365d] text-white hover:bg-[#142849] focus:outline-none focus:ring-2 focus:ring-[#1a365d]"
                : "text-gray-700 bg-white border border-gray-300 hover:bg-gray-50")
            }
          >
            Exit
          </a>
        </div>
      </div>

      {/* Main Content with Sidebar */}
      <div className="flex-1 flex min-h-0 overflow-hidden">
        {/* Left: Chat column (2/3 on desktop, full width on mobile) */}
        <div className="flex flex-col flex-1 md:flex-none w-full md:w-2/3 md:border-r border-gray-200 min-h-0 overflow-hidden">
          {/* Messages Container */}
          <div className="flex-1 overflow-y-auto overflow-x-hidden px-4 py-4 md:px-6">
            <div className="max-w-3xl mx-auto space-y-4">
              {messages.length === 0 && !isStreaming && (
                <div className="text-center py-12 text-gray-500">
                  <p className="text-lg">
                    No messages yet. Start the conversation!
                  </p>
                </div>
              )}

              {messages.map((message) => (
                <div
                  key={message.id}
                  className={`flex ${message.role === "user" ? "justify-end" : "justify-start"}`}
                >
                  <div
                    className={`max-w-[85%] md:max-w-2xl rounded-2xl px-4 py-2 md:py-3 ${
                      message.role === "user"
                        ? "bg-[#1a365d] text-white"
                        : "bg-white text-gray-900 border border-gray-200"
                    }`}
                  >
                    <div className="whitespace-pre-wrap break-words text-[15px] md:text-base">{message.content}</div>
                  </div>
                </div>
              ))}

              {/* Streaming message */}
              {isStreaming && streamingContent && !skipStreamingDisplay && (
                <div className="flex justify-start">
                  <div className="max-w-[85%] md:max-w-2xl rounded-2xl px-4 py-2 md:py-3 bg-white text-gray-900 border border-gray-200">
                    <div className="whitespace-pre-wrap break-words text-[15px] md:text-base">
                      {streamingContent}
                    </div>
                    <div className="mt-2 flex items-center text-gray-400 text-xs">
                      <div className="animate-pulse">●</div>
                    </div>
                  </div>
                </div>
              )}

              <div ref={messagesEndRef} />
            </div>
          </div>

          {/* Input Form */}
          <div className="shrink-0 bg-white border-t border-gray-200 px-4 py-3 md:px-6 md:py-4">
            <div className="max-w-3xl mx-auto">
              <form onSubmit={handleSubmit} className="flex gap-2 md:gap-3">
                <textarea
                  ref={textareaRef}
                  rows={1}
                  value={input}
                  onChange={(e) => {
                    setInput(e.target.value);
                  }}
                  onInput={autoResize}
                  onKeyDown={handleKeyDown}
                  disabled={isStreaming}
                  placeholder="Type your message..."
                  className="flex-1 px-3 py-2 md:px-4 md:py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#1a365d] disabled:bg-gray-100 disabled:cursor-not-allowed resize-none overflow-y-auto max-h-32 leading-6 text-base"
                />
                <button
                  type="submit"
                  disabled={!input.trim() || isStreaming}
                  className="px-4 py-2 md:px-6 md:py-3 bg-[#1a365d] text-white rounded-lg font-medium hover:bg-[#142849] focus:outline-none focus:ring-2 focus:ring-[#1a365d] disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
                >
                  {isStreaming ? "..." : "Send"}
                </button>
              </form>
            </div>
          </div>
        </div>

        {/* Right: Sidebar (1/3, hidden on mobile) */}
        <aside className="hidden md:block w-1/3 bg-gray-100 px-6 py-4 overflow-y-auto text-gray-900 min-h-0">
          <div className="space-y-4">
            <h2 className="text-sm font-semibold text-gray-700 uppercase tracking-wide">
              Conversation Review
            </h2>
            <ReviewPanel review={review} />
          </div>
        </aside>
      </div>
    </div>
  );
}

function ReviewPanel({ review }) {
  if (!review) return null;

  const parsed = splitReview(review);
  if (!parsed) {
    return <Markdown text={review} />;
  }

  const { good, improve } = parsed;
  return (
    <div className="space-y-4">
      <div className="bg-white border border-gray-200 rounded-lg p-4">
        <h3 className="text-sm font-semibold text-gray-800 mb-2">What went well</h3>
        {good.length > 0 ? (
          <ul className="list-disc ml-5 space-y-1 text-gray-800">
            {good.map((b, i) => (
              <li key={`good-${i}`}>{b}</li>
            ))}
          </ul>
        ) : (
          <p className="text-gray-500 text-sm">No highlights yet.</p>
        )}
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-4">
        <h3 className="text-sm font-semibold text-gray-800 mb-2">What could be better</h3>
        {improve.length > 0 ? (
          <ul className="list-disc ml-5 space-y-1 text-gray-800">
            {improve.map((b, i) => (
              <li key={`imp-${i}`}>{b}</li>
            ))}
          </ul>
        ) : (
          <p className="text-gray-500 text-sm">No improvements noted.</p>
        )}
      </div>
    </div>
  );
}

function splitReview(text) {
  // Expecting sections:
  // What went well:\n- bullet\n- bullet\n\nWhat could be better:\n- bullet...
  const lines = (text || "").split(/\r?\n/);
  let section = null;
  const good = [];
  const improve = [];

  for (let raw of lines) {
    const line = raw.trim();
    if (!line) continue;
    if (/^\{\s*"wrapping_up"\s*:\s*(true|false)\s*\}$/i.test(line)) {
      // ignore trailing JSON control line
      continue;
    }
    if (/^what went well\s*:\s*$/i.test(line)) {
      section = "good";
      continue;
    }
    if (/^what could be better\s*:\s*$/i.test(line)) {
      section = "improve";
      continue;
    }
    if (/^[-*]\s+/.test(line)) {
      const bullet = line.replace(/^[-*]\s+/, "").trim();
      if (section === "good") good.push(bullet);
      else if (section === "improve") improve.push(bullet);
    }
  }

  if (good.length === 0 && improve.length === 0) return null;
  return { good, improve };
}
