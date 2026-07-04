local core_fields = require('hlcraft.core.fields')

local M = {}

local function with_group(keys)
  local result = { 'group' }
  for _, key in ipairs(keys) do
    result[#result + 1] = key
  end
  return result
end

M.search_prefixes = {
  name = ' Name:',
  color = ' Color:',
}

M.search_placeholders = {
  name = 'e.g. Normal (case-insensitive)',
  color = 'e.g. #7aa2f7, 7aa2f7, or NONE',
}

M.detail_order = with_group(core_fields.override_keys)

M.detail_labels = {
  group = 'Group',
  fg = 'FG',
  bg = 'BG',
  sp = 'SP',
  bold = 'Bold',
  italic = 'Italic',
  underline = 'Underline',
  undercurl = 'Undercurl',
  strikethrough = 'Strikethrough',
  underdouble = 'Under Double',
  underdotted = 'Under Dotted',
  underdashed = 'Under Dashed',
  blend = 'Blend',
}

M.detail_kinds = { group = 'group' }
for _, key in ipairs(core_fields.color_keys) do
  M.detail_kinds[key] = 'color'
end
for _, key in ipairs(core_fields.style_keys) do
  M.detail_kinds[key] = 'boolean'
end
M.detail_kinds.blend = 'blend'

M.color_step = 5
M.dynamic_duration_step = 250
M.dynamic_phase_step = 0.05
M.dynamic_timeline_swatch = '████'
M.dynamic_preview_swatch = '████████████'
M.blend_small_step = 1
M.blend_large_step = 5

return M
