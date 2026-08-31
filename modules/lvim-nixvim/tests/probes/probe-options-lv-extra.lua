local __pbuf = {}
local __pout = function(l) __pbuf[#__pbuf+1] = tostring(l) end
-- window/editor global prop comparison battery (~110 checks)
local os_ = vim.o
local props = {"autochdir","autoread","autoindent","backup","backupcopy","binary","belloff","bomb","breakindent","cedit","clipboard","cmdheight","colorcolumn","complete","completeopt","conceallevel","cursorline","cursorlineopt","diffopt","directory","display","emoji","encoding","errorbells","expandtab","fileencoding","fileformat","foldenable","foldexpr","foldlevelstart","foldmethod","formatoptions","formatprg","gdefault","grepprg","helplang","hidden","history","hlsearch","ignorecase","imdisable","iminsert","imsearch","incsearch","indentexpr","isprint","joinspaces","jumpoptions","keywordprg","langmap","laststatus","lazyredraw","linebreak","linespace","lisp","lispoptions","list","magic","makeprg","matchtime","maxmapdepth","modeline","modelines","modifiable","more","mouse","mousemoveevent","mousetime","nrformats","number","opendevice","operatorfunc","paste","patchexpr","patchmode","path","preserveindent","previewheight","prompt","pumblend","pumheight","pumwidth","pyxversion","quickfixtextfunc","quoteescape","readonly","redrawdebug","redrawtime","regexpengine","relativenumber","remap","report","revins","ruler","scroll","scrollback","scrollbind","scrolljump","scrolloff","selectmode","shadafile","shellcmdflag","shellpipe","shellquote","shellslash","shelltemp","shellxescape","shellxquote","shiftround","shiftwidth","showbreak","showcmd","showcmdloc","showfulltag","showmatch","showmode","showtabline","sidescroll","sidescrolloff","signcolumn","smartcase","smartindent","smarttab","smoothscroll","softtabstop","spell","spellfile","spelllang","spelloptions","spellsuggest","splitbelow","splitkeep","splitright","startofline","statuscolumn","statusline","suffixesadd","swapfile","switchbuf","synmaxcol","tabclose","tabpagemax","tabstop","tagbsearch","tagcase","tagfunc","taglength","tagrelative","tags","tagstack","termbidi","termencoding","termguicolors","termsync","terse","textwidth","tildeop","timeout","timeoutlen","title","titlelen","titleold","titlestring","ttimeout","ttimeoutlen","ttyfast","undofile","undolevels","undoreload","updatecount","updatetime","varsofttabstop","vartabstop","verbose","verbosefile","virtualedit","visualbell","warn","whichwrap","wildchar","wildcharm","wildignore","wildignorecase","wildmenu","wildmode","winaltkeys","winbar","winblend","winborder","window","winfixbuf","winfixheight","winfixwidth","winheight","winhighlight","winminheight","winminwidth","winwidth","wrap","wrapmargin","wrapscan","write","writeany","writebackup","writedelay"}
local ok_count = 0
for _, n in ipairs(props) do
  local ok, v = pcall(function() return os_[n] end)
  if ok then
    ok_count = ok_count + 1
    __pout("opt." .. n .. "=" .. tostring(v))
  end
end
__pout("opt.ok_count=" .. ok_count)
-- file-formats
__pout("ff=" .. tostring(vim.bo.fileformat))
-- echo buffer options
__pout("buf.et=" .. tostring(vim.bo.expandtab))
local __f = io.open(vim.env.UNIT_OUT, "w")
for _, l in ipairs(__pbuf) do __f:write(l .. "\n") end
__f:close()
