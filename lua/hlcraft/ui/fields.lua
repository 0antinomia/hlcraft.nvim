local M = {}

M.search_prefixes = {
  name = ' Name:',
  color = ' Color:',
}

M.search_placeholders = {
  name = 'e.g. Normal (case-insensitive)',
  color = 'e.g. #7aa2f7, 7aa2f7, or NONE',
}

M.detail_order = {
  'group',
  'fg',
  'bg',
  'sp',
  'bold',
  'italic',
  'underline',
  'undercurl',
  'strikethrough',
  'blend',
}

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
  blend = 'Blend',
}

M.detail_kinds = {
  group = 'group',
  fg = 'color',
  bg = 'color',
  sp = 'color',
  bold = 'boolean',
  italic = 'boolean',
  underline = 'boolean',
  undercurl = 'boolean',
  strikethrough = 'boolean',
  blend = 'blend',
}

M.color_small_step = 5
M.color_large_step = 16
M.blend_small_step = 1
M.blend_large_step = 5

return M
