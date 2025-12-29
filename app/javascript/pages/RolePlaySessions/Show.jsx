import React, { useState, useEffect, useRef } from "react";
import { useSelector } from "react-redux";
import { createConsumer } from "@rails/actioncable";

// Heroicon: Bolt (for Clary avatar)
function BoltIcon({ className }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className={className}>
      <path fillRule="evenodd" d="M14.615 1.595a.75.75 0 01.359.852L12.982 9.75h7.268a.75.75 0 01.548 1.262l-10.5 11.25a.75.75 0 01-1.272-.71l1.992-7.302H3.75a.75.75 0 01-.548-1.262l10.5-11.25a.75.75 0 01.913-.143z" clipRule="evenodd" />
    </svg>
  );
}

// Heroicon: User Circle (for Role Play avatar)
function UserCircleIcon({ className }) {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className={className}>
      <path fillRule="evenodd" d="M18.685 19.097A9.723 9.723 0 0021.75 12c0-5.385-4.365-9.75-9.75-9.75S2.25 6.615 2.25 12a9.723 9.723 0 003.065 7.097A9.716 9.716 0 0012 21.75a9.716 9.716 0 006.685-2.653zm-12.54-1.285A7.486 7.486 0 0112 15a7.486 7.486 0 015.855 2.812A8.224 8.224 0 0112 20.25a8.224 8.224 0 01-5.855-2.438zM15.75 9a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" clipRule="evenodd" />
    </svg>
  );
}

// Avatar component - renders appropriate icon based on phase
function Avatar({ phase, role }) {
  // Only show avatar for assistant messages
  if (role === "user") return null;

  const isClaryPhase = phase === "setup" || phase === "debrief";

  if (isClaryPhase) {
    return (
      <div className="flex-shrink-0 w-8 h-8 rounded-full bg-purple-600 flex items-center justify-center">
        <BoltIcon className="w-5 h-5 text-white" />
      </div>
    );
  }

  // Role play phase
  return (
    <div className="flex-shrink-0 w-8 h-8 rounded-full bg-gray-600 flex items-center justify-center">
      <UserCircleIcon className="w-5 h-5 text-white" />
    </div>
  );
}

// Transition button rendered as a system message in the chat
function TransitionButton({ type, onClick, disabled }) {
  if (type === "start_role_play") {
    return (
      <div className="flex justify-center my-4">
        <button
          onClick={onClick}
          disabled={disabled}
          className="px-5 py-2.5 bg-[#6b116e] text-white text-sm font-medium rounded-full hover:bg-[#571056] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#6b116e]/50 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
        >
          Start Role Play
        </button>
      </div>
    );
  }

  if (type === "end_role_play") {
    return (
      <div className="flex justify-center my-4">
        <button
          onClick={onClick}
          disabled={disabled}
          className="px-5 py-2.5 bg-[#1a365d] text-white text-sm font-medium rounded-full hover:bg-[#142849] focus:outline-none focus-visible:ring-2 focus-visible:ring-[#1a365d]/50 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
        >
          End Role Play
        </button>
      </div>
    );
  }

  return null;
}

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
          <p key={`p-${key++}`} className="">
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
            <ul key={`ul-${key++}`} className="space-y-1">
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
            <ol key={`ol-${key++}`} className="space-y-1">
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
  // Phase management
  const [phase, setPhase] = useState(data.phase || "setup");
  const messagesEndRef = useRef(null);
  const scrollContainerRef = useRef(null);
  const channelRef = useRef(null);
  const textareaRef = useRef(null);
  const revealTimerRef = useRef(null);
  const lastTickRef = useRef(null);
  const carryRef = useRef(0);
  const streamBufferRef = useRef("");
  const assistantDoneRef = useRef(false);
  const pendingAssistantMessageRef = useRef(null);
  const streamingContentRef = useRef("");
  const autoScrollRef = useRef(true);
  const [showJumpLatest, setShowJumpLatest] = useState(false);
  const LOCK_DISTANCE = 4; // px from bottom to (re)lock
  const BREAK_DISTANCE = 80; // px away from bottom to unlock
  const programmaticScrollRef = useRef(false);
  const userScrollUpRef = useRef(false);
  const touchStartYRef = useRef(null);
  // Fixed reveal speed
  const CHARS_PER_SECOND = 50;

  const setStreamBufferSync = (val) => {
    streamBufferRef.current = val;
    setStreamBuffer(val);
  };

  // Sync messages from server data on initial load
  useEffect(() => {
    if (data.messages && data.messages.length > 0 && messages.length === 0) {
      setMessages(data.messages);
    }
  }, [data.messages]);

  // Sync phase from server data on initial load
  useEffect(() => {
    if (data.phase && data.phase !== phase) {
      setPhase(data.phase);
    }
  }, [data.phase]);

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
          // Setup phase intro is generated synchronously by the controller
          // No need to start conversation here
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
              // Lock to bottom like WhatsApp when a new response starts typing
              autoScrollRef.current = true;
              requestAnimationFrame(() => forceScrollToBottom());
              break;

            case "assistant_chunk":
              if (!skipStreamingDisplay) {
                setStreamBufferSync(
                  (streamBufferRef.current || "") + (data.content || ""),
                );
              }
              break;

            case "assistant_complete":
              // Check if we're actively streaming (use ref to avoid stale closure)
              const activelyStreaming = streamBufferRef.current.length > 0 || streamingContentRef.current.length > 0;
              if (skipStreamingDisplay || !activelyStreaming) {
                // Instantly show message if not streaming (e.g., phase transition intros)
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
              // Check for wrapping_up flag from role play LLM
              if (data.wrapping_up !== undefined && data.wrapping_up !== null) {
                setWrappingUp(data.wrapping_up);
              }
              break;

            case "phase_changed":
              setPhase(data.phase);
              setWrappingUp(false);
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

    return () => {
      channel.unsubscribe();
    };
  }, [data.session_id]);

  const forceScrollToBottom = () => {
    const el = scrollContainerRef.current;
    if (!el) return;
    programmaticScrollRef.current = true;
    el.scrollTop = el.scrollHeight;
    requestAnimationFrame(() => { programmaticScrollRef.current = false; });
    autoScrollRef.current = true;
    setShowJumpLatest(false);
  };

  useEffect(() => {
    // Auto-scroll only if user is at bottom (auto-scroll enabled)
    if (autoScrollRef.current) {
      forceScrollToBottom();
    } else {
      // New content arrived while user scrolled up
      setShowJumpLatest(true);
    }
  }, [messages, streamingContent]);

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
    // reset user intent flag after handling
    userScrollUpRef.current = false;
  };

  const scrollToBottom = () => {
    const el = scrollContainerRef.current;
    if (!el) return;
    programmaticScrollRef.current = true;
    el.scrollTop = el.scrollHeight;
    requestAnimationFrame(() => { programmaticScrollRef.current = false; });
    autoScrollRef.current = true;
    setShowJumpLatest(false);
  };

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
      // Re-lock to bottom on send (WhatsApp behavior)
      autoScrollRef.current = true;
      requestAnimationFrame(() => scrollToBottom());
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

  // Phase transition handlers
  const handleStartRolePlay = () => {
    if (channelRef.current) {
      channelRef.current.perform("transition_phase", { phase: "role_play" });
    }
  };

  const handleEndRolePlay = () => {
    if (channelRef.current) {
      channelRef.current.perform("transition_phase", { phase: "debrief" });
    }
  };

  // Determine styling based on current phase
  const isClaryPhase = phase === "setup" || phase === "debrief";
  const bgColor = isClaryPhase ? "bg-purple-50" : "bg-gray-50";
  const headerTitle = phase === "role_play" ? (data.role_play_name || "Role Play") : "Clary";
  const userBubbleColor = (msgPhase) => {
    return msgPhase === "role_play" ? "bg-[#1a365d]" : "bg-[#6b116e]";
  };
  const buttonColor = isClaryPhase
    ? "bg-[#6b116e] hover:bg-[#571056] focus-visible:ring-[#6b116e]/50"
    : "bg-[#1a365d] hover:bg-[#142849] focus-visible:ring-[#1a365d]/50";
  const inputRingColor = isClaryPhase ? "focus:ring-[#6b116e]" : "focus:ring-[#1a365d]";

  return (
    <div className={`fixed inset-0 flex flex-col ${bgColor} overflow-hidden transition-colors duration-300`}>
      {/* Header */}
      <div className="shrink-0 bg-white border-b border-gray-200 px-4 py-3 md:px-6 md:py-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Avatar phase={phase} role="assistant" />
            <h1 className="text-xl md:text-2xl font-semibold text-gray-900">{headerTitle}</h1>
          </div>
          <a
            href="/"
            className="px-3 py-1.5 md:px-4 md:py-2 text-sm font-medium rounded-lg sm:rounded-full transition-colors focus:outline-none focus-visible:ring-2 text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 focus-visible:ring-gray-300/60"
          >
            Exit
          </a>
        </div>
      </div>

      {/* Main Content with Sidebar */}
      <div className="flex-1 flex min-h-0">
        {/* Left: Chat column. 2/3 when admin sidebar visible, full width otherwise */}
        <div
          className={
            `flex flex-col flex-1 md:flex-none w-full ` +
            (data.is_admin ? `md:w-2/3 md:border-r` : `md:w-full`) +
            ` border-gray-200 min-h-0`
          }
        >
          {/* Messages Container */}
          <div
            ref={scrollContainerRef}
            onScroll={handleScroll}
            onWheel={(e) => { if (e.deltaY < 0) userScrollUpRef.current = true; }}
            onTouchStart={(e) => { touchStartYRef.current = e.touches?.[0]?.clientY ?? null; }}
            onTouchMove={(e) => {
              const y = e.touches?.[0]?.clientY;
              if (touchStartYRef.current != null && y != null) {
                // If finger moves down (increasing Y), content tends to scroll up
                if (y - touchStartYRef.current > 4) userScrollUpRef.current = true;
              }
            }}
            className="flex-1 overflow-y-auto overflow-x-hidden px-4 py-4 md:px-6"
          >
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
                  className={`flex ${message.role === "user" ? "justify-end" : "justify-start"} items-start gap-2`}
                >
                  {/* Avatar for assistant messages */}
                  {message.role === "assistant" && (
                    <Avatar phase={message.phase || "setup"} role={message.role} />
                  )}
                  <div
                    className={`max-w-[85%] md:max-w-2xl rounded-2xl px-4 py-2 md:py-3 ${
                      message.role === "user"
                        ? `${userBubbleColor(message.phase || phase)} text-white`
                        : "bg-white text-gray-900 border border-gray-200"
                    }`}
                  >
                    <div className="text-[15px] md:text-base leading-6"><Markdown text={message.content} /></div>
                  </div>
                </div>
              ))}

              {/* Show Start Role Play button when in setup phase */}
              {phase === "setup" && !isStreaming && messages.length > 0 && (
                <TransitionButton type="start_role_play" onClick={handleStartRolePlay} />
              )}

              {/* Show End Role Play button when wrapping_up is true */}
              {phase === "role_play" && wrappingUp && !isStreaming && (
                <TransitionButton type="end_role_play" onClick={handleEndRolePlay} />
              )}

              {/* Streaming message */}
              {isStreaming && streamingContent && !skipStreamingDisplay && (
                <div className="flex justify-start items-start gap-2">
                  <Avatar phase={phase} role="assistant" />
                  <div className="max-w-[85%] md:max-w-2xl rounded-2xl px-4 py-2 md:py-3 bg-white text-gray-900 border border-gray-200">
                    <div className="whitespace-pre-wrap break-words text-[15px] md:text-base leading-6">
                      {streamingContent}<span className="inline-block ml-1 text-gray-400 animate-pulse">●</span>
                    </div>
                  </div>
                </div>
              )}

              {showJumpLatest && (
                <div className="sticky bottom-2 flex justify-center pointer-events-none">
                  <button
                    type="button"
                    onClick={scrollToBottom}
                    className="pointer-events-auto px-3 py-1.5 text-sm rounded-full bg-gray-800 text-white shadow hover:bg-gray-700"
                  >
                    Jump to latest
                  </button>
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
                  className={`flex-1 px-3 py-2 md:px-4 md:py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 ${inputRingColor} disabled:bg-gray-100 disabled:cursor-not-allowed resize-none overflow-y-auto max-h-32 leading-6 text-base`}
                />
                <button
                  type="submit"
                  disabled={!input.trim() || isStreaming}
                  className={`px-5 py-2.5 md:px-6 md:py-3 ${buttonColor} text-white rounded-lg sm:rounded-full font-medium focus:outline-none focus-visible:ring-2 disabled:bg-gray-300 disabled:text-white/70 disabled:cursor-not-allowed transition-colors`}
                >
                  {isStreaming ? "..." : "Send"}
                </button>
              </form>
            </div>
          </div>
        </div>

        {/* Right: Sidebar only for admins */}
        {data.is_admin && (
          <aside className="hidden md:block w-1/3 bg-gray-100 px-6 py-4 overflow-y-auto text-gray-900 min-h-0">
            <div className="space-y-4">
              <h2 className="text-sm font-semibold text-gray-700 uppercase tracking-wide">
                Conversation Review
              </h2>
              <ReviewPanel review={review} />
            </div>
          </aside>
        )}
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
