local M = {}

local color = require('hlcraft.core.color')
local fields = require('hlcraft.core.fields')

local function terminal_name(chain)
  local terminal = chain and chain[#chain] or nil
  return terminal and terminal:gsub(' %(circular%)$', '') or nil
end

local function assert_name(name)
  if type(name) ~= 'string' then
    error('highlight entry name must be a string', 3)
  end
  return name
end

local function assert_attrs(attrs)
  if type(attrs) ~= 'table' then
    error('highlight attrs must be a table', 3)
  end
  return attrs
end

local function optional_opts(opts)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error('highlight entry options must be a table', 3)
  end
  return opts
end

function M.from_attrs(name, attrs, opts)
  name = assert_name(name)
  attrs = assert_attrs(attrs)
  opts = optional_opts(opts)
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

  for _, key in ipairs(fields.style_keys) do
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
