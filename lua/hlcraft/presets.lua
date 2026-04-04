--- @type table
local M = {}

local core_transparent_groups = {
  'Normal',
  'NormalNC',
  'NormalFloat',
  'FloatBorder',
  'SignColumn',
  'EndOfBuffer',
  'StatusLine',
  'StatusLineNC',
  'TabLineFill',
}

local extended_transparent_groups = {
  'FloatTitle',
  'FloatFooter',
  'FoldColumn',
  'CursorLineFold',
  'CursorLineSign',
  'WinBar',
  'WinBarNC',
  'Pmenu',
  'PmenuSel',
  'PmenuSbar',
  'PmenuThumb',
}

--- Build the broad transparent baseline used when from_none is enabled.
--- @param scope '"core"'|'"extended"'|nil
--- @return table
function M.transparent(scope)
  local overrides = {}
  local groups = vim.deepcopy(core_transparent_groups)

  if scope == 'extended' or scope == nil then
    vim.list_extend(groups, extended_transparent_groups)
  end

  for _, group in ipairs(groups) do
    overrides[group] = { bg = 'NONE' }
  end

  return overrides
end

return M
