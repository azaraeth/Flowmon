# flowmon · Flow Monitor

> Background Run Manager · Live Logs · REPL interface for [Flow-SN](https://github.com/azaraeth/Flow-SN)

```
     ███████╗██╗      ██████╗ ██╗    ██╗███╗   ███╗ ██████╗ ███╗   ██╗
     ██╔════╝██║     ██╔═══██╗██║    ██║████╗ ████║██╔═══██╗████╗  ██║
     █████╗  ██║     ██║   ██║██║ █╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║
     ██╔══╝  ██║     ██║   ██║██║███╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║
     ██║     ███████╗╚██████╔╝╚███╔███╔╝██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
     ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝ ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
     V1.0 · Background Run Monitor
```

---

## What is flowmon?

`flowmon` is a companion monitoring tool for **Flow-SN** — the node-based workflow runner built for Termux on Android. While Flow-SN lets you build and execute pipelines by connecting nodes, `flowmon` gives you a dedicated REPL interface to observe those pipelines running in the background, inspect per-node status, tail live logs, and kill or clean up runs — all without interrupting the workflow itself.

Think of it as a lightweight `htop` for your Flow-SN background jobs.

---

## Features

- **Run registry** — tracks all background runs launched via `runbg` inside Flow-SN
- **Per-node status table** — see each node's type and state (pending / running / done / error)
- **Live log tailing** — follow workflow or node logs in real time
- **Live watch mode** — auto-refreshing dashboard that updates every 2 seconds
- **Stop / kill** — gracefully (or forcefully) terminate a running workflow
- **Cleanup commands** — remove individual runs or bulk-clean all finished ones
- **Blue-themed REPL UI** — consistent color language with status badges and a persistent prompt

---

## Requirements

- **Termux** on Android (or any Bash 4+ environment)
- **Flow-SN** installed and set up — see [azaraeth/Flow-SN](https://github.com/azaraeth/Flow-SN)
- The shared `UIM` library (sourced from the same script directory)
- `$DATA` environment variable pointing to Flow-SN's data directory

---

## Installation

`flowmon` ships alongside Flow-SN. No separate installation is needed — just make sure `flowmon.sh` is in the same directory as your `UIM` library file.

```bash
# Make it executable
chmod +x flowmon.sh

# Launch flowmon
bash flowmon.sh
```

---

## Quick Start

**Step 1** — Start a workflow in the background from inside Flow-SN:
```
runbg
```

**Step 2** — Open a second Termux session and launch flowmon:
```bash
bash flowmon.sh
```

**Step 3** — Monitor your run:
```
ls                                      # see all runs
status myproj_20250101_120000           # per-node breakdown
watch  myproj_20250101_120000           # live-refresh view
logs   myproj_20250101_120000           # workflow log
logs   myproj_20250101_120000 fetch     # log for a specific node
stop   myproj_20250101_120000           # kill the run
```

---

## Commands

| Command | Description |
|---|---|
| `ls` | List all background runs and their status |
| `status <run_id>` | Show per-node status table for a run |
| `watch <run_id>` | Live-refresh status every 2s (auto-stops when done) |
| `logs <run_id> [node]` | Show logs — live tails if still running |
| `tail <run_id> [node]` | Always live-tail a log (Ctrl+C to stop) |
| `stop <run_id>` | Kill a running workflow |
| `rm <run_id>` | Delete all data for a finished run |
| `clean` | Remove all completed and errored runs |
| `clear` | Redraw the banner and stats |
| `help` | Show the help screen |
| `exit` / `quit` | Exit flowmon |

---

## Run States

| Badge | Meaning |
|---|---|
| `⟳ RUNNING` | Workflow is actively executing |
| `✓ COMPLETE` | Workflow finished successfully |
| `✗ ERROR` | Workflow encountered an error or was stopped |
| `? UNKNOWN` | Status file missing or unreadable |

Node-level states follow the same pattern: `○ pending`, `⟳ running`, `✓ done`, `✗ error(code)`.

---

## Directory Structure

flowmon reads from the run registry automatically. Runs are stored under `$DATA/runs/` and tracked in `$DATA/runs/.registry`.

```
$DATA/runs/
├── .registry                  # list of all known run IDs
└── <run_id>/
    ├── meta                   # proj, started, pid
    ├── workflow.status        # RUNNING / COMPLETE / ERROR:...
    ├── run.log                # main workflow log
    ├── connections.snap       # node connection graph snapshot
    ├── <node>.node.snap       # per-node type snapshot
    ├── node_<node>.status     # per-node status
    └── node_<node>.log        # per-node log
```

---

## Part of Flow-SN

flowmon is a utility within the **Flow-SN** ecosystem — a powerful workflow runner built for Termux on Android where you build pipelines by connecting nodes.

→ [View the main Flow-SN repository](https://github.com/azaraeth/Flow-SN)
