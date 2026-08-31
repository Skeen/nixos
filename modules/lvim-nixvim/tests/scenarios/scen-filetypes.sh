source /tmp/opencode/harness/lib-common.sh
ex "edit src/lib.py" 3
press_enter_if_gate
w 2
txt ":redir >> "$HOME_R"/opts.txt" 0.4
key Enter 0.6
w 0.6
txt ":lua print('ft',vim.bo.filetype,'ts',vim.o.ts,'sw',vim.o.sw,'et',vim.o.et,'wrap',vim.o.wrap,'nu',vim.o.nu,'cl',vim.o.cursorline,'sc',vim.o.signcolumn,'ls',vim.o.laststatus,'tgc',vim.o.termguicolors,'mouse',vim.o.mouse,'cb',vim.o.clipboard,'hidden',vim.o.hidden,'so',vim.o.scrolloff,'ut',vim.o.updatetime,'to',vim.o.timeoutlen,'nw',vim.o.numberwidth,'fm',vim.o.foldmethod)" 0.5
key Enter 0.8
w 0.8
txt ":redir END" 0.4
key Enter 0.8
w 1
ex "q!" 2
