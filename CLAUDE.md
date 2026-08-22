# valettrashmobile

**Tier: `client_confidential`**

> Client work. Never cross-quote between clients or into personal projects.

## Read first

`brain/` is the contract. Before touching any code:

1. `brain/project_context.md` — what this is, who it's for, why it exists
2. `brain/current_state.md` — what actually works right now
3. `brain/next_steps.md` — prioritized; start here for "what should I do"

Also available: `architecture.md`, `change_log.md`, `cheat_sheet.md`.

If the code and `current_state.md` disagree, say so — do not silently pick one.

### If the owner (Reggie) is asking "what's left?" or "catch me up"

Point him at the **START HERE** box at the top of `brain/next_steps.md`, and at
`HANDOFF_FOR_REGGIE.md` in the repo root for the friendly step-by-step version. Everything
outstanding is owner action — accounts, keys, and one SQL migration — not code.

### Selling the service — `brain/sales/`

Separate from the app. `brain/sales/offer.md` is the **source of truth for pricing and terms**
(what the property pays, what residents pay, contract structure) — read it before quoting any
number, and change it there first, then propagate to `sales-script.md` and `call-card.html`.
Also: `sales-script.md`, `pitch-practice.md` + `roleplay-project-instructions.txt` (ChatGPT-voice
practice partner), and `call-card.html` (the "Breezeway Board" tap-through card — **each person
publishes their own artifact copy**; see the START HERE box in `next_steps.md`).

## Write after

When you finish meaningful work, update `brain/current_state.md` and
`brain/change_log.md` in the same session. A stale brain lies with confidence.

## Conventions

- Harness: **Claude Code** on Adam's end. **The client actively uses Cursor on this project** —
  `.cursor/rules/`, `.cursor/mcp.json`, and `cursor-os/` are live shared tooling here. Keep them
  current (e.g. the Supabase `project_ref` in `.cursor/mcp.json`); **do not delete them.** This is a
  deliberate exception to the "Cursor is retired" rule in `~/Projects/CLAUDE.md`, which describes
  Adam's own harness, not the client's.
- Secrets live in `.env`, never in `brain/`. Treat `brain/` files as public.
- `lowercase-with-hyphens`, no spaces in new file names.

Root index: `~/Projects/CLAUDE.md`
