local numbers = require('hlcraft.core.number')
local spec = require('hlcraft.config.spec')

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

local function normalize_transparent(value)
  value = assert_table(value, 'transparent config')

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
  value = assert_table(value, 'persistence.reapply_events config')
  local events = {}
  for index, event in ipairs(value.events) do
    events[index] = normalize_reapply_event(event)
  end

  return {
    enabled = value.enabled ~= false,
    events = events,
  }
end

local function normalize_search(value)
  value = assert_table(value, 'search config')
  local search = spec.field('search')
  return {
    threshold = normalize_number(value.threshold, 'search.threshold', search.fields.threshold.range),
    include_sp = value.include_sp == true,
    debounce_ms = normalize_number(value.debounce_ms, 'search.debounce_ms', search.fields.debounce_ms.range),
  }
end

local function normalize_persistence(value)
  value = assert_table(value, 'persistence config')
  return {
    dir = vim.trim(value.dir),
    reapply_events = normalize_reapply_events(value.reapply_events),
  }
end

local function normalize_dynamic(value)
  value = assert_table(value, 'dynamic config')

  local interval = spec.field('dynamic').fields.interval_ms.range
  local interval_ms = math.floor(normalize_number(value.interval_ms, 'dynamic.interval_ms', interval))

  return {
    interval_ms = interval_ms,
  }
end

local function normalize_preview_opts(value)
  value = assert_table(value, 'keymaps.preview.opts config')
  local normalized = {}
  if value.desc ~= nil then
    normalized.desc = vim.trim(value.desc)
  end
  if value.silent ~= nil then
    normalized.silent = value.silent
  end
  if value.nowait ~= nil then
    normalized.nowait = value.nowait
  end
  return normalized
end

local function normalize_preview_keymap(value)
  if value == false then
    return false
  end
  value = assert_table(value, 'keymaps.preview config')
  return {
    lhs = vim.trim(value.lhs),
    mode = vim.trim(value.mode),
    opts = normalize_preview_opts(value.opts),
  }
end

local function normalize_keymaps(value)
  value = assert_table(value, 'keymaps config')
  return {
    preview = normalize_preview_keymap(value.preview),
  }
end

function M.config(config)
  local normalized = vim.deepcopy(assert_table(config, 'hlcraft config'))
  normalized.transparent = normalize_transparent(normalized.transparent)
  normalized.search = normalize_search(normalized.search)
  normalized.persistence = normalize_persistence(normalized.persistence)
  normalized.dynamic = normalize_dynamic(normalized.dynamic)
  normalized.keymaps = normalize_keymaps(normalized.keymaps)

  return normalized
end

return M
