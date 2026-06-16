local search_scene = require('hlcraft.ui.scene.search')
local session = require('hlcraft.ui.session')
local ui_fields = require('hlcraft.ui.fields')
local window = require('hlcraft.ui.workspace.window')

local M = {}

local function restore_search_scene(instance)
  require('hlcraft.ui.scene').set(instance, 'search')
end

function M.enter(instance, opts)
  instance.state.detail_index = opts and opts.index or instance.state.detail_index
end

function M.render(instance)
  search_scene.update_results(instance)
  require('hlcraft.ui.render.detail').render(instance)
end

function M.back(instance)
  M.close(instance)
  return true, nil
end

--- Get the highlight result currently shown in detail view
--- @param instance table The Instance object holding UI state
--- @return table|nil Result entry, or nil if no detail is open
function M.current_result(instance)
  local index = instance.state.detail_index
  if not index then
    return nil
  end
  return instance.state.results[index]
end

--- Re-render and navigate to a named result, optionally reopening detail view
--- @param instance table The Instance object holding UI state
--- @param name string Highlight group name to navigate to
--- @param reopen_detail boolean Whether to reopen the detail view for this result
--- @return nil
function M.refresh(instance, name, reopen_detail)
  local active_field = instance.state.field_editor and instance.state.field_editor.field or nil
  instance:rerender()
  for index, result in ipairs(instance.state.results) do
    if result.name == name then
      instance.state.list_cursor = index
      if reopen_detail then
        instance.state.detail_index = index
        instance.state.field_editor.field = active_field
        require('hlcraft.ui.render.workspace').render(instance)
      end
      return
    end
  end

  if reopen_detail then
    instance.state.detail_index = nil
    instance.state.field_editor.field = nil
    instance.state.list_cursor = math.min(math.max(instance.state.list_cursor, 1), math.max(#instance.state.results, 1))
    restore_search_scene(instance)
    require('hlcraft.ui.render.workspace').render(instance)
  end
end

--- Close and delete the unsaved-changes prompt window and buffer
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close_unsaved_prompt(instance)
  local prompt = instance.state.unsaved_prompt or {}
  if window.is_valid_win(prompt.win) then
    pcall(vim.api.nvim_win_close, prompt.win, true)
  end
  if window.is_valid_buf(prompt.buf) then
    pcall(vim.api.nvim_buf_delete, prompt.buf, { force = true })
  end
  instance.state.unsaved_prompt = { win = nil, buf = nil }
end

--- Close the detail view without checking for unsaved changes
--- @param instance table The Instance object holding UI state
--- @return nil
function M.force_close(instance)
  M.close_unsaved_prompt(instance)
  instance.state.detail_index = nil
  instance.state.field_editor.field = nil
  restore_search_scene(instance)
  instance:rerender()
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return
  end
  for line, index in pairs(instance.state.geometry.result_lines or {}) do
    if index == instance.state.list_cursor then
      vim.api.nvim_win_set_cursor(win, { line, 0 })
      break
    end
  end
end

--- Open a confirmation prompt for closing a dirty detail view
--- @param instance table The Instance object holding UI state
--- @param name string Highlight group name
--- @return nil
function M.open_unsaved_prompt(instance, name)
  M.close_unsaved_prompt(instance)

  local lines = {
    'Unsaved highlight changes',
    's: save   d: discard   c/q: cancel',
  }
  local width = 38
  local height = #lines
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'rounded',
    width = width,
    height = height,
    row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    zindex = 90,
  })

  instance.state.unsaved_prompt = { win = win, buf = buf }
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false

  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set('n', 's', function()
    local ok, err = session.save(instance, name)
    if ok then
      M.force_close(instance)
    elseif err then
      vim.notify(('hlcraft: %s'):format(err), vim.log.levels.ERROR)
    end
  end, opts)
  vim.keymap.set('n', 'd', function()
    session.discard(instance, name)
    M.force_close(instance)
  end, opts)
  for _, key in ipairs({ 'c', 'q', '<Esc>' }) do
    vim.keymap.set('n', key, function()
      M.close_unsaved_prompt(instance)
    end, opts)
  end
end

--- Close the detail view and return to the result list, restoring cursor position
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close(instance)
  if not instance.state.detail_index then
    return
  end
  local result = M.current_result(instance)
  if result and session.is_dirty(result.name) then
    M.open_unsaved_prompt(instance, result.name)
    return
  end
  M.force_close(instance)
end

function M.row_at_cursor(instance)
  local win = require('hlcraft.ui.workspace.window').get_win(instance)
  if not require('hlcraft.ui.workspace.window').is_valid_win(win) then
    return nil
  end
  local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
  for _, row in pairs(instance.state.geometry.detail_menu or {}) do
    if row.line == cursor_line then
      return row
    end
  end
end

function M.activate(instance)
  local row = M.row_at_cursor(instance)
  local result = M.current_result(instance)
  if not row or not result then
    return false, nil
  end
  if row.kind == 'boolean' then
    local runtime_value = session.field_value(result.name, row.key)
    local next_value = true
    if runtime_value == true then
      next_value = false
    elseif runtime_value == false then
      next_value = nil
    end
    return session.set_style(instance, result.name, row.key, next_value)
  end
  if row.kind == 'group' or row.kind == 'color' or row.kind == 'blend' then
    require('hlcraft.ui.scene').set(instance, 'field_editor', {
      field = row.key,
      kind = ui_fields.detail_kinds[row.key],
    })
    instance:rerender()
    return true, nil
  end
  return false, nil
end

function M.handle(instance, action)
  if action == 'activate' then
    return M.activate(instance)
  end
  if action == 'save' then
    local result = M.current_result(instance)
    if not result then
      return false, nil
    end
    return session.save(instance, result.name)
  end
  return false, ('unsupported detail action: %s'):format(tostring(action))
end

return M
