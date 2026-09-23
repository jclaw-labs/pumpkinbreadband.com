---
name: create-pr
description: Create a draft pull request in the active git repo, drafting a tight, reviewer-facing body that explains intent, impact, and review focus instead of narrating the diff. Uses the repo's PR template if present, or a project-specific local override. Always creates drafts; leaves unknown sections of the template blank rather than fabricating content. Use whenever you finish making changes (new work or review feedback) — commit, push, and open or update a PR without waiting to be asked — and whenever the user asks to open, create, push up, draft, revise, or tighten a PR.
---

# Create PR

## When to use

Whenever you made changes that should ship: commit and push, then create or update the PR. Don't wait to be asked. Also use when the user asks to create / open / push up / draft / revise / tighten a PR. If a PR already exists for the branch, update it rather than opening a second one.

## Confirm the host clone (do this first)

Convention: the user often keeps two checkouts — their own (named the same as the GitHub repo) and a separate "agent" checkout named differently, so the agent's PR work doesn't interfere with the user's open files. Not every project has a separate agent clone, though.

Detect by comparing the local checkout's directory basename to the origin repo name:

```bash
toplevel_name="$(basename "$(git rev-parse --show-toplevel)")"
origin_repo="$(basename -s .git "$(git remote get-url origin)")"
```

- **`toplevel_name != origin_repo`** → this is an agent-named clone (e.g. cloned into `foo-ai` from `github.com/owner/foo`). Proceed silently.
- **`toplevel_name == origin_repo`** → this looks like the user's primary checkout. The user may have started the skill here on purpose (no separate agent clone exists), or by mistake. Ask once before proceeding:

  > Just confirming — this looks like your primary `<origin_repo>` checkout (directory name matches the origin repo). Did you mean to run me here, or did you want me to work in a separate clone? The push and any branch creation will happen wherever we proceed.

  Wait for the answer. **Once given, treat it as standing for the rest of the session** — don't re-ask for further PR or worktree work in this same project. If a worktree was just created via `new-worktree` in the same project, that decision already covered this question; don't re-ask.

## Hard rules

- **Always `--draft`.** No exceptions unless the user explicitly says "not a draft".
- **Leave unknown sections blank.** Don't invent ticket numbers, test plans, screenshots, or reviewer steps. An empty heading is better than a hallucinated one.
- **Ask once for the related ticket** if it isn't already known (see "Ticket intake" below). This is the one allowed clarifying question (besides the host-clone confirmation, if applicable); everything else falls back to "produce the best body from available info".
- **Always start the body with the tracker URL on the first line** when one exists. Omit the line entirely if there genuinely is no ticket.
- **Don't narrate the diff.** Reviewers can read the diff. The body should give them what the diff _can't_.
- **Concise.** High signal-to-noise. Treat every sentence as guilty until proven necessary.
- **Never push with `--no-verify`.** If pre-push fails, fix the underlying issue (most commonly: husky not bootstrapped in a worktree — see the `new-worktree` skill).
- **Never push when local checks fail.** Run lint, typecheck, and tests locally before push (see step 3) and surface failures rather than letting CI catch them. Don't claim "CI will tell us" — that wastes a CI cycle and a review pass.
- **Never fabricate screenshots or image descriptions.** Either upload real images via the "Add screenshots" step (8), or leave the Screenshots heading and any HTML comment from the template intact. Don't invent captions or describe UI you haven't seen.
- **When a PR changes tests, report what they cost in suite time.** Measure it, don't estimate it, and keep it to two durations in the Checklist section (see "Test time" below). No test changes, no line.

## Voice and style

Follow the [`writing-style`](../writing-style/SKILL.md) skill for tone, phrasing, what-to-cut rules, and the two-pass drafting workflow. The rules below cover what's PR-specific.

## What makes a good PR body

A PR body is a note from author to reviewer. Optimize for a reviewer who skims first, reads closely second — they should be able to answer in seconds:

1. What changed?
2. Why did it change?
3. What should I pay attention to?

**Include** something only if it surfaces at least one of:

- intent / primary goal
- rationale or trade-off
- review focus (where to look hard)
- user-facing or system-level impact
- meaningful risk, rollout concern, or follow-up

**Omit (PR-specific):**

- facts obvious from the diff (renames, moves, type changes, mirrored tests)
- file-by-file or function-by-function summaries
- low-level details that don't affect review priorities

The general style rules in `writing-style` cover the rest (filler, narration, citations, empty intensifiers, abstracting up).

## Default body structure

Unless the user asks for a different shape, the **Summary** section is:

1. **One sentence** of the PR's main purpose. Stands alone.
2. **2–5 short bullets** with the most important supporting points (rationale, non-obvious choices, impact).
3. **Optional final bullet** for review focus, risk, rollout, or follow-up.

The leading tracker line and the template's other sections (Checklist, reviewer testing, screenshots) follow the per-section rules in step 5 below.

## Test time

Every test that lands is time the whole team pays on every build from then on, and nobody sees that cost at review time unless somebody puts a number on it. So when a PR changes tests, measure the cost and put it in the body.

**A PR that doesn't touch tests gets no line at all** — not even "no new tests". When there is something to report, it's two durations: what the change added or removed, and what the touched test files now cost in total.

```
Test time: +6.6s, 24s total
Test time: -2.1s, 9.4s total
```

That's the whole readout almost every time. The file names and the case count are already in the diff, so leave them out.

**Measure it, don't estimate it.** The total is the wall time of the test files the PR touches, run on this branch — step 3 already has you running them. For the delta: a brand-new file's whole time is its delta; for cases added to an existing file, time just those cases by name (`-g` / `--grep` / `-t`), unless they share expensive setup with the cases already there, in which case run the file on the base too and diff the two. Deletions are the same in reverse. Take the second run of each, since the first pays for a cold cache and compilation.

**The line goes at the bottom of the `## Checklist` section**, as a plain line rather than a `- [ ]` item — it's something to read, not something to tick. Leave the template's own checklist items alone.

**Defend a number only when it needs defending.** A few seconds doesn't. Past that, go look at what the tests are doing before you write anything — there's usually something to take: two cases asserting the same path collapse into one, setup that runs per case gets hoisted to run once, a unit test stands in for one that goes to the database. If the time is still worth paying, one clause says what it buys; if you can't say, cut the test rather than shipping the number with a shrug.

```
Test time: +14s, 41s total — each case seeds a publication to hit a different rejection path
```

## Ticket intake

Before finalizing the body, make sure you know whether there's a related tracker ticket (Linear, Jira, GitHub issue, etc.) — or have confirmed there isn't.

**If no ticket has been provided** — and one isn't obvious from chat history, the branch name (e.g. `jdoe-ABC-123-fix-dropdown` → `ABC-123`), or recent commit messages — ask once:

> Is there a tracker ticket or issue for this change? (Paste a URL or ID, or say "none".)

Wait for the answer, then continue automatically. Don't re-ask, don't expand the question, don't block on anything else.

**If a URL or ID is provided**, fetch context where you can — Linear via the `plugin-linear-linear` MCP server (`get_issue`), GitHub issues via `gh issue view <id>`, etc. Use the ticket as supporting context to sharpen the Summary's explanation of:

- why the change exists
- user-facing or system-level impact
- important constraints or trade-offs
- risks, rollout concerns, or follow-ups
- what the reviewer should scrutinize

**Do not turn the PR body into a ticket summary.** Compress ticket details into the few points that improve reviewer understanding. The link itself carries the rest.

**Always include the link** as the body's first line, above the `## Summary` heading. Use a label that matches the tracker:

```
Linear: https://linear.app/...

## Summary
…
```

```
Issue: https://github.com/owner/repo/issues/123

## Summary
…
```

If the ticket can't be fetched (connector unavailable, permissions, etc.) but the user supplied a link, use what they gave you and still include the link on the first line.

If the user explicitly says there is no ticket, omit the line entirely.

## End-to-end workflow

### 1. Locate the PR template

Try in this order:

1. **Local override** — a project-specific template at `<local-config>/repo-tools/pr-templates/<repo-name>.md`, where `<local-config>` is the dir holding the user's shared shell/git/agent config. Resolve via `~/.agents` if present (its target's grandparent is the local-config root). `<repo-name>` is the basename of the repo's git toplevel.
2. **Repo template** — `.github/pull_request_template.md` or `.github/PULL_REQUEST_TEMPLATE.md` in the repo.
3. **Default** — a minimal inline template:

   ```
   ## Summary
   ```

If a template is found, use it as the starting body.

### 2. Determine the base branch

- Default: the repo's default branch. Detect via `git symbolic-ref refs/remotes/origin/HEAD` (typically `main` or `master`).
- **Stacked PR check**: if the current branch was branched off another branch with an open PR (not the default), base on that branch instead so the diff only shows the new work. Detect by:

  ```bash
  git log --oneline origin/<default>..HEAD
  ```

  If that shows commits clearly belonging to another in-flight branch, run `gh pr list --head <that-branch>` to confirm an open PR exists. If so, base on that branch and mention the stacking sequence in the Summary.

- **Slicing the stack yourself?** If you're deciding *how* to split work into a stack (not just opening a PR on a branch that already exists), use the `split-to-prs` skill for the general slicing process. Whichever way the stack came to be, every PR in it must be safe to land on its own — read the `stacked-pr-rules` skill for the landing-safety rules and hold each slice to them.

- **Resolve the full stack**: if a stack is detected (this PR sits on another open PR, or other open PRs are stacked on this branch), resolve the entire stack — step 5 needs the parent's URL, and step 8 puts the stack outline on every PR in it. `pr-stack-section <parent-PR-or-branch>` prints the resolved chain; so does `restack-detect <bottom-parent-branch-or-PR>`. Neither can see this PR before it exists, so run it against the parent now and let step 8 pick up the new PR. Failing both, walk base refs manually: `gh pr list --state open --json number,headRefName,baseRefName,url` and follow `baseRefName → headRefName` links up and down from the current branch.

### 3. Run local checks

Before pushing, run the project's check scripts so CI doesn't catch what local would have. This implements the global `Local checks` rule from `~/.agents/AGENTS.md` at the latest possible moment.

Pick the package manager from the lockfile: `pnpm-lock.yaml` → `pnpm`, `yarn.lock` → `yarn`, otherwise `npm`. For non-JS repos, use the equivalent (`cargo check / clippy / test`, `go vet / test`, `pytest`, etc.).

Read `package.json` `scripts` and run the ones that exist, in this order:

- `lint` — if it fails, try one auto-fix pass (`<pm> run lint -- --fix` or whatever the script accepts) and re-run.
- `typecheck` — fix any errors before continuing.
- `test` — fix any failures before continuing. If snapshot tests fail, **don't blindly run `--updateSnapshot` to make them green** — diff the snapshots and confirm the change is intentional first. If the test suite is slow and the change is non-test code, it's fine to scope to the affected package or to skip with a one-line note to the user; otherwise run it. If the PR changes tests, take the timing measurement here while you're already running them ("Test time" above).

If a script doesn't exist, skip it silently. If `package.json` has none of these, mention once that no local check scripts were discovered and continue.

If anything still fails after the auto-fix pass, surface the failures and stop. Don't push, don't `--no-verify`. The user decides whether to fix or override.

### 4. Push the branch (if not already pushed)

```bash
git push -u origin HEAD
```

If the pre-push hook fails with `.husky/_/husky.sh: No such file or directory`, the current dir is a worktree without husky bootstrapped. Run the install command in the package dir of the worktree (per the `new-worktree` skill), then retry the push.

### 5. Fill in the template

Read the diff vs base:

```bash
git diff <base>...HEAD --stat
git log --oneline <base>..HEAD
```

Apply the two-pass workflow to write the **Summary**. Per-section rules:

- **Summary** — one sentence + 2–5 bullets per the structure above. Use the user's stated intent and any ticket context as the source of "why".
- **Checklist** (if the template has one) — leave items unchecked. The author checks them after manual verification. **Keep every default checklist item the template ships with** (e.g. `Unit/integration tests`, `Tested manually and confirmed it works as expected`). Stack/dependency items are added _in addition to_ these — never replace or drop the template's defaults, and don't substitute a custom `Test plan` section for them. After rendering, re-read the template's `## Checklist` and confirm each of its items is present in your body verbatim. If the PR changes tests, the `Test time` line from step 3 goes at the bottom of this section, below the items and outside the list — and if it doesn't, that line is absent entirely ("Test time" above).

  **If this PR is part of a stack** (resolved in step 2), it also carries the two stack checklist items, prepended above the template's defaults — and every other open PR in the chain has to carry the merge-mechanism one too. [`pr-body-rules`](../pr-body-rules/SKILL.md) is the single source of truth for both items' exact text and for the backfill; follow it rather than reproducing the rules here, and report which PRs you updated in step 10. The stack *outline* is a separate, generated thing — step 8 handles it, and it is not something you write into the template.
- **Reviewer test steps** (e.g. an "If you'd like to test yourself" section) — only include concrete steps if you actually know how to exercise the change locally (a script command, a URL, a feature flag toggle). If unsure, delete the section. Do not write generic "run the app and click around" filler. If the user said reviewer testing is required (rare), rename the heading to something like `Please test this yourself before approving`.
- **Migration commands** — if the diff is a database migration PR, add a `## Migration commands` section (after Summary, before the Checklist) with the exact apply and revert commands for each migration file, copy-pasteable from the app directory. Use the repo's real invocation — check how migrations are actually run (package.json scripts, migration docs) rather than guessing. In Substack, that's the writer knexfile explicitly:

  ```bash
  ./esr node_modules/.bin/knex migrate:up <migration_file>.js --env development --knexfile knexfile-writer.ts

  ./esr node_modules/.bin/knex migrate:down <migration_file>.js --env development --knexfile knexfile-writer.ts
  ```

- **Screenshots** — leave the heading + any HTML comment if it's a UI change (Step 9 will offer to fill it in); delete the section entirely if not. If the template has no Screenshots section and Step 9 ends up wiring in images, append one at the end of the body.
- **Tracker first line** — fill in the URL gathered during intake. Drop the line entirely if the user confirmed there's no ticket. If the template ships with a placeholder (e.g. `Linear:` on the first line), complete it or remove it.
- **Name the item, not just the issue**, when the ticket is an umbrella holding several findings — `Issue: <url> (item 3)`. Whoever merges this PR is the one who ticks that item, per AGENTS.md's "Keeping a filed finding's state", and an issue number alone doesn't tell them which of six boxes to tick. The line costs three words and is the only thing carrying the fix's target past the moment you stop working on it.

### 6. Choose a title

- Concise, present-tense, no trailing period.
- If a tracker ticket ID is known and the repo's existing PR titles use one (check `gh pr list --limit 10`), prepend it (e.g. `[ABC-123] `).
- Otherwise reuse the latest commit message subject if it's already good, or summarize the diff in <80 chars.
- The title is itself a single-sentence summary; same rules apply (purpose, not narration).

### 7. Create the PR

```bash
CREATE_PR_SKILL=1 gh pr create --draft --base <base> --title "<title>" --body "$(cat <<'EOF'
<rendered template>
EOF
)"
```

The `CREATE_PR_SKILL=1` prefix is required: a `beforeShellExecution` guard denies bare `gh pr create` / `gh pr edit` to enforce that PRs go through this skill. Keep the prefix on every `gh pr create` / `gh pr edit` invocation below. It keys on the command, not on how you pass the body, so `--body-file <path>` needs it just the same — and without it that form is denied identically, with a message that names the skill rather than the flag, which reads like `--body-file` being unsupported when it isn't.

Use a HEREDOC for the body so newlines and markdown survive intact.

**Don't escape backticks, dollar signs, or backslashes inside the heredoc.** The single-quoted delimiter (`<<'EOF'`) makes the body fully literal — no parameter, command, or backslash interpretation. The surrounding `"$(...)"` only captures stdout as a string; it does not re-evaluate the captured content. Writing `\`\`\`bash` produces a literal backslash-backtick sequence in the PR body and breaks the code fence on GitHub. Just write ` ```bash ` plain.

### 8. Refresh the stack outline

If this PR is part of a stack, put the `## PR stack` outline on every PR in the chain now that this one exists:

```bash
pr-stack-section --apply <new-pr-number>
```

That's the whole step — the script resolves the chain in both directions from whatever PR you name, so it also refreshes the parent's and any children's outlines to include this new PR. It places the block under the tracker line and above the Summary, and rewrites nothing that's already current. [`pr-body-rules`](../pr-body-rules/SKILL.md) owns the rules; don't hand-write the block, reproduce its format, or put it in the template in step 5.

This step is also load-bearing for later: the block records the tree it drew, and that record is the only thing that survives a merge deleting the parent's branch and retargeting the children. Running it here, while the base refs are still intact, is what lets the outline still show the landed part of the stack months from now. Skipping it doesn't just leave today's outline missing — it means there is no history to recover.

Do this **before** step 9, not after: step 9 sends the user to the browser's pencil, and any body write racing that is how their edits get clobbered. Skip the step entirely for a standalone PR (the script will tell you it isn't stacked, and change nothing).

### 9. Add screenshots (optional)

After the draft PR exists, offer to wire up screenshots. Skip the question (and this step) only if the diff has zero UI surface — no `.tsx` / `.jsx` / `.vue` / `.swift` / `.kt` files, no CSS, no template changes. When in doubt, ask.

**Why this flow looks like it does.** GitHub's `user-attachments/assets/<uuid>` URLs (the format the user wants) can only be produced by a real browser session — the undocumented `/upload/policies/assets` endpoint rejects OAuth tokens and `gh-attach` can't reliably extract Chrome cookies on macOS. So the user does the drag-drop themselves on github.com, and this skill handles everything else: parsing the URLs back out of the body, format choice, captioning, table rendering, and splicing into the Screenshots section.

#### 9.1 Ask the user

First, offer to **take the screenshots yourself**. Ask via the structured multiple-choice UI (the `AskQuestion` tool / native question card) whenever the harness provides one; options should be clickable and self-describing — never bare numeric codes like `done 2` that the user has to decode:

- **Take them for me** — you capture the screenshots (dev server + browser, simulator, etc.), save them to their own folder under `/tmp` (per the global screenshots rule in `~/.agents/AGENTS.md`), and reveal that folder in Finder. The user then drag-drops the files into the PR body on github.com. In this path, **you choose the format** (pick whatever fits the images best — plain inline, two-column, or captioned) and skip the format question and the format-specific input in 9.4; go straight from parsing (9.2) and order confirmation (9.3) to rendering (9.5).
- **I'll upload my own** — the user captures and uploads their own screenshots; continue with the upload instructions and format question below.
- **Skip** — leave the Screenshots section blank.

If the user chose "take them for me", capture the screenshots, reveal the folder in Finder, then send the upload instructions:

> Screenshots are in <folder> (just revealed in Finder). To get them onto the PR:
>
> 1. Open the PR: <PR URL>
> 2. Click the pencil to edit the body, then drag-drop the screenshots anywhere in the body (don't worry about where — I'll move them into the Screenshots section). Wait for each upload to finish (the `[Uploading ...]` placeholder gets replaced with the real URL), then save, and let me know.

If the user chose "I'll upload my own", send the same two upload steps (without the folder line), then ask the format as a multiple-choice question. Name **and** describe every option in plain language:

- **Plain inline** — each image full-width on its own line
- **Two-column table** — images paired side by side under shared column headers like "Before | After" (follow up once for the two header names)
- **Captioned table** — images side by side with a caption row under each pair (follow up for one caption per image; see https://github.com/substackinc/substack/pull/63999 for the rendered shape)

Treat the user's format answer as the "uploads are finished" signal — don't require a separate "done" message. If the structured question UI isn't available, ask the same questions in plaintext with the option names and descriptions spelled out, and accept answers by name (e.g. "two-column"), not just by number.

#### 9.2 Fetch the body and parse images

Once the user answers with a format:

```bash
gh pr view <pr-number> --json body --jq .body > /tmp/pr-<N>-body.md
```

Extract every user-attachments image reference, in document order. GitHub emits two shapes when you drag-drop:

- `<img width="W" height="H" alt="<filename>" src="https://github.com/user-attachments/assets/<uuid>" />` (the modern shape; carries intrinsic dimensions and alt text)
- `![<alt>](https://github.com/user-attachments/assets/<uuid>)` (the older markdown shape, occasionally)

For each match record: URL, width, height (if present), alt text (if present). Missing dimensions are fine — just omit the `width`/`height` attributes in the rendered output and let GitHub auto-size.

If zero images were found, the user probably saved before the uploads finished. Tell them: "I don't see any `user-attachments/assets/...` URLs in the body yet — did the uploads finish before you saved? Wait for each `[Uploading ...]` placeholder to turn into a real URL, save again, and let me know." Don't proceed.

#### 9.3 Confirm order

List the parsed images in chat, numbered by alt text (the filename GitHub auto-fills), and ask once:

```
Found N image(s) in the body:
  1. Screenshot 2026-05-28 at 1.04.27 PM
  2. Screenshot 2026-05-28 at 1.05.09 PM
  3. ...

Order look right? (y / "swap N M" to swap two / "drop N" to remove one)
```

Accept one round of reordering edits, re-print the list, then proceed. Don't loop forever — if the user keeps tweaking, fold them all in and move on.

In-chat preview is not available: GitHub gates `user-attachments/...` URLs behind real browser cookies, so the URLs neither render inline in Cursor's chat panel nor download with the `gh` OAuth token. The user identifies images by filename + index, with the PR open in their browser as the visual reference. Don't try to embed them.

#### 9.4 Collect format-specific input

Skip this step entirely if you took the screenshots yourself (9.1 "take them for me") — you chose the format, so write your own headers/captions from what each screenshot shows.

- **Plain inline** — no further input.
- **Two-column table** — ask once: "Two column headers? (e.g. `Before | After` or `Desktop | Mobile`)". Parse the two halves on either side of the separator.
- **Captioned table** — ask one caption per image, one at a time, referencing the filename so the user can identify it:

  ```
  Caption for image 1 of N (Screenshot 2026-05-28 at 1.04.27 PM):
  ```

  Accept the reply and move to the next. An empty reply leaves that caption blank (`|  |`). After the last image, confirm: "All captions captured. Splicing into the PR body."

#### 9.5 Render the Screenshots block

Use the recorded URL / width / height / alt for every `<img>` tag. Width/height attributes are optional — omit them entirely (no empty `width=""`) if you don't have them.

**Plain inline.** One `<img>` per line:

```
<img width="W" height="H" alt="<filename>" src="https://github.com/user-attachments/assets/<uuid>" />
```

**Two-column table with shared headers.** Lay out in 2-column rows; if the count is odd, leave the last cell empty:

```
| <header A> | <header B>
| --- | ---
| <img width="..." height="..." alt="..." src="..." /> | <img width="..." height="..." alt="..." src="..." />
| <img width="..." height="..." alt="..." src="..." /> | <img width="..." height="..." alt="..." src="..." />
```

**Captioned table.** A 2-column table where each pair of images is followed by a row of captions, and pairs are separated by two blank rows. Matches the format in https://github.com/substackinc/substack/pull/63999. The `| _ | _` header row is intentional — GitHub renders the cells empty so no visible header sits above the images.

```
| _ | _
| --- | ---
| <img width="..." height="..." alt="..." src="..." /> | <img width="..." height="..." alt="..." src="..." />
| <caption 1> | <caption 2>
|  |
|  |
| <img width="..." height="..." alt="..." src="..." /> | <img width="..." height="..." alt="..." src="..." />
| <caption 3> | <caption 4>
```

If the image count is odd in either table format, the trailing image cell gets a partner empty cell (`| <img ... /> | `), and in the captioned table the caption row matches (`| <caption N> | `).

#### 9.6 Splice into the PR body

**Re-fetch the body first.** The copy from 9.2 predates every question you asked in 9.3 and 9.4, and the user has had the pencil open the whole time — writing that copy back is how this skill has already wiped their edits twice. Refetch now, re-locate the image tags in the fresh text, and make the two edits below against it ([`pr-body-rules`](../pr-body-rules/SKILL.md)).

Two edits to the body in one `gh pr edit` call:

1. **Strip every parsed `<img>` / `![](...)` user-attachments reference from wherever it currently sits in the body.** Otherwise the images render twice (once where the user pasted them, once in the formatted block). Also strip any now-orphaned blank lines those tags left behind.
2. **Insert the rendered Screenshots block** into the existing `## Screenshots` section, replacing any HTML-comment placeholder from the template. If the template had no Screenshots section, append `## Screenshots\n\n<block>` at the end of the body.

Then push:

```bash
CREATE_PR_SKILL=1 gh pr edit <number> --body "$(cat <<'EOF'
<updated body>
EOF
)"
```

Same heredoc rules as Step 7 — single-quoted delimiter, no escaping. Keep the `CREATE_PR_SKILL=1` prefix (see Step 7).

### 10. Report the PR URL

Print just the URL `gh` returned, plus a one-line note if you based on a non-default branch (so the user knows the stacking order), a one-line note naming the other stack PRs whose bodies you touched — the outline refresh in step 8 and any `/merge-stack` reminder you backfilled in step 5 — and a one-line note if a screenshot upload failed (so they know to attach manually).

## Editing an existing PR body

If the user asks to revise / tighten / rewrite an existing PR body (not create a new PR):

- Preserve real meaning; remove filler and repetition aggressively.
- Elevate low-level bullets into higher-level reviewer-relevant statements when possible.
- Keep only details that affect reviewer understanding, scrutiny, or risk.

**Read [`pr-body-rules`](../pr-body-rules/SKILL.md) before you write.** `--body` overwrites the whole body, so the mechanics — refetch immediately before the write, edit that exact text, verify after, and recover a version you clobbered — live there. This applies to every body write in this skill, not just a user-requested rewrite: the screenshot splice in step 9.6 and the checklist backfill in step 5 are the two that have actually destroyed the user's writing.

Update via:

```bash
CREATE_PR_SKILL=1 gh pr edit <number> --body "$(cat <<'EOF'
<new body>
EOF
)"
```

## Behavior on weak input

If the user provides only a rough description, scattered notes, or just "open a PR":

- Infer the likely reviewer-facing purpose from the diff and chat history.
- Compress details into higher-level points.
- Don't invent specifics not supported by the input.
- If key context is missing, still produce the best possible body from what's available rather than blocking on questions. Make uncertainty explicit only when it's real and matters to the reviewer.
- The **only** allowed clarifying questions are the ticket intake (above) and, if applicable, the host-clone confirmation (above). Don't expand to a list of follow-ups.

## Branch and commit conventions

Follow whatever conventions the repo already uses — read its `CLAUDE.md`, `CONTRIBUTING.md`, or recent branch/commit history (`git log --oneline -20`, `git branch -a`) and match. Don't impose a default if the repo has its own pattern.
