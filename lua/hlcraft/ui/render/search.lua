local render_util = require('hlcraft.render.util')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local ui_fields = require('hlcraft.ui.fields')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local buffer = require('hlcraft.ui.render.buffer')
local decorations = require('hlcraft.ui.render.decorations')
local hints = require('hlcraft.ui.render.hints')
local list = require('hlcraft.ui.render.list')
local theme = require('hlcraft.ui.theme')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('search renderer requires an instance', 3)
  end
  return instance.state
end

local function instance_namespace(instance)
  return numbers.assert_non_negative_integer(instance.ns, 'search renderer namespace', 3)
end

local function result_list(state)
  return tables.assert_sequence(state.results, 'search renderer results', 3)
end

local function positive_integer(value, label)
  return numbers.assert_positive_integer(value, label, 3)
end

local function optional_color(value, label)
  if value ~= nil and type(value) ~= 'string' then
    error(('%s must be a string or nil'):format(label), 3)
  end
  return value
end

local function result_at(results, index)
  index = positive_integer(index, 'search rendered result index')
  local result = results[index]
  if type(result) ~= 'table' then
    error('search rendered result must be a table', 3)
  end
  optional_color(result.fg, 'search rendered fg')
  optional_color(result.bg, 'search rendered bg')
  optional_color(result.sp, 'search rendered sp')
  return result
end

local function result_cells_at(geometry, line_nr)
  local cells = geometry.result_cells[line_nr]
  if type(cells) ~= 'table' then
    error('search result cell geometry is missing', 3)
  end
  return cells
end

local function add_line_highlight(buf, ns, lines, row1, hl)
  if lines[row1] then
    vim.api.nvim_buf_add_highlight(buf, ns, hl, row1 - 1, 0, -1)
  end
end

local function apply_result_cell(instance, buf, line_nr, start_col, cell, suffix)
  if cell.dynamic then
    decorations.apply_dynamic_cell(instance, buf, line_nr - 1, start_col, cell.text)
  else
    decorations.apply_color_cell(instance, buf, line_nr - 1, start_col, cell.text, cell.color, suffix)
  end
end

local function append_hint_lines(lines, width)
  local start_line = #lines + 1
  for _, line in ipairs(render_util.string_list(hints.search(width), 'search hint lines', 3)) do
    lines[#lines + 1] = line
  end
  return start_line
end

function M.render(instance)
  local state = instance_state(instance)
  local results = result_list(state)
  local width = buffer.prepare(instance)
  if not width then
    return
  end
  local ns = instance_namespace(instance)

  local lines
  local geometry
  local results_top
  local result_cells
  local hint_start_line
  local dynamic_preview_snapshot = dynamic_preview.begin_render(instance)
  local render_ok, render_err = xpcall(function()
    lines = {}
    geometry = buffer.new_geometry()
    results_top = buffer.append_search_inputs(instance, lines, geometry, width)

    local result_lines, selectable
    result_lines, selectable, result_cells = list.build(instance, width)
    for _, line in ipairs(result_lines) do
      lines[#lines + 1] = line
    end
    lines[#lines + 1] = ''
    hint_start_line = append_hint_lines(lines, width)
    for index, result_index in pairs(selectable) do
      local line_nr = results_top + index - 1
      geometry.result_lines[line_nr] = result_index
      geometry.result_cells[line_nr] = result_cells[index]
    end

    buffer.replace(instance, lines, geometry, function()
      decorations.set_input_header(instance, geometry.name, ui_fields.search_prefixes.name)
      decorations.set_input_header(instance, geometry.color, ui_fields.search_prefixes.color)
      decorations.set_results_header(instance, results_top, width)
      add_line_highlight(state.buf, ns, lines, results_top, theme.groups.header)
      add_line_highlight(state.buf, ns, lines, results_top + 1, theme.groups.rule)
      for line_nr = hint_start_line, #lines do
        decorations.apply_hint_line(instance, line_nr - 1, lines[line_nr])
      end
      for line_nr, result_index in pairs(geometry.result_lines) do
        result_at(results, result_index)
        render_util.line_at(lines, line_nr, 'search result geometry')
        local cells = result_cells_at(geometry, line_nr)
        apply_result_cell(instance, state.buf, line_nr, cells.fg.start_col, cells.fg, 'fg')
        apply_result_cell(instance, state.buf, line_nr, cells.bg.start_col, cells.bg, 'bg')
        apply_result_cell(instance, state.buf, line_nr, cells.sp.start_col, cells.sp, 'sp')
      end

      decorations.refresh_input_placeholders(instance)
      dynamic_preview.tick(instance, vim.uv.hrtime() / 1000000)
      dynamic_preview.sync(instance)
    end)
  end, debug.traceback)
  if not render_ok then
    local restored, restore_err = dynamic_preview.restore_render(instance, dynamic_preview_snapshot)
    if not restored then
      render_err = ('%s; rollback errors: %s'):format(render_err, tostring(restore_err))
    end
    error(render_err, 0)
  end
end

return M
