local ui_fields = require('hlcraft.ui.fields')
local render_util = require('hlcraft.render.util')
local input_model = require('hlcraft.ui.input.model')
local decorations = require('hlcraft.ui.render.decorations')
local detail_values = require('hlcraft.ui.state.detail_values')
local overrides = require('hlcraft.overrides')
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

--- Build the result list lines and selectable row map for list view
--- @param instance table The Instance object holding UI state
--- @param width integer Available display width
--- @return string[] lines Buffer lines for the results area
--- @return table selectable Map of 1-based line numbers to result indices
local function build_list_lines(instance, width)
  local gap = 3
  local name_width = math.min(36, math.max(24, width - 36))
  local remaining = math.max(18, width - name_width - (gap * 3))
  local fg_width = math.max(8, math.floor(remaining / 3))
  local bg_width = math.max(8, math.floor(remaining / 3))
  local sp_width = math.max(8, remaining - fg_width - bg_width)
  local lines = {}
  local selectable = {}

  local header = table.concat({
    render_util.pad('NAME', name_width),
    render_util.pad('FG', fg_width),
    render_util.pad('BG', bg_width),
    render_util.pad('SP', sp_width),
  }, string.rep(' ', gap))

  lines[#lines + 1] = header
  lines[#lines + 1] = string.rep('─', vim.fn.strdisplaywidth(header))

  if #instance.state.results == 0 then
    lines[#lines + 1] = results_state.empty_message(instance)
  else
    for index, result in ipairs(instance.state.results) do
      lines[#lines + 1] = table.concat({
        render_util.pad(render_util.truncate(result.name, name_width), name_width),
        render_util.pad(render_util.display_color(result.fg), fg_width),
        render_util.pad(render_util.display_color(result.bg), bg_width),
        render_util.pad(render_util.display_color(result.sp), sp_width),
      }, string.rep(' ', gap))
      selectable[#lines] = index
    end
  end

  return lines, selectable
end

--- Get the default value shown for a detail menu row
--- @param result table Highlight group result with resolved colors and styles
--- @param key string Detail field key
--- @return any value Default value for the field
local function detail_fallback_value(result, key)
  if key == 'fg' then
    return result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  end
  if key == 'bg' then
    return result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  end
  if key == 'sp' then
    return result.sp
  end
  return result[key]
end

--- Convert a detail menu value to display text
--- @param value any Detail value
--- @return string Display text
local function detail_display_text(value)
  if value == nil then
    return 'unset'
  end
  if value == true then
    return 'true'
  end
  if value == false then
    return 'false'
  end
  return tostring(value)
end

--- Append a selectable editor row and register it in geometry
--- @param lines string[] Mutable list of buffer lines being built
--- @param geometry table Mutable geometry table to register editor rows in
--- @param key string Editor row key
--- @param text string Display text
--- @return table The created editor row descriptor
local function append_editor_row(lines, geometry, key, text)
  local row = {
    line = #lines + 1,
    key = key,
  }
  geometry.editor_rows[key] = row
  lines[#lines + 1] = text
  return row
end

--- Build the read-only detail menu and register row geometry
--- @param geometry table Mutable geometry table to register rows in
--- @param result table Highlight group result with resolved colors and styles
--- @param width integer Available display width
--- @return string[] lines Buffer lines for the detail menu
local function build_detail_menu_lines(geometry, result, width)
  local lines = {
    'Detail fields  (<CR> edit/toggle, s save, q back)',
  }
  local label_width = 0
  for _, key in ipairs(ui_fields.detail_order) do
    label_width = math.max(label_width, vim.fn.strdisplaywidth(ui_fields.detail_labels[key] or key))
  end

  local dirty_mark = detail_values.is_dirty(result.name) and '*' or ' '
  for _, key in ipairs(ui_fields.detail_order) do
    local fallback = detail_fallback_value(result, key)
    local value = key == 'group' and detail_values.display_group(result.name)
      or detail_values.display_value(result.name, key, fallback)
    local line = ('%s %s  %s'):format(
      dirty_mark,
      render_util.pad(ui_fields.detail_labels[key] or key, label_width),
      detail_display_text(value)
    )
    geometry.detail_menu[key] = {
      line = #lines + 1,
      key = key,
      kind = ui_fields.detail_kinds[key],
    }
    lines[#lines + 1] = render_util.truncate(line, width)
  end

  return lines
end

--- Build color editor lines and register selectable row geometry
--- @param geometry table Mutable geometry table to register rows in
--- @param result table Highlight group result with resolved colors and styles
--- @param field string Color field key ('fg', 'bg', 'sp')
--- @param width integer Available display width
--- @return string[] lines Buffer lines for the color editor
local function build_color_editor_lines(geometry, result, field, width)
  local label = ui_fields.detail_labels[field] or field:upper()
  local fallback = detail_fallback_value(result, field)
  local value = detail_values.display_value(result.name, field, fallback)
  local display_value = detail_display_text(value)
  local sample = 'The quick brown fox jumps over hlcraft.'
  local lines = {
    ('Color editor: %s'):format(label),
    string.rep('─', math.max(20, math.min(width, 36))),
    ('Current: %s'):format(display_value),
    ('Sample: %s'):format(sample),
    ('Swatch: %s'):format(display_value),
  }

  geometry.color_sample = {
    line = 4,
    text = sample,
    value = value,
    field = field,
  }
  geometry.color_swatch = {
    line = 5,
    text = display_value,
    value = value,
    field = field,
  }
  append_editor_row(
    lines,
    geometry,
    'color_keys',
    'Keys: r/R red -/+5, g/G green -/+5, b/B blue -/+5, n NONE, i input, s save, q back'
  )

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

--- Build group editor lines and register selectable row geometry
--- @param geometry table Mutable geometry table to register rows in
--- @param result table Highlight group result with resolved colors and styles
--- @param width integer Available display width
--- @return string[] lines Buffer lines for the group editor
local function build_group_editor_lines(geometry, result, width)
  local lines = {
    ('Group editor: %s'):format(result.name),
    string.rep('─', math.max(20, math.min(width, 36))),
  }

  for _, group_name in ipairs(overrides.known_groups()) do
    append_editor_row(lines, geometry, 'group:' .. group_name, group_name)
  end
  append_editor_row(lines, geometry, 'new_group', '+ New group (i)')

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

--- Build blend editor lines and register selectable row geometry
--- @param geometry table Mutable geometry table to register rows in
--- @param result table Highlight group result with resolved colors and styles
--- @param width integer Available display width
--- @return string[] lines Buffer lines for the blend editor
local function build_blend_editor_lines(geometry, result, width)
  local fallback = detail_fallback_value(result, 'blend')
  local value = detail_values.display_value(result.name, 'blend', fallback)
  local lines = {
    'Blend editor',
    string.rep('─', math.max(20, math.min(width, 36))),
    ('Current: %s'):format(detail_display_text(value)),
  }
  append_editor_row(lines, geometry, 'blend_keys', 'Keys: -/+ by 1, </> by 5, u unset, i input, s save, q back')

  for index, line in ipairs(lines) do
    lines[index] = render_util.truncate(line, width)
  end
  return lines
end

--- Build the active field editor lines, if a supported editor is open
--- @param geometry table Mutable geometry table to register rows in
--- @param result table Highlight group result with resolved colors and styles
--- @param field string Active field editor key
--- @param width integer Available display width
--- @return string[]|nil lines Buffer lines for the editor, or nil if unsupported
local function build_field_editor_lines(geometry, result, field, width)
  if field == 'fg' or field == 'bg' or field == 'sp' then
    return build_color_editor_lines(geometry, result, field, width)
  end
  if field == 'group' then
    return build_group_editor_lines(geometry, result, width)
  end
  if field == 'blend' then
    return build_blend_editor_lines(geometry, result, width)
  end
  return nil
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

--- Full render of the workspace: search inputs, results or detail form, decorations, and placeholders
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
    detail_fields = {},
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
      local detail_lines = field and build_field_editor_lines(geometry, detail_result, field, width)
        or build_detail_menu_lines(geometry, detail_result, width)
      for _, line in ipairs(detail_lines) do
        lines[#lines + 1] = line
      end
      for _, row in pairs(geometry.detail_menu) do
        row.line = results_top + row.line - 1
      end
      absolutize_editor_geometry(geometry, results_top)
    end
  else
    local result_lines, selectable = build_list_lines(instance, width)
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
