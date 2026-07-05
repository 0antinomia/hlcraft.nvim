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

local function add_line_highlight(buf, ns, lines, row1, hl)
  if lines[row1] then
    vim.api.nvim_buf_add_highlight(buf, ns, hl, row1 - 1, 0, -1)
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

  local lines = {}
  local geometry = buffer.new_geometry()
  local results_top = buffer.append_search_inputs(instance, lines, geometry, width)

  local result_lines, selectable = list.build(instance, width)
  for _, line in ipairs(result_lines) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = ''
  local hint_start_line = append_hint_lines(lines, width)
  for index, result_index in pairs(selectable) do
    geometry.result_lines[results_top + index - 1] = result_index
  end

  buffer.set_lines(instance, lines)
  buffer.finish(instance, geometry)

  decorations.set_input_header(
    instance,
    geometry.name,
    ui_fields.search_prefixes.name,
    { top_virt_lines = { decorations.help_virt_line() } }
  )
  decorations.set_input_header(instance, geometry.color, ui_fields.search_prefixes.color)
  decorations.set_results_header(instance, results_top, width)
  add_line_highlight(state.buf, ns, lines, results_top, theme.groups.header)
  add_line_highlight(state.buf, ns, lines, results_top + 1, theme.groups.rule)
  for line_nr = hint_start_line, #lines do
    decorations.apply_hint_line(instance, line_nr - 1, lines[line_nr])
  end
  for line_nr, result_index in pairs(geometry.result_lines) do
    local result = result_at(results, result_index)
    local line = render_util.line_at(lines, line_nr, 'search result geometry')
    local fg_text = render_util.display_color(result.fg)
    local bg_text = render_util.display_color(result.bg)
    local sp_text = render_util.display_color(result.sp)
    local fg_start = decorations.require_text_start(line, fg_text, 0, 'search result fg')
    local bg_start = decorations.require_text_start(line, bg_text, fg_start + #fg_text, 'search result bg')
    local sp_start = decorations.require_text_start(line, sp_text, bg_start + #bg_text, 'search result sp')
    decorations.apply_color_cell(instance, state.buf, line_nr - 1, fg_start, fg_text, result.fg, 'fg')
    decorations.apply_color_cell(instance, state.buf, line_nr - 1, bg_start, bg_text, result.bg, 'bg')
    decorations.apply_color_cell(instance, state.buf, line_nr - 1, sp_start, sp_text, result.sp, 'sp')
  end

  decorations.refresh_input_placeholders(instance)
  dynamic_preview.tick(instance, vim.uv.hrtime() / 1000000)
  dynamic_preview.sync(instance)
end

return M
