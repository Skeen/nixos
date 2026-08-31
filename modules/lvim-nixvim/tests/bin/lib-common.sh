TMUX_BIN=/nix/store/m7gd6hk60nd2hkmpyrfzm2v3q3j8ymrc-tmux-3.7b/bin/tmux
sk() { $TMUX_BIN send-keys -t "$SESSION" "$@"; }
w()  { sleep "${1:-1.2}"; }
txt() { sk -l "$1"; sleep "${2:-0.5}"; }
key() { sk "$1"; sleep "${2:-0.6}"; }
capture() { $TMUX_BIN capture-pane -t "$SESSION" -p > "$1"; }
press_enter_if_gate() {
  local out; out=$($TMUX_BIN capture-pane -t "$SESSION" -p | tail -3)
  case "$out" in
    *"Press ENTER"*) key Enter 1.0 ;;
    *) true ;;
  esac
}
ex() { key Escape 0.4; txt ":$1" 0.6; key Enter; sleep "${2:-2.0}"; press_enter_if_gate; }
clear_prompt() { press_enter_if_gate; }
