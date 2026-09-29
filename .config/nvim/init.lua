vim.o.number = true
vim.o.termguicolors = true
vim.o.clipboard = "unnamedplus"

local ok, c = pcall(require, "matugen_colors")
if ok then
  vim.api.nvim_set_hl(0, "Normal", { fg = c.foreground, bg = c.background })
  vim.api.nvim_set_hl(0, "NormalFloat", { fg = c.foreground, bg = c.background })
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = c.primary, bold = true })

  vim.api.nvim_set_hl(0, "Comment", { fg = c.secondary, italic = true })
  vim.api.nvim_set_hl(0, "String", { fg = c.primary })
  vim.api.nvim_set_hl(0, "DiagnosticError", { fg = c.error })
end
