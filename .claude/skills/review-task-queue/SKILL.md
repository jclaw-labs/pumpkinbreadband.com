---
name: review-task-queue
description: Use when continuously reviewing implementation work from a profile-backed repository queue, especially when claiming Needs-review issues, running deep-review loops, reviewing PR stacks bottom-up, waiting for merges, or monitoring for the next review.
---

# Review a task queue

Continuously turn truthful `Needs review` work into reviewed merge handoffs. One validated profile
and the complete live queue and PR graph are the inputs; reviewed owner handoffs, stack
subscriptions, and an armed reviewer monitor are the outputs.

## Ordered workflow

### 1. Load dependencies and validate the profile

Read and follow these dependencies before touching the tracker:

- [`steward-task-queue`](../steward-task-queue/SKILL.md) for profile resolution, validation,
  backend access, live-input completeness, and monitoring.
- [`claim-task`](../claim-task/SKILL.md) for eligibility, claim arbitration, Queue transitions,
  Claim, and file-lock rules.
- [`deep-review-orchestrate`](../deep-review-orchestrate/SKILL.md) for the complete review and
  addressing loop, its current-head stop rule, and escalation conditions.
- [`stacked-pr-rules`](../stacked-pr-rules/SKILL.md) for stack navigation and landing safety.

Derive each dependency's skill directory from the path used to read its `SKILL.md`. Derive every
executable path from that directory: in particular, use the validator and backend adapter beside
`steward-task-queue`, the `task-queue` and replay executables beside `claim-task`, and review-loop
helpers beside `deep-review-orchestrate`. Never assume the current working directory or copy an
executable into this skill.

Fresh-read this reviewer session's identity at role startup and run
`<claim-task-skill-dir>/task-queue validate-session --session <session-identity>`
before tracker access, selection, or any marker, `Queue`, `Claim`, or generation-ref write.
Require exactly one identity and fail closed if it is missing or is not a `claim-task` session
token. Keep that validated token unchanged for `--reviewer`, every claim marker, Claim event,
settlement caller, and ref-authority check in this role.

Resolve and validate exactly one repository profile through `steward-task-queue`. Stop before
tracker access on a missing or invalid profile, unsupported mutation capability, or failed
preflight. Use that profile for every subsequent read and write.

For a GitHub profile, apply this requirement:
Apply `steward-task-queue`'s Cursor Cloud GitHub credential contract before tracker access.
Keep that credential on every queue read and write.

### 2. Fetch the complete live inputs

Use `steward-task-queue` to fetch the full current issue set and complete PR graph, including
Queue metadata, activated generations, scoped Claim events, blockers, exact `Touches`, required
issue labels, owner links, full stack descriptions and bases, changed files, current head
revisions, CI, reviews, draft state, and merge state. Include merged changes whose owners still
need reconciliation.

Normalize through the profile's backend adapter and `claim-task` replay path. Fetch every exact
base and head from the live provider; never fabricate a revision or substitute one remembered
from an earlier tick. Derive each issue's complete stack ancestry from the live PR graph and
owner links rather than from Touches or remembered navigation. Re-fetch before every selection
and after every event.

### 3. Select one eligible review

Resolve the live PR/owner mappings into each issue's complete `stack_ancestors` list before
selection. Fresh-read every candidate's implementation author/session identities and this review
session's identity from live issue, PR, and session data before selection or any marker, `Queue`,
`Claim`, or generation-ref write. Normalize every `Needs review` record with:

- `implementation_authors`, a unique, nonempty array of session tokens;
- `runtime_target`, read from the owner's open implementation PRs' agent context blocks: run
  `agent-provenance body-record --body <fresh-PR-body-file>` on each PR and take the recorded
  `target`, or `null` when a block records none. When an owner has several PRs, use
  `both` if any says `both` or they name both `cloud` and `local`, otherwise the one named
  environment, otherwise `either`, otherwise `null`. A failed `body-record` means that PR's block
  is missing or malformed. Omit the field when any PR's block is missing or malformed, and give
  the record a `normalization_error` naming that PR, so it fails closed while the steward reports
  it; and
- the validated review session token as a separate executable input.

Pass this session's runtime as `--runtime`: `cloud` when the authoritative provenance source
reports a Cloud environment, `local` when it reports Local. That source is the one
`agent-provenance` names for this harness. Never infer it from the prompt, and stop before
selection when the environment is unknown, including in a harness that has no provenance adapter.

Pass the validated review session token only as `--reviewer`; do not put
`review_excluded` in the input. On a record-local replay or authorship failure, include that issue
with a nonempty `normalization_error`, preserve its live Queue and exact `Touches`, blockers, and
stack ancestry, and omit the Claim, generation, or authorship that could not be established while
the steward repairs it. The executable makes only that record ineligible while its live Queue
continues to hold its files, so valid siblings remain selectable in the same pass.

Do not fabricate `implementation_authors`. If complete live evidence cannot recover authorship,
write no review claim or PR mutation; preserve its locks during repair and have the steward return
the owner through a fresh `Ready` generation. A worker adopts or verifies the existing PR and
later creates a truthful `Needs review` handoff. This is recovery through executable generations,
not an exception to self-review exclusion.

Fail closed for the whole normalized snapshot on incomplete live input, missing or ambiguous owner
mappings, malformed ancestry, an ambiguous reviewer identity, duplicate JSON object keys, invalid
normalized field types, or a stack cycle. After every candidate has either trusted normalized
authorship or an explicit record-local error, run
`<claim-task-skill-dir>/task-queue next --queue "Needs review" --reviewer <review-session-identity> --runtime <cloud|local>`
on the complete normalized issue set. The executable derives `review_excluded` by exact membership
of `--reviewer` in `implementation_authors`. Choose only the highest-priority eligible `Needs review` result
and accept the executable's directed stack, blocker, collision, self-review exclusion, priority,
and deterministic tie-break decisions. Never turn a computed dependency, `Touches` collision, or
unmerged stack parent into an invented Queue state.

The executable leaves a self-authored record ineligible with the reason
`self-authored implementation is excluded from review`, while preserving its unmerged file locks.
Write no marker, `Queue`, `Claim`, or generation ref for an excluded record. Because every
candidate is annotated before selection, one executable pass selects the next eligible
non-self-authored item. If `.next` is `null` because all review candidates are excluded, go to
section 10 without writing review state.

Runtime compatibility works the same way. A record this runtime cannot certify — `local` work for
a Cloud reviewer, `cloud` work for a Local one, and `both` work for either — is ineligible with a
reason naming the runtime it needs, keeps every file lock, and stays unclaimed in `Needs review`
for a compatible reviewer's own pass. Write no marker, `Queue`, `Claim`, or generation ref for it,
and do not post-filter results in prose; the next eligible record is already selected.

### 4. Claim the activated review generation

Use `claim-task`'s complete review-claim protocol with the active generation for this
`Needs review` visit: write the generation-scoped marker, enter `Under review` with scoped Claim,
re-read authority, and run `<claim-task-skill-dir>/task-queue settle`. Converge Claim exactly as
that dependency directs.

Only after settlement names this session as winner, create its generation-specific lock ref
`claude/review-<N>-<generation>`. On a lost settlement, do not change Queue or begin review;
follow `claim-task`'s losing path and select again from fresh state. Run `claim-task`'s
**Rejected generation-ref protocol** unchanged after any rejected generation ref.

### 5. Resolve the owner PRs and stack

Resolve every live PR to exactly one owner issue. For a stack, read the complete synchronized
change-set navigation and traverse bottom-up. Apply `stacked-pr-rules` to each PR against its
landing base; a slice that depends on a later PR to build, test, or remain coherent is not ready
for review.

Fail closed on missing owner links, incomplete navigation, stale bases, or ambiguous stack shape.
Separate governing instructions may authorize PR-description repair only; PR-label writes remain
unconditionally forbidden.

### 6. Review the bottom unmerged PR

Select the bottom unmerged PR only. Fetch its exact current base and head, make local and remote
heads agree, and run `deep-review-orchestrate` through its clean current-head stop or a named
escalation. Tests and an old approval do not review a newer head.

After a clean review, go to section 7. Do not review a child while its reviewed parent remains
unmerged: subscribe and wait for that PR to merge before selecting the next PR in the stack.

### 7. Hand off a clean current head

Treat an inspectably live merge monitor as a hard precondition for any `Ready to merge` handoff.
First attempt the product-native PR merge subscription. If native setup is unavailable or fails,
start one inspectable persistent fallback monitor at the validated profile's
`cadence_minutes.merge_monitor` and verify its handle is live. Monitoring becomes armed only after
the native subscription setup succeeds or the fallback handle is verified live.

If neither setup path succeeds, do not perform any `Ready to merge` handoff write: keep Queue
`Under review`, keep the scoped `Under review` Claim, preserve exact `Touches` and required issue
labels, report the merge-monitor capability gap, and remain in a live retry/monitor loop until one
setup path succeeds. Never clear Claim, expose `Ready to merge`, or continue the handoff without an
inspectably live watcher.

Only after monitoring is armed, immediately fresh-read the PR's merge state and head plus the owner
issue's Queue, Claim, exact `Touches`, and required issue labels. If that read finds the PR merged,
skip every open-PR handoff write and enter section 8 from that fresh state.

If that read finds the PR still open, perform the `Ready to merge` handoff writes only after
requiring the review loop's clean stop to cover that exact current head. A changed or unreviewed
head returns to section 6 without a handoff. Re-derive `runtime_target` from fresh owner PR
bodies as section 3 does; when it is missing, malformed, or no longer one `--runtime` can
certify, make no `Ready to merge` write and use section 9's intentional `Needs review` handoff, where
a compatible reviewer selects it or the steward reports its unreadable block. Otherwise, update the owner issue's exact `Touches`
from every PR it still owns and its profile-required issue labels, set Queue to `Ready to merge`,
append the scoped `Under review` Claim clear, and repair the Claim projection as `claim-task`
directs. Report the reviewed head from the live read. The resulting `Ready to merge` state is
unheld and carries no Claim.

Immediately after those writes, fresh-read the same PR and owner state and reconcile any merge
before waiting on the armed merge monitor. A merge observed by either immediate read enters
section 8 immediately. If the PR remains open after the second read, keep the subscription armed
or the fallback handle live and wait for its merge event.

This role must not merge a PR, enable auto-merge, mark a draft ready, or change PR labels. It may
update only the owner issue fields and issue labels authorized by the validated profile.

### 8. Continue only after merge

Enter this section only after a fresh provider read proves the PR merged. Use this same
reconciliation whether the merge was observed by either immediate read or delivered by the armed
merge monitor. For the monitor path, resume only after the merge event, then re-read the
provider rather than inferring success from elapsed time. Re-fetch the entire stack because the
next PR's base, head, owner, changed files, blockers, locks, and authorship may have changed.

Follow the ownership shape the worker recorded:

- For `distinct-owner-per-PR`, complete any missing scoped `Under review` Claim clear and
  projection repair, close the merged PR's owner issue, clear only that owner's merged file locks,
  and preserve every unmerged owner's `Touches`. The next PR keeps its distinct owner and
  already-activated review generation.
- For `single-owner-multiple-PRs`, do not close the owner after an intermediate merge; recompute
  exact `Touches` from every remaining unmerged PR, update required issue labels, complete any
  missing scoped `Under review` Claim clear and projection repair, append a pending intent whose
  predecessor is the completed review generation, write `Queue: Needs review`, and append its
  activation. This is a new review generation for the same owner, not reuse of the completed one.
  Close and release the single owner only after its final PR merges.

Return to sections 2 and 3 with complete live inputs. During active stack continuity, use the
freshly normalized `implementation_authors` and validated review session token to run
`<claim-task-skill-dir>/task-queue next --queue "Needs review" --reviewer <review-session-identity> --prefer <next-owner-issue> --runtime <cloud|local>`.
The option may prefer the next owner only when that record is fully eligible. A blocker, open
ancestor, or unrelated file lock makes it fall back to the canonical highest-priority eligible
issue; a review exclusion or runtime incompatibility does the same. An eligible preferred owner remains selected even when
another eligible issue has higher Priority.

A preferred record whose `implementation_authors` contains the `--reviewer` identity is ineligible
and falls back to the canonical eligible non-self-authored result. Do not post-filter or reselect a
self-authored result in prose; the normalized input makes the executable decision. Only after live
selection returns an eligible record may you proceed to section 4 for the active generation. If it
returns no record, go to section 10. Continue bottom-up until the stack is merged.

### 9. Escalate without waiving review

A capped, pivoted, write-stopped, or otherwise escalated loop is never `Ready to merge`, and
there is no exception that can make an unreviewed current head merge-ready. Fetch and record the
live unreviewed current head; never invent its SHA.

If actively continuing or waiting for an explicit event, keep `Under review`, keep Claim, and
continue or re-arm monitoring. For an intentional review handoff, preserve exact `Touches` and
the unmerged branch's file locks, then use the profile's two-phase transition: append the pending
intent for a new `Needs review` generation, perform the `Queue write` to `Needs review`, and
append its activation. Clear only the scoped old review Claim and record the unresolved decision,
cap reason, and unreviewed current head. For a cap handoff whose capped round's response names a
pushed SHA (not `none` or `rejected`) that is still the current head, write that record as an issue
comment naming the head's SHA and the word `certification`: that comment is what returns the head for
`deep-review-orchestrate`'s certification pass. Any other cap handoff keeps the unresolved-decision
record without that word, because certification only reads a head the capped round pushed.

The one path out of a cap is that certification. A clean certification pass of exactly the
handed-back head reviews it, so that head alone goes to the section 7 `Ready to merge` handoff. A
certification with any finding, a head that moved after the handoff, and every other capped or
escalated head stay out of `Ready to merge`.

An issue with an unmerged branch must never enter `Waiting for input`; use the profile's dedicated
decision state if one exists, otherwise retain active review stewardship or make the safe
`Needs review` handoff above.

### 10. Select the next review or monitor

After a single PR or full stack completes, return to section 2 and select the highest-priority
eligible review. When none exists, claim nothing and report the live dependency, collision,
unmerged-parent, or runtime reason. Report every `both` record waiting this way, since no single
reviewer can certify it.

Start or refresh the product-native subscription preferred by `steward-task-queue`; otherwise use
one inspectable persistent monitor at `cadence_minutes.reviewer` from the validated profile. Finish
the current tick and its writes before you re-arm the monitor. After each event, fetch live state
and repeat this workflow. While idle, never switch roles or invent eligibility. This reviewer
never stops while idle; it remains on the armed monitor after each refresh.

Before any intentional stop, re-read and reconcile Queue, Claim, exact `Touches`, and required
issue labels through the profile adapter. Record non-obvious escalation or handoff state, then
leave the corresponding monitor armed.
