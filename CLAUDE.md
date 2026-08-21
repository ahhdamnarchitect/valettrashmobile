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
