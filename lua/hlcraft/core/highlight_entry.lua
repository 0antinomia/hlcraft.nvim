local M = {}

local color = require('hlcraft.core.color')
local fields = require('hlcraft.core.fields')
local tables = require('hlcraft.core.tables')

local function terminal_name(chain)
  return chain[#chain]:gsub(' %(circular%)$', '')
end

local function assert_name(name)
  if type(name) ~= 'string' or name == '' then
    error('highlight entry name must be a non-empty string', 3)
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
  if opts.resolve_chain ~= nil and type(opts.resolve_chain) ~= 'function' then
    error('highlight entry resolve_chain option must be a function', 3)
  end
  if opts.resolve_attrs ~= nil and type(opts.resolve_attrs) ~= 'function' then
    error('highlight entry resolve_attrs option must be a function', 3)
  end
  return opts
end

local function style_value(attrs, key)
  local value = attrs[key]
  if value ~= nil and type(value) ~= 'boolean' then
    error(('highlight style %s must be boolean or nil'):format(key), 3)
  end
  return value == true
end

local function link_chain(value)
  if type(value) ~= 'table' then
    error('highlight link chain resolver must return a table', 3)
  end
  if not tables.is_sequence(value) or #value == 0 then
    error('highlight link chain resolver must return a non-empty sequence', 3)
  end
  for index, name in ipairs(value) do
    if type(name) ~= 'string' or name == '' then
      error(('highlight link chain entry %d must be a non-empty string'):format(index), 3)
    end
  end
  return value
end

local function default_link_chain(name, target)
  if target == name then
    return { name, target .. ' (circular)' }
  end
  return { name, target }
end

local function resolved_attrs(value)
  if value ~= nil and type(value) ~= 'table' then
    error('highlight attrs resolver must return a table or nil', 3)
  end
  return value
end

function M.from_attrs(name, attrs, opts)
  name = assert_name(name)
  attrs = assert_attrs(attrs)
  opts = optional_opts(opts)
  if attrs.link ~= nil and (type(attrs.link) ~= 'string' or attrs.link == '') then
    error('highlight link must be a non-empty string or nil', 2)
  end
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
    entry[key] = style_value(attrs, key)
  end

  if attrs.link then
    if opts.resolve_chain then
      entry.link_chain = link_chain(opts.resolve_chain(name))
    else
      entry.link_chain = default_link_chain(name, attrs.link)
    end

    local resolved
    if opts.resolve_attrs then
      resolved = resolved_attrs(opts.resolve_attrs(terminal_name(entry.link_chain)))
    end
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
