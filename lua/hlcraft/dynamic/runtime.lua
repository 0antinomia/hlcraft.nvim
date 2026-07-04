local config = require('hlcraft.config')
local effects = require('hlcraft.dynamic.effects')
local model = require('hlcraft.dynamic.model')
local timers = require('hlcraft.core.timers')
local store = require('hlcraft.engine.store')

local M = {}

local state = {
  tasks = {},
  timer = nil,
}

local function assert_name(name)
  if type(name) ~= 'string' or name == '' then
    error('dynamic runtime group name must be a non-empty string', 3)
  end
  return name
end

local function assert_table(value, label)
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

local function task_count()
  local count = 0
  for _ in pairs(state.tasks) do
    count = count + 1
  end
  return count
end

local function restore_group(name, spec)
  if not spec then
    return
  end
  spec = assert_table(spec, 'dynamic runtime restore spec')
  pcall(store.data.original_set_hl, 0, name, vim.deepcopy(spec))
end

local function close_timer()
  timers.stop(state.timer)
  state.timer = nil
end

function M.tick(now_ms)
  if not config.config.dynamic.enabled then
    M.stop()
    return
  end

  for name, task in pairs(state.tasks) do
    local spec = vim.deepcopy(task.base_spec)

    for _, channel in ipairs(model.channels) do
      local channel_spec = task.dynamic[channel]
      if channel_spec then
        local value = effects.compute(channel_spec, task.base_spec[channel], now_ms, task.base_spec)
        if value ~= nil then
          spec[channel] = value
        end
      end
    end

    pcall(store.data.original_set_hl, 0, name, spec)
  end
end

function M.start()
  if state.timer or not config.config.dynamic.enabled or next(state.tasks) == nil then
    return
  end

  state.timer = timers.repeating(config.config.dynamic.interval_ms, function()
    vim.schedule(function()
      M.tick(vim.uv.hrtime() / 1000000)
    end)
  end)
end

function M.base_spec(name)
  name = assert_name(name)
  local task = state.tasks[name]
  return task and vim.deepcopy(task.base_spec) or nil
end

function M.clear_group(name, restore_spec)
  name = assert_name(name)
  if restore_spec ~= nil then
    restore_spec = assert_table(restore_spec, 'dynamic runtime restore spec')
  end
  local existed = state.tasks[name] ~= nil
  state.tasks[name] = nil

  if existed and restore_spec ~= nil then
    restore_group(name, restore_spec)
  end

  if next(state.tasks) == nil then
    close_timer()
  end
end

function M.sync_group(name, base_spec, entry)
  name = assert_name(name)
  base_spec = assert_table(base_spec, 'dynamic runtime base spec')
  entry = assert_table(entry, 'dynamic runtime entry')
  local dynamic = model.normalize_dynamic(entry.dynamic)
  if not config.config.dynamic.enabled or not dynamic then
    M.clear_group(name, base_spec)
    return
  end

  state.tasks[name] = {
    base_spec = vim.deepcopy(base_spec),
    dynamic = dynamic,
  }
  M.start()
end

function M.stop()
  for name, task in pairs(state.tasks) do
    restore_group(name, task.base_spec)
  end
  state.tasks = {}
  close_timer()
end

function M.active_count()
  return task_count()
end

return M
