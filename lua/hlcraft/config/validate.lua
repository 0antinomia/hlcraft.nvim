local defaults = require('hlcraft.config.defaults')
local numbers = require('hlcraft.core.number')

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

local function validate_known_keys(errors, user_config)
  for key, _ in pairs(user_config) do
    if not defaults.known_keys[key] then
      add(errors, ('unknown config key: %q'):format(tostring(key)))
    end
  end
end

local function validate_from_none(errors, value)
  local value_type = type(value)
  if value_type ~= 'boolean' and value_type ~= 'table' then
    add(errors, 'from_none: must be boolean or table, got ' .. value_type)
    return
  end

  if value_type ~= 'table' then
    return
  end

  validate_boolean(errors, 'from_none.enabled', value.enabled)
  if value.scope == nil then
    return
  end
  if type(value.scope) ~= 'string' then
    add(errors, 'from_none.scope: must be a string, got ' .. type(value.scope))
  elseif value.scope ~= 'core' and value.scope ~= 'extended' then
    add(errors, ('from_none.scope: must be "core" or "extended", got %q'):format(value.scope))
  end
end

local function validate_reapply_event(errors, index, entry)
  local entry_type = type(entry)
  if entry_type == 'string' then
    if entry == '' then
      add(errors, ('reapply_events.events[%d]: must be a non-empty string'):format(index))
    end
    return
  end

  if entry_type ~= 'table' then
    add(errors, ('reapply_events.events[%d]: must be a string or table, got %s'):format(index, entry_type))
    return
  end

  if type(entry.event) ~= 'string' or entry.event == '' then
    add(errors, ('reapply_events.events[%d].event: must be a non-empty string'):format(index))
  end
  if entry.pattern ~= nil and type(entry.pattern) ~= 'string' then
    add(errors, ('reapply_events.events[%d].pattern: must be a string'):format(index))
  end
  validate_boolean(errors, ('reapply_events.events[%d].once'):format(index), entry.once)
end

local function validate_reapply_events(errors, value)
  local value_type = type(value)
  if value_type ~= 'boolean' and value_type ~= 'table' then
    add(errors, 'reapply_events: must be boolean or table, got ' .. value_type)
    return
  end

  if value_type ~= 'table' then
    return
  end

  validate_boolean(errors, 'reapply_events.enabled', value.enabled)
  if value.events ~= nil and type(value.events) ~= 'table' then
    add(errors, 'reapply_events.events: must be a table, got ' .. type(value.events))
    return
  end

  if type(value.events) ~= 'table' then
    return
  end
  for index, entry in ipairs(value.events) do
    validate_reapply_event(errors, index, entry)
  end
end

local function validate_dynamic(errors, value)
  if type(value) ~= 'table' then
    add(errors, 'dynamic: must be a table, got ' .. type(value))
    return
  end

  local interval = defaults.dynamic_interval_ms
  validate_boolean(errors, 'dynamic.enabled', value.enabled)
  validate_number(errors, 'dynamic.interval_ms', value.interval_ms, {
    min = interval.min,
    max = interval.max,
    range_message = ('dynamic.interval_ms: must be between %d and %d'):format(interval.min, interval.max),
  })
end

local function validate_preview_key(errors, value)
  local key_type = type(value)
  if key_type ~= 'string' and key_type ~= 'boolean' then
    add(errors, 'preview_key: must be a string or boolean, got ' .. key_type)
  elseif key_type == 'string' and vim.trim(value) == '' then
    add(errors, 'preview_key: must be a non-empty string when provided')
  elseif key_type == 'boolean' and value ~= false then
    add(errors, 'preview_key: boolean value must be false when used')
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

  validate_number(errors, 'threshold', user_config.threshold, {
    min = 0,
    max = 1000,
    range_message = 'threshold: must be between 0 and 1000',
  })
  validate_boolean(errors, 'include_sp_in_color_search', user_config.include_sp_in_color_search)

  if user_config.persist_dir ~= nil then
    validate_non_empty_string(errors, 'persist_dir', user_config.persist_dir)
  end
  if user_config.from_none ~= nil then
    validate_from_none(errors, user_config.from_none)
  end
  if user_config.reapply_events ~= nil then
    validate_reapply_events(errors, user_config.reapply_events)
  end
  if user_config.dynamic ~= nil then
    validate_dynamic(errors, user_config.dynamic)
  end
  validate_number(errors, 'debounce_ms', user_config.debounce_ms, {
    min = 0,
    range_message = 'debounce_ms: must be >= 0',
  })
  if user_config.preview_key ~= nil then
    validate_preview_key(errors, user_config.preview_key)
  end

  if #errors > 0 then
    return false, 'hlcraft config errors:\n  ' .. table.concat(errors, '\n  ')
  end
  return true, nil
end

return M
