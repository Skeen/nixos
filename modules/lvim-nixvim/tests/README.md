# lvim-nixvim tests

Two suites:

- `probes/` + `bin/unit-probe.sh` — unit fingerprint tests. Each probe is a Lua
  file that runs in BOTH editors and emits a fingerprint; the runner diffs them.
  ~230 option/state assertions + 13 probe files (editor identity, plugin
  load sets, keymaps, autocmds, commands, highlights, diagnostics,
  telescope/gitsigns/cmp/lualine/dap/nvim-tree config knobs, file-type
  indentation, etc.).

- `scenarios/` + `bin/run-scenario.sh` — keystroke-level tmux flows replayed in
  both editors, comparing the resulting work trees. Current set covers
  editing/motions/search/replace, macro records, visual/visual-block,
  comment toggling, splits, quickfix, registers, nvim-tree toggle, toggleterm,
  telescope find/live-grep, undo across sessions, buffer-kill via which-key,
  statusline, Lvim* commands, completion (native cmp), gitsigns modify+stage,
  which-key popup, quickfix2, registers2, visualblock2, lvimui, α-dashboard
  dismissal.

Run (dev sandbox):

    export NIX_SYS=/nix/store/...-nixos-system-satchel
    # unit suite
    for p in tests/probes/probe-*.lua; do
      tests/bin/unit-probe.sh "$(basename $p .lua | sed 's/probe-//')" "$p"
    done
    # scenario suite
    for s in tests/scenarios/scen-*.sh; do
      tests/bin/run-scenario.sh "$(basename $s .sh | sed 's/scen-//')" "$s"
    done
