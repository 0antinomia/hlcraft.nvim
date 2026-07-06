local color = require('hlcraft.core.color')
local numbers = require('hlcraft.core.number')
local ui_detail = require('hlcraft.ui.detail')
local window = require('hlcraft.ui.workspace.window')
local buffer_lines = require('hlcraft.ui.buffer_lines')
local line_highlights = require('hlcraft.ui.render.line_highlights')
local placeholders = require('hlcraft.ui.render.placeholders')
local theme = require('hlcraft.ui.theme')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('render decorations require an instance', 3)
  end
  return instance.state
end

local function instance_namespace(instance)
  if type(instance.ns) ~= 'number' then
    error('render decoration namespace must be a number', 3)
  end
  if not numbers.is_integer(instance.ns, 0) then
    error('render decoration namespace must be a non-negative finite integer', 3)
  end
  return instance.ns
end

local function instance_id(instance)
  if type(instance.id) ~= 'string' or instance.id == '' then
    error('render decoration instance id must be a non-empty string', 3)
  end
  return instance.id
end

local function input_label_hl(instance)
  if type(instance.input_label_hl) ~= 'string' or instance.input_label_hl == '' then
    error('input label highlight must be a non-empty string', 3)
  end
  return instance.input_label_hl
end

local function input_marks(state)
  if type(state.input_marks) ~= 'table' then
    error('render decoration input marks must be a table', 3)
  end
  return state.input_marks
end

local function valid_buffer(buf)
  return type(buf) == 'number' and window.is_valid_buf(buf)
end

local function positive_integer(value, label)
  return numbers.assert_positive_integer(value, label, 3)
end

local function non_negative_integer(value, label)
  return numbers.assert_non_negative_integer(value, label, 3)
end

local function extmark_id(value, label)
  if value == nil then
    return nil
  end
  return numbers.assert_positive_integer(value, label, 3)
end

local function non_empty_string(value, label)
  if type(value) ~= 'string' or value == '' then
    error(('%s must be a non-empty string'):format(label), 3)
  end
  return value
end

local function optional_string(value, label)
  if value ~= nil and type(value) ~= 'string' then
    error(('%s must be a string or nil'):format(label), 3)
  end
  return value
end

local function optional_boolean(value, label)
  if value ~= nil and type(value) ~= 'boolean' then
    error(('%s must be boolean or nil'):format(label), 3)
  end
  return value == true
end

local function field_line(field)
  if type(field) ~= 'table' then
    error('input header field must be a table', 3)
  end
  return positive_integer(field.line, 'input header field line')
end

--- Build virtual lines with detail info (name, colors, source, links, file) for a highlight group
--- @param instance table The Instance object holding UI state
--- @param result table Highlight group result from search
--- @return table[] Virtual lines for extmark display
function M.detail_info_virt_lines(instance, result)
  instance_state(instance)
  local win = window.get_win(instance)
  local width = window.is_valid_win(win) and math.max(50, vim.api.nvim_win_get_width(win) - 1) or 50
  return ui_detail.build_virt_lines(result, function(bg, suffix)
    return M.detail_color_hl(instance, bg, suffix)
  end, width)
end

M.apply_hint_line = line_highlights.apply_hint_line
M.apply_label_line = line_highlights.apply_label_line
M.apply_workbench_line_highlights = line_highlights.apply_workbench_lines

local function assert_detail_menu(detail_menu)
  if type(detail_menu) ~= 'table' then
    error('detail menu geometry must be a table', 3)
  end
  return detail_menu
end

local function optional_opts(opts, label)
  if opts == nil then
    return {}
  end
  if type(opts) ~= 'table' then
    error(('%s must be a table'):format(label), 3)
  end
  for key in pairs(opts) do
    if key ~= 'extra' then
      error(('unknown %s option: %s'):format(label, tostring(key)), 3)
    end
  end
  return opts
end

local function detail_row(row)
  if type(row) ~= 'table' then
    error('detail menu row must be a table', 3)
  end
  row.line = positive_integer(row.line, 'detail menu row line')
  return row
end

--- Set the virtual text header (label and optional extra text) above an input field
--- @param instance table The Instance object holding UI state
--- @param field table Field descriptor with a `line` key
--- @param label string Display label for the input
--- @param opts table|nil Options: extra (string)
--- @return nil
function M.set_input_header(instance, field, label, opts)
  local state = instance_state(instance)
  opts = optional_opts(opts, 'input header options')
  local line = field_line(field)
  label = non_empty_string(label, 'input header label')
  local extra = optional_string(opts.extra, 'input header extra')
  local marks = input_marks(state)
  local ns = instance_namespace(instance)
  if not valid_buffer(state.buf) then
    return
  end

  local header = { { label, input_label_hl(instance) } }
  if extra and extra ~= '' then
    header[#header + 1] = { '  ' .. extra, theme.groups.muted }
  end

  local key = label .. ':' .. line
  marks[key] = vim.api.nvim_buf_set_extmark(state.buf, ns, line - 1, 0, {
    id = extmark_id(marks[key], 'input header extmark id'),
    virt_lines = { header },
    virt_lines_leftcol = true,
    virt_lines_above = true,
    right_gravity = false,
  })
end

--- Set the section separator virtual line above the results area
--- @param instance table The Instance object holding UI state
--- @param row1 number 1-based row number where results start
--- @param width integer Display width for the separator
--- @return nil
function M.set_results_header(instance, row1, width)
  local state = instance_state(instance)
  local marks = input_marks(state)
  local ns = instance_namespace(instance)
  row1 = positive_integer(row1, 'results header row')
  width = positive_integer(width, 'results header width')
  if not valid_buffer(state.buf) then
    return
  end

  local separator = string.rep('─', math.max(20, width))
  marks.results_header = vim.api.nvim_buf_set_extmark(state.buf, ns, row1 - 1, 0, {
    id = extmark_id(marks.results_header, 'results header extmark id'),
    virt_lines = {
      { { separator, theme.groups.rule } },
    },
    virt_lines_leftcol = true,
    virt_lines_above = true,
    right_gravity = false,
  })
end

function M.set_detail_menu_header(instance, row1, result)
  local state = instance_state(instance)
  local marks = input_marks(state)
  local ns = instance_namespace(instance)
  row1 = positive_integer(row1, 'detail menu header row')
  local detail_virt_lines = select(1, M.detail_info_virt_lines(instance, result))
  if not valid_buffer(state.buf) then
    return
  end

  marks.detail_menu_header = vim.api.nvim_buf_set_extmark(state.buf, ns, row1 - 1, 0, {
    id = extmark_id(marks.detail_menu_header, 'detail menu header extmark id'),
    virt_lines = detail_virt_lines,
    virt_lines_leftcol = true,
    virt_lines_above = true,
    right_gravity = false,
  })
end

local function add_row_highlight(ns, buf, line_idx, line_len, hl, start_col, end_col)
  line_idx = non_negative_integer(line_idx, 'detail menu highlight line')
  if start_col == nil then
    return
  end
  start_col = non_negative_integer(start_col, 'detail menu highlight start column')
  if start_col < line_len then
    if end_col ~= nil then
      end_col = non_negative_integer(end_col, 'detail menu highlight end column')
    end
    vim.api.nvim_buf_add_highlight(buf, ns, hl, line_idx, start_col, math.min(end_col or line_len, line_len))
  end
end

function M.apply_detail_menu_highlights(instance, detail_menu, dirty)
  local state = instance_state(instance)
  local ns = instance_namespace(instance)
  dirty = optional_boolean(dirty, 'detail dirty flag')
  local buf = state.buf
  if not valid_buffer(buf) then
    return
  end

  for _, row in pairs(assert_detail_menu(detail_menu)) do
    row = detail_row(row)
    local line_idx = row.line - 1
    local line = buffer_lines.line(buf, line_idx, 'detail menu geometry')
    local line_len = #line

    if dirty and line_len > 0 then
      vim.api.nvim_buf_add_highlight(buf, ns, theme.groups.dirty, line_idx, 0, 1)
    end
    add_row_highlight(ns, buf, line_idx, line_len, theme.groups.section, row.label_start_col, row.label_end_col)
    add_row_highlight(ns, buf, line_idx, line_len, theme.groups.value, row.value_col, nil)
  end
end

--- Apply a color cell highlight to a text range in the buffer
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle
--- @param line_idx number 0-based line index
--- @param start_col number 0-based start column
--- @param text string Display text for the color cell
--- @param bg string Background color value (#RRGGBB or 'NONE')
--- @param suffix string Color key suffix ('fg', 'bg', 'sp')
--- @return nil
function M.apply_color_cell(instance, buf, line_idx, start_col, text, bg, suffix)
  instance_state(instance)
  local ns = instance_namespace(instance)
  local id = instance_id(instance)
  if not valid_buffer(buf) then
    error('color cell target buffer must be valid', 3)
  end
  line_idx = non_negative_integer(line_idx, 'color cell line')
  start_col = non_negative_integer(start_col, 'color cell start column')
  text = non_empty_string(text, 'color cell text')
  suffix = non_empty_string(suffix, 'color cell suffix')
  if bg == nil or bg == 'NONE' then
    return
  end
  bg = non_empty_string(bg, 'color cell background')

  local hl_name = ('hlcraft_ui_%s_%s_%d_%d'):format(id, suffix, line_idx, start_col)
  vim.api.nvim_set_hl(ns, hl_name, {
    bg = bg,
    fg = color.contrast_fg(bg),
    bold = true,
  })
  vim.api.nvim_buf_add_highlight(buf, ns, hl_name, line_idx, start_col, start_col + #text)
end

function M.apply_dynamic_cell(instance, buf, line_idx, start_col, text)
  instance_state(instance)
  local ns = instance_namespace(instance)
  if not valid_buffer(buf) then
    error('dynamic cell target buffer must be valid', 3)
  end
  line_idx = non_negative_integer(line_idx, 'dynamic cell line')
  start_col = non_negative_integer(start_col, 'dynamic cell start column')
  text = non_empty_string(text, 'dynamic cell text')

  vim.api.nvim_buf_add_highlight(buf, ns, theme.groups.dynamic, line_idx, start_col, start_col + #text)
end

--- Create or retrieve a highlight group for a detail view color swatch
--- @param instance table The Instance object holding UI state
--- @param bg string Background color value (#RRGGBB or 'NONE')
--- @param suffix string Color key suffix ('fg', 'bg', 'sp')
--- @return string Highlight group name
function M.detail_color_hl(instance, bg, suffix)
  suffix = non_empty_string(suffix, 'detail color suffix')
  if bg == nil or bg == 'NONE' then
    return theme.groups.muted
  end
  instance_state(instance)
  local ns = instance_namespace(instance)
  local id = instance_id(instance)
  bg = non_empty_string(bg, 'detail color background')

  local hl_name = ('hlcraft_ui_%s_detail_%s_%s'):format(id, suffix, bg:gsub('#', ''))
  vim.api.nvim_set_hl(ns, hl_name, {
    bg = bg,
    fg = color.contrast_fg(bg),
    bold = true,
  })
  return hl_name
end

--- Find the 0-based column where a text substring first occurs on or after start_col
--- @param line string|nil Line to search in
--- @param text string Text to find
--- @param start_col number|nil 0-based column to start searching from
--- @return number|nil 0-based column where text starts, or nil if not found
function M.find_text_start(line, text, start_col)
  if type(line) ~= 'string' then
    error('search line must be a string', 2)
  end
  if type(text) ~= 'string' then
    error('search text must be a string', 2)
  end
  if start_col ~= nil and (not numbers.is_integer(start_col, 0)) then
    error('search start column must be a non-negative integer', 2)
  end

  local init = (start_col or 0) + 1
  local first = line:find(text, init, true)
  return first and (first - 1) or nil
end

function M.require_text_start(line, text, start_col, label)
  if type(label) ~= 'string' or label == '' then
    error('required text lookup label must be a non-empty string', 2)
  end

  local col = M.find_text_start(line, text, start_col)
  if col == nil then
    error(('%s did not contain %q'):format(label, text), 2)
  end
  return col
end

M.refresh_input_placeholders = placeholders.refresh

return M
