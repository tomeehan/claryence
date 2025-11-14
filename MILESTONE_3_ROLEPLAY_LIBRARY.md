# Milestone 3: Role Play Library

## Overview

Define the library of role play scenarios with metadata about when each is useful. This creates the content foundation for the role play experience.

## Deliverables

### 1. RolePlay Model (Not Tenanted)

Stores role play scenarios/challenges.

**Fields:**
- `name` (string, required, unique) - e.g., "Delegation", "Giving Feedback", "Difficult Conversations"
- `description` (text, required) - detailed explanation of the scenario shown on home screen
- `llm_instructions` (text, required) - instructions provided to LLM during role play
- `duration_minutes` (integer, required) - length of role play (e.g., 10 minutes)
- `recommended_for` (text, required) - guidance on when this role play is useful
  - e.g., "Managers struggling with giving constructive criticism"
  - e.g., "Leaders who avoid delegating important tasks"
- `category` (enum, required) - grouping (e.g., "Communication", "Team Management", "Conflict Resolution")
- `active` (boolean, default: true) - whether to show this role play to users
- `created_at`, `updated_at` (timestamps) - position/ordering determined by created_at

**Validations:**
- Name must be present and unique
- All text fields must be present
- Duration must be a positive integer
- Category must be a valid enum value

**Authorization:**
- All fields use Pundit policies for admin-only editing

---

### 2. Seed Initial Role Play Library

**Location:** `db/seeds.rb`

**Scenarios (6-8 role plays):**

1. **Delegation**
2. **Giving Feedback** (constructive criticism)
3. **Difficult Conversations**
4. **Performance Reviews**
5. **Conflict Resolution**
6. **Setting Boundaries**
7. **Motivating Team Members**
8. **Managing Up**

**Requirements:**
- Each seed includes complete `llm_instructions`, `description`, and `recommended_for` text
- Duration defaults to 10 minutes for most scenarios

---

### 3. Admin Dashboard Integration (Madmin)

**Navigation:**
- Add RolePlay model to admin navigation

**List View:**
- Shows: name, category, active status, created_at
- Ordered by created_at (oldest first)

**Edit View:**
- All fields editable
- Use **Lexxy** (Basecamp markdown editor) for editing:
  - `llm_instructions` field
  - `description` field
  - `recommended_for` field

---

### 4. Audit Logging (PaperTrail Gem)

**Requirements:**
- Track all changes to RolePlay records
- Record who made changes and when
- Store versions of content for compliance
- Viewable from admin dashboard (version history per role play)

---

### 5. RolePlay Categories

**Implementation:**
- Categories defined as enum on RolePlay model
- Used for filtering on home screen (future enhancement)
- Displayed as badges/tags in admin

**Categories (Enum Values):**
- `communication` - Communication
- `team_management` - Team Management
- `conflict_resolution` - Conflict Resolution
- `performance_management` - Performance Management
- `leadership_development` - Leadership Development

---

### 6. Testing

**Test Coverage:**
- Model tests for validations
- Test seeds load successfully
- Test audit logging captures changes
- Test admin policy enforcement

---

## Implementation Notes

### Non-Tenanted Model
The RolePlay model is **not** account-scoped. All users across all accounts see the same library of role plays.

### Admin-Only Management
Only admin users can create, edit, or delete role plays. Regular users have read-only access.

### Markdown Editing
Three fields support rich markdown editing via Lexxy:
1. `description` - shown to users on home screen
2. `llm_instructions` - provided to LLM during role play
3. `recommended_for` - helps users choose appropriate scenarios

---

## Dependencies

**Gems to Install:**
- [ ] PaperTrail gem for audit logging
- [ ] Lexxy for markdown editing (https://github.com/basecamp/lexxy)

**Already Installed:**
- Madmin for admin dashboard
- Pundit for authorization

---

## Implementation Steps

1. Install PaperTrail gem
2. Install Lexxy gem and update Madmin configuration
3. Generate RolePlay model and migration
4. Set up Pundit policies (admin-only CRUD)
5. Create Madmin resource for RolePlay
6. Configure Lexxy for markdown fields in Madmin
7. Write seed data for initial 6-8 role plays
8. Add model tests (validations, policies)
9. Test seeds and audit logging
