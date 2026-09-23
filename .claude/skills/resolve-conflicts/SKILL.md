---
name: resolve-conflicts
description: Intelligently resolve merge conflicts in a repo or worktree that is mid-rebase, mid-merge, mid-cherry-pick, or mid-revert. Reads both sides, resolves to preserve both intents, and continues the operation — pausing only when the two sides genuinely conflict. Use when a rebase/merge stops on conflicts, or when another skill (e.g. refresh-stack) hands off a conflicted worktree. Stack-agnostic.
---

# Resolve conflicts

Resolve the conflicts in a repository (or a specific worktree) that is partway
through a `rebase`, `merge`, `cherry-pick`, or `revert`, then continue to
completion. This skill knows nothing about PR stacks — it operates on whatever
operation git is currently in. Callers pass a working directory; default to the
current one.

## Operating mode

Semi-autonomous: resolve clear conflicts yourself; **pause and ask** only when the
two sides change the same behavior in genuinely incompatible ways. Never silently
drop either side's intent.

## 1. Read the state — before touching anything

```bash
git -C "$WT" status
git -C "$WT" diff --name-only --diff-filter=U   # files with unresolved conflicts
```

Identify the operation from what's present in `.git`:

| In progress | Marker | `--continue` command |
|---|---|---|
| rebase | `rebase-merge/` or `rebase-apply/` | `git rebase --continue` |
| merge | `MERGE_HEAD` | `git merge --continue` |
| cherry-pick | `CHERRY_PICK_HEAD` | `git cherry-pick --continue` |
| revert | `REVERT_HEAD` | `git revert --continue` |

**The ours/theirs inversion (read this every time):**
- In a **merge**, `--ours` = your current branch, `--theirs` = the branch merging in.
- In a **rebase / cherry-pick**, it flips: `--ours` = the commit you're replaying *onto* (the new base), `--theirs` = the commit being replayed (your own work). During a stack refresh the "theirs" side is *your PR's changes*.

Always confirm direction with `git status` / commit subjects (`git -C "$WT" log --oneline -1 REBASE_HEAD` for the commit being applied) rather than trusting intuition.

## 2. Resolve each conflicted file

For every file from `--diff-filter=U`:

1. **Read the whole file** and each conflict hunk (`<<<<<<<` / `=======` / `>>>>>>>`).
2. **Understand both intents** — what did each side change and why? Use `git log`/blame on both sides if the intent isn't obvious.
3. **Merge to preserve both.** The goal is the union of intent, not picking a winner. Combine both changes when they're orthogonal; reconcile them when they touch the same code.
4. Remove **all** conflict markers. Keep the file syntactically valid.
5. Stage it: `git -C "$WT" add -- <file>`.

### Special cases

- **Lockfiles / generated files** (`package-lock.json`, `yarn.lock`, `Cargo.lock`, `*.generated.*`, snapshots): don't hand-merge. Take the incoming base, finish the resolution of source files, then **regenerate** (`npm install`, `cargo build`, the repo's codegen) and stage the result.
- **delete/modify**: decide whether the deletion or the edit should win based on intent; if unsure, this is a pause-and-ask case.
- **add/add** (both added the same path): merge the two versions into one.
- **A purely one-sided hunk** (only one side meaningfully changed): take that side — but verify it's genuinely one-sided, not a subtle semantic clash.

### Never

- `git checkout --ours/--theirs <file>` wholesale unless the file is truly one-sided. It silently discards the other side.
- `git rebase --skip` (drops a commit entirely) or `--abort` without asking the caller first.
- Leave a resolution with conflict markers or broken syntax.

## 3. Pause-and-ask criteria

Stop and surface the conflict to the caller/user when:
- Both sides change the **same logic** in incompatible ways (not just adjacent lines).
- A delete/modify where losing either side changes behavior.
- Resolving correctly needs product/domain context you don't have.

Present: the file, both sides' intent, and your proposed resolution. Wait for a decision.

## 4. Continue — and loop

Once every conflicted file is staged with no markers left:

```bash
# rebase/cherry-pick reuse the original message; skip the editor.
GIT_EDITOR=true git -C "$WT" rebase --continue
```

A rebase may stop again on the **next** commit. Repeat from step 1 until
`git -C "$WT" status` shows the operation is complete (no rebase/merge in
progress). Verify nothing is left behind:

```bash
rg -n '^(<<<<<<<|=======|>>>>>>>)' "$WT" && echo "MARKERS REMAIN" || echo "clean"
```

## 5. Report

For each commit/step you resolved, report the files touched and a one-line note on
how you reconciled each (which intents you combined). Flag anything you took a
judgment call on so the caller can spot-check.
