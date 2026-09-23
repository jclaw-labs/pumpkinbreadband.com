---
name: address-deep-review
description: Triage and act on findings from a deep-review run — deciding which to take, which to decline, when the PR is done, and when to stop reviewing. Use whenever you sit down to address, respond to, or work through review feedback on a PR that has had deep-review run on it, before you change any code. Owns the judgment half and the stopping rule; the deep-review skill owns finding and posting the review marker.
---

# Addressing review feedback

A deep review arrives as a numbered list of well-argued findings. Working down it in order and
fixing each one is the wrong default, and it is the default almost every agent falls into —
because each finding, read alone, looks reasonable.

**The reviewer's job is to surface everything worth considering. Yours is to decide.** A review
that produced 18 findings is not a list of 18 defects; it is a list of 18 claims, some wrong, some
right but not worth the change, and some that matter more than the rest of the PR combined.
Sorting them is the work. Skipping the sort is how a PR grows a commit of naming churn per round,
and how a reviewer's speculative suggestion becomes shipped architecture.

The asymmetry is structural, so guard against it deliberately: `deep-review` tells the reviewer
there is no cap on findings and never to trim real ones. Nothing tells you to trim. One side is
instructed to maximize and the other is uninstructed, and the result drifts one reasonable-looking
acceptance at a time.

## The one number that tells you you've stopped deciding

**State your acceptance rate in every response.** If you have taken every finding in two
consecutive rounds, you are no longer triaging — you are complying, and from the inside that is
indistinguishable from diligence.

This is not a rule against a high rate. Early rounds legitimately run high: the first review of
unreviewed code finds real defects. It is a rule about *noticing*. In one four-PR stack, declines
ran ~8% across rounds 1–2 and then **0 declines across 38 findings in every round from 3 on** —
the collapse was invisible until someone asked. When the rate hits 100% and stays, stop and re-read
the round asking what you would have written unprompted. Usually at least one is a naming
preference, a speculative guard, or a change you could not verify.

**100% across two rounds is not the only trigger, and on its own it is too coarse.** Also stop when
the round had `consider` findings and you took all of them — the default there is not to take them.
That needs the floor, or it fires on any round where nothing was filed as minor. A run that went
60% → 86% → 89%, declining nothing but preferences and taking all three `consider` findings in the
last round, slides under a 100% bar while being the same failure. Noticing it in writing and
proceeding anyway, because each change was one line, is the shape to watch for: cheapness is a reason
the changes are harmless, not a reason they were wanted.

Whether you declined any finding the reviewer filed as a *defect* is worth reading alongside the
rate, but it does not work as a trigger on its own. Measured over every round of two review loops,
most of them declined no defect finding at all — including the round with the lowest acceptance rate
of the lot, at 64% with four declines, all of them preferences. A first review of unreviewed code
legitimately finds defects that are all real, so treat this as colour on the rate rather than a
verdict of its own. What it is good for is the opposite reading: a long run of rounds where no defect
claim was ever refused, while the rate climbs. (Don't restate that as a count of rounds. Written as
one, it goes stale inside the loop that is editing it, because the loop keeps adding rounds to its
own denominator.)

## Step 1: Verify before you accept

Every finding is a claim about the code. Reproduce it before acting on it. Prefer the reviewer's
own strongest technique: **run the code and break it**, rather than reading it. If the round has
more than one review, dedupe the lists first — Step 2 has that case.

- **Numbers:** re-measure, and do it on the head you are answering. Never copy a figure out of a
  review into a document or a test — and don't carry your own earlier measurement across a commit
  either. One response said a mutation failed 3 tests when it failed 2 on that head; the 3 was real,
  measured a head earlier, on a different mutation. Every commit invalidates the whole table.
- **"Nothing reads X" / "no consumer":** grep for it.
- **"This is a no-op" / "no behaviour change":** construct the case where it isn't.
- **"This test can't fail":** mutate the code it covers and run it. If it still passes, the finding
  is right and important; if it fails, say so with the assertion output.
- **A suggested fix:** re-derive it. When a finding hands you replacement wording, that sentence
  carries no evidence — the reviewer was describing a fix, not reproducing a defect — and it is more
  persuasive than a finding precisely because it arrives already written. Execute the mechanism it
  names before you paste it, and keep every clause of it: where the reviewer named two operations
  and you ship one, a true sentence becomes a false one, and it still reads fine.

**Probe in a throwaway clone whenever the code under test writes to a repo it can find by itself.**
A tool that resolves its own repo root will find the real one from wherever you run it, so a probe
that looks read-only isn't. Verifying one finding meant running a worktree-creating script from the
review checkout, and it created a worktree and a branch inside the live repo. Reviewers get this rule
from whatever dispatches them; whoever is addressing usually hasn't been given it.

The clone is only half of it, because what decides the target is **what you invoke, not where you
stand.** A wrapper on your `PATH` is usually a symlink into the live checkout, and a script that
derives its root from its own location acts on that checkout from any directory — standing in the
clone changes nothing. Invoke the clone's own copy, or point the tool at the clone with whatever
root override it honours.

Reviews carry wrong claims at a rate worth planning for. Real examples from one stack: a premise
about what a downstream PR already did; a measured median attributed to the wrong fixture; a
finding reported as unaddressed that had been declined in writing a round earlier; and a review
whose central praise — "this window is calibrated to those anchors exactly" — was arithmetically
wrong, and wrong in a way that hid a real defect, because the check as written forbade the very
schedule the design document specified.

That last one is the pattern to internalize: **a wrong claim in a review is often attached to a
real problem.** Refuting the claim is not the end of the work. Ask what the reviewer was looking at
when they got it wrong.

A particular shape to watch for, because it survives a mechanism check: **a review can be right about
the mechanism and wrong about whether it fires.** One traced a token to a log line correctly at every
step and missed that the logger elides at a shallower depth than the token sits. And a reviewer's own
"I watched it happen" can be an artifact of its harness rather than of the code — that one's
reproduction was its mocking library echoing the request back in an error message. Rebuild the shape
and measure it yourself.

When a finding turns out to be wrong, **say so with the reproduction**. A review that carries a
wrong claim forward costs the next round more than it saves.

## Step 2: Triage by severity, not by list order

**Must address** — take it, unless verification shows the premise is false. Correctness, data
loss, a test that doesn't test its property, a citation attached to behaviour that isn't the
source's.

**Should address** — take it when it names a defect. Decline when it names a preference. The
question that separates them: *does something behave wrongly, or does something read differently
than the reviewer would have written it?* A misleading name is a defect; a name you'd have chosen
differently is a preference.

**Consider** — the default here is **not** to take it. Take one only when the change costs less
than the ambiguity it removes. A one-line guard against a degenerate input, yes. A rename of a
private function, a blank line in an import block, a restructured paragraph — these cost a commit,
a push, and on a stack a re-render of every downstream diff. The reviewer filing it as minor is
telling you they know.

### When a round has more than one review

Two sessions can have reviewers in flight on the same head — a resuming session is structurally
blind to that, because the re-review guard keys on a head *it* recorded. Absorb the race rather than
trying to prevent it; preventing it needs a cross-session lease, which then has its own stale-lock
failure.

**Dedupe before Step 1 verifies anything**, or you will prove the same claim several times before
noticing it was one claim. Then key each finding by which pass raised it, and take **the highest
severity any pass assigned**. One round of three reviewers on byte-identical code gave 23 raw
findings and 14 unique, and one pass's `must` was right where two others had said `should`.

The fact that makes the severity rule matter: **the most important finding of that round appeared in
only one of the three passes.** Agreement across passes is not a proxy for importance, so a
consolidation that weighted confirmed findings higher would have buried the best one.

Promoting a severity costs you something, and it is worth paying knowingly: a `must` is one Step 6
forbids declining without a reproduction, so a lone pass's `must` raises both your acceptance rate
and your evidentiary burden. Pay it rather than falling back on the majority's reading — the pass on
its own was the one that was right.

**Pass-qualify the row ids** — `A1` for a finding one pass raised, `A1 · B2 · C3` for one all three
raised — because each pass numbers from 1 and the ledger's `#` column is round-scoped. Expect plenty
of composite rows: half of them were, on the round this comes from. Two distinct findings both
filed as `1` collapse into a single entry in the parse that reads declined must-address rows back off
the PR, so a response declining three of them reports two.

**State the rate on unique findings, and carry the raw count as well.** The round this section comes
from put the pass count in its header and the rate in the body below, but left the raw total out —
and that is the number that makes the rate comparable to a single-review round. All three belong
together:

```
responded to run 4 (a84838b) — three reviewer passes ran on the same head; consolidated to
14 unique findings from 23 raw: 10 taken, 1 settled, 3 declined. Pushed 3a9bc13.

Acceptance rate 10/14 (71%).
```

## Step 3: The over-engineering tests

Run these on anything you're about to build because a review suggested it.

1. **Would you have written this unprompted?** If no, and the finding is in "consider", that is
   usually the whole answer.
2. **Does it fix the thing it was proposed for?** Check literally. A proposed rule matching on
   *names*, offered as a fix for a defect that was a wrong *section reference*, would not have
   caught the defect that motivated it. That is not a smaller version of the right fix; it is the
   wrong fix wearing its clothes.
3. **Is the invariant it guards one anybody has broken?** A property test for a property the
   reviewer already swept and found solid is a cost with no incident behind it.
4. **Can you verify the change?** If a fix touches a pipeline you cannot run against an input you
   do not have, decline until someone can run it. A disclaimer is not a substitute for a test.

## Step 4: Sweep the second order

**This is the step that gets skipped, and it produces the next round's must-address finding.**

Fixes introduce defects. Measured across one stack, roughly one addressing round in five shipped a
new defect that only the following review caught — including a fix that re-created the exact bug
the PR had originally been opened to fix, in a commit whose own comment asserted that could not
happen.

So when a fix changes behaviour rather than structure, find everything that quotes the old
behaviour before committing:

- figures in decision records and design docs
- numbers in the PR body
- test bounds and assertions
- doc comments and labels stating a threshold or a frame

Ask **"which documents and tests quote this?"**, not "which paragraph am I editing?". The durable
fix is to make the quoted figures the tests' assertions, so the build fails next to the prose that
went stale.

**Then re-run the probe that found the finding.** If a mutation exposed it, re-apply that mutation
and confirm it now fails. Two of the three injected defects in that stack would have died here.

**Record which assertions fail under which mutation, and read the map by assertion: no assertion
should fail under a mutation that has nothing to do with the property that assertion pins.** Two
different ways of breaking the same property landing on the same assertion is that assertion doing
its job, however far apart in the code they sit, and most of the suite failing under nothing at all
is normal in a targeted sweep — neither is what you are looking for. Pass/fail counts hide all of
this: a count-only sweep shows "1 failure" for each mutation and invites you to assume each is its
own. What caught a defect in one round's *new* assertion was that it failed
under three mutations having nothing to do with the guard it covered — it targeted a fixture that
earlier tests in the same file reclaim, so it passed only by luck of ordering. That pattern means
either the assertion is order-dependent or the mutation isn't isolated, and both are worth knowing
before you commit.

A healthy map, from a sweep of another repo's `tests/worktree-pool-status.test.sh` — three targeted
mutations, each landing where it should:

```
gate-reverted             -> 2  (detached-at-remote-tip-resolves-pr, detached-at-remote-tip-reclaimable)
second-conjunct-dropped   -> 1  (deep-stack-open-grandparent-blocked)
gh-repo-guard-dropped     -> 1  (unresolvable-repo-fails-closed)
```

Run the mutations in parallel if the sweep is slow, but give each one **its own checkout**. Per-run
fixtures are not the isolation that matters here: a suite that resolves the tool under test through
the checkout it lives in re-reads that file on every assertion, so a second mutation written into the
same checkout mid-run surfaces as a failure in the first run — which looks exactly like the
order-dependence you are sweeping for. And if the suite has a load-sensitive flake in it, fix that
before parallelising rather than reading its failures as findings.

### Prove the fix engaged, not just that the symptom moved

A fix that skips work — a cache, a short-circuit, an early return — is verified by showing **the new
code path ran**, not by showing the number got better. Those are different claims, and the second
one is satisfied by any change in conditions at all.

The case this is written from: a negative cache meant to stop an offline run retrying at every call
site was verified by timing a `check` against `127.0.0.1:9` and finding it instant. It was instant
because that port *refuses* the connection in 5ms. Against a black-holed host, which is what a real
outage looks like, the run still took two minutes — the cache had never executed once, because the
marker was written with `touch` and the freshness test opened with `[[ -s ]]`. The measurement was
real and meaningless, the round reported it as fixed, and only the next review caught it.

So before writing "measured" next to a fix like that:

- **Pick an input that can only pass through the new path.** A fast failure and a skipped fetch look
  identical from the outside; make the slow case slow.
- **Observe the mechanism directly** — the file it writes, the request it doesn't make, the branch it
  takes — and not only the elapsed time.
- **Check the second run differs from the first.** A cache that never fires is indistinguishable from
  one that always hits until you compare them.
- **Then write the assertion**, because a mechanism nobody can see from the outside is exactly the
  kind the suite will let rot. One test here would have failed the commit.

## Step 5: Decline well

A decline is a first-class outcome, and it needs to survive someone reading the thread later.

- **Name the mechanism, don't report a failed search.** "I searched and nothing sets that" is how
  you talk yourself into dismissing a true finding. "A trailing slash restricts the pattern to
  directories, and a symlink is not a directory to git — here is the `git status` transcript" is a
  refutation.
- **"There is nothing left to catch" is a universal claim, so build the counterexample before you
  write it.** Step 1's own technique refutes claims like that by construction, and it takes two
  minutes. One decline argued that precedence made a parenthesisation cosmetic, so a full-string
  assertion had nothing to catch. The precedence was right and the conclusion was wrong: the next
  round produced three single-token mutations that each left the suite green, one of which silenced
  the feature entirely. If your reason is that no counterexample exists, go try to build one.
- **Give the reason in the response.** A finding recorded as declined with a one-line reason reads
  as decided; the same finding left unmentioned reads as ignored, and comes back next round. Record
  it as declined, not settled — settled is for findings resolved another way, and folding declines
  into it zeroes out the decline count Step 6 leans on.
- **A `settled` row has to be earned by re-reading the location the finding named.** Declines stay in
  the ledger and settled rows leave it, so a wrong `settled` is invisible forever — the one asymmetry
  here with no check under it. One was recorded by reading a neighbouring sentence that had been
  rewritten, while the sentence the finding actually named sat untouched in a file loaded into every
  session. Check the place the reviewer pointed at, not the fix you think covers it.
- **Declining on cost is legitimate.** So is "this is unverifiable from here."
- **Half-declines are common and worth stating.** Taking the accessor but not extending it to
  three other ids is a decision; say which half you took so the other half isn't re-filed.
- **Reverse a decline when it acquires a counterexample.** A decline is a judgment under evidence,
  not a position to defend. When the failure you said wouldn't happen happens, say so plainly and
  build the thing.

## Step 6: When the PR is done

This is the stopping rule, and it is the part that makes an unattended review loop safe.

**Two tempting criteria are both wrong, and the data says so.**

- *"Stop when the review finds nothing."* Findings decay but do not reach zero — 18 → 12 → 7 → 5
  across four rounds on one PR, 16 → 12 → 8 → 6 on another. A loop waiting for an empty review
  never terminates.
- *"Stop when there are no must-address findings."* Not monotone. One PR ran 4 → 2 → 0 → **1**: a
  must-address appeared at round 4 after round 3 was clean.

**The sound criterion is that the reviewer has seen the final state.** You cannot certify your own
work, because addressing injects defects and only the next review catches them. Any round that
produces a commit invalidates the review that prompted it.

Which gives a rule that is mechanical and terminates:

> **The loop ends on a round that produces no commit** — every finding was declined or already
> settled — with local checks and CI green on that head.

A round produces no commit only when the head the reviewer just examined *is* the final head. That
is the certification, and it comes from the reviewer rather than from you.

Note what this does to the acceptance-rate discipline above: **an agent that takes every finding
can never terminate.** Every round produces a commit, which requires another round, forever. That
is the point — it converts over-compliance from a silent quality problem into a visible
non-termination, and it is why the acceptance rate belongs in every response.

Three guards, so the rule can't be gamed or run away:

1. **A must-address finding may not be declined without a reproduction refuting its premise.**
   Otherwise "decline everything" is a one-round exit.
2. **Budget the rounds.** Past five, stop and hand the state to the author with what's outstanding
   and why, rather than continuing. Diminishing returns are real: late rounds on that stack cost
   ~100 lines of churn for ~8 findings, of which about one was a genuine defect.
3. **Green is necessary, not sufficient.** Local checks and CI pass on the final head, and every
   finding from every run has an outcome.

**Stopping is not merging.** Report that the criterion is met and hand the merge decision to the
author — a repo that makes marking a PR ready a separate act means that separation is deliberate.
Do not mark ready, do not merge, and do not keep iterating because another round is available.

## Recording what you did

**Post your own comment. Never edit the review's.**

The review comment records what was found; yours records what was done about it. Keeping them
apart means neither can destroy the other, and it makes your response something a script can find
rather than a mutation buried inside somebody else's comment. It also replaces a convention that
did not work: half the surfaces that run this skill have no tool that can edit a comment at all,
and across one four-PR stack the marker was successfully edited **once in fourteen rounds**.

Open with `<!-- address-deep-review-marker -->`, and **never put `<!-- deep-review-marker -->` on
that first line**. Automation classifies a comment by the marker its first non-blank line carries,
so a record that opens with the review marker is counted as a review round — inflating the count
and making a later re-review skip a head it should have read. Quoting either string further down
the body is fine; naming the run by number and short SHA is still the clearer way to refer to it.
`deep-review` carries the mirror of this rule.

Style it like the review: small text, detail collapsed.

Keep the `DEEP_REVIEW_SKILL=1` prefix — the same one `deep-review`'s marker carries. Some setups
run an agent hook (`guard-no-reviewer-reply.sh`) that denies a bare `gh pr comment`, so an agent
can't answer a human reviewer on your behalf; that prefix is the guard's one sanctioned exception,
and it covers both a review marker and this response. Without the hook it is an inert env var, so
it is safe either way — but don't reuse it on any other comment.

```bash
DEEP_REVIEW_SKILL=1 gh pr comment <number> --body "$(cat <<'EOF'
<!-- address-deep-review-marker -->
<sub>🛠 <b>address-deep-review</b> responded to run 3 (<code>abc1234</code>) — 8 findings:
5 taken, 2 settled, 1 declined. Pushed <code>def5678</code>.</sub>

<details>
<summary><sub>Deep-review addressed</sub></summary>

| # | Severity | Kind | Outcome | Verified | Note |
|---|---|---|---|---|---|
| 1 | must | defect | taken | mutated | guard was inverted; the test now fails without the fix |
| 2 | should | preference | declined | read | the alternative loses the ordering §4 requires |

</details>
EOF
)"
```

**The header line carries the state**, because it is what a reader — or an orchestrator — needs
without opening anything:

- **Which run this answers**, by number and the short SHA from that run's header. A PR with five
  rounds has five of these, and only the SHA says which is which.
- **The counts**, as taken / settled / declined, plus deferred on a round that escalated. Put the
  decline count where it cannot be missed: in the stack this convention comes from, declines fell to
  **zero across 38 findings** in the late rounds, and the collapse into compliance was invisible
  until someone asked about it directly.
- **What you pushed**, as a short SHA — or **`Pushed: none`** when the round produced no commit.
  That is the whole stopping condition: a round that changes nothing means the head the reviewer
  examined is the head that will merge. It belongs in the header, not only in the table.

**Every finding gets a row**, by the number the review gave it — taken, settled, declined, or
deferred. A finding with no row reads as missed. Per row: severity, `defect` or `preference`, the
outcome, and how you verified it (`measured` / `mutated` / `grepped` / `read`). For a **declined
must-address**, the note carries the reproduction that refutes the finding. A decline without one
is an opinion, and it is the one thing a reviewer cannot check on your behalf.

**`deferred` is the escalation outcome, and reaching for `declined` instead breaks the PR
permanently.** A finding is deferred when it is real and unrefuted and you are handing it to the
author rather than acting on it — a pivot verdict, the round cap, a finding you can neither
reproduce nor refute. `declined` is a judgment *you* made, and `review-loop-state` reads a declined
must-address as blocking: it matches the outcome column against a refusal pattern, and nothing
later removes a hit, because finding numbers are round-scoped. Measured on its fixture door, one
must row reading `declined` beside one reading `deferred` reports `blocking_must_address: ["1"]`;
with both deferred it reports `[]`. So filing an escalation as declined stops every later session
from ever reaching a clean stop on that PR. Name the escalation condition in the header, so
`Pushed: none` isn't read as a clean stop — and state the acceptance rate over the findings you
actually triaged, or say it doesn't apply, since 0% from an escalation is not the over-compliance
signal that rate exists to catch.

A half-take is not this. Refusing half of a must-address is your judgment rather than a hand-over,
so it stays a decline and should still register as blocking; `deep-review-orchestrate` owns how to
write that row so the tool sees it.

## Behavior on weak input

- **"Address the review"** with several runs open → address the newest, and read the previous
  round's own response comment for findings recorded as unsettled.
- **A finding you can't reproduce and can't refute** → say exactly that, take it only if cheap and
  safe, and flag the uncertainty. Don't assert either way.
- **A finding that would pivot the design** → it belongs to the author. Surface it and stop.
