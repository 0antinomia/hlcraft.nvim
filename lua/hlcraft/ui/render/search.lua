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
  if type(instance.ns) ~= 'number' then
    error('search renderer namespace must be a number', 3)
  end
  if not numbers.is_finite(instance.ns) or math.floor(instance.ns) ~= instance.ns or instance.ns < 0 then
    error('search renderer namespace must be a non-negative finite integer', 3)
  end
  return instance.ns
end

local function result_list(state)
  if type(state.results) ~= 'table' then
    error('search renderer results must be a table', 3)
  end
  if not tables.is_sequence(state.results) then
    error('search renderer results must be a sequence', 3)
  end
  return state.results
end

local function positive_integer(value, label)
  if type(value) ~= 'number' then
    error(('%s must be a number'):format(label), 3)
  end
  if not numbers.is_finite(value) or math.floor(value) ~= value or value < 1 then
    error(('%s must be a positive finite integer'):format(label), 3)
  end
  return value
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
  lines[#lines + 1] = hints.search()
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
  decorations.apply_hint_line(instance, #lines - 1, lines[#lines])
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
