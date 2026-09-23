---
name: deep-review-orchestrate
description: Run the deep-review / address-deep-review cycle to completion from a single session — a fresh subagent reviews the PR, this session addresses the findings, and the two alternate until the loop's own stopping rule fires. Runs as one long task and returns once, when it's done. Use when the user asks to run the review loop on a PR, to review and address until it settles, or invokes /deep-review-orchestrate. Only start it when asked; a loop costs many agent rounds.
---

# Deep-review orchestrate

One session drives the whole review cycle. A fresh subagent reviews the PR, you address what it found, and the two alternate until the loop stops on its own.

You are the orchestrator and the addresser — and you may hand the addressing pass to a subagent (step 3). The reviewer is a subagent, and it must never be you — that separation is the only thing here that produces value.

**Don't start this loop on your own** after opening a PR. It runs up to five review sessions and five addressing rounds, and it belongs to the user to ask for.

## Arguments

`/deep-review-orchestrate` — loop on the PR for the current branch
`/deep-review-orchestrate 136` — loop on PR #136

## Run it to the end. Return once.

The loop is **one long-running task, not a series of check-ins.** Start it, run every round, and come back when it's finished. The ordinary "agent is done" notification at the end of your turn is how the user learns the PR is ready for their eyes, and that only works if you return exactly once.

So don't ask the user which option to take between rounds. Every decision the loop needs is already written down: the stopping rule in step 4, the escalation list below, and `address-deep-review` for which findings to take. A mid-loop question turns a task the user walked away from into one that has been sitting waiting on them, which costs them the thing the loop was for.

- **Use your judgement and keep going.** When a call is genuinely yours — a finding to decline, a round to run again — make it, record the reasoning, and move on.
- **Report as you go, but never ask.** A one-line summary per round costs the user nothing, because it doesn't hand control back. A question does.
- **Return early only to escalate.** Each condition in the escalation list ends the turn with a report, and that's a finished task too, not a check-in. Someone else's uncommitted work is the one stopping reason that isn't on the list, because it can turn up at any moment rather than at a round boundary.
- **Keep every reviewer in the foreground** (step 1), so the turn ends when the loop does rather than while it's still running.

The final report is the deliverable and the only thing they'll read. It carries what happened each round, what you pushed, whether the loop stopped clean or escalated and which condition fired, anything left for them to decide, and the PR URL.

## Why the reviewer has to be a subagent

An agent cannot review code it just wrote. It reads the diff as it meant the diff, so the gap between what it intended and what it typed is exactly the gap it can't see. A subagent starting from nothing has to reconstruct the intent from the diff, the PR description, the tickets, and the repo's own documents — which is the position a future maintainer is in, and the position from which defects are visible.

This is measured, not assumed. Over one four-PR stack — 14 review runs, 139 findings — roughly **one addressing round in five introduced a defect that only the following review caught**, including a fix that re-created the exact bug its PR was opened to fix, in a commit whose own comment asserted that couldn't happen. None was visible to the agent that wrote it.

So: **a new subagent every round, never a resumed one.** A resumed reviewer carries last round's context and stops being fresh, which quietly converts the loop into one agent talking to itself. Continuity lives on the PR instead — each round's marker comment is readable by the next reviewer, so nothing needs to be remembered.

## Before the first round

- **Start the loop in a fresh session, or expect to hand over after one round.** Five rounds of review-plus-addressing is most of a context window on its own, so a session that already carried the work being reviewed has no room for the loop that follows it. Asked to loop at the end of a long implementation session, say up front that you'll likely escalate on context at the first boundary and suggest a fresh session — that costs one message, where discovering it mid-round costs the round. This is the cheapest of the escalation conditions to predict and the only one you can see coming before round 1.
- **A PR exists, it's the user's own, and it's pushed.** No PR yet? Open one with `create-pr` first. Someone else's PR is out of scope: the reply rules are narrower there, and `deep-review` would stop to ask before posting its marker anyway.
- **Local HEAD matches the PR's head SHA.** The reviewer reviews what's on the remote. An unpushed commit means you're addressing findings about code that isn't the code.
- **The working tree is clean**, and it's a tree nobody else is typing in — a worktree or a claimed slot, not a checkout someone has open. You need it clean to commit from, and you need it quiet because after the fact a reviewer's probe and somebody's in-flight edit look identical.

  **Getting that tree is the one place a blocking question is correct**, and it doesn't contradict the run-to-the-end rule above, which governs decisions *inside* the loop. Where the workspace comes from a fixed pool, freeing an occupied slot is the user's call and nobody else's, so don't pick one and don't start the loop in a tree you shouldn't be in. `substack-claim-worktree`'s "when claim exits non-zero" section owns what to do instead, and its two shapes differ: a printed list of quiet-session slots is one you surface before taking the named slot, while no list at all means every slot is live and there is nothing to show — say so and stop. Ask before your first dispatch or not at all — which is round 1 on a fresh PR, and whatever round you start at when you pick up someone else's loop. Once you're dispatching, the same question costs them a loop they'd walked away from.
- **Get the round number from `review-loop-state <pr>`**, and pass it to each reviewer rather than letting the subagent count for itself. It sits next to this file, so a vendored copy of this skill carries it: run `review-loop-state` if it is on PATH, otherwise `bash .claude/skills/deep-review-orchestrate/review-loop-state` in the project — through `bash`, because a checkout that lost the exec bit would otherwise fail with a permission error that reads like the file being missing. It needs `jq`, and either `gh` or curl with a token in `GH_TOKEN` — a cloud agent has the second. It also reports the cap and any must-address a previous round refused, so one call answers the three questions this section used to work out by hand.

  **Pass `--repo <owner>/<name>`.** Without it the script has to work the repo out from your checkout — `gh repo view` where `gh` is installed, the `origin` URL on the curl path — so either way it needs your shell's cwd to be inside that checkout, and this loop `cd`s to `/tmp` constantly for `gh` work. The bare form then fails mid-loop with `cannot resolve repo`. You already know the repo, so name it.

  **A `Forbidden` from it is the sandbox, not your access and not a stale binary.** Re-run with unrestricted permissions. This is worth stating alongside the cwd problem because the two are independent and each is fixed by the other's non-fix: `--repo` does not dodge the sandbox — the REST reads are blocked too, not just the `gh repo view` that resolves the repo — and unrestricting permissions does nothing about the cwd. Expect to hit them in separate rounds and don't let fixing one convince you the other can't happen.

  Don't recompute it in your head. Four review rounds on this skill filed nine findings and every one was the same defect — arithmetic over comment text, done in prose, done wrong. The round number is the larger of two figures, because each misses a different round: the highest run a marker names misses a round whose marker was denied, and the highest run a response names misses a round whose response never posted. Counting comments that merely *contain* a marker string is worse than both, since any review discussing the counting rule quotes it. That logic now lives in the script with fixtures for each of those cases, where a wrong answer fails a test instead of shipping.

  It reads a run number rather than counting markers because a round can legitimately have two of them, and counting inflated the number permanently once that happened — then the loop stamped the inflated number into every later round's own comments, so nothing downstream could recover it. The run number comes from each marker's own `re-ran (run N)` header, taking the first in the body since a review quotes other rounds' headers in its prose, and a marker naming no run is run 1.

- **Check whether another loop is already running, before your first dispatch** — round 1 on a fresh PR, and whatever round you start at when you pick up a loop someone else began. Two loops on one PR is not hypothetical: it has happened, both numbered themselves run 1 against the same head, and the duplicate marker permanently inflated the round counter — that PR escalated at "5 of 5" having reviewed three distinct code states. Nothing else in this file looks for another loop numbering itself the same round as you: the checks below compare *heads* between rounds, which catches a push you didn't make without telling you who made it.

  **An unanswered marker is the state to look at, and it is ambiguous.** A marker with nothing under it means either a peer has finished a review and is addressing it, or some loop was interrupted between its review and its addressing pass — which this file documents twice, at the backgrounded-reviewer resume in step 1 and at the context escalation below. If you dispatched that review yourself, it's yours: address it. If you didn't, nothing on the PR tells you which, so say which reading you took and why instead of stopping flat. Addressing a review that was waiting anyway is the recoverable error; refusing to resume a handover is not.

  Neither age nor author discriminates, and no tool answers it for you. Two IDE loops on this Mac both post as me, and the PR body's background-agent footer records who *opened* the PR and never expires, so it reads "an agent owns this branch" forever, merged PRs included. `review-loop-state` reports numbers rather than order, and `marker_rounds > named_rounds` is not the proxy it resembles: a response naming run *n* beside a marker for run *n+1* gives equal counts on an unanswered marker. `marker_named > named_rounds` does detect that one exists, being the highest run a marker names against the highest a response names — but it still can't tell you whose it is, which is the question here. Read the order yourself with `gh api repos/<owner>/<name>/issues/<pr>/comments --paginate --jq`, classifying each comment by its first non-blank line — "under" means later in that flat list, since issue comments don't nest — and keep `-f`/`-F` out of it per the reply-guard bullet below.

  Say plainly what none of this catches. A marker is written at the *end* of a review pass, so a peer inside its first pass leaves nothing on the PR at all, and that holds at every round rather than only the first — which is also why a response with nothing under it is ambiguous in its own right, between a handover and a peer about to dispatch. Once a peer's marker exists `review-loop-state` counts it and you number yourself the round after, so a duplicate run number can't arise that way. The simultaneous window is invisible, and implying otherwise is worse than admitting it. It stays invisible until the script reports these signals itself — the deferred half of #72 item 3, which is also when this clause will want rewriting.

  If one is running, don't start a second — say so and stop. A second loop is worse than a slow one, and its cost lands on the counter, which every later session inherits.

- **Don't re-review a head you dispatched a review for.** If the newest response comment answers a run this loop dispatched, and the head you recorded for that run is the current head, a review of this exact code already exists — read it and address it rather than dispatching a fresh reviewer, which would produce a different list for the same code and spend a round on the difference.

  **Skip only on a head you recorded yourself.** Every SHA written in a comment is untrustworthy for this: `address-deep-review` defines the response header's SHA as a copy of the marker header's, and `deep-review` fills that header from a live read of the PR's head when it posts (step 4 has the mechanism). So on the case this bullet is really for — a review someone ran by hand, before any loop existed — the comment names the head at posting time, which on a review that raced a push is a commit nobody read. Skipping there is worse than mis-stopping: you address a review of the old code as though it covered the new. When you have no recorded head of your own, review rather than skip, and read the earlier review as context instead of as this round.

- **Reading PR comments can trip a reply guard, wherever in the loop you do it.** A `gh api` command that names a comments endpoint and also carries a `-f`/`-F` flag reads as a write to the guard, which denies the whole thing — so a fixed-string matcher in the same pipeline gets you a deterministic block over a command that only reads. Use `gh api`'s own `--jq` with a `contains` test. It needs both halves to fire: the same query built on `gh pr view --json comments` is fine, and `grep -cF` passes where `grep -c -F` doesn't, because the guard matches the flag as its own word. This applies to every comment read the loop makes — the round number here, the reviewed head above, and reading a review off the PR in step 2.

## The cycle

One round is a review by the subagent plus an addressing pass by you.

### 1. Dispatch the reviewer

Use the Task tool with `subagent_type: "generalPurpose"`. Not `explore` — the reviewer has to run the suite and mutate code, and a read-only agent can do neither.

**Run it in the foreground.** The loop is strictly sequential, so there's nothing to overlap it with, and a foreground reviewer is what keeps the turn's end and the loop's end the same event. It also keeps you from editing files while the reviewer probes, though that matters less than it sounds: auto-review declines most in-place mutations, so reviewers work in a throwaway clone anyway.

**If a reviewer ends up backgrounded anyway** — the harness forces it in some modes — then end the turn, because that is the only way its result comes back and polling for it is forbidden. Say in that turn that a reviewer is still running, so the done notification isn't read as the loop finishing. When you pick the round back up, expect that its final message may never arrive at all: read the review off the PR instead (step 2).

**Never replace a reviewer you think has died.** Completion notifications are unreliable in both directions — some never arrive, some arrive an hour late, some arrive twice — so "it's been quiet for a while" is not evidence. One loop diagnosed a reviewer dead from its transcript file sitting unmodified for 26 minutes and launched a duplicate; the original had in fact finished and posted its marker, and the duplicate would have posted a second marker for the same head, which is the thing that corrupts the round counter for every later session. Transcript mtime is not a liveness signal — the file doesn't flush continuously — and there isn't a good one, which is the actual reason for the rule. If you genuinely cannot wait longer, check the PR for a marker naming this round before doing anything else; a duplicate reviewer is worse than a slow one.

**Record the current commit SHA in full before you dispatch, and put it in the prompt.** Steps 2 and 4 both need it: it's how you tell afterwards whether the reviewer stayed within its write-denial, and it's the operand of the stopping test. Record all forty characters, so that comparison is against the API's own format and needs no normalising — an abbreviated one has to be resolved first, and `git rev-parse` on a short SHA it doesn't have exits with `fatal: ambiguous argument` while still printing the input back, which reads as success. Telling the reviewer which commit it's on also gives it something to check itself against.

Don't ask it to write that SHA into its marker header instead of the one `deep-review` specifies. The prompt tells it to follow `deep-review` exactly, so an override in the prompt is a contradiction the reviewer has to resolve, and it resolves toward the skill — the loser being the header, silently. You don't need the header: the SHA you recorded is the operand of the stopping test. (Teaching `deep-review` to prefer a SHA it was handed would fix the header too, for every reader of it rather than just this loop, and that's a change to a shared skill rather than to this one.)

**Say how to run the tests, and warn the reviewer off guessing.** A fresh subagent told to "run the suite" will improvise an invocation, and where a wrong guess is destructive rather than merely wrong that costs more than the round — in Substack a bare `mocha` run resolves the development environment and wipes the local dev database. Look the command up and pass it in. Where there's no single command, as here, say how the suite is actually run.

The subagent gets none of this conversation, so the prompt carries everything:

```
You are the reviewer in an orchestrated deep-review loop. You have no memory of
writing this code, and that is the point — reconstruct the intent from the diff,
the PR description, any linked tickets, and the repo's own documents.

Repository: <absolute path to the repo or worktree>
PR: <#number and URL>
Head: <recorded SHA> — the commit you are reviewing. It must still be the commit
checked out when you finish.
Round: <N>. Earlier rounds are on the PR in two forms — each review's own marker
comment, and the addresser's response comment recording what it did with the
findings. Read both, newest first, and check what the fixes for the last round's
findings touched. Expect some rounds to have only the response: a marker can fail
to post, and then the response is the sole record of that round.

Read and follow, in this order:
  1. <absolute path to deep-review/SKILL.md>
  2. <absolute path to the global AGENTS.md you are operating under>

Follow deep-review exactly, including its verify-by-execution step: run the
suite, gut functions to see what stays green, and construct the input that
breaks the claim rather than reasoning about it. Run the tests with <the repo's
test command> — don't improvise an invocation.

This is the user's own PR, so post the marker comment as the skill describes, using
the round number above as the run number. If a hook denies the post, that denial
is deterministic: say so at the top of your final message and don't retry it.

Whenever the marker does not get posted — a hook denied it, or you have a
read-only credential with no comment-write tool, which deep-review's marker step
tells you how to check — put the marker header on the last line of your final
message, alone, prefixed `MARKER-HEADER: `, and I will post it for you. Don't
paste the whole review a second time to achieve this; the header plus the review
I already have is enough.

Probe in a throwaway clone under /tmp rather than mutating this tree, unless a
probe genuinely needs the real one. Cursor's auto-review declines many in-place
mutations of tracked files, and arguing with it burns the round. /tmp rather
than a scratch directory in here because a scratch directory is inside the
branch under review: git's root search stops at this worktree, so anything you
leave in one turns up in the clean-tree check I run when you're done — and an
`add -A` followed by a commit moves HEAD itself.

Don't read /tmp as a sandbox, though. A tool that finds its repo from its own
install path rather than from your cwd reaches the live checkout from anywhere:
`bin/local-config-worktree` does, and redirects a linked worktree to the main
checkout besides, which is how one review created a branch in my live config.
The answer for those is not to run them, not to run them somewhere else.

Expect some probes to be refused, and say so in the review as unverified rather
than routing around it. Installing host packages, broad API sweeps over hundreds
of records, and printing credential-shaped values all get declined, and whether
an install works differs between me and you — so don't spend a round establishing
that. A refusal is usually a nudge to read the mechanism instead of measuring it.

You are write-denied against the repository. Editing tracked files to probe is
expected; producing a durable change is not. Do not commit, push, edit the PR
body, touch labels, or merge. Restore the working tree before you finish, and
say in the review that you did. Your only durable outputs are the marker comment
and your final message.

Do not fix anything you find. A reviewer that fixes things leaves nobody having
reviewed them.

Return the complete review as your final message, in the format deep-review
specifies. Only that message reaches me, so paste the review in full — don't
summarize it or describe what it said.
```

### 2. Check what came back

- **The full review is in the final message.** A summary isn't reviewable. If the subagent described its review instead of returning it, read the marker comment off the PR rather than dispatching a second reviewer.

  **It will usually tell you it pasted the review in full.** The prompt asks for exactly that, so an assurance that it complied is what you'd get either way and isn't evidence — one reviewer returned a summary under the sentence "the review is above in full". Look for the section headings `deep-review`'s format calls for, not for the claim.
- **The marker comment posted.** If it didn't, the loop still runs — you hold the round number and the review text — but the PR has no record of the round. Say so in your response comment, and paste that review into the next reviewer's prompt so the history it would have read isn't lost.

  **Post it on the reviewer's behalf when it couldn't.** Two ways that happens and neither is exotic: a cloud reviewer's credential is read-only, or a hook denied its command. The prompt asks for a `MARKER-HEADER:` last line in both cases. Getting the record onto the PR is what makes round *n+1* cheaper than round 1 — without it every later round is blind to its predecessors, and a resuming session sees a loop that never happened.

  Two things the header alone won't give you, and both fail silently. The comment has to **open with `<!-- deep-review-marker -->`**: `review-loop-state` reads the first non-blank line, so one opening with the `<sub>` header counts as no marker at all. Your own response comment names the run, so the round count survives that — what you lose is the review's text as a record the next round can read. And the command needs the `DEEP_REVIEW_SKILL=1` prefix, or `guard-no-reviewer-reply.sh` denies it as a top-level comment. That guard reads command shape rather than who is running it, which cuts the way you'd expect: same shape, same verdict, so a hook that denied the reviewer denies you too unless you add the prefix. It's only the read-only-credential case that makes the reviewer's failure not yours. Copy the body shape from `deep-review`'s marker step rather than building it from the header you were handed.
- **HEAD is the SHA you recorded, and the working tree is clean.** Check both. The tree catches a probe the reviewer didn't restore; the SHA catches the failure that matters, because **a reviewer that commits its own fix leaves a perfectly clean tree.** Expect the tree half to be quiet in practice — auto-review declines most in-place mutations, so reviewers probe in a throwaway clone — and the SHA half to be the one doing work.
- **Know where the guarantees stop, and don't try to enumerate them.** This check sees the tree and HEAD, so it catches a commit. Everything a reviewer could do to the PR itself — merge it, mark it ready, close it, retitle it, change its labels, edit its body over the API, even delete the remote branch with an ordinary push — moves neither, so the prompt telling it not to is the entire defence. The hooks stop some of those on some paths and none of them on all paths, and that boundary moves whenever a hook changes, which is why the mechanism is the thing to remember rather than the list.
- **If the tree is dirty, the discriminator is whether it looks like a probe.** A probe — a gutted function, an emptied file, a flipped constant in a file the review discusses — you restore before touching anything, because addressing findings on top of a mutation is how you commit one. Anything else is somebody's in-flight work: leave it exactly as it is, don't restore or stage it, and surface it. Same if HEAD moved.
- **Treat the review's evidence as claims, not transcripts.** Only the reviewer's final message reaches you, so a measurement it describes is unfalsifiable from where you sit — and a plausible-looking block of command output may be a summary written to look like one. Re-run anything a finding turns on; that is how each round here has found the previous round's mistakes.
- **If neither the final message nor a marker carries the review, that round didn't happen.** Re-dispatch at the same round number rather than addressing what you can remember of it. Each of those two is the other's fallback, so losing both is the one case where there's nothing to work from.

### 3. Address the findings

Follow `address-deep-review`. It owns the triage — which findings to take, which to decline, the acceptance rate you state every round, the second-order sweep, and the response comment. Don't re-derive any of that here. The one thing restated below is the stopping rule itself, because deciding when to go again is this skill's job rather than the addresser's.

Three things this skill adds on top:

- **You are the author as well as the addresser**, which biases you in a direction the addresser alone isn't. You know what you meant, so a finding that misread the code reads as simply wrong — when often the code is what misled it. When you're about to decline on "that's not what this does", ask what the reviewer was looking at when it concluded otherwise.
- **Report each round as it lands** — round number, findings, taken / settled / declined, and the SHA you pushed or `none`. One line, no question attached.
- **Delegating the addressing pass to a subagent is allowed**, and on a large repo it is often the only way to finish. The separation this design depends on is reviewer ≠ author; handing the addressing work to a subagent doesn't weaken that, because the subagent is still not the reviewer. Do it when a review comes back several thousand words and you can see the context running out. It buys less than it looks like it will — one loop delegated every addressing pass and still escalated on context at round 2 of 5 — so treat it as a way to get further, not as a fix for starting the loop in a spent session.

  Hand it the review in full, `address-deep-review`, the repo path, the PR number and the round number, and the SHA you recorded. The number and the round matter because its response header is `responded to run N`, which is what `review-loop-state` counts — a subagent left to work either out is counting rounds by hand, which this section already forbids. Say the response comment is its job: that skill puts the comment, the acceptance rate and the second-order sweep on "you", and a delegated pass silently owns all three. The author bullet above is the one that doesn't transfer, and that cuts both ways — a subagent carries none of your bias toward the code, and none of your knowledge of what you meant by it, so a finding that turns on intent is worth resolving yourself before you hand the rest over. Run it in the foreground, for the same reason the reviewer runs there: a backgrounded addressing pass ends your turn mid-round.

  On return, read the response comment it posted and the SHA it pushed rather than its account of them. Step 2's HEAD check inverts here, because this subagent is *supposed* to have moved HEAD, so that comparison belongs to step 4 instead. The tree half still holds: it committed and pushed, so anything left dirty is residue.

### 4. Decide whether to go again

> **The loop ends on a round that produces no commit** — every finding declined or already settled — with local checks and CI green on that head.

That's the whole stopping rule. What it's really testing is that the head the reviewer examined is the head that will merge — no commit of your own is the common way that happens, but it isn't the same statement, so check the SHAs rather than inferring it. The certification comes from the reviewer, on the final state, and any round that produces a commit invalidates the review that prompted it.

- **Commit pushed → go back to step 1** with the round number incremented.
- **You moving the head for any other reason counts as a commit too.** A rebase onto a fresher trunk is the case that comes up — sometimes you need one mid-round just to get the suite running, so it isn't avoidable — but it replaces every SHA the reviewer read, which is exactly what the test below is looking for. Don't reason that it "wasn't a fix" and stop anyway. Verify the rebase preserved the diff by diffing the new tip against the pre-rebase tip across the PR's own files, which is [`merge-stack`](../merge-stack/SKILL.md)'s tip-vs-tip step; it also carries the two things that make the result readable — it is expected to be empty or trivially explainable rather than literally empty, and on a branch whose conflicts you resolved the diff can't be the gate at all. Then say in the response comment that you rebased and why, and treat the round as commit-producing.
- **Nothing pushed → compare the SHA you recorded at dispatch against the PR's head now** (`review-loop-state <pr> --recorded <sha>` does it, and reports `moved: no` when they match). Equal means the head the reviewer was pointed at is the head that will merge, so stop — and don't dispatch another reviewer against it, since reviews aren't deterministic and re-reviewing an unchanged head produces a different list and restarts the cycle for nothing. Different means something else landed during the round — the user pushing, a base merge, another agent — and you'd be certifying a head nobody read, so go again. `review-loop-state` normalises for you: a recorded SHA is usually short — comment headers carry nothing else — and it matches any abbreviation of seven characters or more against the full head. Below seven it answers `unknown` rather than guessing, because that is shorter than git would resolve either. **Treat `unknown` as moved**: it means the comparison did not happen, and stopping on a comparison that did not happen certifies a head nobody read. Re-record a longer SHA and ask again if you want the real answer. Don't normalise by hand with `git rev-parse`: handed a short SHA it doesn't have locally, it exits with `fatal: ambiguous argument` and prints the input back, which reads as success.
- **Use the SHA you recorded, not the one in the marker header.** The header looks like the authority on what was reviewed and isn't: `deep-review` fills it from a live read of the PR's head at the moment it posts, so if the user pushed mid-round the header carries the *new* head. It would agree with the post-push head and hide precisely the case this test exists to catch. The recorded SHA is the one you observed yourself, and it still exists when the marker never posted at all.
- **Never substitute your own memory of whether you pushed.** "I didn't commit anything" is a claim about you, not about the head.
- **CI: check it on the terminating round, not on every round.** Mid-loop it's wasted wall clock, because the next commit invalidates it anyway. **Zero required checks is a pass, not a wait** — `gh pr checks` exits non-zero when a repo reports none at all, which is the normal case wherever workflows don't run on PRs, and reading that as "not green" holds a stop that can never clear. Where there are no checks, the local ones carry the signal.
- **Round cap of five, then hand back.** The cap only overrides a verdict that would otherwise continue — a fifth round that reaches a clean stop stops clean rather than being escalated for having taken five. `address-deep-review` has the cost argument behind the number.
- **At the cap, a real finding that isn't must-address gets filed, not fixed.** The terminal round's awkward shape is no must-address findings sitting beside a handful of one-line defects that are genuinely worth having, including one the reviewer says it would take first. Take any of them and you ship a head nobody has read, with no round left to read it — so file them and hand them back, and say in the response comment that you did. Remember what the size of those edits is worth: "small and safe" is exactly what an addressing pass's own injected defects look like from the inside, which is the reason this loop has rounds at all.

**The reviewer's own another-round verdict is advisory.** It sits at the top of the marker header, in plain English, written by the agent that just read everything — and this test decides anyway. A reviewer's all-clear is not a stopping criterion: the case this whole design is built on is a round whose review said no further round was needed, followed by one that found a reachable must-address.

Note what the rule does to over-compliance: an addresser that takes every finding commits every round, so it can never terminate. That's deliberate. It converts the quiet failure of agreeing with everything into a visible non-terminating loop.

## Escalate instead of continuing

Six conditions end the loop early. Each one ends your turn: say which fired, report what the loop did, and stop.

**"Stop" means after the current round's addressing pass, not instead of it.** A round is a review plus an addressing pass, so a condition that fires once the review has landed leaves findings sitting unaddressed — and "stop now, leave them" and "finish addressing, then stop" are both readable in a bare "stop". Finish the pass — or the rest of it, for a condition that fires part-way through one — then stop; that is the same round boundary the context condition below means. The head that pass ships is by definition unreviewed, so say what went into it when you hand over. Two of these conditions trigger on an inability to do the work this is asking for, so if it's context you're short of, delegate the pass (step 3) rather than skipping it.

The pivot verdict is the one exception. There, finishing the pass means committing and pushing onto code whose shape is the open question — which is the decision you're handing over — so stop on that one without addressing, and say what you left unaddressed.

**Stopping without addressing is not stopping without checking.** Escalating forfeits every round that was left, and a pivot can arrive in round 1, which spends the entire budget — so verify what the different-approach section rests on before you put it in front of the author, exactly as step 2 says to for any finding. A pivot argued from a mechanism that doesn't hold, or from a repo state that has changed since the reviewer looked, is a finding to answer in your response comment rather than a decision to hand over. Record the outcomes as `deferred` rather than `declined`; `address-deep-review` owns why that word and not the other one.

- The round cap is reached.
- **Any must-address finding recorded as declined in any response comment on this PR**, checked at the point where the round would otherwise stop clean. Declining one without a reproduction refuting it is forbidden outright, so that case never reaches here; declining one *with* a reproduction is legitimate, and still can't be the thing that ends the loop, because in a single session the addresser writing that reproduction is also the one grading it. Escalating the moment any must-address is declined would instead forfeit the remaining rounds over one refutable claim out of a dozen, and closing the "decline everything" exit doesn't need that: a round that declines everything produces no commit and would stop clean, which is exactly when this fires.

  **`review-loop-state` reports these**, and reads them the way you'd have to: per-finding rows, not header counts. A decline from round 2 has to still count in round 5, so recollection won't do — that's how a fresh session resumes, sees one clean round, and terminates through a decline nobody refuted. But the header's counts can't answer the question either: a round that refused half of a must-address can honestly report zero declines there, because the half-take is a single row with a single outcome. The severity and outcome columns are what you scan.

  A partly-refused must-address counts here, because the half you didn't take is a decline wearing a different label. `address-deep-review` owns that record's vocabulary and doesn't yet have a word for it, so until it does, the reliable way to keep a half-take visible is to record the untaken half as its own declined row.

  **An escalation clears once the author has answered it.** This condition names a state, and left alone a state never resolves — one partly-refused must-address in round 2 would otherwise block a clean stop on that PR forever, including for every later session. So a decline that a previous escalation already handed over stops counting once the author's ruling is recorded on the PR. What escalates is the finding nobody has ruled on yet.

  **That last part is yours, not the script's.** `blocking_must_address` reports every must-address ever recorded declined on the PR and nothing removes one — a later `taken` row does not, because finding numbers are round-scoped and round 5's finding 2 is not round 2's. So read it as a list of declines to check, and decide for each whether the author has already ruled on it. A reader who treats a non-empty list as "escalate" escalates on settled findings forever.
- The review's Step 2 concluded the change should pivot. A different-approach finding is the author's call and always was.
- You can neither reproduce nor refute a finding.
- CI is red for a reason outside the diff — a broken base, a flaky suite, a missing secret.
- **You're running out of context** — the one condition particular to running this in a single session. Every round adds a full review plus its addressing work to this conversation, and five rounds of that is a lot. Stop at a round boundary and hand over: the PR's markers and response comments hold the entire state of the loop, so a fresh session picks it up at the next round with nothing lost.

Uncommitted work you didn't make is the other reason to stop, and it isn't on the list because it can turn up at any point rather than at a round boundary. Step 2 has the discriminator; what's specific here is that you must not hand a reviewer a tree containing it, because its probes would measure that work alongside yours and its restore could revert it.

## What stays the user's

**Stopping is not merging.** The loop drives a PR to a defensible stopping point and says so. Don't mark it ready, don't merge, don't touch labels, don't force-push, and don't reply to a human reviewer other than the user. Report the stop, the round count, and the PR URL.

## Finish with a retro

Once the final report is delivered, run `task-retro` over the whole loop — reading it from `~/.claude/skills/task-retro/SKILL.md`, since it sets `disable-model-invocation` and so won't appear in your skill list. If it isn't on disk either, say so and suggest the user run the retro themselves rather than improvising one.

This is unusually good retro material. Most tasks give one pass over a skill; this one gives up to five passes over the same two, so friction shows up as a pattern instead of a one-off — and the orchestration itself is in scope, not just the skills it drove. Prefer the background self-fork `task-retro` describes (the Task tool with `resume: "self"` and `run_in_background: true`) so the retro doesn't consume what's left of this session's context, and end the turn after spawning it.
