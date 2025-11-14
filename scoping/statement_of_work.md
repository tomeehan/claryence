# Statement of Work MVP

This project is broken down into milestones. Each milestone has a name and a target date. Each milestone will have a set of deliverables.

## Project Summary

| Milestone | Cost | Target Date |
|-----------|------|-------------|
| 1. Setup | £475 | November 12, 2025 |
| 2. Company Dashboard | £713 | November 12, 2025 |
| 3. Role Play Library | £475 | November 14, 2025 |
| 4. Chat Infrastructure | £2,375 | November 21, 2025 |
| 5. Role Play Experience | £2,375 | November 28, 2025 |
| **Total** (excluding VAT) | **£6,413** | |

---

## Milestone 1: Setup

**Target Date:** November 13, 2025

**Cost:** £475

**TL;DR:** Setting up the foundation using Jumpstart Pro.

We'll start with a new Rails application based on Jumpstart Pro. The goal is a clean, production-ready foundation with a focus on reliability, security, and speed of development (Jumpstart Pro allows cuts out lots of work related to users and account management).

**Deliverables:**
- configure the Jumpstart Pro license;
- set up staging environment (demo.claryence.com):
  - provision server;
  - configure PostgreSQL database with continuous protection and backups;
  - deploy Redis for caching and background jobs;
  - configure storage;
- set up production environment (app.claryence.com):
  - provision server;
  - configure PostgreSQL database with continuous protection and backups;
  - deploy Redis for caching and background jobs;
  - configure storage;
- configure domain/DNS using Cloudflare and SSL certificates;
- configure secrets management using Rails credentials;
- configure CI/CD using GitHub Actions:
  - automated tests using RSpec, Capybara, and Playwright:
    - unit tests with minimum 60% code coverage;
    - integration tests to smoke test full user journeys:
      - company creation → manager invitation → challenge selection → role play → feedback;
      - role play completion → feedback review → try again;
    - use SimpleCov for coverage reporting;
    - fail CI build if coverage drops below 60%;
  - linting;
  - security checks;
  - dependency updates;
  - automatic database migrations;
- implement error monitoring and logging:
  - implement logging with secrets removed;
  - integrate Sentry for error monitoring;
- configure background job processing:
  - use Sidekiq for background jobs;
  - async jobs:
    - email sending (invitation emails, notifications);
    - role play feedback generation via LLM review;
    - OpenAI API calls (queued during rate limiting);
  - implement job monitoring and retries:
    - automatic retry with exponential backoff for failed jobs;
    - dead letter queue for permanently failed jobs;
    - admin dashboard view for job status;
    - alert admins for critical job failures;
- integrate Postmark for transactional email using SMTP server:
  - emails sent asynchronously via background jobs;
  - use existing Postmark email templates;
- implement notification system using Noticed gem:
  - configure Noticed for email delivery channel;
  - set up for future iOS and Android push notification support;
  - notification types:
    - invitation received;
    - role play feedback ready;
  - notifications stored in database;
  - email delivery via Noticed + Postmark integration;
- set up authentication using Devise with email and password;
- implement privacy policy and terms acceptance:
  - create privacy policy and terms of service pages;
  - require acceptance during registration and invitation acceptance;
  - track acceptance with timestamp and version;
  - store accepted_terms_at and accepted_privacy_at on users;
  - require re-acceptance if terms/privacy policy updated;
- implement user profile and settings management:
  - user can view and edit their profile;
  - password change functionality;
  - email update with confirmation;
  - account settings (notifications preferences, timezone);
  - profile page accessible from navigation;
- implement error pages and maintenance mode:
  - create custom 404 (not found) error page;
  - create custom 500 (server error) error page;
  - create custom 503 (service unavailable) error page;
  - create maintenance mode page;
  - all error pages styled consistently with brand;
- hide or disable unused Jumpstart features (billing, teams, API, etc.). These can be re-enabled later as needed.
- configure domain and DNS (Cloudflare):
  - configure domain and subdomains (e.g. app.claryence.com, staging.claryence.com);
  - point DNS to hosting;
  - use Cloudflare proxy for SSL termination and caching;
  - enforce HTTPS;
  - configure redirects (e.g. www → root);
  - add SPF/DKIM/DMARC records;
  - manage SSL certificates via Cloudflare Universal SSL.
- configure assets and storage (AWS S3 + Heroku):
  - set up S3 buckets for staging and production;
  - configure Active Storage credentials;
  - enable server-side encryption and private ACLs;
  - cap file sizes and egress;
  - validate file types, sizes, and image dimensions;
  - direct uploads from browser to S3;
  - use libvips for efficient image processing.
- configure admin dashboard (using Madmin):
  - user management (view users, account relationships, roles);
  - company/account management;
  - RolePlay management (challenge definitions);
  - RolePlaySession monitoring (metadata, status, no chat content);
  - RolePlayFeedback review (scores and feedback text);
  - background job monitoring;
  - system health dashboard;
  - analytics and reporting (user counts, active sessions, API usage).

## Milestone 2: Company Dashboard

**Target Date:** November 13, 2025

**Cost:** £713

**TL;DR:** SMEs can create a company account and invite a manager to join via shareable link. The dashboard uses role-based access control and is tenant-aware. Each company operates in its own isolated environment (aligns with ISO 27001 and SOC 2).

**Deliverables:**
- implement company account creation for SMEs;
- add companies to admin dashboard;
- build invitation system:
  - generate shareable invite link with secure token;
  - invitation links expire after 7 days;
  - expired invitations remain in system but cannot be used to accept invite;
  - display invite link and expiry status in dashboard;
  - allow invite revocation;
  - set user permissions via invite;
- implement role-based access control using Pundit:
  - every record goes through a policy;
  - force every query to use Policy::Scope;
  - tenant all controllers;
  - enforce row-level tenancy on every record (via account_id);
- implement cascading deletes:
  - when a manager is deleted, delete their records;
  - when an account is deleted, delete all associated records.

## Milestone 3: Role Play Library

**Target Date:** November 14, 2025

**Cost:** £475

**TL;DR:** Define the library of role play scenarios with metadata about when each is useful. This creates the content foundation for the role play experience.

**Deliverables:**
- implement RolePlay model (not tenanted):
  - stores role play scenarios/challenges;
  - fields:
    - name (e.g., "Delegation", "Giving Feedback", "Difficult Conversations");
    - description (text) - detailed explanation of the scenario shown on home screen;
    - llm_instructions (text) - instructions provided to LLM during role play;
    - duration_minutes (integer) - length of role play (e.g., 10 minutes);
    - recommended_for (text) - guidance on when this role play is useful (e.g., "Managers struggling with giving constructive criticism", "Leaders who avoid delegating important tasks");
    - category (string) - grouping (e.g., "Communication", "Team Management", "Conflict Resolution");
    - position (integer) - display order on home screen;
    - active (boolean) - whether to show this role play to users;
  - all fields use Pundit policies for admin-only editing;
- seed initial role play library in db/seeds.rb:
  - define 6-8 role play scenarios covering common management challenges:
    - Delegation
    - Giving Feedback (constructive criticism)
    - Difficult Conversations
    - Performance Reviews
    - Conflict Resolution
    - Setting Boundaries
    - Motivating Team Members
    - Managing Up
  - each seed includes complete llm_instructions, description, and recommended_for text;
  - duration defaults to 10 minutes for most scenarios;
- integrate with admin dashboard (using Madmin):
  - add RolePlay model to admin navigation;
  - list view shows name, category, active status, position;
  - edit view for all fields;
  - use Lexxy (Basecamp markdown editor) for editing:
    - llm_instructions field;
    - description field;
    - recommended_for field;
- implement audit logging using PaperTrail gem:
  - track all changes to RolePlay records;
  - record who made changes and when;
  - store versions of content for compliance;
  - viewable from admin dashboard (version history per role play);
- implement RolePlay categories:
  - categories defined in YAML config or enum on model;
  - used for filtering on home screen (future enhancement);
  - displayed as badges/tags in admin;
- implement testing:
  - RSpec model tests for validations;
  - test seeds load successfully;
  - test audit logging captures changes;
  - test admin policy enforcement.

## Milestone 4: Chat Infrastructure

**Target Date:** November 28, 2025

**Cost:** £2,375

**TL;DR:** Build the technical foundation for real-time LLM conversations: OpenAI integration with streaming responses, chat data models, and React-based chat UI.

**Deliverables:**
- implement OpenAI integration:
  - use GPT-4-turbo model;
  - streaming responses via server-sent events;
  - manage API keys via Rails credentials;
  - implement error handling and retry logic:
    - retry failed requests with exponential backoff;
    - handle API timeouts gracefully;
    - log errors to Sentry (with API keys redacted);
    - display user-friendly error messages in UI;
  - implement rate limiting strategy:
    - track API usage per account;
    - implement request throttling to stay within OpenAI limits;
    - queue requests via Sidekiq if rate limit approached;
    - notify admins via email if limits consistently hit;
- implement system prompt configuration:
  - create global system prompt in YAML config file (config/prompts.yml);
  - defines base AI personality and coaching style;
  - role-play-specific prompts appended when role play starts;
  - system prompt combines: global prompt + role play instructions;
- implement chat data models:
  - RolePlaySession model:
    - belongs_to :account (tenanted);
    - belongs_to :account_user (the manager);
    - belongs_to :role_play;
    - has_many :chat_messages;
    - fields: started_at, completed_at, duration_seconds, status (active, completed, abandoned), system_prompt (text - cached for consistency), session_number (integer - tracks attempt number for this role play);
  - ChatMessage model:
    - belongs_to :role_play_session;
    - belongs_to :account (tenanted);
    - fields: role (user/assistant), content (text), created_at, token_count (integer);
    - user input and AI responses stored as separate message records;
  - all models have account_id for row-level tenancy;
  - all queries use Pundit Policy::Scope;
  - add to admin dashboard (metadata only, no message content);
- implement chat UI and real-time streaming:
  - build chat interface with React and Inertia.js;
  - full-page chat layout (not embedded);
  - use Action Cable (WebSockets) for streaming OpenAI responses;
  - user flow:
    - user types message and submits via form;
    - backend creates ChatMessage record and initiates OpenAI streaming;
    - OpenAI tokens stream back via Action Cable to React component;
    - React component updates UI in real-time as tokens arrive;
    - when stream completes, save assistant's full response as ChatMessage;
  - display message history with clear user/assistant distinction;
  - auto-scroll to latest message;
  - loading indicator while AI is responding;
  - handle reconnection if WebSocket drops;
- implement chat testing:
  - RSpec tests for OpenAI integration (with VCR for API mocking);
  - test streaming message delivery via Action Cable;
  - test error handling (API failures, timeouts, rate limits);
  - system tests for chat UI (message sending, real-time updates).

## Milestone 5: Role Play Experience

**Target Date:** December 1, 2025

**Cost:** £2,375

**TL;DR:** Complete role play experience: home screen with challenge selection, timed role play conversations with visual indicators, LLM-generated feedback in interstitial, and ability to retry or pick another challenge.

**Deliverables:**
- implement RolePlayFeedback model:
  - belongs_to :role_play_session;
  - belongs_to :account (tenanted);
  - fields:
    - feedback_text (text) - LLM-generated feedback on performance;
    - score (integer 1-10) - overall performance rating;
    - strengths (jsonb array) - what user did well;
    - improvements (jsonb array) - areas to work on;
    - assessed_at (timestamp);
  - created by background job after role play completes;
- implement home screen (challenge selection):
  - route: root_path (after login) or challenges_path;
  - display all available RolePlays as tiles/cards;
  - each tile shows:
    - role play name and description;
    - user's progress: number of attempts, best score, latest feedback summary;
    - "Start" button (or "Try Again" if attempted before);
  - responsive grid layout;
  - filter by category if needed;
  - built with Rails views (not React) - simpler for static content;
  - policy: only show role plays for user's account;
- implement role play session flow:
  - clicking "Start" creates RolePlaySession and redirects to chat UI;
  - session_number auto-increments (1st attempt, 2nd attempt, etc.);
  - chat UI changes color scheme to indicate role play mode:
    - different background color (e.g., blue instead of white);
    - visual badge/banner: "Role Play: [name]";
  - display countdown timer:
    - prominent position (top of screen or sticky header);
    - shows remaining time (e.g., "8:32 remaining");
    - turns orange at 2 minutes remaining;
    - turns red at 1 minute remaining;
    - plays warning sound at 1 minute (optional);
  - system prompt for LLM:
    - global prompt from config/prompts.yml;
    - RolePlay.llm_instructions;
    - time limit and current time context;
  - conversation continues until:
    - timer reaches zero (graceful ending - LLM completes current message);
    - user clicks "End Early" button;
  - when time expires or user ends:
    - mark RolePlaySession status as 'completed' (or 'abandoned' if ended early);
    - record duration_seconds;
    - redirect to loading screen while feedback generates;
- implement LLM review and feedback generation:
  - trigger async Sidekiq job when role play ends;
  - job loads all ChatMessages for the RolePlaySession;
  - separate OpenAI API call reviews the transcript:
    - use structured prompt to analyze performance;
    - evaluate: communication style, handling of situation, key skills demonstrated;
    - generate: overall score (1-10), strengths (3-5 points), improvements (3-5 points);
  - create RolePlayFeedback record with results;
  - job completion triggers redirect to feedback interstitial;
- implement feedback interstitial:
  - full-page display after role play completes;
  - show:
    - role play name;
    - attempt number (e.g., "Attempt #2");
    - overall score with visual indicator (progress bar, stars, etc.);
    - strengths section (bulleted list);
    - areas for improvement section (bulleted list);
    - detailed feedback text;
  - two prominent buttons:
    - "Try Again" - creates new RolePlaySession for same RolePlay and restarts;
    - "Choose Another Challenge" - returns to home screen;
  - built with React/Inertia for smooth transitions;
  - policy: user can only view their own feedback;
- implement progress tracking:
  - on home screen, show for each RolePlay:
    - total attempts (count of RolePlaySessions);
    - best score (max score from RolePlayFeedback records);
    - latest feedback summary (excerpt from most recent feedback);
    - trend indicator (score improving, stable, or declining);
  - add progress view to admin dashboard:
    - see all users' attempts and scores;
    - identify users struggling with specific challenges;
  - analytics for future:
    - average attempts before improvement;
    - most/least attempted challenges;
- implement edge case handling:
  - if user disconnects during role play:
    - RolePlaySession persists with messages;
    - user can resume if within time limit;
    - if time expired, mark as abandoned and allow restart;
  - if feedback generation fails:
    - retry job with exponential backoff;
    - after 3 failures, log error and show generic feedback;
    - notify admins of persistent failures;
  - if user navigates away from feedback interstitial:
    - feedback remains accessible from home screen (view past attempts);
- implement testing:
  - RSpec tests for role play session lifecycle;
  - test feedback generation with mocked LLM responses;
  - test timer expiry and early exit;
  - system tests for complete flow: select challenge → chat → feedback → try again.
