---
description: Drive a GitLab MR to ready-to-merge — refactor, review --fix, pipeline, reviewers (gitlabduo, srv.venom), mr-fix-all. Never merges.
argument-hint: "<MR iid | !iid | MR URL> [--max-loops N] [--review-loops N] [--max-parallel N] [--reviewers a,b] [--wait-min N]"
allowed-tools: Bash, Read, Skill, Agent, EnterWorktree, TodoWrite, TaskCreate, TaskUpdate
---

# Deliver MR

## Purpose

Take one MR from "code written" to **ready to merge**: converge refactor, converge review fixes, get the pipeline green, mark ready, request gitlabduo + srv.venom reviews, fix their feedback, then verify merge readiness. **Does not merge.**

## Input contract

`$ARGUMENTS` (below).

- **MR** (required): IID (`123`, `!123`) or MR URL. Missing → ask once in plain text; still missing → stop.
- `--max-loops N` (default `3`): cap for the refactor loop (step 4).
- `--review-loops N` (default `6`): cap for the review loop (step 5); review needs more rounds than refactor. Non-positive or non-integer → stop `invalid --review-loops`.
- `--max-parallel N` (default `4`): global concurrent subagent budget for the whole run (positive integer). Non-positive or non-integer → stop `invalid --max-parallel`.
- `--reviewers a,b` (default `gitlabduo,srv.venom`): display names or usernames. Reviewers are **best effort**: one that cannot be added never blocks the verdict (step 6c).
- `--wait-min N` (default `10`): max wait for reviewer responses (step 6d).
- GitLab only. Non-GitLab `origin` → stop. URL whose project ≠ `origin` project → stop.

## Parallel budget

One shared cap `N = --max-parallel` for the entire delivery. Steps run **sequentially**; they do not each reset the budget while another step’s agent is still in flight.

| Context                                             | Budget passed                                                                                    |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Inline step (orchestrator runs the step itself)     | May spawn up to `N` concurrent `Agent`/`Task` workers for that step.                             |
| Delegated step (orchestrator spawns one step agent) | Charge **one** slot for the step agent. The step agent’s nested workers get `remaining = N - 1`. |
| `N = 1` and step is delegated                       | Step agent runs with **no** additional concurrent `Agent`/`Task` workers (`remaining = 0`).      |

Forward `remaining` only through interfaces sub-commands already accept:

- `review-omniva --fix --all` → append `--max-parallel <remaining>` (`--all` includes the test lane that honors it).
- `refactor-omniva` and `mr-fix-all-omniva` have no such flag → pass `MAX_PARALLEL=<remaining>` in the step-agent prompt; the agent must not spawn more concurrent workers than that number.
  Never invent a CLI flag a sub-command would reject.

## Execution routing

After size assessment (step 3b), route each substantive step. Record the chosen mode (`inline` | `subagent`) for the report.

**Always inline** (orchestration state): parse (0), resolve MR (1), locate branch / worktree (2), update ff-only (3), size assessment (3b), final verdict (8).

| Step                         | small  | medium   | large    |
| ---------------------------- | ------ | -------- | -------- |
| 4 Refactor loop              | inline | subagent | subagent |
| 5 Review loop                | inline | subagent | subagent |
| 6 Pipeline, ready, reviewers | inline | inline   | subagent |
| 7 mr-fix-all                 | inline | subagent | subagent |

## Subagent contract

When a step is `subagent`, spawn exactly one step agent whose prompt matches the step scope. Use a Skill-capable agent type (e.g. `general-purpose`): steps 4, 5, 6 (security gate) and 7 invoke Skills, so never an agent whose tool list lacks `Skill` (e.g. `_oa-mr-workflow-fix-agent`: Read, Bash, Agent). Include in the prompt:

- `MR_IID`, `SIZE_CLASS` (`small`|`medium`|`large`), size evidence (`files`, `changed_lines`, `binary_or_unreadable`)
- `WORKTREE_PATH` (absolute), `SOURCE_BRANCH`, `TARGET_BRANCH`
- `MAX_LOOPS` (`--max-loops`, refactor) or `MAX_REVIEW_LOOPS` (`--review-loops`, review), step scope (refactor | review | pipeline-reviewers | mr-fix-all)
- `MAX_PARALLEL` = `remaining` per the table above
- Commit/push rules: stage only step-touched files; hooks never `--no-verify`; plain `git push` (no force); commit message trailer from session reminder when present
- Shell rule: run `git`/`glab` as plain separate commands (see Execution)
- Loop/stop rules from the step definition below (identical diff twice, convergence criteria), including the **convergence check** definition (step 4)
- Prior step results the step needs (e.g. `PIPELINE_SHA`, pipeline state, reviewer outcomes for step 7) so it does not re-derive them

Require a structured result (parse from agent output):

```
step: <refactor|review|pipeline-reviewers|mr-fix-all>
mode: subagent
converged: <true|false|n/a>
loops: <n>
commits: <n>
notes: <pipeline state, reviewer outcomes, mr-fix-all CLEAN|ESCALATED|IN_PROGRESS, review `demoted: <ids>` (Warnings demoted at Challenge), blockers>
```

Parent retains step tracking, size/routing decisions, parallel cap, and final verdict. Subagent does not print the final delivery report. After spawning a step agent, end the turn and wait for its completion notification; no `sleep` or polling calls.

## Execution

Track steps 0–8 with TodoWrite (one todo each; mark done before advancing); when TodoWrite is not in the toolset use `TaskCreate`/`TaskUpdate`, and when neither exists say `tracking N/A` once. Plugin root = `omniva-dev` path from the SessionStart hook context. Use `-C`/`cwd` of the active worktree for every `git`/`glab` call.

Run `git`/`glab` as plain separate commands: no `&&` chains, `$(…)` substitution, or `cd … &&` prefixes (worktree-isolated sessions refuse them).

Security CLI (JSON on stdout, branch on `result.status`, `result.merge_blocked`, `result.findings.blocking_count`, `introduced_blocking_nodes`, `drift_blocking_nodes`): `python3 <plugin root>/skills/gitlab/gitlab-workflow/scripts/cli.py pipeline-security-reports <iid> --baseline target`.

### 0. Parse

Extract IID (+ project from URL), `--max-loops`, `--review-loops`, `--max-parallel`, `--reviewers`, `--wait-min`. Unknown flag → stop `unknown flag: <token>`.

### 1. Resolve MR

`glab mr view <iid> -F json` → `source_branch`, `target_branch`, `state`, `draft`, `sha`. `state` ≠ `opened` → stop.

### 2. Locate the branch

- `git branch --show-current` == `source_branch` → stay.
- Else `git worktree list`: a worktree already holding `source_branch` → reuse it. Otherwise run `git fetch origin <source_branch>`, then
  `git worktree add .claude/worktrees/mr-<iid> -B <source_branch> origin/<source_branch>`.
- Switch with `EnterWorktree(path=<worktree>)`. Never touch the original checkout's uncommitted changes.

### 3. Update (ff-only)

`git fetch origin`, then `git pull --ff-only`. Not fast-forwardable → stop and report; do **not** merge or rebase. Record `behind_target = git rev-list --count HEAD..origin/<target_branch>` for the report.

### 3b. Assess MR size

After refs are available, measure the MR diff against the merge base with `target` (three-dot form; no `$(…)`):

```bash
git diff --numstat origin/<target_branch>...HEAD
```

- **File count**: number of paths in the diff (each path once).
- **Changed lines**: sum of added + deleted columns from `--numstat` (ignore the third “binary” column for arithmetic).
- **Binary / unreadable**: any `-` in the add/delete columns, or any path where `git diff --numstat` cannot be parsed → set `binary_or_unreadable=true` and classify the MR as **large** regardless of counts.

**Balanced thresholds** (both conditions must hold for the smaller bucket):

| Class  | Files                                | Changed lines |
| ------ | ------------------------------------ | ------------- |
| small  | ≤ 10                                 | ≤ 500         |
| medium | ≤ 30                                 | ≤ 2,000       |
| large  | otherwise, or `binary_or_unreadable` |

Store `size_class`, `size_files`, `size_lines`, `binary_or_unreadable` for routing and the report.

### 4. Refactor loop (≤ `--max-loops`)

**Routing:** per matrix above (`inline` or `subagent`).

**Inline** — repeat:

1. `Skill omniva-dev:refactor-omniva` with args `--scope MR`.
2. Convergence check: `git status --porcelain -- . ':!.ai'` empty → **converged**, leave loop. `.ai/` holds skill run artifacts: never commit them and never count them as a diff (tools may write them there; no need to relocate or skip them).
3. Else commit (`refactor: <what changed> (MR !<iid>)`) and `git push`.

**Subagent** — one agent runs the same loop in `WORKTREE_PATH` with `MAX_PARALLEL` as above; parent applies the structured result.

Cap reached without a no-diff run → record `refactor: not converged`, continue. Identical diff twice in a row → stop looping (no progress), record as not converged.

### 5. Review loop (≤ `--review-loops`)

**Routing:** per matrix above.

**Inline** — same shape with `Skill omniva-dev:review-omniva` args `--fix --all --scope MR --max-parallel <remaining>` where `remaining` is the full `N` for inline. Commit prefix `fix(review):`. Converged = convergence check (step 4) shows no diff **and** report shows 0 Critical/Warning remaining, counted **after** the review's Challenge stage. Every Warning demoted at Challenge must be listed (`demoted: <ids>`) in the step result and the final report; a demotion never hides silently.

**Subagent** — same skill invocation and convergence rules inside the worktree; pass `--max-parallel <remaining>` with `remaining = N - 1`.

**Final verify:** if the cap is reached right after a fix commit, run one more assess-only pass (`review-omniva --all --scope MR`, no `--fix`) on the final HEAD. Converged iff it reports 0 Critical/Warning; otherwise `review: not converged`. Never judge convergence from a fix pack that was not re-assessed. Suggestion-only findings do not block convergence.

Commit rules (steps 4, 5, 7): stage only files the step changed; run hooks (**never** `--no-verify`); hook failure → stop and report; plain `git push` (never force). End each commit message with the attribution trailer from the session's system reminder, if one is given.

### 6. Pipeline, ready, reviewers

**Routing:** `inline` for small/medium; **subagent** for large (poll pipeline, mark ready, assign reviewers, wait — same outcomes as below).

`Read` `skills/gitlab/gitlab-workflow/SKILL.md` (plugin root) first and follow its read-protocol; do not invent its subcommands. It is not Skill-invocable.

- **a. Pipeline** — poll `glab ci status` for the pushed HEAD sha every 30–60 s, cap 30 min. Red → note it and go to step 7 (mr-fix-all owns pipeline fixes). Still running at cap → record `pipeline: timeout`.
- **a2. Security gate** — once the pipeline is green, run the Security CLI (Execution). `merge_blocked: true` → keep only `introduced_blocking_nodes` whose file is in the MR diff (`git diff --name-only origin/<target_branch>...HEAD`); nodes outside it are drift: report, never fix. Remaining introduced nodes → `Skill omniva-dev:mr-fix-security-omniva` (same worktree, commit rules above), push, then repeat a–a2 on the new HEAD. Reviewers (c) are requested only on a HEAD that passed a and a2. `status: unavailable` → record it (merge readiness unproven) and continue.
- **b. Ready** — if `draft`: `glab mr update <iid> --ready`.
- **c. Reviewers** — resolve each name to a username via `glab api "projects/:id/members/all?query=<name>"` (bots: also try `glab api users?search=<name>`). **Append** only: `glab mr update <iid> --reviewer +<username>` (a bare list replaces existing reviewers). Skip already-assigned. Unresolvable name → record, continue with the rest.
  **Verify** each add: re-read the MR `reviewers` (`glab mr view <iid> -F json`). `glab` reports success even when GitLab silently drops a non-member. Not applied, non-member, or name matching several users (e.g. group-scoped bots with one display name) → `unassignable`: record it, continue. Never guess one of several candidates, and never work around it (REST `reviewer_ids`, membership changes) — `unassignable` is not a blocker.
- **d. Wait** — poll every 30 s up to `--wait-min` for a response from each **actually added** reviewer (skip when none; `unassignable` ones are never waited on) (new MR note/discussion authored by them, or their review state changing). Responded → `ok`. Timeout → `pending: <name>` and continue.

### 7. mr-fix-all

**Routing:** per matrix above.

**Inline** — `Skill omniva-dev:mr-fix-all-omniva` (no `--max-parallel` flag; if spawning workers inline, cap at `N`).

**Subagent** — same skill in worktree with `MAX_PARALLEL=<remaining>` (`N - 1`).

If it pushed any commit after reviewers were requested (thread answers or fixes), re-request reviewers per the `mr-reviewer-rerequest` row in gitlab-workflow (only reviewers actually added).

**Security gate:** mr-fix-all must not report CLEAN on a green job alone. Before CLEAN, apply **a2** (diff-intersection rule included) on the final HEAD; if step 6 already passed it and HEAD has not moved, reuse that result. Still blocked afterwards → `mr-fix-all: ESCALATED` with the blocking nodes. Drift-only blocking nodes (not introduced by this MR) are reported, not fixed.

### 8. Verdict

Run the gitlab-workflow **Pre-merge checklist** (pipeline success, `pipeline-security-reports --baseline target` `merge_blocked`, unresolved threads, approvals, conflicts) and print the output below. Issue the independent reads (`glab mr view <iid> -F json`, the Security CLI, `glab mr note list <iid>`, `glab api "projects/:id/merge_requests/<iid>/approvals"`) in **one parallel turn**; reuse pipeline state already recorded by steps 6–7 instead of re-polling.

**Title is waived under mr-delivery:** skip checklist step 1's Jira-key title check, print `title waived`, and never stop or ask for a Jira key. If this command invokes `mr-update-omniva`, pass `--no-jira`.

**READY** only if every remaining row passes, no step recorded `not converged` / `timeout`, and no **added** reviewer is `pending`. `unassignable` reviewers and the title never block. Otherwise **NOT READY** with the blockers. Leave the worktree in place and print its path.

## Output contract

```txt
Deliver MR !<iid>
━━━━━━━━━━━━━━━━━
Branch: <source> → <target>   Worktree: <path|current>   Behind target: <N>
Size: <small|medium|large> (<files> files, <lines> changed lines)<optional: ; binary/unreadable → large>
Parallel cap: <N>
Execution: refactor <inline|subagent> · review <inline|subagent> · pipeline/reviewers <inline|subagent> · mr-fix-all <inline|subagent>
Refactor: converged|not converged  (loops <n>, commits <n>)
Review:   converged|not converged  (loops <n>, commits <n>)<optional: ; demoted: <ids>>
Pipeline: <state>   Ready: <yes|already|no>
Reviewers: <name> ok|pending|unassignable, …   (unassignable is non-blocking)
mr-fix-all: CLEAN|ESCALATED|IN_PROGRESS
Pre-merge: title waived · pipeline <…> · security <…> · threads <N> · approvals <…> · conflicts <…>
Verdict: READY | NOT READY — <blockers>
```

## Edge cases

- Source branch not pushed / no remote branch → stop (nothing to attach the MR to).
- Merge conflicts or approvals owed → reported as blockers; resolution is manual (not this command).
- Questions: plain-text options only; no enumerable gates beyond the missing-MR ask.

$ARGUMENTS
