---
name: synergy
description: Orchestrate a tiered fleet of coding agents from one leader session, routing each task to the cheapest agent that can finish it. Use when a task should be delegated rather than done inline, when fanning work out across several agents in parallel, when deciding which model tier a piece of work deserves, or when the user says "synergy", "fan this out", "delegate this", "send this to all of them", or asks to save tokens on routine work. Also covers installing and authenticating the fleet on a new machine.
---

# Synergy

One leader session assigns work to a fleet. The leader decides the tier — the user
states the task, not the agent.

## The routing ladder

Start at the cheapest rung that can finish the task. Escalate only on difficulty or
on a real failure, never pre-emptively.

| Rung | Agent | Use for |
|---|---|---|
| Floor | the leader itself | A single lookup — one grep, one file read, one command. Spawning an agent costs more than the answer. |
| 1 (cheap) | `agy`, `muse`, `worker-sonnet` | Bounded, well-specified work: implementing a decided design, tests, mechanical refactors, search sweeps, log trawls, doc updates, boilerplate, repro scripts. |
| 2 (hard) | `genius-opus` | Architecture decisions, subtle bugs, algorithm and data-model design, security-sensitive code. |
| 3 (escalation) | `genius-fable` | Very hard problems, or anything rung 2 failed at or got wrong. Not a default. |

**Verify before accepting.** A cheap agent's summary is a claim, not evidence. Run
`git diff`/`git show --stat`, run the tests it says it wrote, and read what actually
changed. A wrong answer accepted cheaply costs more than the tokens it saved.

**Escalate on failure, with context.** When rung 1 fails, hand rung 2 the original task
*plus* what the cheaper agent tried and how it failed. Don't make the next agent
rediscover the dead end.

## Dispatching

**Claude tiers** — the Agent tool, no shell-out:

```
Agent(subagent_type: "worker-sonnet", prompt: "...")
Agent(subagent_type: "genius-opus",   prompt: "...")
Agent(subagent_type: "genius-fable",  prompt: "...")
```

**External CLIs** (agy, muse) — the `fleet-run` wrapper, Bash tool:

```sh
fleet-run agy  <workdir> <prompt-file>    # prompt-file may be - for stdin
fleet-run muse <workdir> <prompt-file>
FLEET_TIMEOUT=90m fleet-run agy <workdir> <prompt-file>   # default 60m, agy only
```

Write the prompt to a file rather than inlining it — long multi-line prompts and shell
quoting don't mix. Give the same detail you'd give a subagent: repo path, branch, exact
files, what "done" looks like, how to verify it.

Run them with the Bash tool's `run_in_background: true` for long unattended work, and
fan out by launching several before waiting on any of them.

## Isolation (required for anything that writes)

`fleet-run` runs agy and muse with approvals disabled — they can edit their working
directory freely, without asking. Give each writing agent its own git worktree, never
the live checkout:

```sh
git worktree add ../wt-<task> -b synergy/<task>
fleet-run agy ../wt-<task> /path/to/prompt.txt
# review, then merge the branch yourself
```

Read-only work (analysis, search, review) can point at any directory safely.

Parallel agents in the *same* directory will clobber each other. One worktree per agent.

## Setup on a new machine

```sh
bash install.sh          # copies agents + fleet-run into place, then checks the fleet
fleet-run selftest       # re-check any time; prints ok/FAIL per agent
```

`selftest` pings all five agents with a trivial prompt. Every agent authenticates
separately — there is no shared credential, and nothing here can log in on the user's
behalf:

| Agent | Authenticate with |
|---|---|
| claude (fable/opus/sonnet) | `claude` then `/login`, or an `ANTHROPIC_API_KEY` |
| agy | `agy` (first run prompts), or see `agy --help` |
| muse | `muse login`, or `muse auth` for a provider API key |

A `FAIL` line means that agent is unavailable, not that the fleet is broken. Route
around it: with no agy/muse, rung 1 is `worker-sonnet` alone; the ladder just starts
one rung up.

`fleet-run` needs `Bash(fleet-run:*)` in `permissions.allow` in `~/.claude/settings.json`
(and in `autoMode.allow` if auto mode is used). `install.sh` prints the exact JSON.
The user must add it themselves — an agent cannot widen its own permissions.

Newly installed `~/.claude/agents/*.md` are read at session start, so the three named
tiers resolve in the **next** session, not the one that installed them. In the current
session, use the Agent tool's `model` override (`model: "fable" | "opus" | "sonnet"`)
to reach the same tiers.

## What this does not do

`pact` cannot orchestrate this fleet — its `--agent` is hardcoded to
claude/copilot/codex/gemini and rejects `agy` and `muse`, with no custom-command escape
hatch in `pact.toml`. Use plain `git worktree` + `fleet-run`, and merge the branches
yourself.
