local defaults = require('hlcraft.config.defaults')
local numbers = require('hlcraft.core.number')

local M = {}

local function normalize_from_none(value)
  if type(value) == 'boolean' then
    return {
      enabled = value,
      scope = defaults.from_none.scope,
    }
  end

  if type(value) ~= 'table' then
    return vim.deepcopy(defaults.from_none)
  end

  return {
    enabled = value.enabled == true,
    scope = value.scope == 'core' and 'core' or defaults.from_none.scope,
  }
end

local function normalize_reapply_events(value)
  if type(value) == 'boolean' then
    return {
      enabled = value,
      events = vim.deepcopy(defaults.reapply_events.events),
    }
  end

  if type(value) ~= 'table' then
    return vim.deepcopy(defaults.reapply_events)
  end

  local events = type(value.events) == 'table' and vim.deepcopy(value.events)
    or vim.deepcopy(defaults.reapply_events.events)

  return {
    enabled = value.enabled ~= false,
    events = events,
  }
end

local function normalize_dynamic(value)
  if type(value) ~= 'table' then
    return vim.deepcopy(defaults.dynamic)
  end

  local interval = defaults.dynamic_interval_ms
  local interval_ms = math.floor(numbers.to_finite(value.interval_ms, defaults.dynamic.interval_ms))
  interval_ms = numbers.clamp(interval_ms, interval.min, interval.max)

  return {
    enabled = value.enabled == true,
    interval_ms = interval_ms,
  }
end

function M.config(config)
  local normalized = vim.deepcopy(config or defaults.values)
  normalized.from_none = normalize_from_none(normalized.from_none)
  normalized.reapply_events = normalize_reapply_events(normalized.reapply_events)
  normalized.dynamic = normalize_dynamic(normalized.dynamic)

  if normalized.preview_key == false then
    normalized.preview_key = false
  else
    normalized.preview_key = vim.trim(tostring(normalized.preview_key or defaults.values.preview_key))
  end

  return normalized
end

return M
