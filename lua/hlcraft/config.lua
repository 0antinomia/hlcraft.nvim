--- @type table
local M = {}

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

--- @type table
local defaults = {
  from_none = default_from_none, -- Start from a broad NONE-based transparent baseline before adding custom overrides
  threshold = 100, -- RGB Euclidean distance default for color similarity
  include_sp_in_color_search = false, -- Whether special/underline color participates in color search
  persist_dir = vim.fn.stdpath('config') .. '/.hlcraft', -- Directory used to persist highlight overrides as multiple TOML files
  reapply_events = default_reapply_events, -- Controls whether persisted overrides are replayed automatically and on which events
  dynamic = default_dynamic, -- Controls dynamic highlight effect scheduling
  debounce_ms = 100, -- Debounce delay in milliseconds for search input (0 disables)
  preview_key = 'z', -- Global normal-mode key active while the workspace is open for flashing the current result
}

--- @type table
M.config = vim.deepcopy(defaults)

local function is_finite_number(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
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

--- Validate user config before merging with defaults.
--- Aggregates ALL errors using per-field pcall(vim.validate) instead of stopping at first.
--- @param user_config table|nil User configuration options
--- @return boolean ok True if valid
--- @return string|nil err Error message with all problems, or nil if valid
function M.validate(user_config)
  if user_config == nil or (type(user_config) == 'table' and next(user_config) == nil) then
    return true, nil
  end

  if type(user_config) ~= 'table' then
    return false, 'hlcraft config must be a table, got ' .. type(user_config)
  end

  local errors = {}

  -- Unknown key check
  local known_keys = {
    from_none = true,
    threshold = true,
    include_sp_in_color_search = true,
    persist_dir = true,
    reapply_events = true,
    dynamic = true,
    debounce_ms = true,
    preview_key = true,
  }
  for key, _ in pairs(user_config) do
    if not known_keys[key] then
      errors[#errors + 1] = ('unknown config key: %q'):format(tostring(key))
    end
  end

  -- threshold: number, >= 0 and <= 1000
  if user_config.threshold ~= nil then
    local ok, err = pcall(vim.validate, { threshold = { user_config.threshold, 'number' } })
    if not ok then
      errors[#errors + 1] = err
    elseif user_config.threshold < 0 or user_config.threshold > 1000 then
      errors[#errors + 1] = 'threshold: must be between 0 and 1000'
    end
  end

  -- include_sp_in_color_search: boolean
  if user_config.include_sp_in_color_search ~= nil then
    local ok, err = pcall(vim.validate, {
      include_sp_in_color_search = { user_config.include_sp_in_color_search, 'boolean' },
    })
    if not ok then
      errors[#errors + 1] = err
    end
  end

  -- persist_dir: non-empty string
  if user_config.persist_dir ~= nil then
    local ok, err = pcall(vim.validate, { persist_dir = { user_config.persist_dir, 'string' } })
    if not ok then
      errors[#errors + 1] = err
    elseif vim.trim(user_config.persist_dir) == '' then
      errors[#errors + 1] = 'persist_dir: must be a non-empty string'
    end
  end

  -- from_none: boolean or table { enabled?: boolean, scope?: "core"|"extended" }
  if user_config.from_none ~= nil then
    local fn = user_config.from_none
    local fn_type = type(fn)
    if fn_type ~= 'boolean' and fn_type ~= 'table' then
      errors[#errors + 1] = 'from_none: must be boolean or table, got ' .. fn_type
    elseif fn_type == 'table' then
      if fn.enabled ~= nil and type(fn.enabled) ~= 'boolean' then
        errors[#errors + 1] = 'from_none.enabled: must be boolean, got ' .. type(fn.enabled)
      end
      if fn.scope ~= nil then
        if type(fn.scope) ~= 'string' then
          errors[#errors + 1] = 'from_none.scope: must be a string, got ' .. type(fn.scope)
        elseif fn.scope ~= 'core' and fn.scope ~= 'extended' then
          errors[#errors + 1] = ('from_none.scope: must be "core" or "extended", got %q'):format(fn.scope)
        end
      end
    end
  end

  -- reapply_events: boolean or table { enabled?: boolean, events?: array of string|table }
  if user_config.reapply_events ~= nil then
    local reapply = user_config.reapply_events
    local reapply_type = type(reapply)
    if reapply_type ~= 'boolean' and reapply_type ~= 'table' then
      errors[#errors + 1] = 'reapply_events: must be boolean or table, got ' .. reapply_type
    else
      if reapply_type == 'table' and reapply.enabled ~= nil and type(reapply.enabled) ~= 'boolean' then
        errors[#errors + 1] = 'reapply_events.enabled: must be boolean, got ' .. type(reapply.enabled)
      end
      if reapply_type == 'table' and reapply.events ~= nil and type(reapply.events) ~= 'table' then
        errors[#errors + 1] = 'reapply_events.events: must be a table, got ' .. type(reapply.events)
      elseif reapply_type == 'table' and type(reapply.events) == 'table' then
        for i, entry in ipairs(reapply.events) do
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
    end
  end

  -- dynamic: table { enabled?: boolean, interval_ms?: number between 16 and 1000 }
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

  -- debounce_ms: non-negative number
  if user_config.debounce_ms ~= nil then
    if type(user_config.debounce_ms) ~= 'number' then
      errors[#errors + 1] = 'debounce_ms: must be a number, got ' .. type(user_config.debounce_ms)
    elseif user_config.debounce_ms < 0 then
      errors[#errors + 1] = 'debounce_ms: must be >= 0'
    end
  end

  -- preview_key: string or false/nil to disable
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

--- Setup hlcraft config by merging user options with defaults
--- @param user_config table|nil User configuration options
--- @return table config The merged configuration
function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', vim.deepcopy(defaults), user_config or {})
  M.config.from_none = normalize_from_none(M.config.from_none)
  M.config.reapply_events = normalize_reapply_events(M.config.reapply_events)
  M.config.dynamic = normalize_dynamic(M.config.dynamic)
  if M.config.preview_key == false then
    M.config.preview_key = false
  else
    M.config.preview_key = vim.trim(tostring(M.config.preview_key or defaults.preview_key))
  end
  return M.config
end

--- Return whether the NONE-based transparent baseline is enabled.
--- @return boolean
function M.from_none_enabled()
  return M.config.from_none.enabled == true
end

--- Return the selected transparent baseline scope.
--- @return '"core"'|'"extended"'
function M.from_none_scope()
  return M.config.from_none.scope
end

return M
