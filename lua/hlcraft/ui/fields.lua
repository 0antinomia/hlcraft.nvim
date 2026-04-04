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
  group = 'Group:',
  fg = 'FG:',
  bg = 'BG:',
  sp = 'SP:',
  bold = 'Bold:',
  italic = 'Italic:',
  underline = 'Underline:',
  undercurl = 'Undercurl:',
  strikethrough = 'Strikethrough:',
  blend = 'Blend:',
}

return M
