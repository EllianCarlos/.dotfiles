-- TTY design system for Neovim.
-- Black-first, warm greys, signal yellow for focus/selection/cursor.
-- Accents are semantic: green ok/strings, cyan info/numbers, magenta keywords, red errors.
vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.colors_name = "tty"
vim.o.guicursor = "n-v-c:block,i-ci-ve:block-blinkwait530-blinkon530-blinkoff530,r-cr:hor20"
vim.o.fillchars = "vert:│,horiz:─,eob: ,fold: ,foldopen:▾,foldclose:▸"

local c = {
  void = "#000000", root = "#0A0A09", panel = "#121211", raised = "#1A1A18", hover = "#242422",
  border = "#33332F", strong = "#4A4A45", faint = "#5E5E58", muted = "#8C8C84", secondary = "#B4B4AC", text = "#E8E8E3",
  yellow = "#FFD400", ydim = "#8A7300", ywash = "#2B2608",
  green = "#5AF78E", gdim = "#2E8F52", gwash = "#132A1B",
  cyan = "#5EDFFF", cdim = "#2C7F94", cwash = "#12262B",
  magenta = "#FF6AC1", mdim = "#94396E",
  red = "#FF5C57", rdim = "#933531", rwash = "#2B1414",
}

local hl = function(g, o) vim.api.nvim_set_hl(0, g, o) end
local groups = {
  Normal = { fg = c.text, bg = c.root }, NormalNC = { fg = c.text, bg = c.root },
  NormalFloat = { fg = c.text, bg = c.panel }, FloatBorder = { fg = c.border, bg = c.panel }, FloatTitle = { fg = c.yellow, bg = c.panel, bold = true },
  Cursor = { fg = c.void, bg = c.yellow }, lCursor = { link = "Cursor" }, TermCursor = { link = "Cursor" },
  CursorLine = { bg = c.panel }, CursorColumn = { bg = c.panel }, ColorColumn = { bg = c.panel },
  CursorLineNr = { fg = c.yellow, bold = true }, LineNr = { fg = c.faint }, SignColumn = { bg = c.root }, FoldColumn = { fg = c.faint },
  Folded = { fg = c.muted, bg = c.raised },
  WinSeparator = { fg = c.border }, VertSplit = { link = "WinSeparator" },
  StatusLine = { fg = c.secondary, bg = c.root }, StatusLineNC = { fg = c.faint, bg = c.root },
  TabLine = { fg = c.muted, bg = c.root }, TabLineFill = { bg = c.root }, TabLineSel = { fg = c.void, bg = c.yellow },
  WinBar = { fg = c.secondary, bg = c.root }, WinBarNC = { fg = c.faint, bg = c.root },
  Visual = { fg = c.void, bg = c.yellow }, VisualNOS = { link = "Visual" },
  Search = { fg = c.void, bg = c.ydim }, IncSearch = { fg = c.void, bg = c.yellow }, CurSearch = { link = "IncSearch" }, Substitute = { link = "IncSearch" },
  MatchParen = { fg = c.yellow, bold = true, underline = true },
  Pmenu = { fg = c.text, bg = c.panel }, PmenuSel = { fg = c.void, bg = c.yellow }, PmenuSbar = { bg = c.raised }, PmenuThumb = { bg = c.strong },
  PmenuKind = { fg = c.muted, bg = c.panel }, PmenuExtra = { fg = c.faint, bg = c.panel },
  WildMenu = { link = "PmenuSel" },
  NonText = { fg = c.border }, Whitespace = { fg = c.border }, SpecialKey = { fg = c.border }, EndOfBuffer = { fg = c.root },
  Directory = { fg = c.cyan }, Title = { fg = c.yellow, bold = true }, Question = { fg = c.cyan }, MoreMsg = { fg = c.green },
  ModeMsg = { fg = c.yellow, bold = true }, ErrorMsg = { fg = c.red }, WarningMsg = { fg = c.yellow },
  QuickFixLine = { bg = c.ywash }, Conceal = { fg = c.faint },
  SpellBad = { sp = c.red, undercurl = true }, SpellCap = { sp = c.cyan, undercurl = true }, SpellRare = { sp = c.magenta, undercurl = true }, SpellLocal = { sp = c.cyan, undercurl = true },

  Comment = { fg = c.faint, italic = true },
  Constant = { fg = c.cyan }, String = { fg = c.green }, Character = { fg = c.green }, Number = { fg = c.cyan }, Boolean = { fg = c.cyan }, Float = { fg = c.cyan },
  Identifier = { fg = c.text }, Function = { fg = c.yellow },
  Statement = { fg = c.magenta }, Keyword = { fg = c.magenta }, Conditional = { fg = c.magenta }, Repeat = { fg = c.magenta }, Label = { fg = c.magenta }, Exception = { fg = c.magenta },
  Operator = { fg = c.muted }, PreProc = { fg = c.magenta }, Include = { fg = c.magenta },
  Type = { fg = c.secondary }, StorageClass = { fg = c.magenta }, Structure = { fg = c.secondary }, Typedef = { fg = c.secondary },
  Special = { fg = c.cyan }, Delimiter = { fg = c.muted }, SpecialComment = { fg = c.muted, italic = true },
  Underlined = { underline = true }, Error = { fg = c.red }, Todo = { fg = c.void, bg = c.yellow, bold = true },

  ["@variable"] = { fg = c.text }, ["@variable.builtin"] = { fg = c.secondary, italic = true }, ["@variable.parameter"] = { fg = c.secondary },
  ["@variable.member"] = { fg = c.text }, ["@property"] = { fg = c.text },
  ["@constant"] = { fg = c.cyan }, ["@constant.builtin"] = { fg = c.cyan }, ["@module"] = { fg = c.secondary },
  ["@string"] = { link = "String" }, ["@string.escape"] = { fg = c.cyan }, ["@string.regexp"] = { fg = c.cyan }, ["@string.special.url"] = { fg = c.yellow, underline = true },
  ["@function"] = { link = "Function" }, ["@function.builtin"] = { fg = c.yellow }, ["@function.call"] = { fg = c.yellow }, ["@function.method"] = { fg = c.yellow }, ["@constructor"] = { fg = c.secondary },
  ["@keyword"] = { link = "Keyword" }, ["@keyword.return"] = { fg = c.magenta }, ["@keyword.function"] = { fg = c.magenta }, ["@keyword.operator"] = { fg = c.magenta },
  ["@type"] = { link = "Type" }, ["@type.builtin"] = { fg = c.secondary, italic = true },
  ["@punctuation"] = { fg = c.muted }, ["@punctuation.bracket"] = { fg = c.muted }, ["@punctuation.delimiter"] = { fg = c.muted },
  ["@tag"] = { fg = c.magenta }, ["@tag.attribute"] = { fg = c.secondary }, ["@tag.delimiter"] = { fg = c.muted },
  ["@comment"] = { link = "Comment" }, ["@comment.todo"] = { link = "Todo" }, ["@comment.error"] = { fg = c.void, bg = c.red }, ["@comment.warning"] = { fg = c.void, bg = c.yellow }, ["@comment.note"] = { fg = c.void, bg = c.cyan },
  ["@markup.heading"] = { fg = c.yellow, bold = true }, ["@markup.strong"] = { bold = true }, ["@markup.italic"] = { italic = true },
  ["@markup.link"] = { fg = c.yellow, underline = true }, ["@markup.link.url"] = { fg = c.yellow, underline = true }, ["@markup.raw"] = { fg = c.green },
  ["@markup.list"] = { fg = c.muted }, ["@markup.quote"] = { fg = c.secondary, italic = true },
  ["@diff.plus"] = { fg = c.green }, ["@diff.minus"] = { fg = c.red }, ["@diff.delta"] = { fg = c.yellow },
  ["@lsp.type.parameter"] = { link = "@variable.parameter" }, ["@lsp.type.property"] = { link = "@property" },

  DiagnosticError = { fg = c.red }, DiagnosticWarn = { fg = c.yellow }, DiagnosticInfo = { fg = c.cyan }, DiagnosticHint = { fg = c.muted }, DiagnosticOk = { fg = c.green },
  DiagnosticVirtualTextError = { fg = c.red, bg = c.rwash }, DiagnosticVirtualTextWarn = { fg = c.yellow, bg = c.ywash },
  DiagnosticVirtualTextInfo = { fg = c.cyan, bg = c.cwash }, DiagnosticVirtualTextHint = { fg = c.muted, bg = c.raised },
  DiagnosticUnderlineError = { sp = c.red, undercurl = true }, DiagnosticUnderlineWarn = { sp = c.yellow, undercurl = true },
  DiagnosticUnderlineInfo = { sp = c.cyan, undercurl = true }, DiagnosticUnderlineHint = { sp = c.muted, undercurl = true },
  LspReferenceText = { bg = c.hover }, LspReferenceRead = { bg = c.hover }, LspReferenceWrite = { bg = c.hover, underline = true },
  LspInlayHint = { fg = c.faint, bg = c.panel }, LspSignatureActiveParameter = { fg = c.yellow, bold = true },

  DiffAdd = { bg = c.gwash }, DiffChange = { bg = c.raised }, DiffDelete = { fg = c.rdim, bg = c.rwash }, DiffText = { bg = c.ywash },
  Added = { fg = c.green }, Changed = { fg = c.yellow }, Removed = { fg = c.red },
  GitSignsAdd = { fg = c.gdim }, GitSignsChange = { fg = c.ydim }, GitSignsDelete = { fg = c.rdim },

  -- snacks (LazyVim picker / dashboard / notifier)
  SnacksPicker = { link = "NormalFloat" }, SnacksPickerBorder = { fg = c.yellow, bg = c.panel }, SnacksPickerTitle = { fg = c.yellow, bold = true },
  SnacksPickerMatch = { fg = c.yellow, bold = true }, SnacksPickerListCursorLine = { fg = c.void, bg = c.yellow }, SnacksPickerPrompt = { fg = c.yellow },
  SnacksPickerDir = { fg = c.muted }, SnacksPickerFile = { fg = c.text }, SnacksPickerInputBorder = { fg = c.border, bg = c.panel },
  SnacksDashboardHeader = { fg = c.yellow }, SnacksDashboardKey = { fg = c.yellow }, SnacksDashboardDesc = { fg = c.text }, SnacksDashboardIcon = { fg = c.muted }, SnacksDashboardFooter = { fg = c.faint },
  SnacksIndent = { fg = c.hover }, SnacksIndentScope = { fg = c.strong },
  SnacksNotifierBorderInfo = { fg = c.border }, SnacksNotifierBorderWarn = { fg = c.yellow }, SnacksNotifierBorderError = { fg = c.red },
  SnacksNotifierTitleInfo = { fg = c.text, bold = true }, SnacksNotifierIconInfo = { fg = c.cyan },
  -- telescope (if used)
  TelescopeNormal = { link = "NormalFloat" }, TelescopeBorder = { fg = c.border, bg = c.panel }, TelescopePromptBorder = { fg = c.yellow, bg = c.panel },
  TelescopeSelection = { fg = c.void, bg = c.yellow }, TelescopeMatching = { fg = c.yellow, bold = true }, TelescopeTitle = { fg = c.yellow, bold = true },
  -- neo-tree
  NeoTreeNormal = { fg = c.text, bg = c.root }, NeoTreeNormalNC = { fg = c.text, bg = c.root }, NeoTreeWinSeparator = { fg = c.border, bg = c.root },
  NeoTreeCursorLine = { fg = c.void, bg = c.yellow }, NeoTreeDirectoryName = { fg = c.text }, NeoTreeDirectoryIcon = { fg = c.muted }, NeoTreeRootName = { fg = c.yellow, bold = true },
  NeoTreeDotfile = { fg = c.muted }, NeoTreeGitModified = { fg = c.yellow }, NeoTreeGitAdded = { fg = c.green }, NeoTreeGitUntracked = { fg = c.cyan }, NeoTreeGitDeleted = { fg = c.red }, NeoTreeGitIgnored = { fg = c.faint },
  NeoTreeIndentMarker = { fg = c.border }, NeoTreeExpander = { fg = c.muted }, NeoTreeTitleBar = { fg = c.void, bg = c.yellow },
  -- which-key
  WhichKey = { fg = c.yellow }, WhichKeyGroup = { fg = c.cyan }, WhichKeyDesc = { fg = c.text }, WhichKeySeparator = { fg = c.faint }, WhichKeyNormal = { bg = c.panel }, WhichKeyBorder = { fg = c.border, bg = c.panel },
  -- bufferline
  BufferLineFill = { bg = c.root }, BufferLineBackground = { fg = c.muted, bg = c.root }, BufferLineBufferSelected = { fg = c.void, bg = c.yellow, bold = true },
  BufferLineBufferVisible = { fg = c.secondary, bg = c.root }, BufferLineSeparator = { fg = c.border, bg = c.root }, BufferLineSeparatorSelected = { fg = c.border, bg = c.yellow },
  BufferLineModifiedSelected = { fg = c.void, bg = c.yellow }, BufferLineCloseButtonSelected = { fg = c.void, bg = c.yellow }, BufferLineIndicatorSelected = { fg = c.yellow, bg = c.yellow },
  -- blink.cmp / cmp
  BlinkCmpMenu = { link = "Pmenu" }, BlinkCmpMenuBorder = { fg = c.border, bg = c.panel }, BlinkCmpMenuSelection = { link = "PmenuSel" },
  BlinkCmpLabelMatch = { fg = c.yellow, bold = true }, BlinkCmpKind = { fg = c.muted }, BlinkCmpDoc = { link = "NormalFloat" }, BlinkCmpDocBorder = { fg = c.border, bg = c.panel },
  CmpItemAbbrMatch = { fg = c.yellow, bold = true }, CmpItemKind = { fg = c.muted }, CmpItemMenu = { fg = c.faint },
  -- noice / mini / flash
  NoiceCmdlinePopupBorder = { fg = c.yellow, bg = c.panel }, NoiceCmdlineIcon = { fg = c.yellow }, NoiceCmdlinePopupTitle = { fg = c.yellow },
  MiniIndentscopeSymbol = { fg = c.strong }, MiniStatuslineModeNormal = { fg = c.void, bg = c.yellow, bold = true },
  FlashLabel = { fg = c.void, bg = c.magenta, bold = true }, FlashMatch = { fg = c.yellow }, FlashCurrent = { fg = c.void, bg = c.yellow },
  TroubleNormal = { fg = c.text, bg = c.root }, LazyNormal = { link = "NormalFloat" }, MasonNormal = { link = "NormalFloat" },
}
for g, o in pairs(groups) do hl(g, o) end

local term = { c.raised, c.red, c.green, c.yellow, c.cyan, c.magenta, c.cyan, c.secondary,
               c.faint, c.red, c.green, "#FFE566", c.cyan, c.magenta, c.cyan, c.text }
for i, col in ipairs(term) do vim.g["terminal_color_" .. (i - 1)] = col end
