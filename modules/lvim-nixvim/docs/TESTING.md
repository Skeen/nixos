# lvim-nixvim Testing

Two complementary suites live in this repository.

## 1. Unit fingerprint tests (~230 assertions)

File-driven probes (`tests/probes/probe-*.lua`) run inside BOTH editors (reference
LunarVim and our NixVim build) and dump option/keymap/command/plugin/telescope/
treesitter/diagnostic fingerprints. A bash runner diffs them.

Run from a dev sandbox:

    export NIX_SYS=/nix/store/...-nixos-system-satchel    # the candidate
    tests/bin/unit-probe.sh identity ./probes/probe-identity.lua

Coverage:

  identity          editor identity, module load set
  options           ~215 global options + normalized shortmess/grepprg
  options-lv-extra  215-option battery (parsed)
  keymaps           all-mode keymaps (user wrist keys)
  autocmds          core default autocmds
  commands2         core ex-command presence (user-invoked)
  highlights        48 highlight-group definitions/links
  diagnostics       6 knobs from vim.diagnostic.config
  telescope2        defaults (prompt prefix, sorting, vimgrep, pickers)
  gitsigns2         gitsigns config keys
  cmp2              cmp configuration knobs
  leader            <leader> keymap inventory
  ts                treesitter parser availability
  filetypes-buf     file-type indentation rules (c/css/html/js/json/lua/…)
  mapleaderkeys     which-key registrations
  luasnip           luasnip module/config/loaders
  buffers           buffer/tab/window counts
  runtime           editor runtime flags (filetype, providers)
  weapons           gitsigns/telescope/cmp/lualine/dap/nvim-tree/cmp-config knobs

## 2. Scenario (tmux) tests

Keystroke-level flows (`tests/scenarios/`) replay editor interactions on both
editors and diff the resulting repository work trees — identical results
required (PASS).

## Repeat runs

    tests/bin/unit-probe.sh       # loop over probes
    tests/bin/run-scenario.sh     # loop over scenarios
