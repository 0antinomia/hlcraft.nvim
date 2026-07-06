local numbers = require('hlcraft.core.number')
local spec = require('hlcraft.config.spec')
local tables = require('hlcraft.core.tables')

local M = {}

local function add(errors, message)
  errors[#errors + 1] = message
end

local function validate_boolean(errors, path, value)
  if value ~= nil and type(value) ~= 'boolean' then
    add(errors, ('%s: must be boolean, got %s'):format(path, type(value)))
  end
end

local function validate_number(errors, path, value, opts)
  if value == nil then
    return
  end

  if type(value) ~= 'number' then
    add(errors, ('%s: must be a number, got %s'):format(path, type(value)))
    return
  end
  if not numbers.is_finite(value) then
    add(errors, ('%s: must be finite'):format(path))
    return
  end
  if opts.min ~= nil and value < opts.min then
    add(errors, opts.range_message or ('%s: must be >= %s'):format(path, opts.min))
  elseif opts.max ~= nil and value > opts.max then
    add(errors, opts.range_message or ('%s: must be <= %s'):format(path, opts.max))
  end
end

local function validate_non_empty_string(errors, path, value)
  if type(value) ~= 'string' then
    add(errors, ('%s: must be a string, got %s'):format(path, type(value)))
  elseif vim.trim(value) == '' then
    add(errors, ('%s: must be a non-empty string'):format(path))
  end
end

local function validate_event_name(errors, path, value)
  if type(value) ~= 'string' or vim.trim(value) == '' then
    add(errors, ('%s: must be a non-empty string'):format(path))
  end
end

local function validate_known_keys(errors, user_config)
  for key, _ in pairs(user_config) do
    if not spec.known_keys[key] then
      add(errors, ('unknown config key: %q'):format(tostring(key)))
    end
  end
end

local function validate_table_keys(errors, path, value, known_keys)
  for key, _ in pairs(value) do
    if not known_keys[key] then
      add(errors, ('unknown config key: %q'):format(('%s.%s'):format(path, tostring(key))))
    end
  end
end

local function validate_transparent(errors, value)
  local value_type = type(value)
  if value_type ~= 'table' then
    add(errors, 'transparent: must be a table, got ' .. value_type)
    return
  end

  validate_table_keys(errors, 'transparent', value, spec.field('transparent').keys)
  validate_boolean(errors, 'transparent.enabled', value.enabled)
  if value.scope == nil then
    return
  end
  if type(value.scope) ~= 'string' then
    add(errors, 'transparent.scope: must be a string, got ' .. type(value.scope))
  elseif value.scope ~= 'core' and value.scope ~= 'extended' then
    add(errors, ('transparent.scope: must be "core" or "extended", got %q'):format(value.scope))
  end
end

local function validate_reapply_event(errors, path, index, entry)
  local entry_type = type(entry)
  if entry_type == 'string' then
    validate_event_name(errors, ('%s.events[%d]'):format(path, index), entry)
    return
  end

  if entry_type ~= 'table' then
    add(errors, ('%s.events[%d]: must be a string or table, got %s'):format(path, index, entry_type))
    return
  end

  validate_table_keys(
    errors,
    ('%s.events[%d]'):format(path, index),
    entry,
    spec.field('persistence').reapply_event_keys
  )
  validate_event_name(errors, ('%s.events[%d].event'):format(path, index), entry.event)
  if entry.pattern ~= nil then
    validate_non_empty_string(errors, ('%s.events[%d].pattern'):format(path, index), entry.pattern)
  end
  validate_boolean(errors, ('%s.events[%d].once'):format(path, index), entry.once)
end

local function validate_reapply_events(errors, value)
  local path = 'persistence.reapply_events'
  local value_type = type(value)
  if value_type ~= 'table' then
    add(errors, path .. ': must be a table, got ' .. value_type)
    return
  end

  validate_table_keys(errors, path, value, spec.field('persistence').reapply_events_keys)
  validate_boolean(errors, path .. '.enabled', value.enabled)
  if value.events ~= nil and type(value.events) ~= 'table' then
    add(errors, path .. '.events: must be a table, got ' .. type(value.events))
    return
  end

  if type(value.events) ~= 'table' then
    return
  end
  if not tables.is_sequence(value.events) then
    add(errors, path .. '.events: must be a sequence')
    return
  end
  for index, entry in ipairs(value.events) do
    validate_reapply_event(errors, path, index, entry)
  end
end

local function validate_search(errors, value)
  if type(value) ~= 'table' then
    add(errors, 'search: must be a table, got ' .. type(value))
    return
  end

  local search = spec.field('search')
  validate_table_keys(errors, 'search', value, search.keys)
  validate_number(errors, 'search.threshold', value.threshold, {
    min = search.fields.threshold.range.min,
    max = search.fields.threshold.range.max,
    range_message = 'search.threshold: must be between 0 and 1000',
  })
  validate_boolean(errors, 'search.include_sp', value.include_sp)
  validate_number(errors, 'search.debounce_ms', value.debounce_ms, {
    min = search.fields.debounce_ms.range.min,
    range_message = 'search.debounce_ms: must be >= 0',
  })
end

local function validate_persistence(errors, value)
  if type(value) ~= 'table' then
    add(errors, 'persistence: must be a table, got ' .. type(value))
    return
  end

  validate_table_keys(errors, 'persistence', value, spec.field('persistence').keys)
  if value.dir ~= nil then
    validate_non_empty_string(errors, 'persistence.dir', value.dir)
  end
  if value.reapply_events ~= nil then
    validate_reapply_events(errors, value.reapply_events)
  end
end

local function validate_dynamic(errors, value)
  if type(value) ~= 'table' then
    add(errors, 'dynamic: must be a table, got ' .. type(value))
    return
  end

  validate_table_keys(errors, 'dynamic', value, spec.field('dynamic').keys)
  local interval = spec.field('dynamic').fields.interval_ms.range
  validate_number(errors, 'dynamic.interval_ms', value.interval_ms, {
    min = interval.min,
    max = interval.max,
    range_message = ('dynamic.interval_ms: must be between %d and %d'):format(interval.min, interval.max),
  })
end

local function validate_preview_keymap_opts(errors, value)
  if value == nil then
    return
  end
  if type(value) ~= 'table' then
    add(errors, 'keymaps.preview.opts: must be a table, got ' .. type(value))
    return
  end

  validate_table_keys(errors, 'keymaps.preview.opts', value, spec.field('keymaps').preview_opts_keys)
  if value.desc ~= nil then
    validate_non_empty_string(errors, 'keymaps.preview.opts.desc', value.desc)
  end
  validate_boolean(errors, 'keymaps.preview.opts.silent', value.silent)
  validate_boolean(errors, 'keymaps.preview.opts.nowait', value.nowait)
end

local function validate_preview_keymap(errors, value)
  local value_type = type(value)
  if value == false then
    return
  end
  if value_type ~= 'table' then
    add(errors, 'keymaps.preview: must be false or table, got ' .. value_type)
    return
  end

  validate_table_keys(errors, 'keymaps.preview', value, spec.field('keymaps').preview_keys)
  if type(value.lhs) ~= 'string' or vim.trim(value.lhs) == '' then
    add(errors, 'keymaps.preview.lhs: must be a non-empty string')
  end
  if value.mode ~= nil and (type(value.mode) ~= 'string' or vim.trim(value.mode) ~= 'n') then
    add(errors, 'keymaps.preview.mode: must be "n"')
  end
  validate_preview_keymap_opts(errors, value.opts)
end

local function validate_keymaps(errors, value)
  if type(value) ~= 'table' then
    add(errors, 'keymaps: must be a table, got ' .. type(value))
    return
  end

  validate_table_keys(errors, 'keymaps', value, spec.field('keymaps').keys)
  if value.preview ~= nil then
    validate_preview_keymap(errors, value.preview)
  end
end

function M.config(user_config)
  if user_config == nil or (type(user_config) == 'table' and next(user_config) == nil) then
    return true, nil
  end

  if type(user_config) ~= 'table' then
    return false, 'hlcraft config must be a table, got ' .. type(user_config)
  end

  local errors = {}
  validate_known_keys(errors, user_config)

  if user_config.transparent ~= nil then
    validate_transparent(errors, user_config.transparent)
  end
  if user_config.search ~= nil then
    validate_search(errors, user_config.search)
  end
  if user_config.persistence ~= nil then
    validate_persistence(errors, user_config.persistence)
  end
  if user_config.dynamic ~= nil then
    validate_dynamic(errors, user_config.dynamic)
  end
  if user_config.keymaps ~= nil then
    validate_keymaps(errors, user_config.keymaps)
  end

  if #errors > 0 then
    return false, 'hlcraft config errors:\n  ' .. table.concat(errors, '\n  ')
  end
  return true, nil
end

return M
