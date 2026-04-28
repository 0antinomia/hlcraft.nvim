local config = require('hlcraft.config')
local effects = require('hlcraft.dynamic.effects')
local model = require('hlcraft.dynamic.model')
local override_state = require('hlcraft.overrides.state')

local M = {}

local state = {
  tasks = {},
  timer = nil,
}

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
  pcall(override_state.data.original_set_hl, 0, name, vim.deepcopy(spec))
end

local function close_timer()
  if not state.timer then
    return
  end

  state.timer:stop()
  state.timer:close()
  state.timer = nil
end

local function compute_color(channel_spec, base_color, now_ms)
  local value = effects.compute(channel_spec, base_color, now_ms)
  if value == base_color and channel_spec.mode == 'breath' then
    value = effects.compute(channel_spec, base_color, now_ms + math.floor(channel_spec.speed / 10))
  end
  return value
end

function M.tick(now_ms)
  if not config.config.dynamic.enabled then
    return
  end

  for name, task in pairs(state.tasks) do
    local spec = vim.deepcopy(task.base_spec or {})
    local dynamic = model.normalize_dynamic(task.dynamic)

    for _, channel in ipairs(model.channels) do
      local channel_spec = dynamic and dynamic[channel] or nil
      if channel_spec then
        local value = compute_color(channel_spec, task.base_spec[channel], now_ms)
        if value ~= nil then
          spec[channel] = value
        end
      end
    end

    pcall(override_state.data.original_set_hl, 0, name, spec)
  end
end

function M.start()
  if state.timer or not config.config.dynamic.enabled or next(state.tasks) == nil then
    return
  end

  state.timer = vim.uv.new_timer()
  state.timer:start(config.config.dynamic.interval_ms, config.config.dynamic.interval_ms, function()
    vim.schedule(function()
      M.tick(vim.uv.hrtime() / 1000000)
    end)
  end)
end

function M.clear_group(name, restore_spec)
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
  local dynamic = model.normalize_dynamic(entry and entry.dynamic)
  if not config.config.dynamic.enabled or not dynamic then
    M.clear_group(name, base_spec)
    return
  end

  state.tasks[name] = {
    base_spec = vim.deepcopy(base_spec or {}),
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
