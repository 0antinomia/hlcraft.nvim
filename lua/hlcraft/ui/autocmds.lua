local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local navigation = require('hlcraft.ui.navigation')
local notify = require('hlcraft.notify')
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

local function group_exists(group)
  return type(group) == 'number' and pcall(vim.api.nvim_get_autocmds, { group = group })
end

local function append_rollback_error(err, rollback_err)
  if rollback_err == nil then
    return err
  end
  return ('%s; rollback errors: %s'):format(err, tostring(rollback_err))
end

local function run_callback(label, callback)
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then
    notify.warn(('workspace autocmd %s failed: %s'):format(label, tostring(err)))
  end
end

local function schedule_debounced_text_changed(instance, state, debounce_buf, debounce_group, debounce_ms)
  local debounce_timer
  debounce_timer = vim.defer_fn(function()
    run_callback('debounced TextChanged', function()
      if state.debounce_timer ~= debounce_timer then
        return
      end
      if state.buf ~= debounce_buf or instance.group ~= debounce_group then
        state.debounce_timer = nil
        return
      end
      if state.rendering then
        state.debounce_timer = nil
        schedule_debounced_text_changed(instance, state, debounce_buf, debounce_group, debounce_ms)
        return
      end
      state.debounce_timer = nil
      if state.detail_index then
        return
      end
      if not window.is_valid_buf(state.buf) then
        return
      end
      buffer_fields.sync_queries(instance)
      instance:rerender()
    end)
  end, debounce_ms)
  state.debounce_timer = debounce_timer
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
    if group_exists(instance.group) and instance.autocmd_buf == buf then
      return
    end
    if not group_exists(instance.group) then
      instance.group = nil
      instance.autocmd_buf = nil
    end
  end

  local group
  local ok, err = xpcall(function()
    group = vim.api.nvim_create_augroup(instance.group_name, { clear = true })
    instance.group = group

    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
      group = instance.group,
      buffer = buf,
      callback = function()
        run_callback('TextChanged', function()
          if state.rendering then
            return
          end
          if state.detail_index then
            instance:rerender()
            navigation.clamp_cursor(instance)
            return
          end
          local debounce_ms = config.config.search.debounce_ms
          if debounce_ms <= 0 then
            buffer_fields.sync_queries(instance)
            instance:rerender()
            return
          end
          timers.stop_debounce(instance)
          local debounce_buf = buf
          local debounce_group = instance.group
          schedule_debounced_text_changed(instance, state, debounce_buf, debounce_group, debounce_ms)
        end)
      end,
    })

    vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
      group = instance.group,
      buffer = buf,
      callback = function()
        run_callback('CursorMoved', function()
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
        end)
      end,
    })

    vim.api.nvim_create_autocmd('ModeChanged', {
      group = instance.group,
      buffer = buf,
      callback = function()
        run_callback('ModeChanged', function()
          navigation.clamp_cursor(instance)
        end)
      end,
    })

    vim.api.nvim_create_autocmd('WinResized', {
      group = instance.group,
      callback = function()
        run_callback('WinResized', function()
          if window.is_open(instance) then
            instance:rerender()
          end
        end)
      end,
    })

    vim.api.nvim_create_autocmd('BufWinEnter', {
      group = instance.group,
      buffer = buf,
      callback = function()
        run_callback('BufWinEnter', function()
          local win = vim.api.nvim_get_current_win()
          if window.is_valid_win(win) then
            window.capture_workspace_window(instance, win)
          end
        end)
      end,
    })

    vim.api.nvim_create_autocmd('BufWinLeave', {
      group = instance.group,
      buffer = buf,
      callback = function()
        run_callback('BufWinLeave', function()
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
        end)
      end,
    })

    vim.api.nvim_create_autocmd('BufWipeout', {
      group = instance.group,
      buffer = buf,
      callback = function()
        run_callback('BufWipeout', function()
          instance:cleanup()
        end)
      end,
    })
    instance.autocmd_buf = buf
  end, debug.traceback)
  if not ok then
    local delete_err
    if type(group) == 'number' then
      local deleted, err = pcall(vim.api.nvim_del_augroup_by_id, group)
      if not deleted and group_exists(group) then
        delete_err = err
      end
    end
    if instance.group == group and not group_exists(group) then
      instance.group = nil
    end
    instance.autocmd_buf = nil
    error(append_rollback_error(err, delete_err), 0)
  end
end

return M
