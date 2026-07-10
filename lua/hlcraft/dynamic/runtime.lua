local config = require('hlcraft.config')
local effects = require('hlcraft.dynamic.effects')
local highlight_names = require('hlcraft.core.highlight_names')
local model = require('hlcraft.dynamic.model')
local notify = require('hlcraft.notify')
local numbers = require('hlcraft.core.number')
local timers = require('hlcraft.core.timers')
local store = require('hlcraft.engine.store')

local M = {}

local state = {
  generation = 0,
  tasks = {},
  timer = nil,
}

local function assert_name(name)
  return highlight_names.assert(name, 'dynamic runtime group name', 3)
end

local function assert_table(value, label)
  if type(value) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  return value
end

local function assert_time(now_ms)
  if not numbers.is_finite(now_ms) then
    error('dynamic runtime time must be finite', 3)
  end
  return now_ms
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
    return true
  end
  spec = assert_table(spec, 'dynamic runtime restore spec')
  return pcall(store.data.original_set_hl, 0, name, vim.deepcopy(spec))
end

local function capture_live_spec(name)
  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = name, create = false })
  if not ok then
    error(('dynamic runtime failed to capture group %s: %s'):format(name, tostring(spec)), 2)
  end
  return vim.deepcopy(spec or {})
end

local function capture_live_specs(tasks)
  local captured = {}
  for name in pairs(tasks) do
    captured[name] = capture_live_spec(name)
  end
  return captured
end

local function restore_live_specs(captured)
  local errors = {}
  for name, spec in pairs(captured) do
    local restored, err = restore_group(name, spec)
    if not restored then
      errors[#errors + 1] = ('dynamic runtime failed to restore group %s: %s'):format(name, tostring(err))
    end
  end
  if #errors > 0 then
    return false, table.concat(errors, '; ')
  end
  return true, nil
end

local function apply_group(name, spec)
  local ok, err = pcall(store.data.original_set_hl, 0, name, spec)
  if not ok then
    error(('dynamic runtime failed to apply group %s: %s'):format(name, tostring(err)), 2)
  end
end

local function close_timer()
  local timer = state.timer
  if timer == nil then
    return
  end
  timers.stop(timer)
  if state.timer == timer then
    state.timer = nil
    state.generation = state.generation + 1
  end
end

local function run_timer_tick(generation)
  if generation ~= state.generation then
    return
  end
  local ok, err = xpcall(function()
    M.tick(vim.uv.hrtime() / 1000000)
  end, debug.traceback)
  if not ok and generation == state.generation then
    local message = ('dynamic runtime timer failed: %s'):format(tostring(err))
    local closed, close_err = pcall(close_timer)
    if not closed then
      message = ('%s; timer cleanup failed: %s'):format(message, tostring(close_err))
    end
    notify.warn(message)
  end
end

local function create_timer()
  local generation = state.generation + 1
  local timer = timers.repeating(config.config.dynamic.interval_ms, function()
    vim.schedule(function()
      run_timer_tick(generation)
    end)
  end)
  return timer, generation
end

function M.tick(now_ms)
  now_ms = assert_time(now_ms)
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

    apply_group(name, spec)
  end
end

function M.start()
  if state.timer or next(state.tasks) == nil then
    return true
  end

  local timer, generation = create_timer()
  if not timer then
    return false
  end
  state.timer = timer
  state.generation = generation
  return true
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

  if existed and restore_spec ~= nil then
    local restored = restore_group(name, restore_spec)
    if not restored then
      return false
    end
  end

  state.tasks[name] = nil
  if next(state.tasks) == nil then
    close_timer()
  end
  return true
end

function M.sync_group(name, base_spec, entry)
  name = assert_name(name)
  base_spec = assert_table(base_spec, 'dynamic runtime base spec')
  entry = assert_table(entry, 'dynamic runtime entry')
  local dynamic = model.normalize_dynamic(entry.dynamic)
  if entry.dynamic ~= nil and not dynamic then
    error('dynamic runtime entry has invalid dynamic override', 2)
  end
  if not dynamic then
    if not M.clear_group(name, base_spec) then
      error(('dynamic runtime failed to clear group %s'):format(name), 2)
    end
    return
  end

  local previous_task = state.tasks[name]
  state.tasks[name] = {
    base_spec = vim.deepcopy(base_spec),
    dynamic = dynamic,
  }
  if not M.start() then
    state.tasks[name] = previous_task
    error('dynamic runtime failed to start timer', 2)
  end
end

function M.stop()
  local failed = false
  for name, task in pairs(state.tasks) do
    if restore_group(name, task.base_spec) then
      state.tasks[name] = nil
    else
      failed = true
    end
  end
  if next(state.tasks) == nil then
    close_timer()
  end
  return not failed
end

function M.reset()
  state.tasks = {}
  close_timer()
end

function M.capture()
  return {
    live_specs = capture_live_specs(state.tasks),
    running = state.timer ~= nil,
    tasks = vim.deepcopy(state.tasks),
  }
end

function M.restore(captured)
  captured = assert_table(captured, 'dynamic runtime capture')
  local tasks = vim.deepcopy(assert_table(captured.tasks, 'dynamic runtime captured tasks'))
  local live_specs = vim.deepcopy(assert_table(captured.live_specs, 'dynamic runtime captured live specs'))
  if type(captured.running) ~= 'boolean' then
    error('dynamic runtime captured running state must be boolean', 2)
  end
  for name in pairs(tasks) do
    assert_table(live_specs[name], ('dynamic runtime captured live spec %s'):format(name))
  end
  for name in pairs(live_specs) do
    if tasks[name] == nil then
      error(('dynamic runtime captured live spec %s has no task'):format(name), 2)
    end
  end
  if captured.running and next(tasks) == nil then
    error('dynamic runtime capture cannot run without tasks', 2)
  end
  local previous_timer = state.timer
  local timer
  local generation = state.generation + 1
  if captured.running then
    timer, generation = create_timer()
    if not timer then
      error('dynamic runtime failed to restore timer', 2)
    end
  end

  if previous_timer ~= nil then
    local stopped, stop_err = pcall(timers.stop, previous_timer)
    if not stopped then
      local err = ('dynamic runtime failed to stop previous timer: %s'):format(tostring(stop_err))
      if timer ~= nil then
        local cleaned, cleanup_err = pcall(timers.stop, timer)
        if not cleaned then
          err = ('%s; rollback errors: %s'):format(err, tostring(cleanup_err))
        end
      end
      error(err, 2)
    end
  end

  state.tasks = tasks
  state.timer = timer
  state.generation = generation
  local live_ok, live_err = restore_live_specs(live_specs)
  if not live_ok then
    error(live_err, 2)
  end
end

function M.active_count()
  return task_count()
end

return M
