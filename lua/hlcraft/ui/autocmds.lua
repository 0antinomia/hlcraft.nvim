local input_model = require('hlcraft.ui.input.model')
local workspace_render = require('hlcraft.ui.render.workspace')
local navigation = require('hlcraft.ui.navigation')
local workspace = require('hlcraft.ui.workspace')
local config = require('hlcraft.config')

local M = {}

local function stop_debounce_timer(instance)
  local timer = instance.state.debounce_timer
  if not timer then
    return
  end

  if timer.stop then
    timer:stop()
  end
  if timer.close then
    pcall(function()
      timer:close()
    end)
  end

  instance.state.debounce_timer = nil
end

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
      local debounce_ms = config.config.debounce_ms or 100
      if debounce_ms <= 0 then
        input_model.sync_queries_from_buffer(instance)
        instance:rerender()
        return
      end
      stop_debounce_timer(instance)
      instance.state.debounce_timer = vim.defer_fn(function()
        instance.state.debounce_timer = nil
        input_model.sync_queries_from_buffer(instance)
        instance:rerender()
      end, debounce_ms)
    end,
  })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = instance.group,
    buffer = instance.state.buf,
    callback = function()
      local win = workspace.get_win(instance)
      if not workspace.is_valid_win(win) then
        return
      end
      navigation.clamp_cursor(instance)
      local row = vim.api.nvim_win_get_cursor(win)[1]
      local area, extra = input_model.current_area(instance, row)
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
      if workspace.is_open(instance) then
        workspace_render.render(instance)
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = instance.group,
    buffer = instance.state.buf,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      if workspace.is_valid_win(win) then
        workspace.capture_workspace_window(instance, win)
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWinLeave', {
    group = instance.group,
    buffer = instance.state.buf,
    callback = function()
      local current_win = vim.api.nvim_get_current_win()
      if workspace.is_valid_win(current_win) then
        workspace.release_workspace_window(instance, current_win)
      end

      if workspace.is_valid_win(instance.state.origin_win) then
        local current_buf = vim.api.nvim_win_get_buf(instance.state.origin_win)
        if current_buf ~= instance.state.buf then
          workspace.release_workspace_window(instance, instance.state.origin_win)
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
