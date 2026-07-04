local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local navigation = require('hlcraft.ui.navigation')
local timers = require('hlcraft.ui.timers')
local window = require('hlcraft.ui.workspace.window')
local config = require('hlcraft.config')

local M = {}

--- Register all autocmds for the workspace lifecycle (text change, cursor, resize, wipeout)
--- @param instance table The Instance object holding UI state
--- @return nil
function M.setup(instance)
  if instance.group then
    return
  end

  instance.group = vim.api.nvim_create_augroup(instance.group_name, { clear = true })

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = instance.group,
    buffer = instance.state.buf,
    callback = function()
      if instance.state.detail_index then
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
      instance.state.debounce_timer = vim.defer_fn(function()
        instance.state.debounce_timer = nil
        buffer_fields.sync_queries(instance)
        instance:rerender()
      end, debounce_ms)
    end,
  })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = instance.group,
    buffer = instance.state.buf,
    callback = function()
      local win = window.get_win(instance)
      if not window.is_valid_win(win) then
        return
      end
      navigation.clamp_cursor(instance)
      local row = vim.api.nvim_win_get_cursor(win)[1]
      local area, extra = buffer_fields.current_area(instance, row)
      if area == 'results' then
        instance.state.list_cursor = extra
      end
    end,
  })

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = instance.group,
    buffer = instance.state.buf,
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
    buffer = instance.state.buf,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if window.is_valid_win(win) then
        window.capture_workspace_window(instance, win)
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWinLeave', {
    group = instance.group,
    buffer = instance.state.buf,
    callback = function()
      local current_win = vim.api.nvim_get_current_win()
      if window.is_valid_win(current_win) then
        window.release_workspace_window(instance, current_win)
      end

      if window.is_valid_win(instance.state.origin_win) then
        local current_buf = vim.api.nvim_win_get_buf(instance.state.origin_win)
        if current_buf ~= instance.state.buf then
          window.release_workspace_window(instance, instance.state.origin_win)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWipeout', {
    group = instance.group,
    buffer = instance.state.buf,
    callback = function()
      instance:cleanup()
    end,
  })
end

return M
