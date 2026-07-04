local M = {}

local color = require('hlcraft.core.color')

local style_keys = {
  'bold',
  'italic',
  'underline',
  'undercurl',
  'strikethrough',
  'underdouble',
  'underdotted',
  'underdashed',
}

local function terminal_name(chain)
  local terminal = chain and chain[#chain] or nil
  return terminal and terminal:gsub(' %(circular%)$', '') or nil
end

function M.from_attrs(name, attrs, opts)
  opts = opts or {}
  local entry = {
    name = name,
    fg = color.int_to_hex(attrs.fg),
    bg = color.int_to_hex(attrs.bg),
    sp = color.int_to_hex(attrs.sp),
    blend = attrs.blend,
    link_chain = {},
    resolved_fg = 'NONE',
    resolved_bg = 'NONE',
  }

  for _, key in ipairs(style_keys) do
    entry[key] = attrs[key] or false
  end

  if attrs.link then
    entry.link_chain = opts.resolve_chain and opts.resolve_chain(name) or { name }
    local resolved = opts.resolve_attrs and opts.resolve_attrs(terminal_name(entry.link_chain)) or nil
    if resolved then
      entry.resolved_fg = color.int_to_hex(resolved.fg)
      entry.resolved_bg = color.int_to_hex(resolved.bg)
    end
  else
    entry.resolved_fg = entry.fg
    entry.resolved_bg = entry.bg
  end

  return entry
end

return M
