local M = {}

M.groups = {
  text = '@hlcraft.ui.text',
  muted = '@hlcraft.ui.muted',
  key = '@hlcraft.ui.key',
  label = '@hlcraft.ui.label',
  rule = '@hlcraft.ui.rule',
  header = '@hlcraft.ui.header',
  title = '@hlcraft.ui.title',
  dirty = '@hlcraft.ui.dirty',
}

local palettes = {
  dark = {
    text = '#c9d1d9',
    muted = '#8a94a6',
    accent = '#5fb3a5',
    rule = '#6c9bcf',
    header = '#b9c6d3',
    dirty = '#d49a57',
  },
  light = {
    text = '#25272b',
    muted = '#6a7280',
    accent = '#2f6f66',
    rule = '#496f9d',
    header = '#39414d',
    dirty = '#9a5d18',
  },
}

local function mode(background)
  return background == 'light' and 'light' or 'dark'
end

function M.palette(background)
  return vim.deepcopy(palettes[mode(background or vim.o.background)])
end

function M.apply(ns)
  local palette = M.palette()
  local groups = M.groups

  vim.api.nvim_set_hl(ns, 'Normal', { fg = palette.text, bg = 'NONE' })
  vim.api.nvim_set_hl(ns, 'NormalFloat', { fg = palette.text, bg = 'NONE' })
  vim.api.nvim_set_hl(ns, 'FloatBorder', { fg = palette.rule, bg = 'NONE' })

  vim.api.nvim_set_hl(ns, groups.text, { fg = palette.text })
  vim.api.nvim_set_hl(ns, groups.muted, { fg = palette.muted, italic = true })
  vim.api.nvim_set_hl(ns, groups.key, { fg = palette.accent, bold = true })
  vim.api.nvim_set_hl(ns, groups.label, { fg = palette.accent, bold = true })
  vim.api.nvim_set_hl(ns, groups.rule, { fg = palette.rule, bold = true })
  vim.api.nvim_set_hl(ns, groups.header, { fg = palette.header, bold = true })
  vim.api.nvim_set_hl(ns, groups.title, { fg = palette.header, bold = true })
  vim.api.nvim_set_hl(ns, groups.dirty, { fg = palette.dirty, bold = true })
end

return M
