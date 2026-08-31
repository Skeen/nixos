local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
local out = {}
local function add(name, value)
  table.insert(out, name .. "=" .. tostring(value))
end
local names = {"aleph","allowrevins","ambiwidth","arabic","arabicshape","autochdir","autoindent","autoread","autowrite","autowriteall","background","backup","backupcopy","backupext","belloff","binary","bomb","breakindent","breakindentopt","browsedir","bufhidden","buflisted","buftype","cdhome","cdpath","cedit","channel","charconvert","cindent","cinoptions","cinwords","clipboard","cmdheight","cmdwinheight","colorcolumn","columns","commentstring","compatible","complete","completefunc","completeitemalign","completeopt","completeslash","concealcursor","conceallevel","confirm","copyindent","cursorbind","cursorcolumn","cursorline","cursorlineopt","debug","define","delcombine","dictionary","diff","diffexpr","digraph","directory","display","eadirection","edcompatible","emoji","encoding","endoffile","endofline","equalalways","equalprg","errorbells","eventignore","expandtab","exrc","fileencoding","fileformat","fileignorecase","filetype","fillchars","fixendofline","foldclose","foldcolumn","foldenable","foldexpr","foldignore","foldlevel","foldlevelstart","foldmethod","foldminlines","foldnestmax","foldopen","foldtext","formatexpr","formatlistpat","formatprg","fsync","gdefault","guifont","guioptions","helpheight","helplang","hidden","history","hkmap","hlsearch","icon","iconstring","ignorecase","imcmdline","imdisable","iminsert","imsearch","include","includeexpr","incsearch","indentexpr","infercase","insertmode","isprint","joinspaces","jumpoptions","keymap","keymodel","keywordprg","langmap","laststatus","lazyredraw","linebreak","lines","linespace","lisp","lispoptions","list","magic","makeef","makeprg","matchtime","maxcombine","maxfuncdepth","maxmapdepth","menuitems","modeline","modelineexpr","modelines","modifiable","modified","more","mouse","mousefocus","mousemoveevent","mouseshape","mousetime","nrformats","number","omnifunc","opendevice","operatorfunc","paste","pastetoggle","patchexpr","patchmode","path","preserveindent","previewheight","previewwindow","prompt","pumblend","pumheight","pumwidth","pyxversion","quickfixtextfunc","quoteescape","readonly","redrawdebug","redrawtime","regexpengine","relativenumber","remap","report","revins","rightleft","ruler","rulerformat","scroll","scrollback","scrollbind","scrolljump","scrolloff","secure","selectmode","sessionoptions","shadafile","shell","shellcmdflag","shellpipe","shellquote","shellslash","shelltemp","shellxescape","shellxquote","shiftround","shiftwidth","showbreak","showcmd","showcmdloc","showfulltag","showmatch","showmode","showtabline","sidescroll","sidescrolloff","signcolumn","smartcase","smartindent","smarttab","smoothscroll","softtabstop","spell","spellfile","spelloptions","spellsuggest","splitbelow","splitkeep","splitright","startofline","statuscolumn","statusline","suffixesadd","swapfile","switchbuf","synmaxcol","syntax","tabclose","tabline","tabpagemax","tabstop","tagbsearch","tagcase","tagfunc","taglength","tagrelative","tags","tagstack","termbidi","termencoding","termguicolors","termsync","terse","textwidth","thesaurus","thesaurusfunc","tildeop","timeout","timeoutlen","title","titlelen","titleold","titlestring","ttimeout","ttimeoutlen","ttyfast","undofile","undolevels","undoreload","updatecount","updatetime","varsofttabstop","vartabstop","verbose","verbosefile","virtualedit","visualbell","warn","wildchar","wildcharm","wildignore","wildignorecase","wildmenu","wildmode","winaltkeys","winbar","winblend","winborder","window","winfixbuf","winfixheight","winfixwidth","winheight","winhighlight","winminheight","winminwidth","winwidth","wrap","wrapmargin","wrapscan","write","writeany","writebackup","writedelay"}
for _, n in ipairs(names) do
  local ok, v = pcall(function() return vim.o[n] end)
  if ok then add(n, v) end
end
add("spelllang_full", vim.o.spelllang)
add("whichwrap_full", vim.o.whichwrap)
do
  -- shortmess: sorted unique flags; ordering is not semantic
  local f = {}
  for c in vim.o.shortmess:gmatch("%a") do f[c] = true end
  local keys = {}
  for c in pairs(f) do keys[#keys+1] = c end
  table.sort(keys)
  add("shortmess_flags", table.concat(keys, ""))
end
add("complete_full", vim.o.complete)
add("diffopt_full", vim.o.diffopt)
add("display_full", vim.o.display)
add("formatoptions_full", vim.o.formatoptions)
add("sessionoptions_full", vim.o.sessionoptions)
add("viewoptions_full", vim.o.viewoptions)
add("guicursor_full", vim.o.guicursor)
add("grepprg_full", vim.o.grepprg)
add("undodir_norm", vim.fn.fnamemodify(vim.o.undodir, ":t"))
add("shadafile_norm", vim.fn.fnamemodify(vim.o.shadafile, ":t"))
table.sort(out)
for _, l in ipairs(out) do __pout(l) end

local __f = io.open(vim.env.UNIT_OUT, "w")
if not __f then error("cannot open UNIT_OUT") end
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
