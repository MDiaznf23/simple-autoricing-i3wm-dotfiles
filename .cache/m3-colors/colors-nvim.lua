-- Auto-generated Material 3 theme for NvChad
-- Generated from wallpaper: /home/diaz/Pictures/Wallpapers/purpled-night.jpg
-- Mode: dark
-- Source color: #6019ad

---@type Base46Table
local M = {}

-- UI Colors from Material 3
M.base_30 = {
  white = "#e8dfec",
  black = "#16121a",
  darker_black = "#16121a",
  black2 = "#1e1a22",
  one_bg = "#221e27",
  one_bg2 = "#2d2831",
  one_bg3 = "#38333c",
  grey = "#4b4453",
  grey_fg = "#cdc3d5",
  grey_fg2 = "#978d9f",
  light_grey = "#4b4453",
  
  -- Accent colors
  red = "#ffb4ab",
  baby_pink = "#93000a",
  pink = "#ffb4a4",
  line = "#978d9f",
  green = "#ffb4a4",
  vibrant_green = "#8b1901",
  nord_blue = "#d8bafc",
  blue = "#d8b9ff",
  seablue = "#6019ad",
  yellow = "#ffb4a4",
  sun = "#ffdad3",
  purple = "#d8bafc",
  dark_purple = "#563d76",
  teal = "#6019ad",
  orange = "#ffb4a4",
  cyan = "#d8b9ff",
  
  -- UI elements
  statusline_bg = "#221e27",
  lightbg = "#2d2831",
  pmenu_bg = "#d8b9ff",
  folder_bg = "#d8b9ff"
}

-- Syntax highlighting colors (base16 format)
M.base_16 = {
  base00 = "#16121a",                    -- Default Background
  base01 = "#221e27",           -- Lighter Background
  base02 = "#2d2831",       -- Selection Background
  base03 = "#978d9f",                    -- Comments, Invisibles
  base04 = "#cdc3d5",           -- Dark Foreground
  base05 = "#e8dfec",                  -- Default Foreground
  base06 = "#e8dfec",                  -- Light Foreground
  base07 = "#3c3741",              -- Light Background
  base08 = "#ffb4ab",                      -- Variables, Tags
  base09 = "#ffb4a4",                   -- Integers, Constants
  base0A = "#d8b9ff",                    -- Classes, Search
  base0B = "#ffb4a4",                   -- Strings
  base0C = "#6019ad",           -- Regex, Escapes
  base0D = "#d8b9ff",                    -- Functions, Methods
  base0E = "#d8bafc",                  -- Keywords, Storage
  base0F = "#93000a"              -- Deprecated
}

-- Optional: Custom highlights
M.polish_hl = {
  defaults = {
    Comment = {
      fg = "#978d9f",
      italic = true,
    },
    LineNr = {
      fg = "#4b4453",
    },
    CursorLine = {
      bg = "#1e1a22",
    },
    CursorLineNr = {
      fg = "#d8b9ff",
      bold = true,
    },
    Visual = {
      bg = "#6019ad",
    },
    Pmenu = {
      bg = "#221e27",
    },
    PmenuSel = {
      bg = "#6019ad",
      fg = "#cba3ff",
    },
    StatusLine = {
      bg = "#221e27",
      fg = "#e8dfec",
    },
    TabLine = {
      bg = "#1e1a22",
      fg = "#cdc3d5",
    },
    TabLineSel = {
      bg = "#6019ad",
      fg = "#cba3ff",
    },
    NvimTreeNormal = {
      bg = "#1e1a22",
    },
    NvimTreeFolderIcon = {
      fg = "#d8b9ff",
    },
  },
  
  treesitter = {
    ["@keyword"] = { fg = "#d8bafc" },
    ["@function"] = { fg = "#d8b9ff" },
    ["@function.builtin"] = { fg = "#6019ad" },
    ["@variable"] = { fg = "#e8dfec" },
    ["@variable.builtin"] = { fg = "#ffb4a4" },
    ["@string"] = { fg = "#ffb4a4" },
    ["@number"] = { fg = "#ffb4a4" },
    ["@boolean"] = { fg = "#ffb4a4" },
    ["@constant"] = { fg = "#ffb4a4" },
    ["@type"] = { fg = "#d8bafc" },
    ["@parameter"] = { fg = "#e8dfec" },
    ["@property"] = { fg = "#e8dfec" },
    ["@operator"] = { fg = "#cdc3d5" },
    ["@punctuation"] = { fg = "#4b4453" },
    ["@comment"] = { 
      fg = "#978d9f", 
      italic = true 
    },
    ["@tag"] = { fg = "#ffb4ab" },
    ["@tag.attribute"] = { fg = "#ffb4a4" },
    ["@tag.delimiter"] = { fg = "#4b4453" },
  },

  lsp = {
    DiagnosticError = { fg = "#ffb4ab" },
    DiagnosticWarn = { fg = "#ffb4a4" },
    DiagnosticInfo = { fg = "#d8b9ff" },
    DiagnosticHint = { fg = "#d8bafc" },
    DiagnosticUnderlineError = { 
      undercurl = true, 
      sp = "#ffb4ab" 
    },
    DiagnosticUnderlineWarn = { 
      undercurl = true, 
      sp = "#ffb4a4" 
    },
    DiagnosticUnderlineInfo = { 
      undercurl = true, 
      sp = "#d8b9ff" 
    },
    DiagnosticUnderlineHint = { 
      undercurl = true, 
      sp = "#d8bafc" 
    },
  },

  telescope = {
    TelescopePromptBorder = { fg = "#d8b9ff" },
    TelescopeResultsBorder = { fg = "#978d9f" },
    TelescopePreviewBorder = { fg = "#978d9f" },
    TelescopeSelection = { 
      bg = "#6019ad", 
      fg = "#cba3ff" 
    },
    TelescopeMatching = { fg = "#d8b9ff", bold = true },
  },

  cmp = {
    CmpItemAbbrMatch = { fg = "#d8b9ff", bold = true },
    CmpItemAbbrMatchFuzzy = { fg = "#d8b9ff" },
    CmpItemKindVariable = { fg = "#e8dfec" },
    CmpItemKindFunction = { fg = "#d8b9ff" },
    CmpItemKindKeyword = { fg = "#d8bafc" },
    CmpItemKindConstant = { fg = "#ffb4a4" },
    CmpItemKindModule = { fg = "#d8bafc" },
  },

  git = {
    DiffAdd = { fg = "#ffb4a4" },
    DiffChange = { fg = "#d8b9ff" },
    DiffDelete = { fg = "#ffb4ab" },
    GitSignsAdd = { fg = "#ffb4a4" },
    GitSignsChange = { fg = "#d8b9ff" },
    GitSignsDelete = { fg = "#ffb4ab" },
  },
}

-- Set theme type based on wallpaper analysis
M.type = "dark"

-- Override theme
M = require("base46").override_theme(M, "material3")

return M
