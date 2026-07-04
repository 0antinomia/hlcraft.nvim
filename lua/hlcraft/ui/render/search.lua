local render_util = require('hlcraft.render.util')
local ui_fields = require('hlcraft.ui.fields')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local buffer = require('hlcraft.ui.render.buffer')
local decorations = require('hlcraft.ui.render.decorations')
local hints = require('hlcraft.ui.render.hints')
local list = require('hlcraft.ui.render.list')
local theme = require('hlcraft.ui.theme')

local M = {}

function M.render(instance)
  local width = buffer.prepare(instance)
  if not width then
    return
  end

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
  if lines[results_top] then
    vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.header, results_top - 1, 0, -1)
  end
  if lines[results_top + 1] then
    vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, theme.groups.rule, results_top, 0, -1)
  end
  decorations.apply_hint_line(instance, #lines - 1, lines[#lines])
  for line_nr, result_index in pairs(geometry.result_lines) do
    local result = instance.state.results[result_index]
    local line = lines[line_nr] or ''
    local fg_text = render_util.display_color(result.fg)
    local bg_text = render_util.display_color(result.bg)
    local sp_text = render_util.display_color(result.sp)
    local fg_start = decorations.find_text_start(line, fg_text, 0)
    local bg_start = decorations.find_text_start(line, bg_text, (fg_start or 0) + #fg_text)
    local sp_start = decorations.find_text_start(line, sp_text, (bg_start or 0) + #bg_text)
    decorations.apply_color_cell(instance, instance.state.buf, line_nr - 1, fg_start or 0, fg_text, result.fg, 'fg')
    decorations.apply_color_cell(instance, instance.state.buf, line_nr - 1, bg_start or 0, bg_text, result.bg, 'bg')
    decorations.apply_color_cell(instance, instance.state.buf, line_nr - 1, sp_start or 0, sp_text, result.sp, 'sp')
  end

  decorations.refresh_input_placeholders(instance)
  dynamic_preview.tick(instance, vim.uv.hrtime() / 1000000)
  dynamic_preview.sync(instance)
end

return M
