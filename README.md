# fable-method

A **self-contained** Claude Code plugin that installs "The Fable Way" — a working discipline distilled (with evidence) from a forensic study of the Fable model — for capable models (target: **Opus 4.8**).

It makes a model **scope before building, ground before designing, spawn adversaries before trusting, verify at the layer of the claim before declaring done, and report calibrated** — the effortful moves a model tends to skip under momentum.

## Self-contained by design

**No runtime dependency on any other plugin or skill.** It uses only Claude Code's built-in tools (the Agent/Task tool to spawn subagents, Bash, Read/Grep/Write). Install *this folder* and it works — nothing else required. This mirrors how the source model actually worked: it embodied the discipline and spawned plain **general-purpose** subagents with its own prompts, rather than composing other people's skills.

## What's inside

- **`skills/fable-method`** — the method: 7 reflexes + standing habits + red-flag smells + the project-overlay protocol + an honest note on what a skill can and can't supply. Auto-triggers on task-shaped prompts.
- **Runner skills** (invoke by name, or they auto-trigger):
  - **`fable-scope`** — name the external check + known/assumed + load-bearing unknowns.
  - **`fable-review`** — spawn N blind general-purpose adversaries in parallel; dedup, verify, triage.
  - **`fable-verify`** — the evidence-before-claims gate (identify → run → read → verify-at-the-claim → claim).
  - **`fable-ship`** — calibrated done-claim + docs-as-done + overlay compaction.
- **`hooks/`** — a SessionStart hook that surfaces the current project's overlay pointer, and one *advisory* (non-blocking) hook that nudges toward PR-flow on a push to `main`. Both safe to remove.

## The per-project overlay — `.fable/project.md`

The plugin ships **100% general**. Each project you work in grows its own **`.fable/project.md`** — a small, **git-ignored** file that makes the general method concrete for *that* project: its acceptance oracle, pointers to its canonical docs, its conventions, and a running **Gotchas** log.

- **Git-ignored on purpose:** it never enters the project's repo — no per-project fork of this plugin, and no AI-method artifact committed into a production repo.
- **Tiered loading:** a SessionStart hook surfaces its one-line pointer ambiently; the skill reads the full file when the method triggers.
- **Self-evolving:** on first use in a project the skill *offers* to create it (by scanning `CLAUDE.md`/`README`/stack signals, then asking only the gaps); as it confirms durable facts and hits gotchas, it appends them and announces the change; `fable-ship` compacts it. See `skills/fable-method/references/project-template.md` for the shape.
- **Update-safe:** because it lives in the workspace (not the plugin) and is git-ignored, updating this plugin never touches it.

## Install

This is a Claude Code plugin distributed as a directory marketplace. After cloning the repo:

1. Run `/plugin`, add a local marketplace pointing at the clone directory, and enable `fable-method`. **Restart Claude Code** so the skills and hooks load.
2. Or, in `~/.claude/settings.json`, add a directory marketplace + enable the plugin, then restart:
```json
{
  "extraKnownMarketplaces": {
    "fable-method": { "source": { "source": "directory", "path": "<path-to-your-clone>" } }
  },
  "enabledPlugins": { "fable-method@fable-method": true }
}
```
*(If the `enabledPlugins` key form differs on your version, the `/plugin` menu is the source of truth.)*

## What it can't do

It installs *discipline*. It does **not** supply the environment's hard guarantees (protected-branch/PR-flow, a permission gate for irreversible actions, secrets management, review passes that actually run) — where the environment provides those, this method plus a capable model get you most of the way; where it doesn't, the model must self-enforce, which is weaker. See `skills/fable-method/references/transfer-tiers.md`. The distillation is n = 1 (one project, one model, over days) — treat it as validated for that setting and re-check before assuming it generalizes everywhere.
