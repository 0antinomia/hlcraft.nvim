local M = {}

local function is_finite_number(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local default_from_none = {
  enabled = false,
  scope = 'extended',
}

local default_reapply_events = {
  enabled = true,
  events = {
    'ColorScheme',
  },
}

local default_dynamic = {
  enabled = false,
  interval_ms = 80,
}

M.defaults = {
  from_none = default_from_none,
  threshold = 100,
  include_sp_in_color_search = false,
  persist_dir = vim.fn.stdpath('config') .. '/hlcraft',
  reapply_events = default_reapply_events,
  dynamic = default_dynamic,
  debounce_ms = 100,
  preview_key = 'z',
}

local known_keys = {}
for key, _ in pairs(M.defaults) do
  known_keys[key] = true
end

local function normalize_from_none(value)
  if type(value) == 'boolean' then
    return {
      enabled = value,
      scope = default_from_none.scope,
    }
  end

  if type(value) ~= 'table' then
    return vim.deepcopy(default_from_none)
  end

  return {
    enabled = value.enabled == true,
    scope = value.scope == 'core' and 'core' or default_from_none.scope,
  }
end

local function normalize_reapply_events(value)
  if type(value) == 'boolean' then
    return {
      enabled = value,
      events = vim.deepcopy(default_reapply_events.events),
    }
  end

  if type(value) ~= 'table' then
    return vim.deepcopy(default_reapply_events)
  end

  local events = {}
  if type(value.events) == 'table' then
    events = vim.deepcopy(value.events)
  else
    events = vim.deepcopy(default_reapply_events.events)
  end

  return {
    enabled = value.enabled ~= false,
    events = events,
  }
end

local function normalize_dynamic(value)
  if type(value) ~= 'table' then
    return vim.deepcopy(default_dynamic)
  end

  local interval_ms = tonumber(value.interval_ms)
  if interval_ms == nil then
    interval_ms = default_dynamic.interval_ms
  else
    interval_ms = math.floor(interval_ms)
  end

  return {
    enabled = value.enabled == true,
    interval_ms = interval_ms,
  }
end

local function validate_reapply_events(errors, value)
  local reapply_type = type(value)
  if reapply_type ~= 'boolean' and reapply_type ~= 'table' then
    errors[#errors + 1] = 'reapply_events: must be boolean or table, got ' .. reapply_type
    return
  end

  if reapply_type ~= 'table' then
    return
  end

  if value.enabled ~= nil and type(value.enabled) ~= 'boolean' then
    errors[#errors + 1] = 'reapply_events.enabled: must be boolean, got ' .. type(value.enabled)
  end

  if value.events ~= nil and type(value.events) ~= 'table' then
    errors[#errors + 1] = 'reapply_events.events: must be a table, got ' .. type(value.events)
    return
  end

  if type(value.events) ~= 'table' then
    return
  end

  for i, entry in ipairs(value.events) do
    local entry_type = type(entry)
    if entry_type == 'string' then
      if entry == '' then
        errors[#errors + 1] = ('reapply_events.events[%d]: must be a non-empty string'):format(i)
      end
    elseif entry_type == 'table' then
      if type(entry.event) ~= 'string' or entry.event == '' then
        errors[#errors + 1] = ('reapply_events.events[%d].event: must be a non-empty string'):format(i)
      end
      if entry.pattern ~= nil and type(entry.pattern) ~= 'string' then
        errors[#errors + 1] = ('reapply_events.events[%d].pattern: must be a string'):format(i)
      end
      if entry.once ~= nil and type(entry.once) ~= 'boolean' then
        errors[#errors + 1] = ('reapply_events.events[%d].once: must be a boolean'):format(i)
      end
    else
      errors[#errors + 1] = ('reapply_events.events[%d]: must be a string or table, got %s'):format(i, entry_type)
    end
  end
end

function M.validate(user_config)
  if user_config == nil or (type(user_config) == 'table' and next(user_config) == nil) then
    return true, nil
  end

  if type(user_config) ~= 'table' then
    return false, 'hlcraft config must be a table, got ' .. type(user_config)
  end

  local errors = {}

  for key, _ in pairs(user_config) do
    if not known_keys[key] then
      errors[#errors + 1] = ('unknown config key: %q'):format(tostring(key))
    end
  end

  if user_config.threshold ~= nil then
    if type(user_config.threshold) ~= 'number' then
      errors[#errors + 1] = 'threshold: must be a number, got ' .. type(user_config.threshold)
    elseif not is_finite_number(user_config.threshold) then
      errors[#errors + 1] = 'threshold: must be finite'
    elseif user_config.threshold < 0 or user_config.threshold > 1000 then
      errors[#errors + 1] = 'threshold: must be between 0 and 1000'
    end
  end

  if user_config.include_sp_in_color_search ~= nil then
    if type(user_config.include_sp_in_color_search) ~= 'boolean' then
      errors[#errors + 1] = 'include_sp_in_color_search: must be boolean, got '
        .. type(user_config.include_sp_in_color_search)
    end
  end

  if user_config.persist_dir ~= nil then
    if type(user_config.persist_dir) ~= 'string' then
      errors[#errors + 1] = 'persist_dir: must be a string, got ' .. type(user_config.persist_dir)
    elseif vim.trim(user_config.persist_dir) == '' then
      errors[#errors + 1] = 'persist_dir: must be a non-empty string'
    end
  end

  if user_config.from_none ~= nil then
    local from_none = user_config.from_none
    local from_none_type = type(from_none)
    if from_none_type ~= 'boolean' and from_none_type ~= 'table' then
      errors[#errors + 1] = 'from_none: must be boolean or table, got ' .. from_none_type
    elseif from_none_type == 'table' then
      if from_none.enabled ~= nil and type(from_none.enabled) ~= 'boolean' then
        errors[#errors + 1] = 'from_none.enabled: must be boolean, got ' .. type(from_none.enabled)
      end
      if from_none.scope ~= nil then
        if type(from_none.scope) ~= 'string' then
          errors[#errors + 1] = 'from_none.scope: must be a string, got ' .. type(from_none.scope)
        elseif from_none.scope ~= 'core' and from_none.scope ~= 'extended' then
          errors[#errors + 1] = ('from_none.scope: must be "core" or "extended", got %q'):format(from_none.scope)
        end
      end
    end
  end

  if user_config.reapply_events ~= nil then
    validate_reapply_events(errors, user_config.reapply_events)
  end

  if user_config.dynamic ~= nil then
    local dynamic = user_config.dynamic
    if type(dynamic) ~= 'table' then
      errors[#errors + 1] = 'dynamic: must be a table, got ' .. type(dynamic)
    else
      if dynamic.enabled ~= nil and type(dynamic.enabled) ~= 'boolean' then
        errors[#errors + 1] = 'dynamic.enabled: must be boolean, got ' .. type(dynamic.enabled)
      end
      if dynamic.interval_ms ~= nil then
        if type(dynamic.interval_ms) ~= 'number' then
          errors[#errors + 1] = 'dynamic.interval_ms: must be a number, got ' .. type(dynamic.interval_ms)
        elseif not is_finite_number(dynamic.interval_ms) then
          errors[#errors + 1] = 'dynamic.interval_ms: must be finite'
        elseif dynamic.interval_ms < 16 or dynamic.interval_ms > 1000 then
          errors[#errors + 1] = 'dynamic.interval_ms: must be between 16 and 1000'
        end
      end
    end
  end

  if user_config.debounce_ms ~= nil then
    if type(user_config.debounce_ms) ~= 'number' then
      errors[#errors + 1] = 'debounce_ms: must be a number, got ' .. type(user_config.debounce_ms)
    elseif not is_finite_number(user_config.debounce_ms) then
      errors[#errors + 1] = 'debounce_ms: must be finite'
    elseif user_config.debounce_ms < 0 then
      errors[#errors + 1] = 'debounce_ms: must be >= 0'
    end
  end

  if user_config.preview_key ~= nil then
    local key_type = type(user_config.preview_key)
    if key_type ~= 'string' and key_type ~= 'boolean' then
      errors[#errors + 1] = 'preview_key: must be a string or boolean, got ' .. key_type
    elseif key_type == 'string' and vim.trim(user_config.preview_key) == '' then
      errors[#errors + 1] = 'preview_key: must be a non-empty string when provided'
    elseif key_type == 'boolean' and user_config.preview_key ~= false then
      errors[#errors + 1] = 'preview_key: boolean value must be false when used'
    end
  end

  if #errors > 0 then
    return false, 'hlcraft config errors:\n  ' .. table.concat(errors, '\n  ')
  end
  return true, nil
end

function M.normalize(config)
  local normalized = vim.deepcopy(config or M.defaults)
  normalized.from_none = normalize_from_none(normalized.from_none)
  normalized.reapply_events = normalize_reapply_events(normalized.reapply_events)
  normalized.dynamic = normalize_dynamic(normalized.dynamic)

  if normalized.preview_key == false then
    normalized.preview_key = false
  else
    normalized.preview_key = vim.trim(tostring(normalized.preview_key or M.defaults.preview_key))
  end

  return normalized
end

return M
