#!/usr/bin/env python3
"""
Converts Simple Focus VSCode theme + user overrides to a Neovim Lua colorscheme.

Two-track approach:
  Track 1 — semanticTokenColors → @lsp.type.* (direct 1:1 mapping)
  Track 2 — tokenColors (TextMate scopes) → Treesitter @* groups (curated mapping table)

Alpha blending is done mathematically against the appropriate background color.
"""

import json, re

THEME_FILE = "/home/zerohidz/.vscode-oss/extensions/ncodefun.simple-focus-web-5.1.0/themes/simple-focus-web.color-theme.json"
OUTPUT_FILE = "/home/zerohidz/.config/nvim/colors/simple-focus.lua"

# ── User overrides ────────────────────────────────────────────────────────────
# From settings.json: workbench.colorCustomizations [Simple Focus]
USER_COLOR_OVERRIDES = {
    "gitDecoration.ignoredResourceForeground":  "#81a8a1aa",
    "gitDecoration.modifiedResourceForeground": "#cbfff999",
    "gitDecoration.untrackedResourceForeground":"#b4ebbd",
}

# From settings.json: editor.semanticTokenColorCustomizations [Simple Focus] rules
USER_SEMANTIC_OVERRIDES = {
    "keyword":   {"fg": "#65956d"},
    "enum":      {"fg": "#ecffc7"},
    "interface": {"fg": "#ecffc7"},
    "struct":    {"fg": "#b4ebbdc6"},
    "string":    {"fg": "#14b791", "italic": False},
}

# ── JSON parsing ──────────────────────────────────────────────────────────────
def strip_jsonc(text):
    result, in_string = [], False
    i = 0
    while i < len(text):
        if text[i] == '"' and (i == 0 or text[i-1] != '\\'):
            in_string = not in_string
        if not in_string and text[i:i+2] == '//':
            while i < len(text) and text[i] != '\n':
                i += 1
            continue
        result.append(text[i])
        i += 1
    cleaned = ''.join(result)
    cleaned = re.sub(r',(\s*[}\]])', r'\1', cleaned)
    return cleaned

with open(THEME_FILE) as f:
    data = json.loads(strip_jsonc(f.read()))

colors       = data.get("colors", {})
token_colors = data.get("tokenColors", [])
semantic_raw = data.get("semanticTokenColors", {})

colors.update(USER_COLOR_OVERRIDES)

# ── Color utilities ───────────────────────────────────────────────────────────
def parse_hex(color):
    c = color.lstrip('#')
    if len(c) == 3:  c = c[0]*2 + c[1]*2 + c[2]*2
    if len(c) == 6:  return int(c[0:2],16), int(c[2:4],16), int(c[4:6],16), 255
    if len(c) == 8:  return int(c[0:2],16), int(c[2:4],16), int(c[4:6],16), int(c[6:8],16)
    raise ValueError(f"Bad color: {color!r}")

def blend(fg, bg):
    fr,fg_,fb,fa = parse_hex(fg)
    br,bg_,bb,_  = parse_hex(bg)
    a = fa / 255.0
    return f"#{round(fr*a+br*(1-a)):02x}{round(fg_*a+bg_*(1-a)):02x}{round(fb*a+bb*(1-a)):02x}"

def solid(color, bg="#1d1f21"):
    _,_,_,a = parse_hex(color)
    return color[:7] if a == 255 else blend(color, bg)

def c(col):
    return '"NONE"' if col is None else f'"{col}"'

# ── UI palette ────────────────────────────────────────────────────────────────
BG       = colors["editor.background"]
BG_UI    = colors["activityBar.background"]
BG_FLOAT = colors["editorWidget.background"]
BG_INPUT = colors["input.background"]
FG       = colors["editor.foreground"]
FG_DIM   = colors["dropdown.foreground"]
BORDER   = colors["editorHoverWidget.border"]

CURSOR_LINE = solid(colors["editor.lineHighlightBackground"],           BG)
SELECTION   = solid(colors["editor.selectionBackground"],               BG)
SEARCH      = solid(colors["editor.findMatchBackground"],               BG)
LINE_NR     = solid(colors["editorLineNumber.foreground"],              BG_UI)
LINE_NR_ACT =       colors["editorLineNumber.activeForeground"]
PMENU_SEL   = solid(colors["editorSuggestWidget.selectedBackground"],   BG_FLOAT)

INDENT_NORMAL = colors.get("editorIndentGuide.background",       "#404040")
INDENT_ACTIVE = solid(colors.get("editorIndentGuide.activeBackground", "#cbffee88"), BG)

GIT_MOD    = solid(colors["gitDecoration.modifiedResourceForeground"],  BG_UI)
GIT_NEW    = solid(colors["gitDecoration.untrackedResourceForeground"], BG_UI)
GIT_IGNORE = solid(colors["gitDecoration.ignoredResourceForeground"],   BG_UI)

DIAG_ERROR = "#f44747"
DIAG_WARN  = "#cd9731"
DIAG_INFO  = "#6796e6"

# ── Track 1: Semantic token colors ───────────────────────────────────────────
# Parse theme's semanticTokenColors into a flat dict: token_type → {fg, italic}
def parse_semantic_entry(val):
    if isinstance(val, str):
        return {"fg": val, "italic": None}
    if isinstance(val, dict):
        return {
            "fg":     val.get("foreground"),
            "italic": True if "italic" in val.get("fontStyle","") else
                      (False if val.get("fontStyle","") == "" else None),
        }
    return {}

sem_colors = {}
for key, val in semantic_raw.items():
    sem_colors[key] = parse_semantic_entry(val)

# Apply user overrides (higher priority than theme semantic colors)
for key, ov in USER_SEMANTIC_OVERRIDES.items():
    entry = dict(sem_colors.get(key, {}))
    if "fg" in ov:     entry["fg"]     = ov["fg"]
    if "italic" in ov: entry["italic"] = ov["italic"]
    sem_colors[key] = entry

def sem(token_type, fallback_fg, fallback_italic=False):
    """Resolve semantic token color: theme override > user override > fallback."""
    entry   = sem_colors.get(token_type, {})
    fg_raw  = entry.get("fg") or fallback_fg
    italic  = entry.get("italic")
    if italic is None: italic = fallback_italic
    _,_,_,a = parse_hex(fg_raw)
    fg = fg_raw[:7] if a == 255 else blend(fg_raw, BG)
    return fg, italic

# ── Track 2: TextMate tokenColors ────────────────────────────────────────────
# Build scope → {fg, italic} map (last rule wins for a given scope)
scope_map = {}
for rule in token_colors:
    scopes   = rule.get("scope", [])
    settings = rule.get("settings", {})
    if isinstance(scopes, str): scopes = [scopes]
    fg_raw = settings.get("foreground")
    style  = settings.get("fontStyle", "")
    for sc in scopes:
        sc = sc.strip()
        if sc and fg_raw:
            _,_,_,a = parse_hex(fg_raw)
            fg = fg_raw[:7] if a == 255 else blend(fg_raw, BG)
            scope_map[sc] = {
                "fg":     fg,
                "italic": "italic" in style,
                "bold":   "bold"   in style,
            }

def tm(*scopes):
    """First matching TextMate scope → (fg, italic, bold)."""
    for sc in scopes:
        if sc in scope_map:
            e = scope_map[sc]
            return e["fg"], e["italic"], e["bold"]
    return None, False, False

# Key colors from TextMate scopes
S_STRING,  STR_IT,  _     = tm("string")
S_FUNC,    _,       _     = tm("entity.name.function", "meta.function-call")
S_CLASS,   _,       _     = tm("entity.name.type.class.js", "entity.name.type.js")
S_STORAGE, _,       _     = tm("storage")
S_KEYWORD, _,       _     = tm("keyword.control")
S_PARAM,   PAR_IT,  _     = tm("variable.parameter")
S_PROP,    _,       _     = tm("meta.object-literal.key", "support.variable.property")
S_TAG,     _,       _     = tm("entity.name.tag")
S_PUNCT,   _,       _     = tm("punctuation")
S_COMMENT, _,       _     = tm("comment")
S_ESCAPE,  _,       _     = tm("constant.character.escape")
S_PINK,    _,       _     = tm("keyword.operator.expression.delete")
S_TMPL,    _,       _     = tm("string.template")
S_CONST,   _,       _     = tm("constant")
S_IMPORT,  _,       _     = tm("keyword.control.import")
S_OPER,    _,       _     = tm("keyword.operator")

# Semantic colors for LSP track (with fallbacks from TextMate)
LSP_CLASS,   CLS_IT   = sem("class",     S_CLASS)
LSP_ENUM,    ENUM_IT  = sem("enum",      S_CLASS)
LSP_IFACE,   IFC_IT   = sem("interface", S_CLASS)
LSP_STRUCT,  STR2_IT  = sem("struct",    S_CLASS)
LSP_KW,      KW_IT    = sem("keyword",   S_STORAGE)
LSP_STR,     LSTR_IT  = sem("string",    S_STRING, bool(STR_IT))

# ── Lua output helpers ────────────────────────────────────────────────────────
lines = []
def section(name):
    lines.append(f"\n-- ─── {name} {'─' * (55 - len(name))}")

def hi(group, fg=None, bg=None, bold=False, italic=False,
       underline=False, undercurl=False, sp=None, link=None):
    if link:
        return f'hi(0, "{group}", {{ link = "{link}" }})'
    parts = []
    if fg:        parts.append(f"fg = {c(fg)}")
    if bg:        parts.append(f"bg = {c(bg)}")
    if bold:      parts.append("bold = true")
    if italic:    parts.append("italic = true")
    if underline: parts.append("underline = true")
    if undercurl: parts.append("undercurl = true")
    if sp:        parts.append(f"sp = {c(sp)}")
    return f'hi(0, "{group}", {{ {", ".join(parts)} }})'

def a(line): lines.append(line)

# ── Generate Lua ──────────────────────────────────────────────────────────────
a("-- Simple Focus colorscheme for Neovim")
a("-- Auto-generated by convert_theme.py (VSCodium theme by ncodefun + user overrides)")
a("")
a('vim.cmd("highlight clear")')
a('if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end')
a('vim.g.colors_name = "simple-focus"')
a('vim.o.background = "dark"')
a("")
a("local hi = vim.api.nvim_set_hl")

section("Editor UI")
a(hi("Normal",       fg=FG,        bg=BG))
a(hi("NormalNC",     fg=FG,        bg=BG))
a(hi("NormalFloat",  fg=FG,        bg=BG_FLOAT))
a(hi("FloatBorder",  fg=BORDER,    bg=BG_FLOAT))
a(hi("FloatTitle",   fg=FG_DIM,    bg=BG_FLOAT))
a(hi("CursorLine",   bg=CURSOR_LINE))
a(hi("CursorColumn", bg=CURSOR_LINE))
a(hi("ColorColumn",  bg=BG_UI))
a(hi("LineNr",       fg=LINE_NR))
a(hi("CursorLineNr", fg=LINE_NR_ACT))
a(hi("SignColumn",   bg="NONE"))
a(hi("FoldColumn",   fg=LINE_NR,   bg="NONE"))
a(hi("Folded",       fg=S_COMMENT, bg="NONE"))
a(hi("StatusLine",   fg=FG_DIM,    bg=BG_UI))
a(hi("StatusLineNC", fg=S_STORAGE, bg=BG_UI))
a(hi("WinSeparator", fg=BG_UI))
a(hi("TabLine",      fg=S_STORAGE, bg=BG_UI))
a(hi("TabLineSel",   fg=FG_DIM,    bg=BG_FLOAT))
a(hi("TabLineFill",  bg=BG_UI))
a(hi("Visual",       bg=SELECTION))
a(hi("Search",       fg=FG,        bg=SEARCH))
a(hi("IncSearch",    fg=FG,        bg=SEARCH))
a(hi("CurSearch",    fg=FG,        bg=SEARCH))
a(hi("Substitute",   fg=FG,        bg=SEARCH))
a(hi("MatchParen",   bg=solid("#4ab33c73", BG), bold=True))
a(hi("Pmenu",        fg=FG,        bg=BG_FLOAT))
a(hi("PmenuSel",     fg=FG_DIM,    bg=PMENU_SEL))
a(hi("PmenuSbar",    bg=BG_FLOAT))
a(hi("PmenuThumb",   bg=S_STORAGE))
a(hi("EndOfBuffer",  fg=BG))
a(hi("NonText",      fg=LINE_NR))
a(hi("SpecialKey",   fg=LINE_NR))
a(hi("Title",        fg=FG,        bold=True))
a(hi("Directory",    fg=S_PROP))
a(hi("ErrorMsg",     fg=DIAG_ERROR))
a(hi("WarningMsg",   fg=DIAG_WARN))
a(hi("WildMenu",     fg=FG_DIM,    bg=PMENU_SEL))
a(hi("Conceal",      fg=S_COMMENT))
a(hi("SpellBad",     undercurl=True, sp=DIAG_ERROR))
a(hi("SpellWarn",    undercurl=True, sp=DIAG_WARN))
a(hi("SpellCap",     undercurl=True, sp=DIAG_INFO))

section("Syntax (Vim built-in / Treesitter fallbacks)")
a(hi("Comment",      fg=S_COMMENT, italic=True))
a(hi("String",       fg=S_STRING,  italic=bool(STR_IT)))
a(hi("Character",    fg=S_STRING))
a(hi("Number",       fg=S_CONST))
a(hi("Float",        fg=S_CONST))
a(hi("Boolean",      fg=S_CONST))
a(hi("Constant",     fg=S_CONST))
a(hi("Identifier",   fg=FG))
a(hi("Function",     fg=S_FUNC))
a(hi("Keyword",      fg=S_STORAGE))
a(hi("Statement",    fg=S_KEYWORD))
a(hi("Conditional",  fg=S_KEYWORD))
a(hi("Repeat",       fg=S_KEYWORD))
a(hi("Label",        fg=S_KEYWORD, italic=True))
a(hi("Exception",    fg=S_KEYWORD))
a(hi("Operator",     fg=S_OPER  or S_FUNC))
a(hi("PreProc",      fg=S_STORAGE))
a(hi("Include",      fg=S_IMPORT or S_STORAGE))
a(hi("Define",       fg=S_STORAGE))
a(hi("Macro",        fg=S_STORAGE))
a(hi("StorageClass", fg=S_STORAGE))
a(hi("Structure",    fg=LSP_CLASS))
a(hi("Typedef",      fg=LSP_CLASS))
a(hi("Type",         fg=LSP_CLASS))
a(hi("Special",      fg=S_ESCAPE))
a(hi("SpecialChar",  fg=S_ESCAPE))
a(hi("Tag",          fg=S_TAG))
a(hi("Delimiter",    fg=S_PUNCT))
a(hi("Error",        fg=DIAG_ERROR))
a(hi("Todo",         fg=S_KEYWORD, bold=True))

section("Treesitter")
a(hi("@comment",                   fg=S_COMMENT,  italic=True))
a(hi("@comment.documentation",     fg=S_COMMENT,  italic=True))
a(hi("@string",                    fg=S_STRING,   italic=bool(STR_IT)))
a(hi("@string.escape",             fg=S_ESCAPE))
a(hi("@string.regex",              fg=S_STRING))
a(hi("@string.special",            fg=S_STRING))
a(hi("@character",                 fg=S_STRING))
a(hi("@character.special",         fg=S_ESCAPE))
a(hi("@number",                    fg=S_CONST))
a(hi("@number.float",              fg=S_CONST))
a(hi("@float",                     fg=S_CONST))
a(hi("@boolean",                   fg=S_CONST))
a(hi("@constant",                  fg=S_CONST))
a(hi("@constant.builtin",          fg=S_CONST))
a(hi("@constant.macro",            fg=S_CONST))
a("")
a(hi("@function",                  fg=S_FUNC))
a(hi("@function.builtin",          fg=S_FUNC))
a(hi("@function.call",             fg=S_FUNC))
a(hi("@function.macro",            fg=S_FUNC))
a(hi("@method",                    fg=S_FUNC))
a(hi("@method.call",               fg=S_FUNC))
a(hi("@constructor",               fg=LSP_CLASS))
a("")
a("-- storage-colored: declaration keywords, modifiers, imports")
a(hi("@keyword",                   fg=S_STORAGE))
a(hi("@keyword.function",          fg=S_STORAGE))
a(hi("@keyword.modifier",          fg=S_STORAGE))   # public/private/static/readonly
a(hi("@keyword.type",              fg=S_STORAGE))   # enum/class/struct/interface/namespace
a(hi("@keyword.import",            fg=S_IMPORT or S_STORAGE))  # using/import
a("-- control-flow keywords (yellow)")
a(hi("@keyword.return",            fg=S_KEYWORD))
a(hi("@keyword.operator",          fg=S_KEYWORD))   # new/typeof/is/in/out/ref
a(hi("@keyword.conditional",       fg=S_KEYWORD))   # if/else/switch
a(hi("@keyword.conditional.ternary", fg=S_KEYWORD))
a(hi("@keyword.repeat",            fg=S_KEYWORD))   # for/while/foreach
a(hi("@keyword.exception",         fg=S_KEYWORD))   # try/catch/throw/finally
a(hi("@keyword.coroutine",         fg=S_KEYWORD))   # async/await
a(hi("@keyword.directive",         fg=S_KEYWORD))   # #if/#region/#pragma
a(hi("@keyword.directive.define",  fg=S_KEYWORD))
a("-- legacy treesitter names (pre-0.9)")
a(hi("@conditional",               fg=S_KEYWORD))
a(hi("@repeat",                    fg=S_KEYWORD))
a(hi("@exception",                 fg=S_KEYWORD))
a(hi("@include",                   fg=S_IMPORT or S_STORAGE))
a(hi("@namespace",                 fg=S_STORAGE))
a("")
a(hi("@operator",                  fg=S_OPER or S_FUNC))
a(hi("@punctuation.bracket",       fg=S_PUNCT))
a(hi("@punctuation.delimiter",     fg=S_PUNCT))
a(hi("@punctuation.special",       fg=S_PUNCT))
a("")
a(hi("@type",                      fg=LSP_CLASS))
a(hi("@type.builtin",              fg=LSP_CLASS,   italic=True))
a(hi("@type.definition",           fg=LSP_CLASS))
a("")
a(hi("@variable",                  fg=FG))
a(hi("@variable.builtin",          fg=FG,          italic=True))
a(hi("@variable.parameter",        fg=S_PARAM,     italic=bool(PAR_IT)))
a(hi("@variable.member",           fg=S_PROP))
a(hi("@property",                  fg=S_PROP))
a(hi("@field",                     fg=S_PROP))
a("")
a(hi("@tag",                       fg=S_TAG))
a(hi("@tag.attribute",             fg=S_PROP))
a(hi("@tag.delimiter",             fg=solid("#677e7b", BG)))
a(hi("@module",                    fg=FG))
a(hi("@label",                     fg=S_KEYWORD,   italic=True))
a(hi("@attribute",                 fg=S_PROP))
a(hi("@attribute.builtin",         fg=S_PROP,      italic=True))
a("")
a(hi("@text",                      fg=FG))
a(hi("@text.title",                fg=FG,          bold=True))
a(hi("@text.strong",               bold=True))
a(hi("@text.emphasis",             italic=True))
a(hi("@text.literal",              fg=S_STRING))
a(hi("@text.uri",                  fg=DIAG_INFO,   underline=True))

section("LSP Semantic Tokens (Track 1 — direct from theme semanticTokenColors)")
# Mapping: VSCode semantic token type → @lsp.type.*
# This is mostly a 1:1 mapping, with user overrides applied via sem()
a("-- These are read directly from the theme's semanticTokenColors section,")
a("-- then user's semanticTokenColorCustomizations overrides are applied on top.")
a(hi("@lsp.type.class",            fg=LSP_CLASS,   italic=CLS_IT  or False))
a(hi("@lsp.type.interface",        fg=LSP_IFACE,   italic=IFC_IT  or False))
a(hi("@lsp.type.struct",           fg=LSP_STRUCT,  italic=STR2_IT or False))
a(hi("@lsp.type.enum",             fg=LSP_ENUM,    italic=ENUM_IT or False))
a(hi("@lsp.type.enumMember",       fg=FG))         # no special color in Simple Focus
a(hi("@lsp.type.type",             fg=LSP_CLASS))
a(hi("@lsp.type.typeParameter",    fg=LSP_CLASS,   italic=True))
a(hi("@lsp.type.function",         fg=S_FUNC))
a(hi("@lsp.type.method",           fg=S_FUNC))
a(hi("@lsp.type.parameter",        fg=S_PARAM,     italic=True))
a(hi("@lsp.type.variable",         fg=FG))
a(hi("@lsp.type.property",         fg=FG))         # too broad in Roslyn, keep as fg
a(hi("@lsp.type.namespace",        fg=FG))         # no special color in theme
a(hi("@lsp.type.keyword",          fg=LSP_KW,      italic=KW_IT or False))
a(hi("@lsp.type.string",           fg=LSP_STR,     italic=LSTR_IT or False))
a(hi("@lsp.type.number",           fg=S_CONST))
a(hi("@lsp.type.operator",         fg=S_OPER or S_FUNC))
a(hi("@lsp.type.comment",          fg=S_COMMENT,   italic=True))
a(hi("@lsp.type.decorator",        fg=S_PROP))
a(hi("@lsp.type.event",            fg=S_PROP))
a(hi("@lsp.type.macro",            fg=S_CONST))
a(hi("@lsp.type.regexp",           fg=S_STRING))
a("")
a("-- Semantic token modifiers (type.modifier combinations)")
DEF_LIB_FG, DEF_LIB_IT = sem("class.defaultLibrary", "#cbff9b")
a(hi("@lsp.typemod.class.defaultLibrary",    fg=DEF_LIB_FG, italic=True))
a(hi("@lsp.typemod.variable.defaultLibrary", fg=DEF_LIB_FG, italic=True))
a(hi("@lsp.typemod.property.defaultLibrary", fg=DEF_LIB_FG, italic=True))
a(hi("@lsp.typemod.function.defaultLibrary", fg=S_FUNC,     italic=True))
PROP_RO_FG, _ = sem("property.readonly.defaultLibrary", S_PROP)
a(hi("@lsp.typemod.property.readonly",       fg=PROP_RO_FG))

section("Diagnostics")
a(hi("DiagnosticError",            fg=DIAG_ERROR))
a(hi("DiagnosticWarn",             fg=DIAG_WARN))
a(hi("DiagnosticInfo",             fg=DIAG_INFO))
a(hi("DiagnosticHint",             fg=S_STORAGE))
a(hi("DiagnosticUnderlineError",   undercurl=True, sp=DIAG_ERROR))
a(hi("DiagnosticUnderlineWarn",    undercurl=True, sp=DIAG_WARN))
a(hi("DiagnosticUnderlineInfo",    undercurl=True, sp=DIAG_INFO))
a(hi("DiagnosticUnderlineHint",    undercurl=True, sp=S_STORAGE))
a(hi("DiagnosticVirtualTextError", fg=DIAG_ERROR,  italic=True))
a(hi("DiagnosticVirtualTextWarn",  fg=DIAG_WARN,   italic=True))
a(hi("DiagnosticVirtualTextInfo",  fg=DIAG_INFO,   italic=True))
a(hi("DiagnosticVirtualTextHint",  fg=S_STORAGE,   italic=True))

section("Git")
a(hi("DiffAdd",          fg=S_STRING, bg=solid("#9bb95533", BG)))
a(hi("DiffChange",       fg=GIT_MOD,  bg=solid("#ffffff11", BG)))
a(hi("DiffDelete",       fg=S_PINK,   bg=solid("#ff000033", BG)))
a(hi("DiffText",         fg=FG,       bg=BG_FLOAT))
a(hi("GitSignsAdd",      fg=S_STRING))
a(hi("GitSignsChange",   fg=GIT_MOD))
a(hi("GitSignsDelete",   fg=S_PINK))

section("Telescope")
a(hi("TelescopeNormal",          fg=FG,        bg=BG_FLOAT))
a(hi("TelescopeBorder",          fg=BORDER,    bg=BG_FLOAT))
a(hi("TelescopePromptBorder",    fg=BORDER,    bg=BG_FLOAT))
a(hi("TelescopePromptTitle",     fg=FG_DIM,    bg=BG_FLOAT))
a(hi("TelescopeResultsTitle",    fg=S_COMMENT, bg=BG_FLOAT))
a(hi("TelescopePreviewTitle",    fg=S_COMMENT, bg=BG_FLOAT))
a(hi("TelescopeSelection",       bg=PMENU_SEL))
a(hi("TelescopeSelectionCaret",  fg=S_FUNC))
a(hi("TelescopeMatching",        fg=S_FUNC,    bold=True))
a(hi("TelescopePromptPrefix",    fg=S_FUNC))

section("Neo-tree")
a(hi("NeoTreeNormal",            fg=FG,        bg=BG_UI))
a(hi("NeoTreeNormalNC",          fg=FG,        bg=BG_UI))
a(hi("NeoTreeRootName",          fg=FG_DIM,    bold=True))
a(hi("NeoTreeDirectoryName",     fg=S_PROP))
a(hi("NeoTreeFileName",          fg=FG))
a(hi("NeoTreeFileNameOpened",    fg=S_FUNC))
a(hi("NeoTreeGitModified",       fg=GIT_MOD))
a(hi("NeoTreeGitAdded",          fg=GIT_NEW))
a(hi("NeoTreeGitIgnored",        fg=GIT_IGNORE))

section("Which-key")
a(hi("WhichKeyFloat",            bg=BG_FLOAT))
a(hi("WhichKey",                 fg=S_FUNC))
a(hi("WhichKeyGroup",            fg=S_PROP))
a(hi("WhichKeyDesc",             fg=FG))
a(hi("WhichKeySeparator",        fg=S_COMMENT))

section("Flash.nvim")
a(hi("FlashBackdrop", link="Comment"))
a(hi("FlashMatch",    fg=BG,    bg=S_FUNC))
a(hi("FlashCurrent",  fg=BG,    bg=S_FUNC))
a(hi("FlashLabel",    fg=BG,    bg=S_TMPL,   bold=True))

section("Indent guides (Snacks + legacy ibl)")
a(hi("SnacksIndent",                  fg=INDENT_NORMAL))
a(hi("SnacksIndentScope",             fg=INDENT_ACTIVE))
a(hi("IndentBlanklineChar",           fg=INDENT_NORMAL))
a(hi("IndentBlanklineContextChar",    fg=INDENT_ACTIVE))
a(hi("IblIndent",                     fg=INDENT_NORMAL))
a(hi("IblScope",                      fg=INDENT_ACTIVE))

with open(OUTPUT_FILE, "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"✓ Written to {OUTPUT_FILE}")
