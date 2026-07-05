local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local navigation = require('hlcraft.ui.navigation')
local timers = require('hlcraft.ui.timers')
local window = require('hlcraft.ui.workspace.window')
local config = require('hlcraft.config')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('workspace autocmds require an instance', 3)
  end
  return instance.state
end

local function assert_group_name(instance)
  if type(instance.group_name) ~= 'string' or instance.group_name == '' then
    error('workspace autocmd group name must be a non-empty string', 3)
  end
end

local function assert_buffer(state)
  if type(state.buf) ~= 'number' or not vim.api.nvim_buf_is_valid(state.buf) then
    error('workspace autocmds require a valid buffer', 3)
  end
  return state.buf
end

local function assert_callbacks(instance)
  if type(instance.rerender) ~= 'function' then
    error('workspace autocmds require a rerender callback', 3)
  end
  if type(instance.cleanup) ~= 'function' then
    error('workspace autocmds require a cleanup callback', 3)
  end
end

--- Register all autocmds for the workspace lifecycle (text change, cursor, resize, wipeout)
--- @param instance table The Instance object holding UI state
--- @return nil
function M.setup(instance)
  local state = instance_state(instance)
  assert_group_name(instance)
  local buf = assert_buffer(state)
  assert_callbacks(instance)
  if instance.group then
    return
  end

  instance.group = vim.api.nvim_create_augroup(instance.group_name, { clear = true })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = instance.group,
    buffer = buf,
    callback = function()
      if state.detail_index then
        instance:rerender()
        navigation.clamp_cursor(instance)
        return
      end
      local debounce_ms = config.config.debounce_ms
      if debounce_ms <= 0 then
        buffer_fields.sync_queries(instance)
        instance:rerender()
        return
      end
      timers.stop_debounce(instance)
      state.debounce_timer = vim.defer_fn(function()
        state.debounce_timer = nil
        buffer_fields.sync_queries(instance)
        instance:rerender()
      end, debounce_ms)
    end,
  })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = instance.group,
    buffer = buf,
    callback = function()
      local win = window.get_win(instance)
      if not window.is_valid_win(win) then
        return
      end
      navigation.clamp_cursor(instance)
      local row = vim.api.nvim_win_get_cursor(win)[1]
      local area, extra = buffer_fields.current_area(instance, row)
      if area == 'results' then
        state.list_cursor = extra
      end
    end,
  })

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = instance.group,
    buffer = buf,
    callback = function()
      navigation.clamp_cursor(instance)
    end,
  })

  vim.api.nvim_create_autocmd('WinResized', {
    group = instance.group,
    callback = function()
      if window.is_open(instance) then
        instance:rerender()
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = instance.group,
    buffer = buf,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if window.is_valid_win(win) then
        window.capture_workspace_window(instance, win)
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWinLeave', {
    group = instance.group,
    buffer = buf,
    callback = function()
      local current_win = vim.api.nvim_get_current_win()
      if window.is_valid_win(current_win) then
        window.release_workspace_window(instance, current_win)
      end

      if window.is_valid_win(state.origin_win) then
        local current_buf = vim.api.nvim_win_get_buf(state.origin_win)
        if current_buf ~= state.buf then
          window.release_workspace_window(instance, state.origin_win)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    group = instance.group,
    buffer = buf,
    callback = function()
      instance:cleanup()
    end,
  })
end

return M
