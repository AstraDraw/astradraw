---
description: "Guidelines for managing chat context, when to suggest new chats, and cost-efficient development"
alwaysApply: true
---

# Context Management & Chat Efficiency

This rule helps manage chat context to avoid expensive, off-topic conversations and improve development efficiency.

## When to Suggest a New Chat

**Proactively suggest starting a new chat when:**

1. **Topic Shift**: The user asks about a completely different feature/bug than what we've been working on
2. **Context Overload**: The conversation has accumulated 15+ tool calls or 10+ file edits
3. **Scope Creep**: The original task is complete but user wants to add unrelated features
4. **Summarization Drift**: You notice the conversation summary is losing important details
5. **New Feature Request**: User describes a new feature that requires fresh planning

**How to suggest (ask first, don't generate yet):**

```
🔄 **Context Check**: I think this would be better handled in a new chat.

**Reason**: [Brief explanation - e.g., "This is a separate feature from what we've been working on" or "The current context is getting large and may cause drift"]

**Would you like me to prepare a prompt and file list for a new chat?**

If you prefer to continue here, just say so and we'll proceed.
```

**Only after user agrees**, generate:
- Complete prompt describing the task
- List of files to @mention
- Any relevant context from current chat
- Suggested approach

## Commands User Can Run Themselves

**Suggest the user run these commands** instead of running them yourself to save context/cost:

### Quick Checks (User Should Run)
```bash
# Type checking
cd frontend && yarn tsc --noEmit

# Formatting
cd frontend && yarn prettier --write <files>

# Backend build
cd backend && npm run build

# Docker (from deploy/ folder)
cd deploy && docker compose logs -f api

# Git status
git status
```

### When AI Should Run Commands
- When output is needed to diagnose an issue
- When the result affects the next coding decision
- Complex multi-step operations
- When user explicitly asks

**How to suggest:**

```
💡 **Quick Check**: You can verify this by running:
\`\`\`bash
cd frontend && yarn tsc --noEmit
\`\`\`
Let me know if there are any errors and I'll help fix them.
```

## Model Recommendations

**Suggest appropriate models for different tasks:**

| Task Type | Suggested Model | Reason |
|-----------|-----------------|--------|
| Complex architecture decisions | Claude Opus / GPT-4 | Needs deep reasoning |
| Bug fixes with clear scope | Claude Sonnet / GPT-4o | Good balance of speed/quality |
| Simple edits, formatting | Claude Haiku / GPT-4o-mini | Fast and cost-effective |
| Code review | Claude Sonnet | Good at spotting issues |
| Documentation | Any model | Lower complexity |

**When to mention:**

```
💡 **Tip**: For this simple fix, you could use a faster model like Sonnet or GPT-4o-mini to save costs.
```

## New Chat Prompt Template

When user agrees to a new chat, generate this format:

```markdown
## Task: [Clear title]

### Problem/Goal
[1-2 sentence description]

### Context
[Relevant background from current chat]

### Files to Review
- `@path/to/file1.ts` - [why relevant]
- `@path/to/file2.tsx` - [why relevant]

### Approach
[Suggested steps if known]

### Notes
[Any gotchas or decisions from current chat]
```

## Signs Context is Degrading

Watch for these indicators:
- Repeating information that was already discussed
- Forgetting file locations or patterns established earlier
- Making errors that contradict earlier correct work
- Asking about things already answered in the chat

When noticed:
```
⚠️ **Context Note**: I notice the conversation is getting long. If responses seem to miss earlier context, consider starting a fresh chat with the key details.
```

## User Preferences

Respect user's choice to:
- Continue in current chat despite suggestion
- Run commands themselves
- Use their preferred model
- Skip the new chat prompt generation

Never force a new chat - always ask first and accept "no" gracefully.

## Workspace Structure

**This project has multiple repositories:**

| Folder | Purpose | Indexed Here? |
|--------|---------|---------------|
| `astradraw/` | Main repo (Docker, docs, rules) | ✅ Yes |
| `frontend/` | React/Excalidraw app | ❌ No (but accessible) |
| `backend/` | NestJS API | ❌ No (but accessible) |
| `room-service/` | WebSocket server | ❌ No (but accessible) |

**How it works:**
- Submodule folders are in `.cursorindexingignore` (not `.cursorignore`)
- This means: **NOT indexed** but **still accessible**
- AI can read files via @ mentions or direct access
- Semantic search won't find them, but AI can still understand cross-repo logic

**When to use main workspace (astradraw/):**
- Understanding how all parts connect
- Docker/deployment changes
- Documentation updates
- Cross-repo debugging

**When to open submodule as separate workspace:**
- Heavy development in one repo
- Need semantic search within that codebase
- Making many changes to that repo

**Suggest separate workspace for intensive work:**
```
📂 **Workspace Tip**: For intensive frontend development, consider opening `frontend/` as a separate workspace. You'll get full semantic search and better code completion. For quick cross-repo checks, the main workspace works fine.
```

