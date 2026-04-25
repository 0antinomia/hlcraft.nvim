local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local input_model = require('hlcraft.ui.input.model')
local decorations = require('hlcraft.ui.render.decorations')
local detail_menu = require('hlcraft.ui.render.detail_menu')
local field_editor = require('hlcraft.ui.render.field_editor')
local list = require('hlcraft.ui.render.list')
local results_state = require('hlcraft.ui.state.results')
local workspace = require('hlcraft.ui.workspace')

local M = {}

--- Create a new input field descriptor table
--- @param name string Field name
--- @param kind string Field kind ('name', 'color', 'detail')
--- @param line number 1-based line number where field starts
--- @param extra table|nil Additional properties (key, label, width)
--- @return table Field descriptor
local function new_input_field(name, kind, line, extra)
  return vim.tbl_extend('force', {
    name = name,
    kind = kind,
    line = line,
  }, extra or {})
end

--- Append an input field line to the lines list and register it in geometry
--- @param lines string[] Mutable list of buffer lines being built
--- @param geometry table Mutable geometry table to register the field in
--- @param name string Field name
--- @param kind string Field kind ('name', 'color', 'detail')
--- @param value string Current value to display
--- @param extra table|nil Additional properties (key, label, width)
--- @return table The created field descriptor
local function append_input(lines, geometry, name, kind, value, extra)
  local field = new_input_field(name, kind, #lines + 1, extra)
  geometry[name] = field
  geometry.inputs[#geometry.inputs + 1] = field
  lines[#lines + 1] = render_util.truncate(input_model.normalize_single_line(value), extra and extra.width or math.huge)
  return field
end

--- Convert local editor geometry rows to absolute buffer rows
--- @param geometry table Mutable geometry table with local editor geometry
--- @param results_top number 1-based line where detail/editor content starts
--- @return nil
local function absolutize_editor_geometry(geometry, results_top)
  for _, row in pairs(geometry.editor_rows) do
    row.line = results_top + row.line - 1
  end
  for _, key in ipairs({ 'color_sample', 'color_swatch' }) do
    if geometry[key] then
      geometry[key].line = results_top + geometry[key].line - 1
    end
  end
end

--- Replace the entire buffer content with the given lines, guarded by rendering flag
--- @param instance table The Instance object holding UI state
--- @param lines string[] Lines to write to the buffer
--- @return nil
local function set_buffer_lines(instance, lines)
  instance.state.rendering = true
  local ok, err = pcall(function()
    vim.bo[instance.state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(instance.state.buf, 0, -1, false, lines)
  end)
  instance.state.rendering = false
  if not ok then
    vim.notify(('hlcraft: buffer render failed: %s'):format(tostring(err)), vim.log.levels.WARN)
  end
end

--- Full render of the workspace: search inputs, results or detail editor, decorations, and placeholders
--- @param instance table The Instance object holding UI state
--- @return nil
function M.render(instance)
  if not workspace.is_valid_buf(instance.state.buf) then
    return
  end

  local win = workspace.get_win(instance)
  if not workspace.is_valid_win(win) then
    return
  end

  local width = math.max(50, vim.api.nvim_win_get_width(win) - 1)
  local lines = {}
  local geometry = {
    inputs = {},
    result_lines = {},
    detail_menu = {},
    editor_rows = {},
  }

  lines[#lines + 1] = ''
  append_input(lines, geometry, 'name', 'name', instance.state.name_query, { width = width })
  append_input(lines, geometry, 'color', 'color', instance.state.color_query, { width = width })

  lines[#lines + 1] = ''
  local results_top = #lines + 1
  local detail_result = instance.state.detail_index and results_state.current_detail_result(instance) or nil

  if instance.state.detail_index then
    if detail_result then
      local field = instance.state.field_editor and instance.state.field_editor.field or nil
      local detail_lines = field and field_editor.build(geometry, detail_result, field, width)
        or detail_menu.build(geometry, detail_result, width)
      for _, line in ipairs(detail_lines) do
        lines[#lines + 1] = line
      end
      for _, row in pairs(geometry.detail_menu) do
        row.line = results_top + row.line - 1
      end
      absolutize_editor_geometry(geometry, results_top)
    end
  else
    local result_lines, selectable = list.build(instance, width)
    for _, line in ipairs(result_lines) do
      lines[#lines + 1] = line
    end
    for index, result_index in pairs(selectable) do
      geometry.result_lines[results_top + index - 1] = result_index
    end
  end

  set_buffer_lines(instance, lines)
  vim.api.nvim_buf_clear_namespace(instance.state.buf, instance.ns, 0, -1)
  instance.state.input_marks = {}
  instance.state.placeholder_marks = {}
  vim.api.nvim_set_hl(instance.ns, instance.input_label_hl, { fg = '#4fa6ff', bold = true })
  vim.api.nvim_set_hl(instance.ns, 'HlcraftSectionHeader', { fg = '#4fa6ff', bold = true })
  vim.api.nvim_set_hl(instance.ns, 'HlcraftSectionText', { fg = '#7f98ff', italic = true })
  vim.api.nvim_set_hl(instance.ns, 'HlcraftColumnHeader', { fg = '#c0cbff', bold = true })
  instance.state.geometry = geometry
  input_model.set_input_extmarks(instance)

  decorations.set_input_header(
    instance,
    geometry.name,
    ui_fields.search_prefixes.name,
    { top_virt_lines = { decorations.help_virt_line() } }
  )
  decorations.set_input_header(instance, geometry.color, ui_fields.search_prefixes.color)
  if instance.state.detail_index and detail_result then
    local detail_virt_lines = select(1, decorations.detail_info_virt_lines(instance, detail_result))
    instance.state.input_marks.detail_menu_header =
      vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, results_top - 1, 0, {
        id = instance.state.input_marks.detail_menu_header,
        virt_lines = detail_virt_lines,
        virt_lines_leftcol = true,
        virt_lines_above = true,
        right_gravity = false,
      })
    if geometry.color_sample then
      local line = lines[geometry.color_sample.line] or ''
      local start_col = decorations.find_text_start(line, geometry.color_sample.text, 0)
      decorations.apply_color_cell(
        instance,
        instance.state.buf,
        geometry.color_sample.line - 1,
        start_col or 0,
        geometry.color_sample.text,
        geometry.color_sample.value,
        geometry.color_sample.field
      )
    end
    if geometry.color_swatch then
      local line = lines[geometry.color_swatch.line] or ''
      local start_col = decorations.find_text_start(line, geometry.color_swatch.text, 0)
      decorations.apply_color_cell(
        instance,
        instance.state.buf,
        geometry.color_swatch.line - 1,
        start_col or 0,
        geometry.color_swatch.text,
        geometry.color_swatch.value,
        geometry.color_swatch.field
      )
    end
  else
    decorations.set_results_header(instance, results_top, width)
    if lines[results_top] then
      vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, 'HlcraftColumnHeader', results_top - 1, 0, -1)
    end
    if lines[results_top + 1] then
      vim.api.nvim_buf_add_highlight(instance.state.buf, instance.ns, 'HlcraftSectionHeader', results_top, 0, -1)
    end
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
  end

  decorations.refresh_input_placeholders(instance)
end

return M
