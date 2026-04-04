local input_model = require('hlcraft.ui.input.model')
local workspace_render = require('hlcraft.ui.render.workspace')
local navigation = require('hlcraft.ui.navigation')
local detail_form_state = require('hlcraft.ui.state.detail_form')
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
        detail_form_state.rerender(instance)
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
      if instance.state.detail_index and detail_form_state.is_layout_dirty(instance) then
        detail_form_state.rerender(instance)
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
      if instance.state.detail_index and detail_form_state.is_layout_dirty(instance) then
        detail_form_state.rerender(instance)
      end
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

  vim.api.nvim_create_autocmd('BufWipeout', {
    group = instance.group,
    buffer = instance.state.buf,
    callback = function()
      instance:cleanup()
    end,
  })
end

return M
