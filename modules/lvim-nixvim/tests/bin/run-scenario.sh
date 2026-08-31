#!/nix/store/l9k32vj2aczxw62134j1x0dsh569jz2l-bash-5.2p37/bin/bash
set -u
TMUX_BIN=/nix/store/m7gd6hk60nd2hkmpyrfzm2v3q3j8ymrc-tmux-3.7b/bin/tmux
export PATH=/nix/store/m7gd6hk60nd2hkmpyrfzm2v3q3j8ymrc-tmux-3.7b/bin:/nix/store/l9k32vj2aczxw62134j1x0dsh569jz2l-bash-5.2p37/bin:/run/current-system/sw/bin:$PATH
NIX_SYS=/nix/store/fkgkjcxl1d1xmhzmilmpj89g3zng7jgw-nixos-system-satchel-25.05.20260102.ac62194
NIXV_IM_BIN=$NIX_SYS/sw/bin/lvim
LV_NVIM=/nix/store/qw8rlayz95nlzcikz6vv3l5csvbw5zk6-neovim-0.11.5/bin/nvim
LV_BASE=/tmp/opencode/lvim-pkg/share/lvim/init.lua
BASE=/tmp/opencode/harness
mkdir -p "$BASE/results" "$BASE/logs" "$BASE/work"
SCEN="$1"; SCRIPT="$2"
setup_home() {
  local ed="$1"
  HOMEDIR="$BASE/work/$SCEN/$ed"
  rm -rf "$HOMEDIR"
  mkdir -p "$HOMEDIR/.config/lvim" "$HOMEDIR/.cache" "$HOMEDIR/.local/share"
  cp -r "$BASE/fixtures/repo" "$HOMEDIR/repo"
  if [ "$ed" = lvim ]; then
    cp /tmp/opencode/lvim-pkg/share/lvim/config.example.lua "$HOMEDIR/.config/lvim/config.lua"
    if [ -d /tmp/opencode/harness/lvim-share ] && [ ! -d "$HOMEDIR/.local/share/lvim" ]; then
      cp -r /tmp/opencode/harness/lvim-share "$HOMEDIR/.local/share/lvim"
    fi
    CMD="env -i HOME=$HOMEDIR TERM=xterm-256color PATH=$NIX_SYS/sw/bin:/usr/bin:/bin \
      LUNARVIM_RUNTIME_DIR=$HOMEDIR/.local/share/lvim \
      LUNARVIM_CONFIG_DIR=$HOMEDIR/.config/lvim \
      LUNARVIM_CACHE_DIR=$HOMEDIR/.cache/lvim \
      $LV_NVIM -u $LV_BASE"
  else
    CMD="env -i HOME=$HOMEDIR TERM=xterm-256color PATH=$NIX_SYS/sw/bin:/usr/bin:/bin \
      NVIM_APPNAME=lvim $NIXV_IM_BIN"
  fi
}
run_editor() {
  local ed="$1"
  setup_home "$ed"
  local sess="t_${SCEN}_${ed}"
  $TMUX_BIN kill-session -t "$sess" 2>/dev/null || true
  OPENARG=${OPENARG:-}
  $TMUX_BIN new-session -d -x 220 -y 50 -s "$sess" "cd $HOMEDIR/repo && $CMD $OPENARG"
  # Wait until the editor is idle: either statusline gone or no Compiling/pending text for 3 polls
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
    sleep 4
    cap=$($TMUX_BIN capture-pane -t "$sess" -p 2>/dev/null)
    if ! echo "$cap" | grep -qE 'Compiling|Tasks:|Install \('; then
      break
    fi
  done
  ENVED="$ed" HOME_R="$HOMEDIR" SESSION="$sess" bash "$SCRIPT" > "$BASE/logs/$SCEN.$ed.in.log" 2>&1
  local rc=$?
  $TMUX_BIN send-keys -t "$sess" Escape; sleep 0.4
  $TMUX_BIN send-keys -t "$sess" -l ":qa!"; sleep 0.4
  $TMUX_BIN send-keys -t "$sess" Enter; sleep 2
  mkdir -p "$BASE/work/$SCEN/$ed/caps"
  if [ "$ed" = "lvim" ]; then
    for f in wk wkb wk-cond cap0 cap1; do
      [ -f "$BASE/work/$SCEN/$f.txt" ] && cp "$BASE/work/$SCEN/$f.txt" "$BASE/work/$SCEN/$ed/caps/$f.txt"
    done
  fi
  $TMUX_BIN kill-session -t "$sess" 2>/dev/null || true
  return $rc
}
echo "=== $SCEN lvim ==="
run_editor lvim > "$BASE/logs/$SCEN.lvim.log" 2>&1; rcL=$?
mkdir -p "$BASE/work/$SCEN/lvim/caps" && for f in wk wkb wk-cond tree tree2 opts term term2; do [ -f "$BASE/work/$SCEN/$f.txt" ] && cp "$BASE/work/$SCEN/$f.txt" "$BASE/work/$SCEN/lvim/caps/$f.txt"; done
echo "=== $SCEN nixvim ==="
run_editor nixvim > "$BASE/logs/$SCEN.nixvim.log" 2>&1; rcN=$?
L=$BASE/work/$SCEN/lvim/repo; N=$BASE/work/$SCEN/nixvim/repo
diff -r --exclude=.git "$L" "$N" > "$BASE/results/$SCEN.diff" 2>&1
echo "rc lvim=$rcL nixvim=$rcN"
if [ -s "$BASE/results/$SCEN.diff" ]; then
  echo "DIFF $SCEN:"; head -40 "$BASE/results/$SCEN.diff"; exit 1
else
  echo "IDENTICAL $SCEN"; echo identical > "$BASE/results/$SCEN.diff"
fi
