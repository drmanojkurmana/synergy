# synergy

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25.svg)](fleet-run)

A Claude Code skill that runs a **tiered fleet of coding agents** from one leader
session. The leader decides which agent gets which task, starting at the cheapest
one that can finish it and escalating only on difficulty or on a real failure.

The point is cost. Most work does not need your most expensive model — but you
only save anything if the routing decision happens automatically, on every task,
without you thinking about it.

## Contents

- [The ladder](#the-ladder)
- [Install](#install)
- [Usage](#usage)
- [Isolation](#isolation)
- [Repo layout](#repo-layout)
- [Not supported](#not-supported)
- [License](#license)

## The ladder

```
task in
  │
  ▼
┌─────────────────────────────────────────────────────────┐
│ Floor   the leader itself                                │  one grep, one read, one command
├─────────────────────────────────────────────────────────┤
│ Rung 1  agy · muse · worker-sonnet         (cheap)        │  bounded, well-specified work
├─────────────────────────────────────────────────────────┤
│ Rung 2  genius-opus                        (hard)         │  architecture, subtle bugs, security
├─────────────────────────────────────────────────────────┤
│ Rung 3  genius-fable                       (escalation)   │  very hard, or rung 2 got it wrong
└─────────────────────────────────────────────────────────┘
```

| Rung | Agent | Use for |
|---|---|---|
| Floor | the leader itself | A single lookup — one grep, one file read, one command. |
| 1 (cheap) | `agy`, `muse`, `worker-sonnet` | Bounded, specified work: tests, mechanical refactors, search sweeps, log trawls, docs, boilerplate. |
| 2 (hard) | `genius-opus` | Architecture, subtle bugs, algorithm and data-model design, security-sensitive code. |
| 3 (escalation) | `genius-fable` | Very hard problems, or anything rung 2 got wrong. Not a default. |

A cheap agent's summary is a claim, not evidence — the leader verifies with `git diff`
and by running the tests before accepting the work.

## Install

```sh
git clone https://github.com/drmanojkurmana/synergy.git ~/.claude/skills/synergy
bash ~/.claude/skills/synergy/install.sh
```

That copies the three tier agents into `~/.claude/agents/` and the `fleet-run`
dispatcher into `~/.local/bin/`, then checks the fleet. Re-run it any time; it's
idempotent.

Two things you must do yourself:

1. **Add the permission rule.** `fleet-run` needs `"Bash(fleet-run:*)"` in
   `permissions.allow` in `~/.claude/settings.json` (and in `autoMode.allow` if you
   use auto mode). An agent cannot widen its own permissions, by design.
2. **Authenticate each agent.** There is no shared credential:

   | Agent | Authenticate with |
   |---|---|
   | claude (fable/opus/sonnet) | `claude` then `/login`, or an `ANTHROPIC_API_KEY` |
   | agy | run `agy` (first run prompts) |
   | muse | `muse login`, or `muse auth` for a provider API key |

   `agy` and `muse` are third-party agent CLIs and are optional — install them from
   their own distributions if you want those rungs.

Check what works:

```sh
$ fleet-run selftest
ok    agy
ok    muse
ok    claude/fable
ok    claude/opus
ok    claude/sonnet
```

A `FAIL` line means that agent is unavailable, not that the fleet is broken — the
skill routes around it. With no agy or muse you still get a working three-tier
fleet on Sonnet/Opus/Fable; the ladder just starts one rung up.

The three named agents load at session start, so they resolve in your **next**
session.

## Usage

You state the task. The leader picks the tier — you don't name agents unless you
want to override it.

```
fan this out to everyone
delegate the test suite
this one's hard, don't cheap out
```

Under the hood, Claude tiers go through the Agent tool (`subagent_type: worker-sonnet`
/ `genius-opus` / `genius-fable`) and the external CLIs through the wrapper:

```sh
fleet-run agy  <workdir> <prompt-file>    # prompt-file may be - for stdin
fleet-run muse <workdir> <prompt-file>
FLEET_TIMEOUT=90m fleet-run agy <workdir> <prompt-file>   # default 60m, agy only
```

## Isolation

`fleet-run` runs agy and muse with approvals disabled — they edit their working
directory freely, without asking. Give each writing agent its own git worktree,
never your live checkout:

```sh
git worktree add ../wt-task -b synergy/task
fleet-run agy ../wt-task ./prompt.txt
# review the branch, then merge it yourself
```

Parallel agents in the same directory will clobber each other. One worktree per
agent. Read-only work (analysis, search, review) can point anywhere safely.

## Repo layout

```
SKILL.md      the skill itself — routing ladder, dispatch, isolation, setup
install.sh    idempotent installer + fleet check
fleet-run     dispatcher for the external CLIs, plus `selftest`
agents/       genius-fable, genius-opus, worker-sonnet definitions
```

## Not supported

`pact` cannot orchestrate this fleet — its `--agent` is hardcoded to
claude/copilot/codex/gemini and rejects `agy` and `muse`, with no custom-command
escape hatch in `pact.toml`. Use plain `git worktree` plus `fleet-run` instead.

## License

MIT — see [LICENSE](LICENSE).
