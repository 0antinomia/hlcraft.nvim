local color = require('hlcraft.core.color')
local numbers = require('hlcraft.core.number')
local ui_detail = require('hlcraft.ui.detail')
local window = require('hlcraft.ui.workspace.window')
local line_highlights = require('hlcraft.ui.render.line_highlights')
local placeholders = require('hlcraft.ui.render.placeholders')
local theme = require('hlcraft.ui.theme')

local M = {}

--- Build virtual lines with detail info (name, colors, source, links, file) for a highlight group
--- @param instance table The Instance object holding UI state
--- @param result table Highlight group result from search
--- @return table[] Virtual lines for extmark display
function M.detail_info_virt_lines(instance, result)
  local win = window.get_win(instance)
  local width = window.is_valid_win(win) and math.max(50, vim.api.nvim_win_get_width(win) - 1) or 50
  return ui_detail.build_virt_lines(result, function(bg, suffix)
    return M.detail_color_hl(instance, bg, suffix)
  end, width)
end

--- Build the help keybinding hint virtual line tokens
--- @return table[] Array of {text, hl_group} pairs for virtual text
function M.help_virt_line()
  local tokens = {
    { text = '? ', hl = theme.groups.key },
    { text = 'help', hl = theme.groups.muted },
    { text = '   ' },
    { text = 'q ', hl = theme.groups.key },
    { text = 'close', hl = theme.groups.muted },
  }

  local virt = {}
  for _, token in ipairs(tokens) do
    virt[#virt + 1] = { token.text, token.hl or theme.groups.text }
  end
  return virt
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
  return opts
end

--- Set the virtual text header (label and optional extra text) above an input field
--- @param instance table The Instance object holding UI state
--- @param field table Field descriptor with a `line` key
--- @param label string Display label for the input
--- @param opts table|nil Options: top_virt_lines (table[]), extra (string)
--- @return nil
function M.set_input_header(instance, field, label, opts)
  opts = optional_opts(opts, 'input header options')
  local virt_lines = {}
  if opts.top_virt_lines then
    for _, line in ipairs(opts.top_virt_lines) do
      virt_lines[#virt_lines + 1] = line
    end
  end

  local header = { { label, instance.input_label_hl } }
  if opts.extra and opts.extra ~= '' then
    header[#header + 1] = { '  ' .. opts.extra, theme.groups.muted }
  end
  virt_lines[#virt_lines + 1] = header

  local key = label .. ':' .. field.line
  instance.state.input_marks[key] = vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, field.line - 1, 0, {
    id = instance.state.input_marks[key],
    virt_lines = virt_lines,
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
  local separator = string.rep('─', math.max(20, width))
  instance.state.input_marks.results_header =
    vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, row1 - 1, 0, {
      id = instance.state.input_marks.results_header,
      virt_lines = {
        { { separator, theme.groups.rule } },
      },
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false,
    })
end

function M.set_detail_menu_header(instance, row1, result)
  local detail_virt_lines = select(1, M.detail_info_virt_lines(instance, result))
  instance.state.input_marks.detail_menu_header =
    vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, row1 - 1, 0, {
      id = instance.state.input_marks.detail_menu_header,
      virt_lines = detail_virt_lines,
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false,
    })
end

local function add_row_highlight(instance, buf, line_idx, line_len, hl, start_col, end_col)
  if start_col and start_col < line_len then
    vim.api.nvim_buf_add_highlight(buf, instance.ns, hl, line_idx, start_col, math.min(end_col or line_len, line_len))
  end
end

function M.apply_detail_menu_highlights(instance, detail_menu, dirty)
  local buf = instance.state.buf
  if not window.is_valid_buf(buf) then
    return
  end

  for _, row in pairs(assert_detail_menu(detail_menu)) do
    local line_idx = row.line - 1
    local line = vim.api.nvim_buf_get_lines(buf, line_idx, line_idx + 1, false)[1] or ''
    local line_len = #line

    if dirty and line_len > 0 then
      vim.api.nvim_buf_add_highlight(buf, instance.ns, theme.groups.dirty, line_idx, 0, 1)
    end
    add_row_highlight(instance, buf, line_idx, line_len, theme.groups.section, row.label_start_col, row.label_end_col)
    add_row_highlight(instance, buf, line_idx, line_len, theme.groups.value, row.value_col, nil)
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
  if not bg or bg == 'NONE' then
    return
  end
  local hl_name = ('hlcraft_ui_%s_%s_%d_%d'):format(instance.id, suffix, line_idx, start_col)
  vim.api.nvim_set_hl(instance.ns, hl_name, {
    bg = bg,
    fg = color.contrast_fg(bg),
    bold = true,
  })
  vim.api.nvim_buf_add_highlight(buf, instance.ns, hl_name, line_idx, start_col, start_col + #text)
end

--- Create or retrieve a highlight group for a detail view color swatch
--- @param instance table The Instance object holding UI state
--- @param bg string Background color value (#RRGGBB or 'NONE')
--- @param suffix string Color key suffix ('fg', 'bg', 'sp')
--- @return string Highlight group name
function M.detail_color_hl(instance, bg, suffix)
  if not bg or bg == 'NONE' then
    return theme.groups.muted
  end
  local hl_name = ('hlcraft_ui_%s_detail_%s_%s'):format(instance.id, suffix, bg:gsub('#', ''))
  vim.api.nvim_set_hl(instance.ns, hl_name, {
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
  if
    start_col ~= nil
    and (
      type(start_col) ~= 'number'
      or not numbers.is_finite(start_col)
      or start_col < 0
      or math.floor(start_col) ~= start_col
    )
  then
    error('search start column must be a non-negative integer', 2)
  end

  local init = (start_col or 0) + 1
  local first = line:find(text, init, true)
  return first and (first - 1) or nil
end

M.refresh_input_placeholders = placeholders.refresh

return M
