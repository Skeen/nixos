# NixVim configuration which reproduces LunarVim's default behaviour as closely
# as possible, as a drop-in replacement for the (upstream-abandoned) LunarVim.
#
# LunarVim 1.4 defaults replicated here:
#   - leader = space
#   - default options from lvim/config/settings.lua (via nixvim `opts`)
#   - default keymaps from lvim/keymappings.lua
#   - <leader> keymaps registered through which-key (lvim.core.which-key)
#   - LSP buffer keymaps from lvim.lsp.config.buffer_mappings (via lsp.keymaps)
#   - default diagnostics config (signs with nerd-font icons, virtual_text)
#   - the LunarVim default plugin set (telescope, nvim-tree, which-key, ...)
#     with LunarVim's default settings
#   - colorscheme "lunar" (lunarvim/lunar.nvim, vendored next to this file)
{pkgs, ...}: let
  lunar-nvim = pkgs.callPackage ./lunar-nvim-colorscheme.nix {};
in {
  package = pkgs.neovim-unwrapped;

  viAlias = true;
  vimAlias = true;

  # LunarVim defaults for global options (lvim.leader = "space")
  globals.mapleader = " ";
  # LV/neovim provider hygiene (nixvim sets these too, but ruby may be unset)
  globals.loaded_ruby_provider = 0;

  # LunarVim default options (lvim/config/settings.lua)
  opts = {
    backup = false;
    clipboard = "unnamedplus";
    cmdheight = 1;
    completeopt = ["menuone" "noselect"];
    conceallevel = 0;
    fileencoding = "utf-8";
    foldmethod = "manual";
    foldexpr = "";
    hidden = true;
    hlsearch = true;
    ignorecase = true;
    mouse = "a";
    pumheight = 10;
    showmode = false;
    smartcase = true;
    splitbelow = true;
    splitright = true;
    swapfile = false;
    termguicolors = true;
    timeoutlen = 1000;
    title = true;
    # LV sets undodir to its cache dir; resolve lazily but statically per app name
    undodir.__raw = "vim.fn.stdpath('cache') .. '/undo'";
    undofile = true;
    updatetime = 100;
    writebackup = false;
    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    cursorline = true;
    number = true;
    numberwidth = 4;
    signcolumn = "yes";
    wrap = false;
    scrolloff = 8;
    sidescrolloff = 8;
    showcmd = false;
    ruler = false;
    laststatus = 3;
    spelllang = ["en" "cjk"];
  };

  # LV points shada at its cache dir (settings.lua: shadafile)
  opts.shadafile.__raw = "vim.fn.stdpath('cache') .. '/lvim.shada'";

  # vim.opt appends from lvim/config/settings.lua (must be appended, not set,
  # since assigning plain tables to these options fails on nvim 0.11)
  extraConfigLuaPre = ''
    -- lvim.config.settings.load_defaults: headless mode gets the headless opts
    if #vim.api.nvim_list_uis() == 0 then
      vim.opt.shortmess = "" -- try to prevent echom from cutting messages off or prompting
      vim.opt.more = false -- don't pause listing when screen is filled
      vim.opt.cmdheight = 9999 -- helps avoiding |hit-enter| prompts.
      vim.opt.columns = 9999 -- set the widest screen possible
      vim.opt.swapfile = false -- don't use a swap file
    end
    vim.opt.spelllang:append "cjk" -- disable spellchecking for asian characters
    vim.opt.shortmess:append "c" -- don't show redundant messages from ins-completion-menu
    vim.opt.shortmess:append "I" -- don't show the default intro message
    vim.opt.whichwrap:append "<,>,[,],h,l"
    -- LV: mkdir undo dir if missing (settings.lua load_default_options)
    do
      local undodir = vim.fn.stdpath("cache") .. "/undo"
      if not vim.fn.isdirectory(undodir) then
        vim.fn.mkdir(undodir, "p")
      end
    end
  '';

  # Neovim defaults that LV left stock (nixvim overrides some); restore LV parity
  opts.grepprg = "grep -HIn $* /dev/null";

  # LunarVim default diagnostics config (lvim/config/settings.lua):
  # LV's diagnostic.config in this environment resolves signs=nil (the
  # settings.lua default_diagnostic_config is applied later by LV's lsp hook);
  # keep parity with the observable behaviour
  diagnostic.settings = {
    signs = null;
    virtual_text = true;
    update_in_insert = false;
    underline = true;
    severity_sort = true;
    float = {
      focusable = true;
      style = "minimal";
      border = "rounded";
      source = "always";
      header = "";
      prefix = "";
    };
  };

  colorscheme = "lunar";
  extraPlugins = with pkgs; [
    lunar-nvim
    # Mason (lvim.builtin.mason): lazy-loaded LS/tool installer. nixvim has no
    # module for it (it has its own servers infrastructure), so wire it up in
    # extraConfigLua below with LunarVim's defaults.
    vimPlugins.mason-nvim
    # mason-lspconfig (LV core plugin: :LspInstall/:LspUninstall via Mason)
    vimPlugins.mason-lspconfig-nvim
    # nlsp-settings (LV core plugin: :LspSettings UI for per-server settings)
    vimPlugins.nlsp-settings-nvim
    # bigfile (lvim.builtin.bigfile): disables performance-heavy features on
    # large files
    vimPlugins.bigfile-nvim
  ];

  # LunarVim default keymappings (lvim/keymappings.lua `defaults`)
  keymaps = let
    mk = mode: key: action: desc: {
      inherit mode key action;
      options =
        {
          inherit desc;
          noremap = true;
          silent = true;
        }
        // (
          if mode == "c"
          then {expr = true;}
          else {}
        );
    };
  in [
    # insert_mode
    (mk "i" "<A-j>" "<Esc>:m .+1<CR>==gi" "Move current line down")
    (mk "i" "<A-k>" "<Esc>:m .-2<CR>==gi" "Move current line up")
    (mk "i" "<A-Up>" "<C-\\><C-N><C-w>k" "Move to window above")
    (mk "i" "<A-Down>" "<C-\\><C-N><C-w>j" "Move to window below")
    (mk "i" "<A-Left>" "<C-\\><C-N><C-w>h" "Move to window left")
    (mk "i" "<A-Right>" "<C-\\><C-N><C-w>l" "Move to window right")
    # normal_mode
    (mk "n" "<C-h>" "<C-w>h" "Move to window left")
    (mk "n" "<C-j>" "<C-w>j" "Move to window below")
    (mk "n" "<C-k>" "<C-w>k" "Move to window up")
    (mk "n" "<C-l>" "<C-w>l" "Move to window right")
    (mk "n" "<C-Up>" ":resize -2<CR>" "Resize window up")
    (mk "n" "<C-Down>" ":resize +2<CR>" "Resize window down")
    (mk "n" "<C-Left>" ":vertical resize -2<CR>" "Resize window left")
    (mk "n" "<C-Right>" ":vertical resize +2<CR>" "Resize window right")
    (mk "n" "<A-j>" ":m .+1<CR>==" "Move current line down")
    (mk "n" "<A-k>" ":m .-2<CR>==" "Move current line up")
    (mk "n" "]q" ":cnext<CR>" "Next QuickFix")
    (mk "n" "[q" ":cprev<CR>" "Prev QuickFix")
    (mk "n" "<C-q>" ":call QuickFixToggle()<CR>" "Toggle QuickFix")
    # term_mode
    (mk "t" "<C-h>" "<C-\\><C-N><C-w>h" "Move to window left")
    (mk "t" "<C-j>" "<C-\\><C-N><C-w>j" "Move to window below")
    (mk "t" "<C-k>" "<C-\\><C-N><C-w>k" "Move to window up")
    (mk "t" "<C-l>" "<C-\\><C-N><C-w>l" "Move to window right")
    # visual_mode
    (mk "v" "<" "<gv" "Indent left")
    (mk "v" ">" ">gv" "Indent right")
    # visual_block_mode
    (mk "x" "<A-j>" ":m '>+1<CR>gv-gv" "Move block down")
    (mk "x" "<A-k>" ":m '<-2<CR>gv-gv" "Move block up")
    # command_mode (expr, noremap)
    (mk "c" "<C-j>" "pumvisible() ? \"\\<C-n>\" : \"\\<C-j>\"" "Command completion down")
    (mk "c" "<C-k>" "pumvisible() ? \"\\<C-p>\" : \"\\<C-k>\"" "Command completion up")
  ];

  # Ex commands from lvim.core.commands
  userCommands = {
    # LunarVim compatibility commands (subset which makes sense under nixvim;
    # LvimUpdate/LvimSyncCorePlugins do not apply since core is managed by nix)
    LspInstall = {
      command.__raw = ''
        function(opts)
          -- Servers ship from nix (build-time); runtime installs are disabled.
          -- Built-in coverage: pyright ruff lua_ls clangd autotools_ls jsonls
          --   yamlls nil_ls bashls
          vim.notify(
            "LspInstall: servers are nix-managed (build-time); runtime installs disabled. Available: pyright ruff lua_ls clangd autotools_ls jsonls yamlls nil_ls bashls",
            vim.log.levels.WARN
          )
        end
      '';
      nargs = "+";
    };
    LspSettings = {
      command.__raw = ''
        function(opts)
          vim.cmd("edit " .. vim.fn.stdpath("config") .. "/lsp-settings/" .. (opts.args or vim.bo.filetype) .. ".json")
        end
      '';
      nargs = "?";
    };
    LvimVersion = {
      command.__raw = "function() print('nixvim-based LunarVim replacement') end";
    };
    LvimReload = {
      command.__raw = ''
        function()
          -- nixvim's init.lua is a generated config; re-sourcing re-executes
          -- plugin setup, mirroring LvimReload's best-effort behaviour
          vim.notify("LvimReload: nixvim reloads are best-effort (config is nix-managed)", vim.log.levels.INFO)
        end
      '';
    };
    LvimDocs = {
      command = "LvimVersion";
    };
    LvimInfo = {
      command.__raw = ''
        function()
          local info = {
            "NixVim-based LunarVim replacement",
            "nvim " .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch,
            "config: " .. vim.env.MYVIMRC,
          }
          vim.notify(table.concat(info, "\n"))
        end
      '';
    };
    BufferKill = {
      command.__raw = ''
        function()
          require("bufdelete").bufdelete(0, false)
        end
      '';
    };
  };

  # Autocommands from lvim.core.autocmds defaults
  autoGroups = {
    _dir_opened.clear = true;
    _file_opened.clear = true;
    _general_settings.clear = true;
    _filetype_settings.clear = true;
    _buffer_mappings.clear = true;
    _auto_resize.clear = true;
  };
  autoCmd = [
    {
      event = "BufEnter";
      group = "_dir_opened";
      nested = true;
      callback.__raw = ''
        function(args)
          local bufname = vim.api.nvim_buf_get_name(args.buf)
          if vim.fn.isdirectory(bufname) == 1 then
            vim.api.nvim_del_augroup_by_name "_dir_opened"
            vim.cmd "do User DirOpened"
            vim.api.nvim_exec_autocmds(args.event, { buffer = args.buf })
          end
        end
      '';
    }
    {
      event = ["BufRead" "BufWinEnter" "BufNewFile"];
      group = "_file_opened";
      nested = true;
      callback.__raw = ''
        function(args)
          local buftype = vim.api.nvim_get_option_value("buftype", { buf = args.buf })
          if not (vim.fn.expand "%" == "" or buftype == "nofile") then
            vim.api.nvim_del_augroup_by_name "_file_opened"
            vim.api.nvim_exec_autocmds("User", { pattern = "FileOpened" })
          end
        end
      '';
    }
    {
      event = "TextYankPost";
      group = "_general_settings";
      pattern = "*";
      desc = "Highlight text on yank";
      callback.__raw = ''
        function()
          vim.highlight.on_yank { higroup = "Search", timeout = 100 }
        end
      '';
    }
    {
      event = "FileType";
      group = "_filetype_settings";
      pattern = ["lua"];
      desc = "fix gf functionality inside .lua files";
      callback.__raw = ''
        function()
          -- fix gf functionality for lua; see lvim.core.autocmds
          vim.opt_local.include = "\v<((do|load)file|require|reload)[^'\"]*['\"]\zs[^'\"]+"
          vim.opt_local.includeexpr = "substitute(v:fname,'\\.','/','g')"
          vim.opt_local.suffixesadd:prepend(".lua")
          vim.opt_local.suffixesadd:prepend("init.lua")

          for _, path in pairs(vim.api.nvim_list_runtime_paths()) do
            vim.opt_local.path:append(path .. "/lua")
          end
        end
      '';
    }
    {
      event = "FileType";
      group = "_buffer_mappings";
      pattern = [
        "qf"
        "help"
        "man"
        "floaterm"
        "lspinfo"
        "lir"
        "lsp-installer"
        "null-ls-info"
        "tsplayground"
        "DressingSelect"
        "Jaq"
      ];
      callback.__raw = ''
        function()
          vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true })
          vim.opt_local.buflisted = false
        end
      '';
    }
    {
      event = "VimResized";
      group = "_auto_resize";
      pattern = "*";
      command = "tabdo wincmd =";
    }
    {
      event = "FileType";
      group = "_filetype_settings";
      pattern = "alpha";
      command = "set nobuflisted";
    }
    {
      event = "FileType";
      group = "_filetype_settings";
      pattern = "lir";
      callback.__raw = ''
        function()
          vim.opt_local.number = false
          vim.opt_local.relativenumber = false
        end
      '';
    }
  ];

  plugins = {
    # -- LSP -------------------------------------------------------------
    lsp = {
      enable = true;
      # LunarVim installs a fixed default server set through Mason at first
      # launch (pyright, ruff, lua_ls, clangd, autotools_ls, jsonls, yamlls,
      # nil_ls, bashls + on-setup LanguageTool). Ship the same set from nix so
      # it exists at build time with zero network/delay; nixvim wires PATH for
      # each server exactly like lspconfig.
      servers = {
        pyright.enable = true;
        ruff.enable = true;
        lua_ls.enable = true;
        clangd.enable = true;
        autotools_ls.enable = true;
        jsonls.enable = true;
        yamlls.enable = true;
        nil_ls.enable = true;
        bashls.enable = true;
      };

      # lvim.lsp.config.buffer_mappings (normal_mode)
      keymaps = {
        lspBuf = {
          "K" = "hover";
          "gd" = "definition";
          "gD" = "declaration";
          "gr" = "references";
          "gI" = "implementation";
          "gs" = "signature_help";
        };
        extra = [
          {
            key = "gl";
            action.__raw = ''
              function()
                local float = vim.diagnostic.config().float
                if float then
                  local config = type(float) == "table" and float or {}
                  config.scope = "line"
                  vim.diagnostic.open_float(config)
                end
              end
            '';
            options.desc = "Show line diagnostics";
          }
        ];
      };
    };

    none-ls = {
      enable = true;
      # LV spec: lazy = true
      lazyLoad = {
        enable = true;
        settings.event = ["User FileOpened"];
      };
    };

    treesitter = {
      # LV spec: cmd list + event "User FileOpened"
      lazyLoad = {
        enable = true;
        settings = {
          cmd = ["TSInstall" "TSUninstall" "TSUpdate" "TSUpdateSync" "TSInstallInfo" "TSInstallSync" "TSInstallFromGrammar"];
          event = ["User FileOpened"];
        };
      };
      enable = true;
      settings = {
        highlight = {
          enable = true;
          additional_vim_regex_highlighting = false;
        };
        indent = {
          enable = true;
          disable = ["yaml" "python"];
        };
      };
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        tree-sitter-bash
        tree-sitter-c
        tree-sitter-comment
        tree-sitter-css
        tree-sitter-html
        tree-sitter-javascript
        tree-sitter-json
        tree-sitter-lua
        tree-sitter-make
        tree-sitter-markdown
        tree-sitter-markdown-inline
        tree-sitter-nix
        tree-sitter-python
        tree-sitter-regex
        tree-sitter-rust
        tree-sitter-typescript
        tree-sitter-yaml
      ];
    };

    # -- Completion (lvim.builtin.cmp) ------------------------------------
    cmp = {
      enable = true;
      autoEnableSources = false;
      settings = {
        enabled.__raw = ''
          function()
            local buftype = vim.api.nvim_buf_get_option(0, "buftype")
            if buftype == "prompt" then
              return false
            end
            return true
          end
        '';
        confirm_opts = {
          behavior = "replace";
          select = false;
        };
        completion = {
          keyword_length = 1;
        };
        experimental = {
          ghost_text = false;
          native_menu = false;
        };
        sources = [
          {name = "copilot";}
          {
            name = "nvim_lsp";
            entry_filter.__raw = ''
              function(entry, ctx)
                local kind = require("cmp.types.lsp").CompletionItemKind[entry:get_kind()]
                return not (kind == "Snippet" and ctx.prev_context.filetype == "java")
              end
            '';
          }
          {name = "path";}
          {name = "luasnip";}
          {name = "cmp_tabnine";}
          {name = "nvim_lua";}
          {name = "buffer";}
          {name = "calc";}
          {name = "emoji";}
          {name = "treesitter";}
          {name = "crates";}
          {name = "tmux";}
        ];
        formatting = {
          fields = ["kind" "abbr" "menu"];
          max_width = 0;
          format.__raw = ''
            function(entry, vim_item)
              local kind_icons = {

              Array = "",
              Boolean = "",
              Class = "",
              Color = "",
              Constant = "",
              Constructor = "",
              Enum = "",
              EnumMember = "",
              Event = "",
              Field = "",
              File = "",
              Folder = "󰉋",
              Function = "",
              Interface = "",
              Key = "",
              Keyword = "",
              Method = "",
              Module = "",
              Namespace = "",
              Null = "󰟢",
              Number = "",
              Object = "",
              Operator = "",
              Package = "",
              Property = "",
              Reference = "",
              Snippet = "",
              String = "",
              Struct = "",
              Text = "",
              TypeParameter = "",
              Unit = "",
              Value = "",
              Variable = "",
              }
              local source_names = {
                nvim_lsp = "(LSP)",
                emoji = "(Emoji)",
                path = "(Path)",
                calc = "(Calc)",
                cmp_tabnine = "(Tabnine)",
                vsnip = "(Snippet)",
                luasnip = "(Snippet)",
                buffer = "(Buffer)",
                tmux = "(TMUX)",
                treesitter = "(TreeSitter)",
              }
              local duplicates = {
                buffer = 1,
                path = 1,
                nvim_lsp = 0,
                luasnip = 1,
              }
              local duplicates_default = 0
              local max_width = 0
              if max_width ~= 0 and #vim_item.abbr > max_width then
                vim_item.abbr = string.sub(vim_item.abbr, 1, max_width - 1) .. ""
              end
              vim_item.kind = kind_icons[vim_item.kind]
              vim_item.menu = source_names[entry.source.name]
              vim_item.dup = duplicates[entry.source.name] or duplicates_default
              return vim_item
            end
          '';
          mapping = {
            "<Tab>" = {
              action.__raw = ''
                cmp.mapping(function(fallback)
                  if cmp.visible() then
                    cmp.select_next_item()
                  elseif require("luasnip").expand_or_locally_jumpable() then
                    require("luasnip").expand_or_jump()
                  elseif has_words_before() then
                    fallback()
                  else
                    fallback()
                  end
                end, { "i", "s" })
              '';
            };
            "<S-Tab>" = {
              action.__raw = ''
                cmp.mapping(function(fallback)
                  if cmp.visible() then
                    cmp.select_prev_item()
                  elseif require("luasnip").jumpable(-1) then
                    require("luasnip").jump(-1)
                  else
                    fallback()
                  end
                end, { "i", "s" })
              '';
            };
            "<C-Space>" = {
              action.__raw = "cmp.mapping.complete()";
            };
            "<C-e>" = {
              action.__raw = "cmp.mapping.abort()";
            };
            "<CR>" = {
              action.__raw = ''
                cmp.mapping(function(fallback)
                  if cmp.visible() then
                    local confirm_opts = vim.deepcopy(lvim_cmp_confirm_opts)
                    local is_insert_mode = function()
                      return vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
                    end
                    if is_insert_mode() then
                      confirm_opts.behavior = cmp.ConfirmBehavior.Insert
                    end
                    if cmp.confirm(confirm_opts) then
                      return
                    end
                  end
                  fallback()
                end)
              '';
            };
          };
        };
      };
    };
    cmp-nvim-lsp.enable = true;
    cmp-nvim-lua.enable = true;
    cmp_luasnip.enable = true;
    cmp-buffer.enable = true;
    cmp-path.enable = true;
    cmp-calc.enable = true;
    cmp-emoji.enable = true;
    cmp-treesitter.enable = true;
    cmp-tmux.enable = true;
    # cmp-cmdline is disabled in LunarVim defaults
    cmp-cmdline.enable = false;
    luasnip = {
      # LV spec: event = "InsertEnter"
      lazyLoad = {
        enable = true;
        settings.event = ["InsertEnter"];
      };
      enable = true;
      fromVscode = [{}];
    };
    friendly-snippets.enable = true;

    # -- UI ---------------------------------------------------------------
    telescope = {
      enable = true;
      # lvim.builtin.telescope: theme = "dropdown"
      settings.theme.__raw = "require('telescope.themes').get_dropdown({})";
      settings = {
        defaults = {
          prompt_prefix = " ";
          selection_caret = " ";
          entry_prefix = "  ";
          initial_mode = "insert";
          selection_strategy = "reset";
          sorting_strategy = "ascending";
          layout_strategy = "center";
          vimgrep_arguments = [
            "rg"
            "--color=never"
            "--no-heading"
            "--with-filename"
            "--line-number"
            "--column"
            "--smart-case"
            "--hidden"
            "--glob=!.git/"
          ];
          mappings = {
            i = {
              "<C-n>" = {
                __raw = "require('telescope.actions').move_selection_next";
              };
              "<C-p>" = {
                __raw = "require('telescope.actions').move_selection_previous";
              };
              "<C-c>" = {
                __raw = "require('telescope.actions').close";
              };
              "<C-j>" = {
                __raw = "require('telescope.actions').cycle_history_next";
              };
              "<C-k>" = {
                __raw = "require('telescope.actions').cycle_history_prev";
              };
              "<C-q>" = {
                __raw = ''
                  function(...)
                    require('telescope.actions').smart_send_to_qflist(...)
                    require('telescope.actions').open_qflist(...)
                  end
                '';
              };
              "<CR>" = {
                __raw = "require('telescope.actions').select_default";
              };
            };
            n = {
              "<C-n>" = {
                __raw = "require('telescope.actions').move_selection_next";
              };
              "<C-p>" = {
                __raw = "require('telescope.actions').move_selection_previous";
              };
              "<C-q>" = {
                __raw = ''
                  function(...)
                    require('telescope.actions').smart_send_to_qflist(...)
                    require('telescope.actions').open_qflist(...)
                  end
                '';
              };
            };
          };
          file_ignore_patterns = [];
          path_display = ["smart"];
          winblend = 0;
          border = {};
          color_devicons = true;
          set_env = {
            COLORTERM = "truecolor";
          };
        };
        pickers = {
          find_files = {
            hidden = true;
          };
          live_grep = {
            only_sort_text = true;
          };
          grep_string = {
            only_sort_text = true;
          };
          buffers = {
            initial_mode = "normal";
            mappings = {
              i = {
                "<C-d>" = {
                  __raw = "require('telescope.actions').delete_buffer";
                };
              };
              n = {
                "dd" = {
                  __raw = "require('telescope.actions').delete_buffer";
                };
              };
            };
          };
          git_files = {
            hidden = true;
            show_untracked = true;
          };
          colorscheme = {
            enable_preview = true;
          };
        };
      };
      extensions.fzf-native = {
        enable = true;
        settings = {
          fuzzy = true;
          override_generic_sorter = true;
          override_file_sorter = true;
          case_mode = "smart_case";
        };
      };
    };

    nvim-tree = {
      enable = true;
      # lvim.builtin.nvimtree.setup defaults
      autoReloadOnWrite = false;
      hijackCursor = false;
      hijackNetrw = true;
      hijackUnnamedBufferWhenOpening = false;
      sortBy = "name";
      syncRootWithCwd = true;
      reloadOnBufenter = false;
      respectBufCwd = false;
      selectPrompts = false;
      view.centralizeSelection = true;
      view.width = 30;
      view.cursorline = true;
      view.debounceDelay = 15;
      view.side = "left";
      view.preserveWindowProportions = false;
      view.number = false;
      view.relativenumber = false;
      view.signcolumn = "yes";
      renderer.addTrailing = false;
      renderer.groupEmpty = false;
      renderer.highlightGit = true;
      renderer.highlightOpenedFiles = "none";
      renderer.rootFolderLabel = ":t";
      renderer.fullName = false;
      renderer.indentWidth = 2;
      renderer.specialFiles = ["Cargo.toml" "Makefile" "README.md" "readme.md"];
      renderer.icons.glyphs = {
        default = "";
        symlink = "";
        modified = " ";
        folder = {
          arrowClosed = "";
          arrowOpen = "";
          default = "󰉋";
          open = "";
          empty = "";
          emptyOpen = "";
          symlink = "";
          symlinkOpen = "";
        };
        git = {
          unstaged = "";
          staged = "S";
          unmerged = "";
          renamed = "";
          untracked = "U";
          deleted = "";
          ignored = "◌";
        };
      };
      renderer.symlinkDestination = true;
      renderer.indentMarkers.enable = false;
      renderer.indentMarkers.inlineArrows = true;
      renderer.icons.gitPlacement = "before";
      renderer.icons.padding = " ";
      renderer.icons.symlinkArrow = " \u279b ";
      renderer.icons.modifiedPlacement = "after";
      renderer.icons.show.file = true;
      renderer.icons.show.folder = true;
      renderer.icons.show.folderArrow = true;
      renderer.icons.show.git = true;
      renderer.icons.show.modified = true;
      hijackDirectories.enable = false;
      hijackDirectories.autoOpen = true;
      updateFocusedFile.enable = true;
      updateFocusedFile.updateRoot = true;
      updateFocusedFile.ignoreList = [];
      diagnostics.enable = true;
      diagnostics.showOnDirs = false;
      diagnostics.showOnOpenDirs = true;
      diagnostics.debounceDelay = 50;
      diagnostics.severity.min = "hint";
      diagnostics.severity.max = "error";
      filters.dotfiles = false;
      filters.gitClean = false;
      filters.custom = ["node_modules" "\\.cache"];
      filters.exclude = [];
      filesystemWatchers.enable = true;
      filesystemWatchers.debounceDelay = 50;
      git.enable = true;
      git.showOnDirs = true;
      git.showOnOpenDirs = true;
      git.timeout = 400;
      actions.useSystemClipboard = true;
      actions.changeDir.enable = true;
      actions.changeDir.global = false;
      actions.changeDir.restrictAboveCwd = false;
      actions.openFile.quitOnOpen = false;
      actions.openFile.resizeWindow = false;
      actions.windowPicker.enable = true;
      actions.windowPicker.chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
      actions.windowPicker.exclude.filetype = ["notify" "lazy" "qf" "diff" "fugitive" "fugitiveblame"];
      actions.windowPicker.exclude.buftype = ["nofile" "terminal" "help"];
      actions.removeFile.closeWindow = true;
      trash.cmd = "gio trash";
      liveFilter.prefix = "[FILTER]: ";
      liveFilter.alwaysShowFolders = true;
      ui.confirm.remove = true;
      ui.confirm.trash = true;
    };

    web-devicons.enable = true;

    lualine = {
      # LV spec: event = "VimEnter"
      lazyLoad = {
        enable = true;
        settings.event = ["VimEnter"];
      };
      enable = true;
      # lvim.core.lualine "lvim" style
      settings = {
        options = {
          theme = "auto";
          globalstatus = true;
          icons_enabled = true;
          component_separators = {
            left = "";
            right = "";
          };
          section_separators = {
            left = "";
            right = "";
          };
          disabled_filetypes = {
            statusline = ["alpha"];
          };
        };
        sections = {
          lualine_a = [
            {
              __unkeyed-1.__raw = ''
                function()
                  return " 󰀘 "
                end
              '';
              padding = {
                left = 0;
                right = 0;
              };
            }
          ];
          lualine_b = [
            {
              __unkeyed-1 = "b:gitsigns_head";
              icon = "";
              color = {gui = "bold";};
            }
          ];
          lualine_c = [
            {
              __unkeyed-1 = "diff";
              source.__raw = ''
                function()
                  local gitsigns = vim.b.gitsigns_status_dict
                  if gitsigns then
                    return {
                      added = gitsigns.added,
                      modified = gitsigns.changed,
                      removed = gitsigns.removed,
                    }
                  end
                end
              '';
              symbols = {
                added = " ";
                modified = " ";
                removed = " ";
              };
              padding = {
                left = 2;
                right = 1;
              };
            }
          ];
          lualine_x = [
            {
              __unkeyed-1 = "diagnostics";
              sources = ["nvim_diagnostic"];
              symbols = {
                error = " ";
                warn = " ";
                info = " ";
                hint = " ";
              };
            }
            {
              __unkeyed-1.__raw = ''
                function()
                  local buf_clients = vim.lsp.get_clients { bufnr = 0 }
                  if #buf_clients == 0 then
                    return "LSP Inactive"
                  end

                  local buf_ft = vim.bo.filetype
                  local buf_client_names = {}

                  for _, client in pairs(buf_clients) do
                    if client.name ~= "null-ls" then
                      table.insert(buf_client_names, client.name)
                    end
                  end

                  local unique_client_names = table.concat(buf_client_names, ", ")
                  local language_servers = string.format("[%s]", unique_client_names)

                  return language_servers
                end
              '';
              color = {gui = "bold";};
            }
            {
              __unkeyed-1.__raw = ''
                function()
                  return " 󰌒 " .. vim.api.nvim_buf_get_option(0, "shiftwidth")
                end
              '';
              padding = 1;
            }
            {
              __unkeyed-1 = "filetype";
              padding = {
                left = 1;
                right = 1;
              };
            }
          ];
          lualine_y = ["location"];
          lualine_z = [
            {
              __unkeyed-1 = "progress";
              fmt.__raw = ''
                function()
                  return "%P/%L"
                end
              '';
            }
          ];
        };
        tabline = {};
        extensions = [];
      };
    };

    bufferline = {
      enable = true;
      # LV loads bufferline on first file (event="User FileOpened"); keep the
      # startup-state parity (dashboard-only session leaves it unloaded)
      lazyLoad = {
        enable = true;
        settings = {
          cmd = ["BufferLinePick" "BufferLineCycleNext" "BufferLineCyclePrev"];
          event = ["User FileOpened"];
        };
      };
      settings = {
        options = {
          themable = true;
          show_duplicate_prefix = true;
          duplicates_across_groups = true;
          auto_toggle_bufferline = true;
          move_wraps_at_ends = false;
          groups = {
            items = [];
            options = {
              toggle_hidden_on_enter = true;
            };
          };
          mode = "buffers";
          numbers = "none";
          close_command.__raw = ''
            function(bufnr)
              require("bufdelete").bufdelete(bufnr, false)
            end
          '';
          right_mouse_command = "vert sbuffer %d";
          left_mouse_command = "buffer %d";
          middle_mouse_command = null;
          indicator = {
            icon = "▎";
            style = "icon";
          };
          buffer_close_icon = "";
          modified_icon = "●";
          close_icon = "";
          left_trunc_marker = "";
          right_trunc_marker = "";
          name_formatter.__raw = ''
            function(buf)
              if buf.name:match "%.md" then
                return vim.fn.fnamemodify(buf.name, ":t:r")
              end
            end
          '';
          max_name_length = 18;
          max_prefix_length = 15;
          truncate_names = true;
          tab_size = 18;
          diagnostics = "nvim_lsp";
          diagnostics_update_in_insert = false;
          offsets = [
            {
              filetype = "undotree";
              text = "Undotree";
              highlight = "PanelHeading";
              padding = 1;
            }
            {
              filetype = "NvimTree";
              text = "Explorer";
              highlight = "PanelHeading";
              padding = 1;
            }
            {
              filetype = "DiffviewFiles";
              text = "Diff View";
              highlight = "PanelHeading";
              padding = 1;
            }
            {
              filetype = "flutterToolsOutline";
              text = "Flutter Outline";
              highlight = "PanelHeading";
            }
            {
              filetype = "lazy";
              text = "Lazy";
              highlight = "PanelHeading";
              padding = 1;
            }
          ];
          color_icons = true;
          show_buffer_icons = true;
          show_buffer_close_icons = true;
          show_close_icon = false;
          show_tab_indicators = true;
          persist_buffer_sort = true;
          separator_style = "thin";
          enforce_regular_tabs = false;
          always_show_bufferline = false;
          hover = {
            enabled = false;
            delay = 200;
            reveal = ["close"];
          };
          sort_by = "id";
          debug = {logging = false;};
        };
      };
    };

    gitsigns = {
      # LV spec: event = "User FileOpened", cmd = "Gitsigns"
      lazyLoad = {
        enable = true;
        settings = {
          event = ["User FileOpened"];
          cmd = ["Gitsigns"];
        };
      };
      enable = true;
      # lvim.builtin.gitsigns defaults (hl/linehl/numhl fields are deprecated
      # upstream now; the named highlight groups are defined below instead)
      settings = {
        signs = {
          add.text = "▎";
          change.text = "▎";
          delete.text = "";
          topdelete.text = "";
          changedelete.text = "▎";
        };
        signcolumn = true;
        numhl = false;
        linehl = false;
        word_diff = false;
        on_attach = {
          __raw = ''
            function(bufnr)
              -- do not bind the default M-n/M-p references navigation that LV does not have
              return true
            end
          '';
        };
        watch_gitdir = {
          interval = 1000;
          follow_files = true;
        };
        attach_to_untracked = true;
        current_line_blame = false;
        current_line_blame_opts = {
          virt_text = true;
          virt_text_pos = "eol";
          delay = 1000;
          ignore_whitespace = false;
        };
        current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>";
        sign_priority = 6;
        update_debounce = 200;
        max_file_length = 40000;
        preview_config = {
          border = "rounded";
          style = "minimal";
          relative = "cursor";
          row = 0;
          col = 1;
        };
      };
    };

    which-key = {
      # LV spec: cmd = "WhichKey", event = "VeryLazy"
      lazyLoad = {
        enable = true;
        settings = {
          cmd = ["WhichKey"];
          event = ["DeferredUIEnter"];
        };
      };
      enable = true;
      # lvim.core.which-key setup
      settings = {
        plugins = {
          marks = false;
          registers = false;
          spelling = {
            enabled = true;
            suggestions = 20;
          };
          presets = {
            operators = false;
            motions = false;
            text_objects = false;
            windows = false;
            nav = false;
            z = false;
            g = false;
          };
        };
        # (which-key v3 renames: opts.operators/hidden/window/popup_mappings/
        # ignore_missing/triggers_blacklist are deprecated; ported below with
        # the same effective behavior LV had on which-key v2)
        icons = {
          breadcrumb = "»";
          separator = "➜";
          group = "+";
        };
        win = {
          no_overlap = false;
          title = false;
          border = "single";
          padding = [2 2];
        };
        layout = {
          height = {
            min = 4;
            max = 25;
          };
          width = {
            min = 20;
            max = 50;
          };
          spacing = 3;
          align = "left";
        };
        filter = {
          # v2 ignore_missing=true hid mappings without explicit labels;
          # v3 equivalent: only show mappings with a desc
          __raw = ''
            function(mapping)
              return mapping.desc ~= nil and mapping.desc ~= ""
            end
          '';
        };
        keys = {
          scroll_down = "<c-d>";
          scroll_up = "<c-u>";
        };
        show_help = true;
        show_keys = true;
        spec = [
          # normal mode
          {
            __unkeyed-1 = "<leader>;";
            __unkeyed-2 = "<cmd>Alpha<CR>";
            desc = "Dashboard";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>w";
            __unkeyed-2 = "<cmd>w!<CR>";
            desc = "Save";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>q";
            __unkeyed-2 = "<cmd>confirm q<CR>";
            desc = "Quit";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>/";
            __unkeyed-2 = "<Plug>(comment_toggle_linewise_current)";
            desc = "Comment toggle current line";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>c";
            __unkeyed-2 = "<cmd>BufferKill<CR>";
            desc = "Close Buffer";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>f";
            __unkeyed-2.__raw = ''
              function()
                local ok = pcall(require("telescope.builtin").git_files, { previewer = false, show_untracked = true, hidden = true })
                if not ok then
                  require("telescope.builtin").find_files { previewer = false, hidden = true }
                end
              end
            '';
            desc = "Find File";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>h";
            __unkeyed-2 = "<cmd>nohlsearch<CR>";
            desc = "No Highlight";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>e";
            __unkeyed-2 = "<cmd>NvimTreeToggle<CR>";
            desc = "Explorer";
            mode = "n";
          }
          # -- Buffers --
          {
            mode = "n";
            __unkeyed-1 = "<leader>b";
            group = "Buffers";
          }
          {
            __unkeyed-1 = "<leader>bj";
            __unkeyed-2 = "<cmd>BufferLinePick<cr>";
            desc = "Jump";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>bf";
            __unkeyed-2 = "<cmd>Telescope buffers previewer=false<cr>";
            desc = "Find";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>bb";
            __unkeyed-2 = "<cmd>BufferLineCyclePrev<cr>";
            desc = "Previous";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>bn";
            __unkeyed-2 = "<cmd>BufferLineCycleNext<cr>";
            desc = "Next";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>bW";
            __unkeyed-2 = "<cmd>noautocmd w<cr>";
            desc = "Save without formatting (noautocmd)";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>be";
            __unkeyed-2 = "<cmd>BufferLinePickClose<cr>";
            desc = "Pick which buffer to close";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>bh";
            __unkeyed-2 = "<cmd>BufferLineCloseLeft<cr>";
            desc = "Close all to the left";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>bl";
            __unkeyed-2 = "<cmd>BufferLineCloseRight<cr>";
            desc = "Close all to the right";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>bD";
            __unkeyed-2 = "<cmd>BufferLineSortByDirectory<cr>";
            desc = "Sort by directory";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>bL";
            __unkeyed-2 = "<cmd>BufferLineSortByExtension<cr>";
            desc = "Sort by language";
            mode = "n";
          }
          # -- Debug --
          {
            mode = "n";
            __unkeyed-1 = "<leader>d";
            group = "Debug";
          }
          {
            __unkeyed-1 = "<leader>dt";
            __unkeyed-2 = "<cmd>lua require'dap'.toggle_breakpoint()<cr>";
            desc = "Toggle Breakpoint";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>db";
            __unkeyed-2 = "<cmd>lua require'dap'.step_back()<cr>";
            desc = "Step Back";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>dc";
            __unkeyed-2 = "<cmd>lua require'dap'.continue()<cr>";
            desc = "Continue";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>dC";
            __unkeyed-2 = "<cmd>lua require'dap'.run_to_cursor()<cr>";
            desc = "Run To Cursor";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>dd";
            __unkeyed-2 = "<cmd>lua require'dap'.disconnect()<cr>";
            desc = "Disconnect";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>dg";
            __unkeyed-2 = "<cmd>lua require'dap'.session()<cr>";
            desc = "Get Session";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>di";
            __unkeyed-2 = "<cmd>lua require'dap'.step_into()<cr>";
            desc = "Step Into";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>do";
            __unkeyed-2 = "<cmd>lua require'dap'.step_over()<cr>";
            desc = "Step Over";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>du";
            __unkeyed-2 = "<cmd>lua require'dap'.step_out()<cr>";
            desc = "Step Out";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>dp";
            __unkeyed-2 = "<cmd>lua require'dap'.pause()<cr>";
            desc = "Pause";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>dr";
            __unkeyed-2 = "<cmd>lua require'dap'.repl.toggle()<cr>";
            desc = "Toggle Repl";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>ds";
            __unkeyed-2 = "<cmd>lua require'dap'.continue()<cr>";
            desc = "Start";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>dq";
            __unkeyed-2 = "<cmd>lua require'dap'.close()<cr>";
            desc = "Quit";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>dU";
            __unkeyed-2 = "<cmd>lua require'dapui'.toggle({reset = true})<cr>";
            desc = "Toggle UI";
            mode = "n";
          }
          # -- Git --
          {
            mode = "n";
            __unkeyed-1 = "<leader>g";
            group = "Git";
          }
          {
            __unkeyed-1 = "<leader>gj";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.nav_hunk('next', {navigation_message = false})<cr>";
            desc = "Next Hunk";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gk";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.nav_hunk('prev', {navigation_message = false})<cr>";
            desc = "Prev Hunk";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gl";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.blame_line()<cr>";
            desc = "Blame";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gL";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.blame_line({full=true})<cr>";
            desc = "Blame Line (full)";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gp";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.preview_hunk()<cr>";
            desc = "Preview Hunk";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gr";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.reset_hunk()<cr>";
            desc = "Reset Hunk";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gR";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.reset_buffer()<cr>";
            desc = "Reset Buffer";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gs";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.stage_hunk()<cr>";
            desc = "Stage Hunk";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gu";
            __unkeyed-2 = "<cmd>lua require 'gitsigns'.undo_stage_hunk()<cr>";
            desc = "Undo Stage Hunk";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>go";
            __unkeyed-2 = "<cmd>Telescope git_status<cr>";
            desc = "Open changed file";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gb";
            __unkeyed-2 = "<cmd>Telescope git_branches<cr>";
            desc = "Checkout branch";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gc";
            __unkeyed-2 = "<cmd>Telescope git_commits<cr>";
            desc = "Checkout commit";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gC";
            __unkeyed-2 = "<cmd>Telescope git_bcommits<cr>";
            desc = "Checkout commit(for current file)";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>gd";
            __unkeyed-2 = "<cmd>Gitsigns diffthis HEAD<cr>";
            desc = "Git Diff";
            mode = "n";
          }
          # -- LSP --
          {
            mode = "n";
            __unkeyed-1 = "<leader>l";
            group = "LSP";
          }
          {
            __unkeyed-1 = "<leader>la";
            __unkeyed-2 = "<cmd>lua vim.lsp.buf.code_action()<cr>";
            desc = "Code Action";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>ld";
            __unkeyed-2 = "<cmd>Telescope diagnostics bufnr=0 theme=get_ivy<cr>";
            desc = "Buffer Diagnostics";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>lw";
            __unkeyed-2 = "<cmd>Telescope diagnostics<cr>";
            desc = "Diagnostics";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>lf";
            __unkeyed-2 = "<cmd>lua vim.lsp.buf.format()<cr>";
            desc = "Format";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>li";
            __unkeyed-2 = "<cmd>LspInfo<cr>";
            desc = "Info";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>lI";
            __unkeyed-2 = "<cmd>Mason<cr>";
            desc = "Mason Info";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>lj";
            __unkeyed-2 = "<cmd>lua vim.diagnostic.goto_next()<cr>";
            desc = "Next Diagnostic";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>lk";
            __unkeyed-2 = "<cmd>lua vim.diagnostic.goto_prev()<cr>";
            desc = "Prev Diagnostic";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>ll";
            __unkeyed-2 = "<cmd>lua vim.lsp.codelens.run()<cr>";
            desc = "CodeLens Action";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>lq";
            __unkeyed-2 = "<cmd>lua vim.diagnostic.setloclist()<cr>";
            desc = "Quickfix";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>lr";
            __unkeyed-2 = "<cmd>lua vim.lsp.buf.rename()<cr>";
            desc = "Rename";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>ls";
            __unkeyed-2 = "<cmd>Telescope lsp_document_symbols<cr>";
            desc = "Document Symbols";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>lS";
            __unkeyed-2 = "<cmd>Telescope lsp_dynamic_workspace_symbols<cr>";
            desc = "Workspace Symbols";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>le";
            __unkeyed-2 = "<cmd>Telescope quickfix<cr>";
            desc = "Telescope Quickfix";
            mode = "n";
          }
          # -- Search --
          {
            mode = "n";
            __unkeyed-1 = "<leader>s";
            group = "Search";
          }
          {
            __unkeyed-1 = "<leader>sb";
            __unkeyed-2 = "<cmd>Telescope git_branches<cr>";
            desc = "Checkout branch";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sc";
            __unkeyed-2 = "<cmd>Telescope colorscheme<cr>";
            desc = "Colorscheme";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sf";
            __unkeyed-2 = "<cmd>Telescope find_files<cr>";
            desc = "Find File";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sh";
            __unkeyed-2 = "<cmd>Telescope help_tags<cr>";
            desc = "Find Help";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sH";
            __unkeyed-2 = "<cmd>Telescope highlights<cr>";
            desc = "Find highlight groups";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sM";
            __unkeyed-2 = "<cmd>Telescope man_pages<cr>";
            desc = "Man Pages";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sr";
            __unkeyed-2 = "<cmd>Telescope oldfiles<cr>";
            desc = "Open Recent File";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sR";
            __unkeyed-2 = "<cmd>Telescope registers<cr>";
            desc = "Registers";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>st";
            __unkeyed-2 = "<cmd>Telescope live_grep<cr>";
            desc = "Text";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sk";
            __unkeyed-2 = "<cmd>Telescope keymaps<cr>";
            desc = "Keymaps";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sC";
            __unkeyed-2 = "<cmd>Telescope commands<cr>";
            desc = "Commands";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sl";
            __unkeyed-2 = "<cmd>Telescope resume<cr>";
            desc = "Resume last search";
            mode = "n";
          }
          {
            __unkeyed-1 = "<leader>sp";
            __unkeyed-2 = "<cmd>lua require('telescope.builtin').colorscheme({enable_preview = true})<cr>";
            desc = "Colorscheme with Preview";
            mode = "n";
          }
          # -- Plugins (LV p group: lazy.nvim commands; under nixvim Lazy is
          # not used, so these operate on nixvim's handling; kept for parity) --
          {
            mode = "n";
            __unkeyed-1 = "<leader>p";
            group = "Plugins";
          }
          {
            __unkeyed-1 = "<leader>pc";
            __unkeyed-2 = "<cmd>Lazy clean<cr>";
            desc = "Clean";
            mode = "n";
          }
          # -- Treesitter --
          {
            mode = "n";
            __unkeyed-1 = "<leader>T";
            group = "Treesitter";
          }
          {
            __unkeyed-1 = "<leader>Ti";
            __unkeyed-2 = ":TSConfigInfo<cr>";
            desc = "Info";
            mode = "n";
          }
          # -- Terminal (from lvim.core.terminal execs) --
          # -- visual mode (lvim.core.which-key vmappings) --
          {
            __unkeyed-1 = "<leader>/";
            __unkeyed-2 = "<Plug>(comment_toggle_linewise_visual)";
            desc = "Comment toggle linewise (visual)";
            mode = "v";
          }
          {
            mode = "v";
            __unkeyed-1 = "<leader>l";
            group = "LSP";
          }
          {
            __unkeyed-1 = "<leader>la";
            __unkeyed-2 = "<cmd>lua vim.lsp.buf.code_action()<cr>";
            desc = "Code Action";
            mode = "v";
          }
          {
            mode = "v";
            __unkeyed-1 = "<leader>g";
            group = "Git";
          }
          {
            __unkeyed-1 = "<leader>gr";
            __unkeyed-2 = "<cmd>Gitsigns reset_hunk<cr>";
            desc = "Reset Hunk";
            mode = "v";
          }
          {
            __unkeyed-1 = "<leader>gs";
            __unkeyed-2 = "<cmd>Gitsigns stage_hunk<cr>";
            desc = "Stage Hunk";
            mode = "v";
          }
        ];
      };
    };

    comment = {
      # LV spec: keys gc/gb + event "User FileOpened"
      lazyLoad = {
        enable = true;
        settings = {
          keys = [
            {
              __unkeyed-1 = "gc";
              mode = ["n" "v"];
            }
            {
              __unkeyed-1 = "gb";
              mode = ["n" "v"];
            }
          ];
          event = ["User FileOpened"];
        };
      };
      enable = true;
      settings = {
        padding = true;
        sticky = true;
        ignore = "^$";
        mappings = {
          basic = true;
          extra = true;
        };
        toggler = {
          line = "gcc";
          block = "gbc";
        };
        opleader = {
          line = "gc";
          block = "gb";
        };
        pre_hook = {
          __raw = ''
            function(...)
              local ok, hook = pcall(require, "ts_context_commentstring.integrations.comment_nvim")
              if ok and hook then
                return hook.create_pre_hook()(...)
              end
            end
          '';
        };
      };
    };

    nvim-autopairs = {
      # LV spec: event = "InsertEnter"
      lazyLoad = {
        enable = true;
        settings.event = ["InsertEnter"];
      };
      enable = true;
      settings = {
        check_ts = true;
        enable_check_bracket_line = false;
        ts_config = {
          lua = ["string" "source"];
          javascript = ["string" "template_string"];
          java = false;
        };
        disable_filetype = ["TelescopePrompt" "spectre_panel"];
        disable_in_macro = false;
        disable_in_visualblock = false;
        disable_in_replace_mode = true;
        enable_moveright = true;
        enable_afterquote = true;
        enable_abbr = false;
      };
    };

    # -- project (lvim.builtin.project) ------------------------------------
    project-nvim = {
      enable = true;
      # LV loads the telescope "projects" extension (:Telescope projects)
      enableTelescope = true;
      # lvim.builtin.project defaults
      settings = {
        manual_mode = false;
        detection_methods = ["pattern"];
        patterns = [
          ".git"
          "_darcs"
          ".hg"
          ".svn"
          "package.json"
          "Makefile"
        ];
        exclude_dirs = [];
        show_hidden = false;
        silent_chdir = true;
        scope_chdir = "global";
      };
    };

    illuminate = {
      enable = true;
      # lvim.core.illuminate defaults (deprecated option names, renamed upstream)
      providers = ["lsp" "treesitter" "regex"];
      delay = 120;
      filetypesDenylist = [
        "dirvish"
        "fugitive"
        "alpha"
        "NvimTree"
        "lazy"
        "neogitstatus"
        "Trouble"
        "lir"
        "Outline"
        "spectre_panel"
        "toggleterm"
        "DressingSelect"
        "TelescopePrompt"
      ];
      underCursor = true;
      largeFileCutoff = 10000;
      # LV predates illuminate's default <A-n>/<A-p>/<A-i> mappings; disable
      # them (configure() merges via tbl_extend, so this overrides the defaults),
      # done in extraConfigLuaPost below.
    };

    indent-blankline = {
      # LV spec: event = "User FileOpened"
      lazyLoad = {
        enable = true;
        settings.event = ["User FileOpened"];
      };
      enable = true;
      # lvim.builtin.indentlines defaults (indent-blankline v2 syntax, mapped to v3)
      settings = {
        exclude = {
          buftypes = ["terminal" "nofile"];
          filetypes = [
            "help"
            "startify"
            "dashboard"
            "lazy"
            "neogitstatus"
            "NvimTree"
            "Trouble"
            "text"
          ];
        };
        indent = {
          char = "▏";
        };
        scope = {
          enabled = true;
          char = "▏";
        };
      };
    };

    navic = {
      # LV spec: event = "User FileOpened"
      lazyLoad = {
        enable = true;
        settings.event = ["User FileOpened"];
      };
      enable = true;
      settings = {
        icons = {
          File = "󰈙 ";
          Module = " ";
          Namespace = "󰌗 ";
          Package = " ";
          Class = "󰌗 ";
          Method = "󰆧 ";
          Property = " ";
          Field = " ";
          Constructor = " ";
          Enum = "󰕘";
          Interface = "󰕘";
          Function = "󰊕 ";
          Variable = "󰆧 ";
          Constant = "󰏿 ";
          String = "󰀬 ";
          Number = "󰎠 ";
          Boolean = "◩ ";
          Array = "󰅪 ";
          Object = "󰅩 ";
          Key = "󰌋 ";
          Null = "󰟢 ";
          EnumMember = " ";
          Struct = "󰌗 ";
          Event = " ";
          Operator = "󰆕 ";
          TypeParameter = "󰊄 ";
        };
        highlight = false;
        separator = " > ";
        depth_limit = 0;
        depth_limit_indicator = "..";
        safe_output = true;
        lazy_update_context = false;
        click = false;
        lsp = {
          auto_attach = false;
          preference = null;
        };
      };
    };

    # -- DAP (lvim.builtin.dap) --------------------------------------------
    dap = {
      enable = true;
      signs = {
        dapBreakpoint = {
          text = "";
          texthl = "DiagnosticSignError";
          linehl = "";
          numhl = "";
        };
        dapBreakpointRejected = {
          text = "";
          texthl = "DiagnosticSignError";
          linehl = "";
          numhl = "";
        };
        dapStopped = {
          text = "➜";
          texthl = "DiagnosticSignWarn";
          linehl = "Visual";
          numhl = "DiagnosticSignWarn";
        };
      };
    };

    dap-ui = {
      enable = true;
      settings.layouts.__raw = ''
        {
          {
            elements = {
              { id = "scopes", size = 0.33 },
              { id = "breakpoints", size = 0.17 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.25 },
            },
            size = 0.33,
            position = "right",
          },
          {
            elements = {
              { id = "repl", size = 0.45 },
              { id = "console", size = 0.55 },
            },
            size = 0.27,
            position = "bottom",
          },
        }
      '';
      settings.mappings = {
        expand = ["<CR>" "<2-LeftMouse>"];
        open = "o";
        remove = "d";
        edit = "e";
        repl = "r";
        toggle = "t";
      };
      settings.expand_lines = true;
      settings.auto_open = true;
      settings.controls = {
        enable = true;
        element = "repl";
      };
    };
    dap-python.enable = false;

    # -- Terminal (lvim.builtin.terminal) -----------------------------------
    toggleterm = {
      # LV spec: cmd list + keys
      lazyLoad = {
        enable = true;
        settings = {
          cmd = ["ToggleTerm" "TermExec" "ToggleTermToggleAll" "ToggleTermSendCurrentLine" "ToggleTermSendVisualLines" "ToggleTermSendVisualSelection"];
          keys = ["<C-Bslash>"];
        };
      };
      enable = true;
      # lvim.builtin.terminal defaults
      settings = {
        size = 20;
        open_mapping.__raw = "[[<c-\\>]]";
        hide_numbers = true;
        shade_filetypes = [];
        shade_terminals = true;
        shading_factor = 2;
        start_in_insert = true;
        insert_mappings = true;
        persist_size = false;
        direction = "float";
        close_on_exit = true;
        auto_scroll = true;
        float_opts = {
          border = "curved";
          winblend = 0;
          highlights = {
            border = "Normal";
            background = "Normal";
          };
        };
        winbar = {
          enabled = false;
        };
      };
    };

    schemastore.enable = true;

    # -- Dashboard (lvim.builtin.alpha) --------------------------------------
    # LunarVim uses alpha-nvim with its "dashboard" theme (headers of lunarvim
    # ASCII art, buttons for find/new/projects/recent/grep/config/quit and a
    # footer with lunarvim.org and the LV version). We replicate that layout
    # through extraConfigLuaPre-free config below by using the same sections.
    alpha = {
      enable = true;
      theme = null;
      layout = [
        {
          type = "text";
          val.__raw = ''
            (function()
            local banner_big = {
                "                ⢀⣀⣤⣤⣤⣶⣶⣶⣶⣶⣶⣤⣤⣤⣀⡀                ",
                "             ⣀⣤⣶⣿⠿⠟⠛⠉⠉⠉⠁⠈⠉⠉⠉⠛⠛⠿⣿⣷⣦⣀             ",
                "          ⢀⣤⣾⡿⠛⠉                ⠉⠛⢿⣷⣤⡀          ",
                "         ⣴⣿⡿⠃                      ⠙⠻⣿⣦         ",
                " ⢀⣠⣤⣤⣤⣤⣤⣾⣿⣉⣀⡀                        ⠙⢻⣷⡄       ",
                "⣼⠋⠁   ⢠⣿⡟ ⠉⠉⠉⠛⠛⠶⠶⣤⣄⣀    ⣀⣀      ⢠⣤⣤⡄   ⢻⣿⣆      ",
                "⢻⡄   ⢰⣿⡟        ⢠⣿⣿⣿⠉⠛⠲⣾⣿⣿⣷    ⢀⣾⣿⣿⠁    ⢻⣿⡆     ",
                " ⠹⣦⡀ ⣿⣿⠁        ⢸⣿⣿⡇   ⠻⣿⣿⠟⠳⠶⣤⣀⣸⣿⣿⠇      ⣿⣷     ",
                "   ⠙⢷⣿⡇         ⣸⣿⣿⠃          ⢸⣿⣿⢷⣤⡀     ⢸⣿⡆    ",
                "    ⢸⣿⠇         ⣿⣿⣿     ⣿⣿⣷  ⢠⣿⣿⡏ ⠈⠙⠳⢦⣄  ⠈⣿⡇    ",
                "    ⢸⣿⡆        ⢸⣿⣿⡇     ⣿⣿⣿ ⢀⣿⣿⡟      ⠈⠙⠷⣤⣿⡇    ",
                "    ⠘⣿⡇        ⣼⣿⣿⠁     ⣿⣿⣿ ⣼⣿⣿⠃         ⢸⣿⠷⣄⡀  ",
                "     ⣿⣿        ⣿⣿⡿      ⣿⣿⣿⢸⣿⣿⠃          ⣾⡿ ⠈⠻⣆ ",
                "     ⠸⣿⣧      ⢸⣿⣿⣇⣀⣀⣀⣀⣀⣀⣸⣿⣿⣿⣿⠇          ⣼⣿⠇   ⠘⣧",
                "      ⠹⣿⣧     ⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏          ⣼⣿⠏    ⣠⡿",
                "       ⠘⢿⣷⣄   ⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉         ⢠⣼⡿⠛⠛⠛⠛⠛⠛⠉ ",
                "         ⠻⣿⣦⣄                      ⣀⣴⣿⠟         ",
                "          ⠈⠛⢿⣶⣤⣀                ⣀⣤⣶⡿⠛⠁          ",
                "             ⠉⠻⢿⣿⣶⣤⣤⣀⣀⡀  ⢀⣀⣀⣠⣤⣶⣿⡿⠟⠋             ",
                "                ⠈⠉⠙⠛⠻⠿⠿⠿⠿⠿⠿⠟⠛⠋⠉⠁                ",
              }
            local banner_small = {
              "  ⢀⣀                                                ⣰⣶   ⢀⣤⣄             ",
              "  ⢸⣿                                          ⣀⡀   ⣰⣿⠏   ⠘⠿⠟             ",
              "  ⣿⡟      ⣤⡄   ⣠⣤  ⢠⣤⣀⣤⣤⣤⡀   ⢀⣤⣤⣤⣤⡀   ⢠⣤⢀⣤⣤⣄  ⣿⣿  ⢰⣿⠏  ⣶⣶⣶⣶⡦   ⢠⣶⣦⣴⣦⣠⣴⣦⡀ ",
              " ⢠⣿⡇     ⢠⣿⠇   ⣿⡇  ⣿⡿⠉ ⠈⣿⣧  ⠰⠿⠋  ⢹⣿   ⣿⡿⠋ ⠹⠿  ⢻⣿⡇⢠⣿⡟   ⠈⠉⢹⣿⡇   ⢸⣿⡏⢹⣿⡏⢹⣿⡇ ",
              " ⢸⣿      ⢸⣿   ⢰⣿⠃ ⢠⣿⡇   ⣿⡇  ⣠⣴⡶⠶⠶⣿⣿  ⢠⣿⡇      ⢸⣿⣇⣿⡿      ⣿⣿⠁   ⣿⣿ ⣾⣿ ⣾⣿⠁ ",
              " ⣿⣟      ⢻⣿⡀ ⢀⣼⣿  ⢸⣿   ⢰⣿⠇ ⢰⣿⣇  ⣠⣿⡏  ⢸⣿       ⢸⣿⣿⣿⠁   ⣀⣀⣠⣿⣿⣀⡀ ⢠⣿⡟⢠⣿⡟⢀⣿⡿  ",
              " ⠛⠛⠛⠛⠛⠛⠁ ⠈⠛⠿⠟⠋⠛⠃  ⠛⠛   ⠘⠛   ⠙⠿⠿⠛⠙⠛⠃  ⠚⠛       ⠘⠿⠿⠃    ⠿⠿⠿⠿⠿⠿⠿ ⠸⠿⠇⠸⠿⠇⠸⠿⠇  ",
            }

            local alpha_wins = vim.tbl_filter(function(win)
              local buf = vim.api.nvim_win_get_buf(win)
              return vim.api.nvim_buf_get_option(buf, "filetype") == "alpha"
            end, vim.api.nvim_list_wins())

            if #alpha_wins > 0 and vim.api.nvim_win_get_height(alpha_wins[#alpha_wins]) < 36 then
              return banner_small
            end
            return banner_big
            end)
          '';
          opts = {
            position = "center";
            hl = "Label";
          };
        }
        {
          type = "padding";
          val = 2;
        }
        {
          type = "group";
          val = [
            {
              type = "button";
              val = "  Find File";
              on_press.__raw = "function() vim.cmd[[Telescope find_files]] end";
              opts.shortcut = "f";
            }
            {
              type = "button";
              val = "  New File";
              on_press.__raw = "function() vim.cmd[[ene!]] end";
              opts.shortcut = "n";
            }
            {
              type = "button";
              val = "  Projects ";
              on_press.__raw = "function() vim.cmd[[Telescope projects]] end";
              opts.shortcut = "p";
            }
            {
              type = "button";
              val = "  Recent files";
              on_press.__raw = "function() vim.cmd[[Telescope oldfiles]] end";
              opts.shortcut = "r";
            }
            {
              type = "button";
              val = "  Find Text";
              on_press.__raw = "function() vim.cmd[[Telescope live_grep]] end";
              opts.shortcut = "t";
            }
            {
              type = "button";
              val = "  Configuration";
              on_press.__raw = "function() vim.cmd[[edit ~/.config/nvim/]] end";
              opts.shortcut = "c";
            }
            {
              type = "button";
              val = "  Quit";
              on_press.__raw = "function() vim.cmd[[quit]] end";
              opts.shortcut = "q";
            }
          ];
          opts = {
            hl_shortcut = "Include";
            spacing = 1;
          };
        }
        {
          type = "padding";
          val = 1;
        }
        {
          type = "text";
          val.__raw = ''
            function()
              -- mirrors lvim.interface.text.align_center (with container.width = 0)
              local function align_center(container, lines, alignment)
                local max_len = 0
                for _, line in ipairs(lines) do
                  if #line > max_len then
                    max_len = #line
                  end
                end

                local output = {}
                for _, line in ipairs(lines) do
                  local padding = string.rep(" ", (math.max(container.width, max_len) - #line) * alignment)
                  table.insert(output, padding .. line)
                end

                return output
              end
              return align_center({ width = 0 }, { "", "lunarvim.org", "nixvim (LunarVim replacement)" }, 0.5)
            end
          '';
          opts = {
            position = "center";
            hl = "Number";
          };
        }
      ];
    };

    # bigfile (lvim.builtin.bigfile)
    # nixvim does not have a bigfile module; handled in extraConfigLua below.

    # tabline. always Show bufferline (LV sets vim.opt.showtabline = 2 in setup)
    # done via opts.showtabline below.

    # Lir (lvim.builtin.lir) - LV loads it on "User DirOpened"; replicate via
    # our _dir_opened autocmd which fires that same User event.
    lir = {
      enable = true;
      settings = {
        show_hidden_files = false;
        ignore = [];
        devicons = {
          enable = true;
          highlight_dirname = true;
        };
        mappings = {
          "l" = {__raw = "require('lir.actions').edit";};
          "<CR>" = {__raw = "require('lir.actions').edit";};
          "<C-s>" = {__raw = "require('lir.actions').split";};
          "v" = {__raw = "require('lir.actions').vsplit";};
          "<C-t>" = {__raw = "require('lir.actions').tabedit";};
          "h" = {__raw = "require('lir.actions').up";};
          "q" = {__raw = "require('lir.actions').quit";};
          "A" = {__raw = "require('lir.actions').mkdir";};
          "a" = {__raw = "require('lir.actions').newfile";};
          "r" = {__raw = "require('lir.actions').rename";};
          "@" = {__raw = "require('lir.actions').cd";};
          "Y" = {__raw = "require('lir.actions').yank_path";};
          "i" = {__raw = "require('lir.actions').toggle_show_hidden";};
          "d" = {__raw = "require('lir.actions').delete";};
          "J" = {
            __raw = ''
              function()
                require("lir.mark.actions").toggle_mark()
                vim.cmd("normal! j")
              end
            '';
          };
          "c" = {__raw = "require('lir.clipboard.actions').copy";};
          "x" = {__raw = "require('lir.clipboard.actions').cut";};
          "p" = {__raw = "require('lir.clipboard.actions').paste";};
        };
        float = {
          winblend = 0;
          curdir_window = {
            enable = false;
            highlight_dirname = true;
          };
        };
        hide_cursor = false;
      };
    };
  };

  # Bufferline is lazy-loaded (see plugins.bufferline.lazyLoad above)
  plugins.lz-n.enable = true;

  # QuickFixToggle: LV defines a VimL function (via lvim.core.commands) used
  # by the <C-q> mapping; not a user command.
  extraConfigVim = ''
    function! QuickFixToggle()
      if empty(filter(getwininfo(), 'v:val.quickfix'))
        copen
      else
        cclose
      endif
    endfunction
  '';

  # ===================
  # Lua snippets glueing together things nixvim does not have modules for
  # ===================
  extraConfigLua = ''
    -- Provide the `lvim_cmp_confirm_opts` table used by the cmp <CR> mapping
    -- (equals lvim.builtin.cmp.confirm_opts). cmp is lazy-loaded now, so
    -- resolve its ConfirmBehavior lazily on first use.
    lvim_cmp_confirm_opts = { behavior = "replace", select = false }

    -- Provide `has_words_before` used by the cmp <Tab> mapping (from lvim.core.cmp)
    function _G.has_words_before()
      local line, col = unpack(vim.api.nvim_win_get_cursor(0))
      return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match "%s" == nil
    end

    -- Fix gf inside .lua files is handled through autocmds above.

    -- Disable illuminate's default <A-n>/<A-p>/<A-i> mappings, which LunarVim
    -- did not have (configure() merges via tbl_extend, overriding the above)
    require("illuminate").configure({ disable_keymaps = true })

    -- bigfile (lvim.builtin.bigfile defaults)
    do
      local ok, bigfile = pcall(require, "bigfile")
      if ok then
        bigfile.config({})
      end
    end

    -- Mason (lvim.builtin.mason defaults)
    do
      local ok, mason = pcall(require, "mason")
      if ok then
        local join_paths = function(...)
          local result = table.concat({ ... }, "/")
          return result
        end
        mason.setup({
          ui = {
            check_outdated_packages_on_open = false,
            width = 0.8,
            height = 0.9,
            border = "rounded",
            keymaps = {
              toggle_package_expand = "<CR>",
              install_package = "i",
              update_package = "u",
              check_package_version = "c",
              update_all_packages = "U",
              check_outdated_packages = "C",
              uninstall_package = "X",
              cancel_installation = "<C-c>",
              apply_language_filter = "<C-f>",
            },
          },
          icons = {
            package_installed = "◍",
            package_pending = "◍",
            package_uninstalled = "◍",
          },
          install_root_dir = join_paths(vim.fn.stdpath "data", "mason"),
          -- NOTE: everything is nix-managed (build-time); Mason exists only as
          -- an informational UI (:Mason: installed servers come from the nix
          -- store). No PATH, no registries, no network.
          PATH = "skip",
          registries = {
            "lua:mason-registry.index",
          },
          providers = {},
        })

        -- LunarVim ex commands for mason
        vim.api.nvim_create_user_command("MasonInstallAll", function() end, {})
      end
    end

    -- Terminal execs from lvim.core.terminal (toggleterm custom terminals).
    -- Keys bound eagerly (LV parity); toggleterm resolves lazily on press.
    local term_keymap_opts = { noremap = true, silent = true }
    local __term_toggle = function(direction)
      return function()
        local Terminal = require("toggleterm.terminal").Terminal
        local term
        if direction == "h" then
          term = Terminal:new { direction = "horizontal", size = 0.3, hidden = true }
        elseif direction == "v" then
          term = Terminal:new { direction = "vertical", size = 0.4, hidden = true }
        else
          term = Terminal:new { direction = "float", hidden = true }
        end
        term:toggle()
      end
    end
    vim.keymap.set({ "n", "t" }, "<M-1>", __term_toggle("h"),
      vim.tbl_extend("force", term_keymap_opts, { desc = "Horizontal Terminal" }))
    vim.keymap.set({ "n", "t" }, "<M-2>", __term_toggle("v"),
      vim.tbl_extend("force", term_keymap_opts, { desc = "Vertical Terminal" }))
    vim.keymap.set({ "n", "t" }, "<M-3>", __term_toggle("f"),
      vim.tbl_extend("force", term_keymap_opts, { desc = "Float Terminal" }))
  '';

  # hide cursorline in lir buffers etc. handled through autocmds

  # Basic tooling for nvim runtime features (same as old LV wrapper's PATH)
  extraPackages = with pkgs; [
    # Used by telescope (vimgrep_arguments) and live_grep
    ripgrep
    # Used by nvim-spectre-ish things; find is used by nvim-tree open with
    fd
    # Telescope fuzzy finder native sorter is built; fzf binary not required
    fzf
    # Treesitter parser compilation (same as LV wrapper)
    gcc
    tree-sitter
    curl
    unzip
    gzip
    gnumake
    git
  ];
}
