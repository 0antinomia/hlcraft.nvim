local config = require('hlcraft.config')
local ui_fields = require('hlcraft.ui.fields')
local color = require('hlcraft.color')
local ui_detail = require('hlcraft.ui.detail')
local workspace = require('hlcraft.ui.workspace')
local input_model = require('hlcraft.ui.input.model')

local M = {}

local function get_detail_form_state()
  return require('hlcraft.ui.state.detail_form')
end

local function get_results_state()
  return require('hlcraft.ui.state.results')
end

--- Build virtual lines with detail info (name, colors, source, links, file) for a highlight group
--- @param instance table The Instance object holding UI state
--- @param result table Highlight group result from search
--- @return table[] Virtual lines for extmark display
--- @return table Form values snapshot for the detail fields
function M.detail_info_virt_lines(instance, result)
  local win = workspace.get_win(instance)
  local width = workspace.is_valid_win(win) and math.max(50, vim.api.nvim_win_get_width(win) - 1) or 50
  return ui_detail.build_virt_lines(result, get_detail_form_state().snapshot(instance, result), function(bg, suffix)
    return M.detail_color_hl(instance, bg, suffix)
  end, width)
end

--- Set or update an overlay extmark (placeholder text) on a buffer line
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle
--- @param key string Unique key for this overlay
--- @param row0 number 0-based row number
--- @param text string Overlay text to display
--- @param hl string Highlight group name for the overlay
--- @return nil
function M.set_overlay(instance, buf, key, row0, text, hl)
  instance.state.placeholder_marks[key] = vim.api.nvim_buf_set_extmark(buf, instance.ns, row0, 0, {
    id = instance.state.placeholder_marks[key],
    virt_text = { { text, hl } },
    virt_text_pos = 'overlay',
    right_gravity = false,
  })
end

--- Remove an overlay extmark by key
--- @param instance table The Instance object holding UI state
--- @param key string Unique key of the overlay to remove
--- @return nil
function M.clear_overlay(instance, key)
  local mark_id = instance.state.placeholder_marks[key]
  if not mark_id or not workspace.is_valid_buf(instance.state.buf) then
    return
  end
  pcall(vim.api.nvim_buf_del_extmark, instance.state.buf, instance.ns, mark_id)
  instance.state.placeholder_marks[key] = nil
end

--- Build the help keybinding hint virtual line tokens
--- @return table[] Array of {text, hl_group} pairs for virtual text
function M.help_virt_line()
  local tokens = {
    { text = 'Enter ', hl = 'Function' },
    { text = 'confirm/apply', hl = 'Comment' },
    { text = '   ' },
    { text = '? ', hl = 'Function' },
    { text = 'help', hl = 'Comment' },
    { text = '   ' },
    { text = 'q ', hl = 'Function' },
    { text = 'close', hl = 'Comment' },
    { text = '   ' },
    { text = 'Tab ', hl = 'Function' },
    { text = 'next input', hl = 'Comment' },
  }

  local virt = {}
  for _, token in ipairs(tokens) do
    virt[#virt + 1] = { token.text, token.hl or 'Normal' }
  end
  return virt
end

--- Set the virtual text header (label and optional extra text) above an input field
--- @param instance table The Instance object holding UI state
--- @param field table Field descriptor with a `line` key
--- @param label string Display label for the input
--- @param opts table|nil Options: top_virt_lines (table[]), extra (string)
--- @return nil
function M.set_input_header(instance, field, label, opts)
  opts = opts or {}
  local virt_lines = {}
  if opts.top_virt_lines then
    for _, line in ipairs(opts.top_virt_lines) do
      virt_lines[#virt_lines + 1] = line
    end
  end

  local header = { { label, instance.input_label_hl } }
  if opts.extra and opts.extra ~= '' then
    header[#header + 1] = { '  ' .. opts.extra, 'Comment' }
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
        { { separator, 'HlcraftSectionHeader' } },
      },
      virt_lines_leftcol = true,
      virt_lines_above = true,
      right_gravity = false,
    })
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
    return 'Comment'
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
  local target = line or ''
  local init = (start_col or 0) + 1
  local first = target:find(text, init, true)
  return first and (first - 1) or nil
end

--- Build placeholder values table for the detail form fields from a highlight result
--- @param result table Highlight group result with resolved colors and styles
--- @return table Map of field names to placeholder string values
function M.detail_placeholder_values(result)
  local resolved_fg = result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  local resolved_bg = result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  return {
    group = config.default_group_name(),
    fg = resolved_fg or 'NONE',
    bg = resolved_bg or 'NONE',
    sp = result.sp or 'NONE',
    bold = result.bold and 'true' or 'false',
    italic = result.italic and 'true' or 'false',
    underline = result.underline and 'true' or 'false',
    undercurl = result.undercurl and 'true' or 'false',
    strikethrough = result.strikethrough and 'true' or 'false',
    blend = result.blend ~= nil and tostring(result.blend) or '',
  }
end

--- Get the placeholder text for a given input field
--- @param instance table The Instance object holding UI state
--- @param field table Field descriptor with name/key
--- @return string|nil Placeholder text, or nil if none applicable
function M.placeholder_text_for_field(instance, field)
  local name = field.key or field.name
  if name == 'name' then
    return ui_fields.search_placeholders.name
  end
  if name == 'color' then
    return ui_fields.search_placeholders.color
  end
  if not instance.state.detail_index then
    return nil
  end
  local result = get_results_state().current_detail_result(instance)
  if not result then
    return nil
  end
  return M.detail_placeholder_values(result)[name]
end

--- Update overlay placeholders for all input fields based on current values
--- @param instance table The Instance object holding UI state
--- @return nil
function M.refresh_input_placeholders(instance)
  if not workspace.is_valid_buf(instance.state.buf) then
    return
  end

  for _, field in ipairs(instance.state.geometry.inputs or {}) do
    local key = field.key or field.name
    local text = M.placeholder_text_for_field(instance, field)
    local value = input_model.field_line_text(instance, field)
    if value == '' and text and text ~= '' then
      M.set_overlay(instance, instance.state.buf, key, field.line - 1, tostring(text), 'Comment')
    else
      M.clear_overlay(instance, key)
    end
  end
end

return M
