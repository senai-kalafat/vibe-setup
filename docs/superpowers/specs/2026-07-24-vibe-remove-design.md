# vibe-setup: change record + `remove` command — design

Date: 2026-07-24
Status: approved

## Problem

`.vibe-setup.json` today is a flat "current state" snapshot: for every path in
`managed_paths()` that exists on disk, it records `{v, sha}` — regardless of whether
vibe-setup created that file or found it already there and `SKIP`ped it. There is no way
to tell, from the manifest alone, "did vibe-setup put this here." Cursor/Gemini extra
files (`.cursor/rules/project.mdc`, `.cursorrules`, `GEMINI.md`) aren't recorded anywhere
at all — a deliberate choice when `init-cursor`/`init-gemini` were built (no
version/drift tracking wanted for them), but it also means there's zero provenance for
them today.

This makes safe removal impossible: any "undo vibe-setup" command built on top of the
current manifest risks deleting a file the user already had before ever running
vibe-setup (the tool's own core promise — "asla ezmez" — would be violated on the way
out, not just on the way in).

## Decisions (from brainstorming)

1. **Scope:** `remove` only reverses the deterministic layer (scaffold.sh-written files +
   the one `.gitignore` line + the manifest itself). LLM-authored content (CLAUDE.md,
   `docs/`, tests, `.claude/settings.json`'s filled-in `allow`/`deny` content) is never
   auto-deleted — it's listed in the report as needing manual review, because it's
   authored content intermixed with real project information, not a clean
   template-in/template-out artifact.
2. **Hand-edited files are never auto-deleted.** If a file vibe-setup created has since
   been modified (its sha no longer matches what vibe-setup last wrote), `remove --apply`
   leaves it untouched and lists it in the persistent report with the reason. This mirrors
   `upgrade()`'s existing UPDATE-vs-CONFLICT distinction, applied to deletion instead of
   overwriting.
3. **Extras get provenance too.** `init-cursor`/`init-gemini` now record what they wrote
   in the manifest (`created` + `sha`, no `v` — they still don't participate in
   version/drift tracking, that decision is unchanged). This is required for `remove` to
   safely handle them at all.
4. **Dry-run by default.** `scaffold.sh remove [DIR]` only prints a plan. Nothing is
   deleted until `scaffold.sh remove [DIR] --apply`. Destructive-and-hard-to-reverse
   action gets an extra confirmation gate beyond what `audit`/`upgrade` need.
5. **Command name:** `remove` (matches the existing single-word subcommand convention:
   `audit|init|init-cursor|init-gemini|upgrade|profile`). The user-facing/skill-level name
   can be "vibe-remove" in prose; the actual subcommand is `scaffold.sh remove`.
6. **Persistent report, `--apply` only.** `scaffold.sh remove --apply` writes
   `vibe-remove-report.md` to the repo root (same drop-at-root convention as
   `vibe-checklist.md`). Dry-run only prints to stdout (cheap to re-run, no need to
   persist a plan that might go stale before the user acts on it). The report is written
   because after deletion the "what got kept and why" state can't be reconstructed by
   re-running anything — it's a one-time receipt.

## Manifest schema changes

Current `managed` entry:
```json
"AGENTS.md": { "v": 4, "sha": "1234567890" }
```

New `managed` entry (adds `created`):
```json
"AGENTS.md": { "v": 4, "sha": "1234567890", "created": true }
```

`created` semantics:
- `true` — vibe-setup wrote this file (it did not exist before, `write_managed`/`write_extra`
  printed `NEW`).
- `false` — the file already existed when vibe-setup first touched this path (`SKIP`).
  `remove` must never delete a `created: false` path, regardless of anything else.
- **Once set, `created` never flips.** A later `init`/`upgrade` run that finds the path
  already tracked in the manifest preserves whatever `created` value is already there —
  the same "don't re-bless" principle `CONFLICT_PATHS`/`sha_for_manifest` already use for
  `sha`. Only the very first time a path is written to the manifest does its live
  NEW/SKIP result get recorded.

New top-level `extras` section (parallel structure, no `v` field):
```json
"extras": {
  ".cursor/rules/project.mdc": { "sha": "2222222222", "created": true },
  ".cursorrules":              { "sha": "3333333333", "created": true },
  "GEMINI.md":                 { "sha": "4444444444", "created": false }
}
```
Populated from a new fixed list `extra_paths()` (analogous to `managed_paths()`):
`.cursor/rules/project.mdc .cursorrules GEMINI.md`. Only paths that currently exist on
disk get an entry (same "only if present" rule `write_manifest` already applies to
`managed`).

New optional top-level field, only present if vibe-setup actually appended the line:
```json
"gitignoreLine": ".claude/settings.local.json"
```
Recorded only in the branch where `init()` performs the append (i.e. the line was not
already present). If the line pre-existed, nothing is recorded (nothing was done).

**Architectural change to `write_manifest`:** it becomes callable from `init()`,
`upgrade()`, `init_cursor()`, and `init_gemini()` alike — not just `init()`/`upgrade()`.
Every call regenerates both the `managed` and `extras` sections from whatever's on disk
`right now`, using the preserve-if-already-recorded rule for `created` (and the existing
preserve-if-CONFLICT rule for `sha` on `managed` only — `extras` have no CONFLICT concept
since they're not drift-tracked). This means the manifest is always a complete,
current, self-healing record no matter which subcommand last touched it — calling
`init-cursor` on a repo that was never `init`-ed still produces a valid (if
mostly-empty-`managed`) manifest.

**Provenance capture during a single run:** a new global array (bash-3-compatible, no
associative arrays — matches the existing `CONFLICT_PATHS` style) collects every path
that was `NEW` (not `SKIP`) during *this* invocation, for both `write_managed` and
`write_extra` to append to. `write_manifest`'s per-path `created` value is: preserved
value if the manifest already had one for that path, else `true` if the path is in this
run's NEW list, else `false`.

## `remove` command

```
scaffold.sh remove [DIR]           → dry-run: prints the plan, deletes nothing
scaffold.sh remove [DIR] --apply   → deletes, writes vibe-remove-report.md, deletes .vibe-setup.json last
```

**No manifest → nothing to do.** Same message pattern as `upgrade()`'s "Repo init
edilmemiş" case: "Manifest yok — vibe-setup bu repoda kurulu değil (ya da zaten
kaldırılmış)." Exit cleanly, no error.

**Classification (both modes compute this; only `--apply` acts on it):**
For every path in `managed` ∪ `extras` sections of the manifest that exists on disk:
- `created=false` → **never touched.** Not deleted, not itemized in the report (a single
  summary count is enough — the file was never ours to begin with, itemizing every
  pre-existing path would bury the signal).
- `created=true` and current on-disk sha == manifest sha → **REMOVE** (safe: untouched
  since vibe-setup wrote it).
- `created=true` and current on-disk sha != manifest sha → **KEEP-EDITED** (hand-modified
  since creation; itemized in the report with the reason, never auto-deleted).

Additionally:
- If `gitignoreLine` is set in the manifest and that exact line is still present in
  `.gitignore`, it's a REMOVE-eligible line-level edit (not a whole-file delete): `--apply`
  removes just that one line, leaving the rest of `.gitignore` untouched. If the line's
  already gone (someone removed it separately), nothing to do, no report entry needed.
- After deleting files, `--apply` removes any directory among the deleted paths' parents
  that is now empty (plain `rmdir`, which no-ops harmlessly if the directory still has
  content — e.g. `.githooks/` after both hooks are gone, `docs/architecture/decisions/`
  if the ADR template was the only file in it). This is a targeted cleanup of directories
  vibe-setup's own files lived in, not a general "prune empty dirs" sweep of the repo.
- `.vibe-setup.json` itself is always deleted last in `--apply` (it's 100% vibe-setup's
  own artifact — no `created` ambiguity, no scenario where the user "already had" a
  vibe-setup manifest before vibe-setup existed).

**Always reported, regardless of mode, as an out-of-scope reminder (not itemized per-file,
one fixed block):** CLAUDE.md, `docs/`, `tests/`, and `.claude/settings.json`'s
`permissions.allow`/`permissions.deny` content are LLM-authored and never touched by
`remove` — the report/dry-run output says so once, pointing the user/LLM at manual
review. If the user previously ran `init-cursor`/`init-gemini` and set
`git config core.hooksPath` / `commit.template` / `vibe.ticketre` (done by the SKILL
layer, not scaffold.sh — scaffold.sh has no record of these), the report includes one
fixed informational block with the exact `git config --unset ...` commands, presented as
a suggestion, never executed automatically.

**`vibe-remove-report.md` structure (written only by `--apply`, repo root, same
drop-at-root convention as `vibe-checklist.md`):**
```markdown
# vibe-remove report — <timestamp>

## Silinen dosyalar
- <path> (managed, v<N>)
- <path> (extra)
...

## Elle düzenlenmiş — dokunulmadı
- <path> — oluşturulduğundan beri değişmiş, silinmedi

## Pre-existing — hiç dokunulmadı
<N> dosya vibe-setup'tan önce zaten vardı, elle silinmedi.

## Kapsam dışı — elle gözden geçir
CLAUDE.md, docs/, tests/, .claude/settings.json içeriği (LLM tarafından dolduruldu,
otomatik silinmez).

## (varsa) git config temizliği — önerilir, otomatik yapılmadı
git config --unset core.hooksPath
git config --unset commit.template
git config --unset vibe.ticketre
```

## Out of scope (explicit)

- Auto-deleting LLM-authored content (CLAUDE.md/docs/tests/settings.json content) —
  decision 1.
- Auto-unsetting git config (core.hooksPath/commit.template/vibe.ticketre) — scaffold.sh
  never set these itself (the SKILL/LLM layer did, conditionally, after asking), so it has
  no deterministic record to act on.
- Any kind of "undo history" beyond current-state provenance — no multi-run journal, no
  timestamped log of every past init/upgrade call. The manifest stays a single
  current-state file, just a richer one (adds `created` + `extras` + `gitignoreLine`).
- Interactive per-file confirmation during `--apply` — classification is fully
  deterministic (sha match / no match / created flag), so there's nothing left to ask
  once the user has typed `--apply`. The dry-run IS the confirmation step.
