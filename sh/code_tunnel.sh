# --- VS Code tunnel helper ------------------------------------
code_tunnel() {
  local action="$1"                       # start | stop | restart | status | log
  local NAME="${CODE_TUNNEL_NAME:-inigo-dslab}"
  local BASE="$HOME/.code-tunnel"         # per‑user working dir (persists on PVC)
  local PIDFILE="$BASE/${NAME}.pid"
  local LOG="$BASE/${NAME}.log"
  local CMD="code tunnel --name ${NAME} --accept-server-license-terms"

  mkdir -p "$BASE"

  # ---------- internal helpers ----------
  _is_running() {
    [[ -f "$PIDFILE" ]] || return 1
    local pid=$(<"$PIDFILE")
    [[ -n "$pid" ]] || return 1
    # verify the PID really is our tunnel
    ps -p "$pid" -o cmd= | grep -qF "$CMD"
  }

  _kill_tree() {                    # kill a whole process‑group safely
    local pid="$1"
    local pgid
    pgid=$(ps -o pgid= -p "$pid" | tr -d ' ')
    [[ -n "$pgid" ]] && {
      kill -TERM "-$pgid" 2>/dev/null
      sleep 2
      kill -KILL "-$pgid" 2>/dev/null
    }
  }

  case "$action" in
    start)
      if _is_running; then
        echo "➜ Tunnel already running (pid $(<"$PIDFILE"))."
        read -p "Kill it and launch a new one? [y/N] " ans
        [[ $ans =~ ^[Yy]$ ]] || { echo "Aborting."; return 1; }
        _kill_tree "$(cat "$PIDFILE")"
        rm -f "$PIDFILE"
      fi
      # detach in its own session so it survives the shell
      (
        setsid bash -c "$CMD >>\"$LOG\" 2>&1" &
        echo $! >"$PIDFILE"
      )
      disown -a                          # release shell's job control
      echo "✓ Started tunnel '${NAME}' (pid $(<"$PIDFILE")); log → $LOG"
      ;;

    stop)
      if _is_running; then
        _kill_tree "$(cat "$PIDFILE")"
        rm -f "$PIDFILE"
        echo "✓ Stopped tunnel '${NAME}'."
      else
        echo "⚠ No running tunnel found."
      fi
      ;;

    restart)
      $FUNCNAME stop && sleep 1 && $FUNCNAME start
      ;;

    status)
      if _is_running; then
        echo "✓ Tunnel '${NAME}' is running (pid $(<"$PIDFILE"))."
      else
        echo "✗ Tunnel '${NAME}' is NOT running."
      fi
      ;;

    log)
      tail -f "$LOG"
      ;;

    *)
      echo "Usage: code_tunnel {start|stop|restart|status|log}"
      return 1
      ;;
  esac
}
# --------------------------------------------------------------
