local color = require('hlcraft.core.color')
local search = require('hlcraft.core.search')
local window = require('hlcraft.ui.workspace.window')
local navigation = require('hlcraft.ui.navigation')
local ui_fields = require('hlcraft.ui.fields')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')

local M = {}

function M.enter(instance)
  instance.state.scene.name = 'search'
end

function M.render(instance)
  M.update_results(instance)
  require('hlcraft.ui.render.workspace').render(instance)
end

function M.back(instance)
  lifecycle.close(instance)
  return true, nil
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
--- @param query string Color query string
--- @return boolean True if query is valid for color search
local function valid_color_query(query)
  return query:upper() == 'NONE' or color.hex_to_int(query) ~= nil
end

--- Intersect name search and color search results, sorted by color distance
--- @param name_results table[] Results from name search
--- @param color_results table[] Results from color search
--- @return table[] Intersection of results sorted by distance then name
local function intersect_results(name_results, color_results)
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
    if valid_color_query(instance.state.color_query) then
      results =
        intersect_results(search.by_name(instance.state.name_query), search.by_color(instance.state.color_query))
    end
  elseif instance.state.name_query ~= '' then
    results = search.by_name(instance.state.name_query)
  elseif instance.state.color_query ~= '' then
    if valid_color_query(instance.state.color_query) then
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
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
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
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
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

--- Open the detail view for the result at the current cursor position
--- @param instance table The Instance object holding UI state
--- @return nil
function M.open_detail(instance)
  local win = window.get_win(instance)
  if not window.is_valid_win(win) then
    return
  end
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local index = instance.state.geometry.result_lines[row]
  if not index then
    return
  end
  instance.state.detail_index = index
  instance.state.field_editor.field = nil
  require('hlcraft.ui.scene').set(instance, 'detail', { index = index })
  instance:rerender()
  local first_key = ui_fields.detail_order[1]
  local first_row = first_key and instance.state.geometry.detail_menu[first_key]
  if first_row then
    navigation.jump_to_row(instance, first_row.line, false)
  end
end

return M
