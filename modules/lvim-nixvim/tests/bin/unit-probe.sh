#!/nix/store/l9k32vj2aczxw62134j1x0dsh569jz2l-bash-5.2p37/bin/bash
# Run a named unit assertion in BOTH editors and compare captured output.
# usage: unit-probe.sh <name> <lua-probe-file>
set -u
export PATH=/nix/store/m7gd6hk60nd2hkmpyrfzm2v3q3j8ymrc-tmux-3.7b.bin:/run/current-system/sw/bin:/nix/store/m7gd6hk60nd2hkmpyrfzm2v3q3j8ymrc-tmux-3.7b/bin:$PATH
NAME="$1"; PROBE="$2"
export PATH=/run/current-system/sw/bin:$PATH
LV_HOME=${LV_HOME:-/tmp/opencode/unit/home-lvim}
NX_HOME=${NX_HOME:-/tmp/opencode/unit/home-nixvim}
mkdir -p "$LV_HOME/.config/lvim" "$NX_HOME"
[ -f "$LV_HOME/.config/lvim/config.lua" ] || cp /tmp/opencode/lvim-pkg/share/lvim/config.example.lua "$LV_HOME/.config/lvim/config.lua"
LV_NVIM=${LV_NVIM:-/nix/store/qw8rlayz95nlzcikz6vv3l5csvbw5zk6-neovim-0.11.5/bin/nvim}
LV_BASE=${LV_BASE:-/tmp/opencode/lvim-pkg/share/lvim/init.lua}
NIX_SYS=${NIX_SYS:?}
run_probe() {
  local which="$1" out="$2" home
  if [ "$which" = lvim ]; then
    home=$LV_HOME
    local inner="env -i HOME=$home TERM=xterm-256color PATH=/run/current-system/sw/bin:/usr/bin:/bin NVIM_APPNAME=lvim LUNARVIM_RUNTIME_DIR=$home/.local/share/lvim LUNARVIM_CONFIG_DIR=$home/.config/lvim LUNARVIM_CACHE_DIR=$home/.cache/lvim $LV_NVIM -u $LV_BASE"
  else
    home=$NX_HOME
    local inner="env -i HOME=$home TERM=xterm-256color NVIM_APPNAME=lvim PATH=/run/current-system/sw/bin:/usr/bin:/bin $NIX_SYS/sw/bin/lvim"
  fi
  # through a pty so windowed-only options load in BOTH ( LV gates its
  # default_options on #vim.api.nvim_list_uis() ).
  # The probe itself writes its fingerprint to $home/unit-out.txt.
  rm -f "$home/unit-out.txt"
  timeout 240 script -qec "$inner -c \"lua vim.env.UNIT_OUT='$home/unit-out.txt'\" -c \"lua local f=loadfile([[$PROBE]]) if f then f() else error('probe missing') end\" -c 'qa!'" /dev/null > "$out.raw" 2>"$out.err" || true
  if [ -f "$home/unit-out.txt" ]; then
    cp "$home/unit-out.txt" "$out"
    echo "rc=0" >> "$out"
  else
    echo "PROBE-DID-NOT-RUN" > "$out"
  fi
  # keep stderr noise but normalized away from the diff (paths/appname) below
  # msgs land in stderr; keep both
  mv "$out.stripped" "$out" 2>/dev/null || true
}
run_probe lvim "/tmp/unit.$NAME.lvim.out"
run_probe nixvim "/tmp/unit.$NAME.nixvim.out"
# normalize paths/appname noise
for e in lvim nixvim; do
  sed -i -e "s|/tmp/opencode/unit/home-lvim|HOMED|g" -e "s|/tmp/opencode/unit/home-nixvim|HOMED|g" -e "s|.local/state/lvim|STATE|g" -e "s|.cache/lvim|CACHE|g" -e "s|/nix/store/[a-z0-9]*-|/nix/store/xxx-|g" "/tmp/unit.$NAME.$e.out" 2>/dev/null
done
if diff -u "/tmp/unit.$NAME.lvim.out" "/tmp/unit.$NAME.nixvim.out" > "/tmp/unit.$NAME.diff"; then
  echo "PASS $NAME"
else
  echo "FAIL $NAME"; head -20 "/tmp/unit.$NAME.diff"
fi
