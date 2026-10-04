---
name: work-task-queue
description: Use when continuously taking implementation work from a profile-backed repository queue, especially when claiming Ready issues, opening implementation PRs or safe stacks, handing work to review, or monitoring for the next eligible task.
---

# Work a task queue

Continuously turn truthful `Ready` work into reviewable implementation handoffs. One validated
profile and the complete live queue are the inputs; draft implementation PRs, truthful issue
handoffs, and an armed worker monitor are the outputs.

## Ordered workflow

### 1. Load dependencies and validate the profile

Read and follow these dependencies before touching the tracker:

- [`steward-task-queue`](../steward-task-queue/SKILL.md) for profile resolution, validation,
  backend access, live-input completeness, and monitoring.
- [`claim-task`](../claim-task/SKILL.md) for eligibility, claim arbitration, Queue transitions,
  Claim, and file-lock rules.
- [`create-pr`](../create-pr/SKILL.md) for committing, pushing, and opening or updating a draft PR.
- [`stacked-pr-rules`](../stacked-pr-rules/SKILL.md) whenever more than one PR is proposed.

Derive each dependency's skill directory from the path used to read its `SKILL.md`. Derive every
executable path from that directory: in particular, use the validator and backend adapter beside
`steward-task-queue`, and the `task-queue` and replay executables beside `claim-task`. Never assume
the current working directory or copy an executable into this skill.

Fresh-read this worker session's identity at role startup and run
`<claim-task-skill-dir>/task-queue validate-session --session <session-identity>`
before tracker access, selection, or any marker, `Queue`, `Claim`, or generation-ref write.
Require exactly one identity and fail closed if it is missing or is not a `claim-task` session
token. Keep that validated token unchanged for every claim marker, Claim event, settlement caller,
and ref-authority check in this role.

Resolve and validate exactly one repository profile through `steward-task-queue`. Stop before
tracker access on a missing or invalid profile, unsupported mutation capability, or failed
preflight. Use that profile for every subsequent read and write.

For a GitHub profile, apply this requirement:
Apply `steward-task-queue`'s Cursor Cloud GitHub credential contract before tracker access.
Keep that credential on every queue read and write.

### 2. Fetch the complete live inputs

Use `steward-task-queue` to fetch the full current issue set and all open implementation changes,
including Queue metadata, activated generations, scoped Claim events, blockers, exact `Touches`,
required issue labels, owner links, changed files, current heads, CI, review state, and merge
state. Include merged changes needed to reconcile an open owner.

Normalize through the profile's backend adapter and `claim-task` replay path. Cached queue output,
an old PR head, or a previous monitor tick is context only. Re-fetch before every selection and
after every event.

### 3. Select one eligible Ready issue

Run `<claim-task-skill-dir>/task-queue next` on the normalized complete issue set and choose only
its highest-priority valuable eligible `Ready` result. Follow its deterministic tie-break and
eligibility result; do not recreate those rules in prose.

A dependency or live `Touches` collision makes an issue currently ineligible but does not change
its stored Queue state. Leave a colliding issue `Ready`; there is no stored `Blocked` state. If
there is no eligible valuable result, go to section 9 without claiming or inventing work.

### 4. Claim the activated Ready generation

Use `claim-task`'s complete work-claim protocol with the active generation for this `Ready` visit:
write the generation-scoped marker, enter `In progress` with scoped Claim, re-read authority, and
run `<claim-task-skill-dir>/task-queue settle`. Converge Claim exactly as that dependency directs.

Only after settlement names this session as winner, create its generation-specific lock ref
`claude/issue-<N>-<generation>`. After losing settlement, converge Claim to the winner, do not
revert Queue or create work or the generation-specific ref, and do not immediately select the
same issue against the unchanged snapshot. Refresh the complete queue and choose the next eligible
item. Run `claim-task`'s **Rejected generation-ref protocol** unchanged after any rejected
generation ref.

### 5. Re-read before implementation

After winning, re-read the issue, activated generation, current default branch, open and recently
merged changes, owner mappings, exact changed-file lists, and live `Touches`. Confirm the problem
and acceptance criteria still apply. If another change invalidates the plan, reconcile under
section 10 rather than implementing against stale assumptions.

If stewardship returned an owner with an existing PR through a fresh `Ready` generation because
review authorship was unrecoverable, preserve its locks and inspect that PR before changing code.
The worker adopts or verifies the existing PR: establish its current head, ownership, diff,
tests, and provenance; make only required fixes; then use section 8 to create a truthful
`Needs review` handoff under this worker's validated identity. Do not infer or backfill the prior
author's `implementation_authors`.

### 6. Implement and verify

Implement only the claimed issue under repository instructions. Keep `Touches` exact as the
change evolves, and update profile-required issue labels through the profile adapter. Verify the
behavior and required repository checks before describing the work as reviewable.

Do not change role merely because review work exists. This session remains a worker and never
uses worker ownership as permission to review its own result.

### 7. Open or update the implementation PR

Follow `create-pr` to commit, push, and open or update a draft PR linked to the owner issue. Do not
claim that an unpushed or unverified diff has a durable review handoff.

Use more than one PR only under `stacked-pr-rules`. Every slice must be independently landing-safe
in merge order and every description must carry the synchronized full change-set navigation. If
the proposed bottom slice needs a later slice to pass, redraw the slices or keep one PR.

The worker never merges a PR, enables auto-merge, marks a draft ready, or changes PR labels.
It may update the owner issue's required issue labels through the validated profile.

### 8. Hand off reviewable work

Re-fetch the issue and every owner PR. Continue only when all implementation work being handed
off is pushed, reviewable, correctly linked, and accurately represented by exact `Touches` and
profile-required issue labels. Check every owner PR body with
`agent-provenance body-record --body <fresh-PR-body-file>`. A missing or malformed block is not
fixed in this workflow, so name that PR and its `body-record` error in the handoff; the steward reports
it to the user for a decision.

Before the `Needs review` transition, record the stack ownership shape in the handoff. For
`distinct-owner-per-PR`, map every PR to its owner issue and record the complete owner ancestry.
For `single-owner-multiple-PRs`, map the remaining ordered PRs to the same owner issue. Do not
leave the reviewer to infer ownership from branch names, `Touches`, or stack position.

Perform the profile's two-phase transition in this order: append the pending intent for the next
review generation, perform the `Queue write` to `Needs review`, then append its activation.
Append the scoped Claim clear for the completed `In progress` generation and repair the Claim
projection exactly as `claim-task` directs. Report the resulting generation and handoff.
The resulting `Needs review` state is unheld and carries no Claim.

Never review your own work. Leave the activated `Needs review` visit unheld for an independent
reviewer, then continue as a worker.

### 9. Select the next task or monitor

Return to section 2 and select again. When no valuable eligible `Ready` issue exists, claim
nothing and report the live dependency, collision, or value reason.

Start or refresh the product-native subscription preferred by `steward-task-queue`; otherwise use
one inspectable persistent monitor at `cadence_minutes.worker` from the validated profile. Finish
the current tick and its writes before you re-arm the monitor. After each event, fetch live state
and repeat this workflow. While idle, never switch roles, lower the value bar, or invent
eligibility. This worker never stops while idle; it remains on the armed monitor after each
refresh.

### 10. Interrupt or put work down truthfully

`Waiting for input` is only for an exact human decision discovered before any implementation
branch exists. Clear the active scoped Claim as `claim-task` requires, record the precise
alternatives, set the profile's real `Waiting for input` state, and leave no file lock. A later
return to `Ready` is a stewarded two-phase transition, not a direct Queue edit.

Work with an unmerged branch must never enter `Waiting for input`. If it is genuinely reviewable,
use section 8 and state what remains. If it is not reviewable or cannot be safely released, it
must not enter `Needs review`: keep `In progress`, keep Claim, preserve exact `Touches` and issue
labels, and continue or re-arm monitoring. Do not log out while pretending those live locks were
released.

Before any intentional stop, re-read and reconcile Queue, Claim, exact `Touches`, and required
issue labels through the profile adapter. Record any non-obvious decision or incomplete handoff,
then leave the corresponding monitor armed; elapsed time never proves that a claim or branch is
dead.
