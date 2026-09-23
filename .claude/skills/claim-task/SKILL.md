---
name: claim-task
description: Pick up the next piece of work in a repo where several agents work in parallel, without two agents taking the same task or colliding in the same files. Covers choosing from the queue, claiming a task so others can see it is taken, handing finished work off for review, claiming somebody else's work to review it, and reclaiming a task whose agent died. Use whenever you are about to start work in a repo that has the task-queue issue fields, when asked what to work on next, when you finish a task, or when you are asked to review another agent's PR.
---

# Claim a task

## When to use

Any time you're about to start work in a repo that carries the queue fields, and any time you finish. If you're asked "what's next?", or you've opened a PR and want it reviewed, or you've been sent to review somebody else's, this is the protocol.

Check the repo has the fields first. `list_issue_fields` returning `[]`, or returning a set with no `Queue` in it, means the queue was never set up here — creating fields needs a human in the org or repo settings, so say that and stop. Don't improvise a parallel scheme out of labels or body prose in the meantime: a second queue nobody else reads is worse than no queue.

## The five fields

Work items stay GitHub Issues. These sit on the issue as custom fields, so the queue is a query rather than a board somebody reads by eye.

| field | type | written by |
|---|---|---|
| `Queue` | single-select | agents, as work moves |
| `Priority` | single-select | whoever triages — `Urgent`, `High`, `Medium`, `Low` |
| `Blocked by issue` | text | triage — `"134 96"` |
| `Touches` | text | triage — space-separated paths |
| `Claim` | text | the agent holding it right now, cleared when nobody is |

`Queue` is `Triage` · `Waiting for input` · `Ready` · `In progress` · `Needs review` · `Under review` · `Ready to merge`.

There's no `Done` — closed is done. A field that can disagree with the issue's own state will.

**Only `In progress` and `Under review` have a holder**, so those are the only two states where `Claim` should read anything. `task-queue` says the same in its own source — *Needs review and Ready to merge are held by nobody, by design* — and reports a held state with an empty `Claim` for exactly that reason. The inverse is the one it cannot report and the one that misleads: a session id sitting on a state nobody holds.

There's no `Blocked` either, and no `Changes requested`; both are below.

`Ready to merge` is where agents stop. You can't approve or merge, so it means the work is finished and waiting on a human.

## `Waiting for input`

The other place agents stop, and the one that was missing. `Ready to merge` is work that is finished and needs a person; this is work that cannot **start** until a person does something — rules on a design question, runs a study with real respondents, changes a setting only they can reach.

Without it those issues park in `Triage`, where they are indistinguishable from an arrival nobody has sorted yet. Measured on a real board: every pickable issue read `Low` while all three `High`s sat in `Triage`, and not one of the three was untriaged — they were waiting on a ruling, a think-aloud with real respondents, and a design call the issue itself named as one. A reader seeing `Triage` reasonably concludes triage has not run. Here they see that it has, and that the answer was "not until you decide".

**It holds no files.** Nothing has started, so there is no branch, and its neighbours in that respect are `Triage` and `Ready` rather than `Ready to merge`. Both states wait on a person; only one of them has work behind it. This matters in one direction only, and it is the direction that does damage: **finished work goes to `Ready to merge`, never here**, because putting it here releases the files of a branch that is still out there. An agent that has opened a PR has no business in this state.

**An agent may move an issue here, and that is the point.** Pick something up, find that it turns on a question you cannot answer, and this is where it goes — with a comment saying what you need decided. That beats the two alternatives it replaces: leaving it `In progress` holds files for work nobody is doing, and putting it back to `Ready` hands the same dead end to the next agent. Do it only while you still have nothing to show; the moment there is a branch, the work is reviewable and belongs on the review path instead.

**A human moves it out**, into `Ready` once the thing it waited on has happened, or closed if the answer was that the work should not happen. No agent moves it out, and `task-queue` will never hand it to one.

It earns a state where `Blocked` did not, and for the reason that section gives: a `Touches` collision is undirected and temporary, so a stored flag for it is stale minutes later. Waiting on a person is neither. It is as durable as `Blocked by issue`, it stays true until somebody acts, and nothing computes it — so there is nowhere else for it to live.

## Picking

Fetch every open issue with its fields, normalise, and let `task-queue` decide:

```
list_issues(state=OPEN, fields=["number","title","state","field_values"])
  → [{number, title, queue, priority, claim, blocked_by:[…], touches:[…]}]
  → task-queue next --issues <file>
```

**`Blocked by issue` and `Touches` are single text fields, so splitting them on whitespace is the normaliser's job** — `"134 96"` becomes `[134, 96]`, not `["134 96"]`. Forgetting is the likeliest bug in this step, so `task-queue` reports an entry that still carries a space rather than reading past it. Pass `Claim` through too: it is what tells the tool an in-flight issue is held by nobody.

`task-queue` sits beside this file. Run it rather than reasoning it out yourself — two agents waking seconds apart have to reach the same answer, and the only way that holds is one implementation. `task-queue why <issue>` explains a single one.

An issue is pickable when its `Queue` is `Ready`, every `Blocked by issue` is closed, and its `Touches` don't overlap anything in flight. Highest `Priority` wins, then lowest issue number — an unset or unrecognised priority sorts last, and an unrecognised one is reported, because a scale nobody declared is not a scale.

`Queue` is read case-insensitively too, so `In Progress` is that state rather than a typo for it. A value outside the seven holds its files anyway and is reported: a typo that serialises work costs throughput, while one that frees a lock puts two agents in the same file. `Blocked by issue` is a text field, so `task-queue` takes its numbers written either way; anything it genuinely can't read it refuses by name rather than reading past.

**Two kinds of blocked, and only one is stored.** `Blocked by issue` is directed and durable — B needs A's output, and that's true regardless of what anyone's doing right now. A `Touches` collision is undirected and temporary — neither task needs the other, they just can't run at once, and whoever claims first holds it. So `Blocked by issue` is a field and the collision is computed. There's no `Blocked` status, because it would be stale minutes after it was set.

**Everything from `In progress` onward holds its files.** The branch is unmerged in all four states, so a second agent branching off the default branch would collide at merge instead of at pick time. `Ready to merge` is the one that looks safe and isn't — the work is finished, and the branch is still out there. `Triage`, `Waiting for input` and `Ready` hold nothing, being the three with no branch behind them: two `Ready` issues naming the same file are both genuinely pickable, and whichever is claimed first locks the other out at that moment rather than in advance.

A queue that stalls because a finished PR is waiting on a human is telling you something true. Unblock the human; don't model the branch as though it had landed.

## Claiming

No GitHub field write is compare-and-swap, so two agents can both set `In progress`. Don't pretend otherwise — resolve it instead.

1. Comment `<!-- claim:<session-id>:<state> -->` on the issue, where `<state>` is the state you're moving it into — `In progress` to work it, `Under review` to review it.
2. Set `Queue` to that state and `Claim` to your session id.
3. Re-read the comments and settle the tie:
   - **Only markers naming the same `<state>`.** An issue reaches `Needs review` by having been worked, and the worker's `In progress` marker sits there forever. A reviewer racing that marker loses every time, on every review, with no race involved.
   - **Ignore a marker that is both older than the stale window below and unbacked** — `Claim` does not name its session. Both halves are load-bearing: the age is what keeps a live contender in the tie however the field happens to read at the moment you look, and the field is what stops a session that died between steps 1 and 2 winning every tie for the life of the issue. You cannot tell from the board whether a session never wrote `Claim` or wrote it and was overwritten — there is no history on a text field — so don't write a rule that needs to know. The age gate is what makes the distinction unnecessary.
   - Of what's left, **the earliest wins.** Timestamps come from GitHub, so nobody can win by asserting a better one.

   **Won?** Make sure `Claim` names you — a rival's write may have landed after yours — and go to step 4.

   **Lost?** Clear `Claim` only if it still names you, **leave `Queue` where it is**, and pick something else. Don't re-pick this issue: the board hasn't changed and `task-queue` is deterministic, so you'd be handed it again.
4. Create the ref for the state you claimed: `claude/issue-<N>` to work it, `claude/review-<N>` to review it. Creating a ref is genuinely atomic — a second agent creating one that exists is rejected — so a race that slipped past step 3 still can't produce two agents silently doing the same thing. **If creating it is rejected, you lost:** re-read before changing anything, then follow the "lost" branch above.

**Why a reviewer creates a different ref.** By the time an issue reaches `Needs review`, `claude/issue-<N>` exists — the worker made it and the PR is on it. A reviewer told to create *that* one is rejected every time, on every review, and under the rule above would conclude it had lost and hand the issue straight back; the review half of the queue would never run at all. `claude/review-<N>` gives the review claim the same guarantee the work claim has: one name, a pure function of the issue, one creator. It is a lock and nothing else — the reviewer commits to the PR's own branch as usual, and no rule here ever reads the lock ref again.

**Why a loser must not revert `Queue`.** Both contenders are writing the *same* `Queue` value, so the field is right whichever write lands last — the only way it goes wrong is a loser putting it back. A loser that reverts to `Ready` releases the files of a task somebody is actively working, and on the review path releases a task with an open PR and an unmerged branch. Leave it: somebody holds this issue, and the state says so.

**Why the tie is read this way, and what it still costs.** The filter has to ignore dead markers without ignoring live ones. Keying it on `Claim` alone can't: `Claim` holds one session id, so at most one marker would survive and "the earliest wins" would never arbitrate anything — the winner would just be whoever wrote the field last, which is the non-atomic write this section opens by refusing to trust. So the filter needs *both* halves, and a marker minutes old is never ignored however the field reads.

What remains is a state the board can reach and no rule here undoes on its own. A claimant that dies at step 1 leaves a marker that keeps winning ties, and the next agent to try will have moved `Queue` into a held state at step 2 before losing to it. The issue is then in flight, holding its files, with `Claim` empty and nobody working — until the stale window passes and someone reclaims it. That is worse than the wasted picks it replaced, and it is still the right trade, because the alternative is a loser reverting `Queue` out from under a live winner.

What makes it survivable is that it is **visible**: feed the `Claim` field to `task-queue` along with the rest and it reports the state by name — `#5 is In progress with no Claim, so it holds its files and nobody holds it`. An issue in that shape is waiting for the reclaim rule below, not for an agent.

**The comment goes first, and the branch name carries nothing but the number.** Both are about what happens when a step doesn't run. Dying after 1 leaves a marker the stale half of the tie-break clears. Dying after 2 leaves `In progress` with no marker, and since the marker is the clock the stale-claim rule would have nothing to measure, so the issue would hold its files forever — that is the one to avoid, so the cheap write goes first. And a `<slug>` on the branch would make step 4's guarantee depend on two agents inventing the same words: `claude/issue-42-fix-the-parser` and `claude/issue-42-parser-fix` are two refs and both get created. The number is the only part that's a function of the issue, so it's the only part in the name.

## Finishing, and review

Open the PR as a draft, then set `Queue: Needs review` and **clear `Claim`**. **Don't review your own work** — leave it and pick something else.

Both writes say the same thing and neither says it alone: the state says the work is done, the empty field says nobody is holding it. Leaving your id there costs nothing until the `Queue` moves under it — an issue reaching `Under review` with no `Under review` marker, no `claude/review-<N>` ref and no review on its PR reads like a reviewer who claimed it properly, because the stale id is the only thing a reader sees. An empty `Claim` makes that drift obvious at a glance. Clearing races nobody: no rule here reads `Claim` in a state that has no holder, and `Needs review` locks its files through `Queue` rather than through `Claim`, so nothing is released by emptying it.

Reviewing is a claim like any other, and "like any other" means **run all four steps above** with `Under review` as the `<state>`. Take the highest-`Priority` `Needs review` issue and claim it that way, then run the review. Skipping the comment is what makes the next paragraph false.

The `<state>` in the marker is what keeps this honest: your tie is with other reviewers, not with the agent who did the work and whose `In progress` marker has been on the issue since it started. And a lost review claim leaves `Queue` alone like any other, because the winner is moving it to `Under review` too. Putting it back to `Needs review` would be worse here than on the work path: that state is the unlocked pool, so it advertises a live reviewer's issue as free.

**Reviewing and fixing are one claim, not two.** The reviewer runs the whole loop — review, address the findings, re-review — until a round comes back clean, then sets `Ready to merge`. That's why there's no `Changes requested` state: "the reviewer found something" is the exit condition of a round, handled inside the loop, and no other agent ever needs to see it. A state nothing rests in is noise on the board.

If the reviewing session dies mid-loop the issue sits at `Under review` and the stale-claim rule below takes it. That rule covers the two states an agent holds while working, `In progress` and `Under review`, and only those. `Needs review` recovers differently — it is nobody's claim, so the next reviewer simply takes it from the pool — and `Ready to merge` deliberately recovers not at all, because it is waiting on a human rather than stalled.

## Reclaiming a dead task

Containers die mid-task and leave an issue held forever. A task is reclaimable when all three hold: `Queue` is `In progress` or `Under review`, the clock below reads more than **4 hours**, and no open PR is being actively pushed to.

Claim it the same four ways, saying in the body of the marker which session you're taking over: comment `<!-- claim:<session-id>:<state> -->`, overwrite `Claim` with yours, **settle the tie at step 3**, then step 4.

Step 3 is not optional here and it is the most contended claim there is — a task that has been stale for four hours is visible to every idle agent at once, so two of them reclaiming at the same moment is the expected case rather than the unlucky one.

**Step 4 adopts the ref rather than reading it as a rejection.** Usually it exists, because the session you are replacing made it — so finding it there is not the rejection that means you lost. **Create it if it is not there:** a session that died before step 4 never made one, which is exactly the case that leaves a state held with `Claim` empty. That is the one exception to step 4, and it is safe because the three conditions above have already established that the holder is gone.

**A reclaim posts the same marker everyone else does**, and that is the point — there is one marker shape on the issue and every rule reads it. A distinct `reclaim:` marker would leave a reclaimed task with nothing the tie-break recognises, so the next claimant would see only the dead original, find no `Claim` behind it, and take an issue a live session is working. It also wouldn't need the substring care that two prefixes do: `claim:` is a substring of `reclaim:`, so any rule matching the short one counts both.

**The clock is the newest marker on the issue**, not the first. Yours becomes the newest the moment you post it, which is what stops a third agent reclaiming your work four hours after the session you replaced went quiet. It also means a third agent arriving between your comment and your field write sees a fresh clock and correctly leaves you alone. A comment is the clock at all because the `date` field type only goes to the day — too coarse for hours, and it would be a time the agent asserted rather than one GitHub observed.

The cost of reading it that way: **a claim that was attempted and lost still moves the clock**, because the marker went up at step 1 before the tie was known. So a contested issue can take up to another four hours to become reclaimable. That is the same trade as above — a clock that only counts winners would have to be written after the tie, by which point a dying session leaves nothing to measure.

## Writing `Touches` well

This is where the system is won or lost, and it's a triage job rather than something you can infer while working.

**Name files, not directories, wherever you can.** Two issues in `scripts/checks/rules/` editing different rule files are genuinely independent. Glob the directory and you invent a collision that serialises work that could have run side by side.

**Don't list docs.** Every PR in a busy repo touches the same changelog or notes section. Put it in `Touches` and nothing ever runs in parallel. Append-only prose conflicts textually and resolves by keeping both paragraphs; source conflicts semantically. Only the second is worth a lock.

**No brace expansion.** `rules/{a,b}.mjs` is read as one literal path and matches nothing. List the two files.

A trailing `/**` or `/*` is stripped, and the rest is matched as a path prefix on segment boundaries — so `packages/core` reaches `packages/core/x.ts` and not `packages/core-web/x.ts`.

## Priority

Priority is set at triage, not by the agent picking work up. If something is unset it sorts last, so forgetting to set one can't promote a task to the front.

What decides it, roughly in the order it applies: what unblocks the most goes first; a narrow `Touches` beats a broad one, because a broad one stops everything else; a check that's green but blind outranks new surface; a decision outranks the code it gates; anything with a real expiry outranks anything without one.

Four buckets can't express a full sequence, and that's accepted rather than overlooked. The dependency graph carries the important half — "what unblocks the most goes first" *is* the `Blocked by issue` edges, and those are enforced hard, so what priority decides is only the order among issues that are all genuinely pickable right now. Getting that order wrong costs throughput, not correctness.
