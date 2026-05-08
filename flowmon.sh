#!/usr/bin/env bash
# ╔══════════════════════════════════════════════╗
# ║   flowmon.sh  —  Flow Monitor                ║
# ║   Background Run Manager · Live Logs · REPL  ║
# ╚══════════════════════════════════════════════╝

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/UIM"

# ═══════════════════════════════════════════════
# COLORS — blue theme overrides
# ═══════════════════════════════════════════════
CY='\033[38;5;39m'    # bright blue (prompt arrow)
MG='\033[38;5;177m'   # magenta (unused)
# Override orange accent → blue for flowmon theme
OR='\033[38;5;75m'    # sky blue  (replaces orange as main accent)
OD='\033[38;5;68m'    # steel blue (replaces orange-dim)
BL='\033[38;5;111m'   # periwinkle (node lang badges, keep)
GR='\033[38;5;114m'   # green (keep for ✓ done)
RE='\033[38;5;203m'   # red (keep for errors)

# ═══════════════════════════════════════════════
# REGISTRY HELPERS
# ═══════════════════════════════════════════════

RUNS_DIR="$DATA/runs"
REGISTRY="$RUNS_DIR/.registry"

# list all known run IDs (deduped, existing only)
list_run_ids() {
  [[ -f "$REGISTRY" ]] || return
  sort -u "$REGISTRY" | while IFS= read -r rid; do
    [[ -d "$RUNS_DIR/$rid" ]] && echo "$rid"
  done
}


# read a meta field:  meta_get <run_id> <field>
meta_get() {
  local rid="$1" field="$2"
  grep "^${field}=" "$RUNS_DIR/$rid/meta" 2>/dev/null | head -1 | cut -d= -f2-
}

# read workflow status string
run_status() {
  local rid="$1"
  cat "$RUNS_DIR/$rid/workflow.status" 2>/dev/null || echo "UNKNOWN"
}

# colored status badge
status_badge() {
  local s="$1"
  case "$s" in
    RUNNING)   echo -e "${BL}⟳ RUNNING${RS}" ;;
    COMPLETE)  echo -e "${GR}✓ COMPLETE${RS}" ;;
    ERROR*)    echo -e "${RE}✗ ERROR${RS}" ;;
    *)         echo -e "${GY}? UNKNOWN${RS}" ;;
  esac
}

# list node IDs from snapshotted connection file
snap_nodes() {
  local rid="$1"
  local snap="$RUNS_DIR/$rid/connections.snap"
  [[ -f "$snap" ]] || return
  # gather unique node names from connection file + .snap files
  {
    awk '{print $1; print $2}' "$snap"
    ls "$RUNS_DIR/$rid/"*.snap 2>/dev/null | xargs -I{} basename {} .node.snap
  } | sort -u | grep -v '^\s*$'
}

# node status badge (per-node)
node_status_badge() {
  local s="$1"
  case "$s" in
    PENDING)  echo -e "${GY}○ pending${RS}" ;;
    RUNNING)  echo -e "${BL}⟳ running${RS}" ;;
    DONE)     echo -e "${GR}✓ done${RS}" ;;
    ERROR*)   local code="${s#ERROR:}"; echo -e "${RE}✗ error($code)${RS}" ;;
    *)        echo -e "${GY}· waiting${RS}" ;;
  esac
}

# ═══════════════════════════════════════════════
# BANNER
# ═══════════════════════════════════════════════

mon_banner() {
  clear
  echo -e "\033[38;5;39m${BD}"
  echo -e "     ███████╗██╗      ██████╗ ██╗    ██╗███╗   ███╗ ██████╗ ███╗   ██╗"
  echo -e "     ██╔════╝██║     ██╔═══██╗██║    ██║████╗ ████║██╔═══██╗████╗  ██║"
  echo -e "     █████╗  ██║     ██║   ██║██║ █╗ ██║██╔████╔██║██║   ██║██╔██╗ ██║"
  echo -e "     ██╔══╝  ██║     ██║   ██║██║███╗██║██║╚██╔╝██║██║   ██║██║╚██╗██║"
  echo -e "     ██║     ███████╗╚██████╔╝╚███╔███╔╝██║ ╚═╝ ██║╚██████╔╝██║ ╚████║"
  echo -e "     ╚═╝     ╚══════╝ ╚═════╝  ╚══╝╚══╝ ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝"
  echo -e "     V1.0 · Background Run Monitor${RS}${GY}"
  echo -e "\033[38;5;68m────────────────────────────────────────────────────────────────────${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: ls  —  list all runs
# ═══════════════════════════════════════════════
cmd_clear() {
  clear
  mon_banner
  info "type ${OR}help${RS}${WD} for commands  ·  monitoring: ${GL}$RUNS_DIR${RS}"
  echo ""

  # show run count on startup
  local runs=(); mapfile -t runs < <(list_run_ids)
  if [[ ${#runs[@]} -gt 0 ]]; then
    local active=0
    for rid in "${runs[@]}"; do
      [[ "$(run_status "$rid")" == "RUNNING" ]] && active=$((active+1))
    done
    info "${#runs[@]} run(s) in registry · ${BL}${active} active${RS}"
  else
    info "no runs yet — use ${OR}runbg${RS}${WD} inside flow to start one"
  fi
  echo ""
}

cmd_ls() {
  hdr "background runs"
  echo ""

  local runs=()
  mapfile -t runs < <(list_run_ids)

  if [[ ${#runs[@]} -eq 0 ]]; then
    info "no background runs found"
    info "start one with: ${OR}runbg${RS}${WD} inside flow"
    echo ""; return
  fi

  # header row
  printf "  ${GY}%-4s  %-36s  %-10s  %-19s  %s${RS}\n" \
    "#" "RUN ID" "PROJECT" "STARTED" "STATUS"
  echo -e "  ${GY}$(printf '─%.0s' {1..75})${RS}"

  local i=1
  for rid in "${runs[@]}"; do
    local proj started status
    proj=$(meta_get "$rid" "proj")
    started=$(meta_get "$rid" "started")
    status=$(run_status "$rid")
    local badge
    badge=$(status_badge "$status")
    printf "  ${OR}%-4s${RS}  ${WH}%-36s${RS}  ${GL}%-10s${RS}  ${GY}%-19s${RS}  %b\n" \
      "$i" "$rid" "$proj" "$started" "$badge"
    i=$((i+1))
  done
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: status <run_id>  —  per-node status table
# ═══════════════════════════════════════════════

cmd_status() {
  local rid="$1"
  [[ -z "$rid" ]] && { err "usage: status <run_id>"; return; }
  [[ -d "$RUNS_DIR/$rid" ]] || { err "run '$rid' not found — try: ls"; return; }

  local proj started status
  proj=$(meta_get    "$rid" "proj")
  started=$(meta_get "$rid" "started")
  status=$(run_status "$rid")

  hdr "status: $rid"
  echo ""
  echo -e "  ${GL}project  ${RS}${OR}${proj}${RS}"
  echo -e "  ${GL}started  ${RS}${WD}${started}${RS}"
  echo -e "  ${GL}status   ${RS}$(status_badge "$status")"
  echo ""

  # per-node table
  local nodes=()
  # gather from snap files
  for snap in "$RUNS_DIR/$rid/"*.node.snap; do
    [[ -f "$snap" ]] || continue
    local nm
    nm=$(basename "$snap" .node.snap)
    nodes+=("$nm")
  done

  if [[ ${#nodes[@]} -gt 0 ]]; then
    printf "  ${GY}%-20s  %-10s  %s${RS}\n" "NODE" "TYPE" "STATUS"
    echo -e "  ${GY}$(printf '─%.0s' {1..50})${RS}"
    for nm in "${nodes[@]}"; do
      local ntype ns_raw ns_badge
      ntype=$(sed -n '1p' "$RUNS_DIR/$rid/${nm}.node.snap" 2>/dev/null)
      ns_raw=$(cat "$RUNS_DIR/$rid/node_${nm}.status" 2>/dev/null || echo "waiting")
      ns_badge=$(node_status_badge "$ns_raw")
      printf "  ${OR}%-20s${RS}  ${GL}%-10s${RS}  %b\n" "$nm" "$ntype" "$ns_badge"
    done
  else
    info "no node snapshots found (run may still be starting)"
  fi
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: logs <run_id> [node]  —  tail logs
# ═══════════════════════════════════════════════

cmd_logs() {
  local rid="$1" node_id="$2"
  [[ -z "$rid" ]] && { err "usage: logs <run_id> [node_id]"; return; }
  [[ -d "$RUNS_DIR/$rid" ]] || { err "run '$rid' not found — try: ls"; return; }

  local log_file
  if [[ -n "$node_id" ]]; then
    log_file="$RUNS_DIR/$rid/node_${node_id}.log"
    [[ -f "$log_file" ]] || { err "no log for node '$node_id' in run '$rid'"; return; }
    hdr "logs: $rid → $node_id"
  else
    log_file="$RUNS_DIR/$rid/run.log"
    [[ -f "$log_file" ]] || { err "run log not found for '$rid'"; return; }
    hdr "logs: $rid  (workflow log)"
  fi

  local status
  status=$(run_status "$rid")

  echo ""
  echo -e "  ${GY}file: ${WD}${log_file}${RS}"
  div
  echo ""

  if [[ "$status" == "RUNNING" ]]; then
    info "${BL}live tail${RS}${WD} — press ${OR}Ctrl+C${RS}${WD} to return to flowmon"
    echo ""
    trap 'echo ""; info "stopped following log"; echo ""; trap - INT' INT
    tail -n 40 -f "$log_file" &
    local _tail_pid=$!
    wait $_tail_pid 2>/dev/null
    trap - INT
    echo ""
  else
    # show full log with line numbers
    local lineno=0
    while IFS= read -r line; do
      lineno=$((lineno+1))
      printf "  ${GY}%4d  ${RS}${WD}%s${RS}\n" "$lineno" "$line"
    done < "$log_file"
    echo ""
    echo -e "  ${GY}── end of log · $(wc -l < "$log_file") lines ──${RS}"
    echo ""
  fi
}

# ═══════════════════════════════════════════════
# CMD: watch <run_id>  —  live-refresh status
# ═══════════════════════════════════════════════

cmd_watch() {
  local rid="$1"
  [[ -z "$rid" ]] && { err "usage: watch <run_id>"; return; }
  [[ -d "$RUNS_DIR/$rid" ]] || { err "run '$rid' not found — try: ls"; return; }

  # trap Ctrl+C so we can restore cursor and return cleanly to REPL
  local _watch_exit=0
  trap '_watch_exit=1' INT

  # clear screen and hide cursor for clean watch UI
  clear
  tput civis 2>/dev/null

  # restore cursor on any exit
  _watch_cleanup() {
    tput cnorm 2>/dev/null
    trap - INT
  }

  local proj started
  proj=$(meta_get    "$rid" "proj")
  started=$(meta_get "$rid" "started")

  while true; do
    local status
    status=$(run_status "$rid")

    # move to top-left and redraw everything in place
    tput cup 0 0 2>/dev/null

    # header
    echo -e "${OR}${BD}  ── watch: ${rid} ${RS}${GY}────────────────────────────${RS}     "
    echo ""
    echo -e "  ${GL}project  ${RS}${OR}${proj}${RS}                    "
    echo -e "  ${GL}started  ${RS}${WD}${started}${RS}          "
    echo -e "  ${GL}status   ${RS}$(status_badge "$status")                    "
    echo -e "  ${GL}updated  ${RS}${GY}$(date '+%H:%M:%S')${RS}          "
    echo ""
    printf "  ${GY}%-20s  %-10s  %-14s  %s${RS}     \n" "NODE" "TYPE" "STATUS" "LINES"
    echo -e "  ${GY}$(printf '─%.0s' {1..58})${RS}"

    for snap in "$RUNS_DIR/$rid/"*.node.snap; do
      [[ -f "$snap" ]] || continue
      local nm ntype ns_raw ns_badge lines
      nm=$(basename "$snap" .node.snap)
      ntype=$(sed -n '1p' "$snap" 2>/dev/null)
      ns_raw=$(cat "$RUNS_DIR/$rid/node_${nm}.status" 2>/dev/null && true || echo "waiting")
      ns_badge=$(node_status_badge "$ns_raw")
      # suppress error if log file not yet created
      lines=$(wc -l < "$RUNS_DIR/$rid/node_${nm}.log" 2>/dev/null || echo 0)
      printf "  ${OR}%-20s${RS}  ${GL}%-10s${RS}  %b  ${GY}%s lines${RS}     \n" \
        "$nm" "$ntype" "$ns_badge" "$lines"
    done

    echo ""
    echo -e "  ${GY}press Ctrl+C to exit watch${RS}     "

    # exit if workflow finished or user pressed Ctrl+C
    if [[ "$status" != "RUNNING" ]]; then
      echo ""
      echo -e "  ${GY}── workflow ended: $(status_badge "$status") ──${RS}     "
      echo ""
      _watch_cleanup
      break
    fi
    if [[ $_watch_exit -eq 1 ]]; then
      _watch_cleanup
      break
    fi

    sleep 2
  done

  # clear watch screen and return to normal REPL view
  clear
  mon_banner
  info "type ${OR}help${RS}${WD} for commands  ·  monitoring: ${GL}$RUNS_DIR${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: stop <run_id>  —  kill a running workflow
# ═══════════════════════════════════════════════

cmd_stop() {
  local rid="$1"
  [[ -z "$rid" ]] && { err "usage: stop <run_id>"; return; }
  [[ -d "$RUNS_DIR/$rid" ]] || { err "run '$rid' not found — try: ls"; return; }

  local status
  status=$(run_status "$rid")

  if [[ "$status" != "RUNNING" ]]; then
    warn "run '$rid' is not running  (status: $status)"
    return
  fi

  hdr "stop: $rid"
  echo ""
  echo -ne "  ${RE}kill this workflow run? [y/N] ${RS}"
  read -r c
  [[ "$c" == "y" || "$c" == "Y" ]] || { info "cancelled"; return; }

  # read PID from meta
  local pid
  pid=$(meta_get "$rid" "pid")

  local killed=0
  if [[ -n "$pid" && "$pid" -gt 0 ]] 2>/dev/null; then
    # kill the process group to also kill child scripts
    if kill -0 "$pid" 2>/dev/null; then
      kill -- -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null
      sleep 0.5
      # force if still alive
      kill -9 "$pid" 2>/dev/null
      killed=1
    fi
  fi

  # mark all RUNNING nodes as stopped
  for sf in "$RUNS_DIR/$rid/"node_*.status; do
    [[ -f "$sf" ]] || continue
    local sv; sv=$(cat "$sf")
    [[ "$sv" == "RUNNING" || "$sv" == "PENDING" ]] && echo "ERROR:stopped" > "$sf"
  done

  echo "ERROR:stopped" > "$RUNS_DIR/$rid/workflow.status"
  echo "[$(date '+%H:%M:%S')] STOPPED by user (flowmon)" >> "$RUNS_DIR/$rid/run.log"

  if [[ $killed -eq 1 ]]; then
    ok "killed PID $pid and marked run as stopped"
  else
    ok "marked run as stopped (process may have already exited)"
  fi
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: rm <run_id>  —  delete a run's data
# ═══════════════════════════════════════════════

cmd_rm() {
  local rid="$1"
  [[ -z "$rid" ]] && { err "usage: rm <run_id>"; return; }
  [[ -d "$RUNS_DIR/$rid" ]] || { err "run '$rid' not found"; return; }

  local status
  status=$(run_status "$rid")
  if [[ "$status" == "RUNNING" ]]; then
    warn "run is still active — stop it first with: stop $rid"
    return
  fi

  echo -ne "  ${OD}delete all data for run '$rid'? [y/N] ${RS}"
  read -r c
  [[ "$c" == "y" || "$c" == "Y" ]] || { info "cancelled"; return; }

  rm -rf "$RUNS_DIR/$rid"
  # remove from registry
  grep -v "^${rid}$" "$REGISTRY" > "$REGISTRY.tmp" 2>/dev/null
  mv "$REGISTRY.tmp" "$REGISTRY" 2>/dev/null

  ok "deleted run: $rid"
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: clean  —  remove all completed/errored runs
# ═══════════════════════════════════════════════

cmd_clean() {
  hdr "clean finished runs"
  echo ""

  local runs=()
  mapfile -t runs < <(list_run_ids)

  local count=0
  for rid in "${runs[@]}"; do
    local s; s=$(run_status "$rid")
    if [[ "$s" == "COMPLETE" || "$s" == ERROR* ]]; then
      echo -e "  ${GY}removing ${OR}${rid}${GY} (${s})${RS}"
      rm -rf "$RUNS_DIR/$rid"
      grep -v "^${rid}$" "$REGISTRY" > "$REGISTRY.tmp" 2>/dev/null
      mv "$REGISTRY.tmp" "$REGISTRY" 2>/dev/null
      count=$((count+1))
    fi
  done

  if [[ $count -eq 0 ]]; then
    info "nothing to clean (no completed/errored runs)"
  else
    ok "removed $count run(s)"
  fi
  echo ""
}

# ═══════════════════════════════════════════════
# CMD: tail <run_id> [node]  —  continuous tail
# (alias for logs when run is RUNNING)
# ═══════════════════════════════════════════════

cmd_tail() {
  # same as logs but always live-tails regardless of status
  local rid="$1" node_id="$2"
  [[ -z "$rid" ]] && { err "usage: tail <run_id> [node_id]"; return; }
  [[ -d "$RUNS_DIR/$rid" ]] || { err "run '$rid' not found — try: ls"; return; }

  local log_file
  if [[ -n "$node_id" ]]; then
    log_file="$RUNS_DIR/$rid/node_${node_id}.log"
    hdr "tail: $rid → $node_id"
  else
    log_file="$RUNS_DIR/$rid/run.log"
    hdr "tail: $rid  (workflow log)"
  fi

  [[ -f "$log_file" ]] || { err "log file not found: $log_file"; return; }

  echo ""
  info "press ${OR}Ctrl+C${RS}${WD} to return to flowmon"
  echo ""
  trap 'echo ""; info "stopped following log"; echo ""; trap - INT' INT
  tail -n 50 -f "$log_file" &
  local _tail_pid=$!
  wait $_tail_pid 2>/dev/null
  trap - INT
  echo ""
}

# ═══════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════

cmd_mon_help() {
  hdr "flowmon commands"
  echo ""
  local cmds=(
    "ls"                        "list all background runs and their status"
    "status <run_id>"           "show per-node status table for a run"
    "watch <run_id>"            "live-refresh status every 2s (auto-stops when done)"
    "logs <run_id> [node]"      "show logs (live tail if still running)"
    "tail <run_id> [node]"      "always live-tail a log (Ctrl+C to stop)"
    "stop <run_id>"             "kill a running workflow"
    "rm <run_id>"               "delete all data for a finished run"
    "clean"                     "remove all completed/errored runs"
    "help"                      "this screen"
    "exit / quit"               "exit flowmon"
  )
  local i=0
  while [[ $i -lt ${#cmds[@]} ]]; do
    printf "  ${OR}%-32s${RS}${WD}%s${RS}\n" "${cmds[$i]}" "${cmds[$((i+1))]}"
    i=$((i+2))
  done

  echo ""
  hdr "quick workflow"
  echo ""
  echo -e "  ${GL}# 1. start a workflow in the background (inside flow)${RS}"
  echo -e "  ${OR}  runbg${RS}"
  echo ""
  echo -e "  ${GL}# 2. open flowmon in a second terminal${RS}"
  echo -e "  ${OR}  bash flowmon.sh${RS}"
  echo ""
  echo -e "  ${GL}# 3. inside flowmon:${RS}"
  echo -e "  ${OR}  ls${RS}                    ${GY}# see all runs${RS}"
  echo -e "  ${OR}  status myproj_20250101_120000${RS}   ${GY}# node breakdown${RS}"
  echo -e "  ${OR}  watch  myproj_20250101_120000${RS}   ${GY}# live refresh${RS}"
  echo -e "  ${OR}  logs   myproj_20250101_120000 fetch${RS}  ${GY}# node log${RS}"
  echo -e "  ${OR}  stop   myproj_20250101_120000${RS}   ${GY}# kill it${RS}"
  echo ""
}

# ═══════════════════════════════════════════════
# PROMPT
# ═══════════════════════════════════════════════

mon_prompt() {
  local running=0
  local runs=(); mapfile -t runs < <(list_run_ids)
  for rid in "${runs[@]}"; do
    [[ "$(run_status "$rid")" == "RUNNING" ]] && running=$((running+1))
  done

  local badge=""
  if [[ $running -gt 0 ]]; then
    badge="${BL}⟳${RS} ${GY}${running} active${RS}"
  else
    badge="${GY}○ idle${RS}"
  fi

  echo ""
  echo -ne "  ${badge}  ${CY}${BD}▶${RS} "
}

# ═══════════════════════════════════════════════
# MAIN REPL
# ═══════════════════════════════════════════════

main() {
  mon_banner
  info "type ${OR}help${RS}${WD} for commands  ·  monitoring: ${GL}$RUNS_DIR${RS}"
  echo ""

  # show run count on startup
  local runs=(); mapfile -t runs < <(list_run_ids)
  if [[ ${#runs[@]} -gt 0 ]]; then
    local active=0
    for rid in "${runs[@]}"; do
      [[ "$(run_status "$rid")" == "RUNNING" ]] && active=$((active+1))
    done
    info "${#runs[@]} run(s) in registry · ${BL}${active} active${RS}"
  else
    info "no runs yet — use ${OR}runbg${RS}${WD} inside flow to start one"
  fi
  echo ""

  while true; do
    mon_prompt
    read -r input
    [[ -z "$input" ]] && continue

    local cmd arg1 arg2
    read -r cmd arg1 arg2 <<< "$input"

    case "$cmd" in
      clear)		  cmd_clear ;;
      ls|list)        cmd_ls ;;
      status|st)      cmd_status "$arg1" ;;
      watch|w)        cmd_watch  "$arg1" ;;
      logs|log)       cmd_logs   "$arg1" "$arg2" ;;
      tail)           cmd_tail   "$arg1" "$arg2" ;;
      stop|kill)      cmd_stop   "$arg1" ;;
      rm|del)         cmd_rm     "$arg1" ;;
      clean)          cmd_clean ;;
      help|h|\?)      cmd_mon_help ;;
      exit|quit|q)    echo -e "\n  ${GY}bye.${RS}\n"; exit 0 ;;
      *)              err "unknown command: $cmd  (type help)" ;;
    esac
  done
}

main "$@"
