local color = require('hlcraft.color')
local search = require('hlcraft.search')
local workspace = require('hlcraft.ui.workspace')
local navigation = require('hlcraft.ui.navigation')
local ui_fields = require('hlcraft.ui.fields')
local detail_values = require('hlcraft.ui.state.detail_values')

local M = {}

local function get_workspace_render()
  return require('hlcraft.ui.render.workspace')
end

--- Get the highlight result currently shown in detail view
--- @param instance table The Instance object holding UI state
--- @return table|nil Result entry, or nil if no detail is open
function M.current_detail_result(instance)
  local index = instance.state.detail_index
  if not index then
    return nil
  end
  return instance.state.results[index]
end

--- Get the empty-state message based on current query filters
--- @param instance table The Instance object holding UI state
--- @return string Human-readable message explaining why results are empty
function M.empty_message(instance)
  if instance.state.name_query == '' and instance.state.color_query == '' then
    return 'Use Name and Color search together to narrow highlight groups'
  end
  if instance.state.name_query ~= '' and instance.state.color_query ~= '' then
    return 'No highlight groups match both the name and color filters'
  end
  if instance.state.color_query ~= '' then
    return 'No highlight groups match this color filter'
  end
  return 'No highlight groups match this name filter'
end

--- Check if a color query string is a valid hex color or 'NONE'
--- @param instance table The Instance object holding UI state
--- @param query string Color query string
--- @return boolean True if query is valid for color search
function M.valid_color_query(instance, query)
  return query:upper() == 'NONE' or color.hex_to_int(query) ~= nil
end

--- Intersect name search and color search results, sorted by color distance
--- @param instance table The Instance object holding UI state
--- @param name_results table[] Results from name search
--- @param color_results table[] Results from color search
--- @return table[] Intersection of results sorted by distance then name
function M.intersect_results(instance, name_results, color_results)
  local color_index = {}
  local results = {}

  for _, item in ipairs(color_results) do
    color_index[item.name] = item
  end

  for _, item in ipairs(name_results) do
    local color_match = color_index[item.name]
    if color_match then
      local entry = vim.deepcopy(item)
      entry.distance = color_match.distance
      results[#results + 1] = entry
    end
  end

  table.sort(results, function(a, b)
    if a.distance and b.distance and a.distance ~= b.distance then
      return a.distance < b.distance
    end
    return a.name:lower() < b.name:lower()
  end)

  return results
end

--- Run search queries and update instance.state.results with matching highlight groups
--- @param instance table The Instance object holding UI state
--- @return nil
function M.update_results(instance)
  local results = {}

  if instance.state.name_query ~= '' and instance.state.color_query ~= '' then
    if M.valid_color_query(instance, instance.state.color_query) then
      results = M.intersect_results(
        instance,
        search.by_name(instance.state.name_query),
        search.by_color(instance.state.color_query)
      )
    end
  elseif instance.state.name_query ~= '' then
    results = search.by_name(instance.state.name_query)
  elseif instance.state.color_query ~= '' then
    if M.valid_color_query(instance, instance.state.color_query) then
      results = search.by_color(instance.state.color_query)
    end
  end

  instance.state.results = results
  if instance.state.detail_index == nil then
    instance.state.list_cursor = math.min(math.max(instance.state.list_cursor, 1), math.max(#results, 1))
  end
end

--- Get the result rows as a sorted list of {line, index} entries
--- @param instance table The Instance object holding UI state
--- @return table[] Sorted array of {line=number, index=number} entries
function M.rows(instance)
  local rows = {}
  for line_nr, result_index in pairs(instance.state.geometry.result_lines or {}) do
    rows[#rows + 1] = { line = line_nr, index = result_index }
  end
  table.sort(rows, function(a, b)
    return a.line < b.line
  end)
  return rows
end

--- Get the result entry at the current cursor position
--- @param instance table The Instance object holding UI state
--- @return table|nil Entry with row, index, and result keys, or nil
function M.current_entry(instance)
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local index = instance.state.geometry.result_lines[row]
  if not index then
    return nil
  end
  return { row = row, index = index, result = instance.state.results[index] }
end

--- Check if the cursor is on a result row
--- @param instance table The Instance object holding UI state
--- @return boolean True if cursor is on a result row
function M.is_on_row(instance)
  return M.current_entry(instance) ~= nil
end

--- Move the cursor by `step` result rows (jump between result entries)
--- @param instance table The Instance object holding UI state
--- @param step integer Number of entries to jump (+1 forward, -1 backward)
--- @return nil
function M.goto_offset(instance, step)
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return
  end

  local rows = M.rows(instance)
  if #rows == 0 then
    return
  end

  local current_row = vim.api.nvim_win_get_cursor(win)[1]
  for idx, entry in ipairs(rows) do
    if entry.line == current_row then
      local target = rows[math.max(1, math.min(#rows, idx + step))]
      navigation.jump_to_row(instance, target.line, false)
      return
    end
  end

  navigation.jump_to_row(instance, rows[1].line, false)
end

--- Move the cursor to the first result row
--- @param instance table The Instance object holding UI state
--- @return nil
function M.goto_first(instance)
  local rows = M.rows(instance)
  if #rows > 0 then
    navigation.jump_to_row(instance, rows[1].line, false)
  end
end

--- Re-render and navigate to a named result, optionally reopening detail view
--- @param instance table The Instance object holding UI state
--- @param name string Highlight group name to navigate to
--- @param reopen_detail boolean Whether to reopen the detail view for this result
--- @return nil
function M.refresh(instance, name, reopen_detail)
  local workspace_render = get_workspace_render()
  local active_field = instance.state.field_editor and instance.state.field_editor.field or nil
  instance:rerender()
  for index, result in ipairs(instance.state.results) do
    if result.name == name then
      instance.state.list_cursor = index
      if reopen_detail then
        instance.state.detail_index = index
        instance.state.detail_form = {}
        instance.state.field_editor.field = active_field
        workspace_render.render(instance)
      end
      return
    end
  end

  if reopen_detail then
    instance.state.detail_index = nil
    instance.state.detail_form = {}
    instance.state.field_editor.field = nil
    instance.state.list_cursor = math.min(math.max(instance.state.list_cursor, 1), math.max(#instance.state.results, 1))
    workspace_render.render(instance)
  end
end

--- Open the detail view for the result at the current cursor position
--- @param instance table The Instance object holding UI state
--- @return nil
function M.open_detail(instance)
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local index = instance.state.geometry.result_lines[row]
  if not index then
    return
  end
  instance.state.detail_index = index
  instance.state.detail_form = {}
  instance.state.field_editor.field = nil
  instance:rerender()
  local first_key = ui_fields.detail_order[1]
  local first_row = first_key and instance.state.geometry.detail_menu[first_key]
  if first_row then
    navigation.jump_to_row(instance, first_row.line, false)
  end
end

--- Close and delete the unsaved-changes prompt window and buffer
--- @param instance table The Instance object holding UI state
--- @return nil
function M.close_unsaved_prompt(instance)
  local prompt = instance.state.unsaved_prompt or {}
  if workspace.is_valid_win(prompt.win) then
    pcall(vim.api.nvim_win_close, prompt.win, true)
  end
  if workspace.is_valid_buf(prompt.buf) then
    pcall(vim.api.nvim_buf_delete, prompt.buf, { force = true })
  end
  instance.state.unsaved_prompt = { win = nil, buf = nil }
end

--- Close the detail view without checking for unsaved changes
--- @param instance table The Instance object holding UI state
--- @return nil
function M.force_close_detail(instance)
  M.close_unsaved_prompt(instance)
  instance.state.detail_index = nil
  instance.state.detail_form = {}
  instance.state.field_editor.field = nil
  instance:rerender()
  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
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
    local ok, err = detail_values.save(instance, name)
    if ok then
      M.force_close_detail(instance)
    elseif err then
      vim.notify(('hlcraft: %s'):format(err), vim.log.levels.ERROR)
    end
  end, opts)
  vim.keymap.set('n', 'd', function()
    detail_values.discard(instance, name)
    M.force_close_detail(instance)
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
function M.close_detail(instance)
  if not instance.state.detail_index then
    return
  end
  local result = M.current_detail_result(instance)
  if result and detail_values.is_dirty(result.name) then
    M.open_unsaved_prompt(instance, result.name)
    return
  end
  M.force_close_detail(instance)
end

return M
