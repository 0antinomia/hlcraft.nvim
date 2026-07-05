local defaults = require('hlcraft.config.defaults')
local numbers = require('hlcraft.core.number')

local M = {}

local function assert_table(value, label)
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

local function normalize_number(value, label, range)
  if type(value) ~= 'number' or not numbers.is_finite(value) then
    error(('%s must be a finite number'):format(label), 3)
  end
  if range.min ~= nil and value < range.min then
    error(('%s must be >= %s'):format(label, range.min), 3)
  end
  if range.max ~= nil and value > range.max then
    error(('%s must be <= %s'):format(label, range.max), 3)
  end
  return value
end

local function normalize_from_none(value)
  if type(value) == 'boolean' then
    return {
      enabled = value,
      scope = defaults.from_none.scope,
    }
  end

  value = assert_table(value, 'from_none config')

  return {
    enabled = value.enabled == true,
    scope = value.scope,
  }
end

local function normalize_reapply_event(value)
  if type(value) == 'string' then
    return vim.trim(value)
  end

  local normalized = {
    event = vim.trim(value.event),
  }
  if value.pattern ~= nil then
    normalized.pattern = vim.trim(value.pattern)
  end
  if value.once ~= nil then
    normalized.once = value.once
  end
  return normalized
end

local function normalize_reapply_events(value)
  if type(value) == 'boolean' then
    return {
      enabled = value,
      events = vim.deepcopy(defaults.reapply_events.events),
    }
  end

  value = assert_table(value, 'reapply_events config')
  local events = {}
  for index, event in ipairs(value.events) do
    events[index] = normalize_reapply_event(event)
  end

  return {
    enabled = value.enabled ~= false,
    events = events,
  }
end

local function normalize_dynamic(value)
  value = assert_table(value, 'dynamic config')

  local interval = defaults.dynamic_interval_ms
  local interval_ms = math.floor(normalize_number(value.interval_ms, 'dynamic.interval_ms', interval))

  return {
    enabled = value.enabled == true,
    interval_ms = interval_ms,
  }
end

local function normalize_preview_key(value)
  if value == false then
    return false
  end
  if type(value) == 'string' then
    return vim.trim(value)
  end
  error('preview_key must be a string or false', 3)
end

function M.config(config)
  local normalized = vim.deepcopy(assert_table(config, 'hlcraft config'))
  normalized.threshold = normalize_number(normalized.threshold, 'threshold', defaults.threshold_range)
  normalized.debounce_ms = normalize_number(normalized.debounce_ms, 'debounce_ms', defaults.debounce_ms_range)
  normalized.from_none = normalize_from_none(normalized.from_none)
  normalized.reapply_events = normalize_reapply_events(normalized.reapply_events)
  normalized.dynamic = normalize_dynamic(normalized.dynamic)
  normalized.preview_key = normalize_preview_key(normalized.preview_key)

  return normalized
end

return M
