local render_util = require('hlcraft.render.util')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local dynamic_display = require('hlcraft.ui.dynamic_display')
local search_scene = require('hlcraft.ui.scene.search')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('result list renderer requires an instance', 3)
  end
  return instance.state
end

local function result_list(state)
  return tables.assert_sequence(state.results, 'result list renderer results', 3)
end

local function render_width(width)
  return numbers.assert_positive_integer(width, 'result list renderer width', 3)
end

local function optional_color(value, label)
  if value ~= nil and type(value) ~= 'string' then
    error(('%s must be a string or nil'):format(label), 3)
  end
  return value
end

local function highlight_result(result)
  if type(result) ~= 'table' then
    error('result list renderer result must be a table', 3)
  end
  if type(result.name) ~= 'string' or result.name == '' then
    error('result list renderer result name must be a non-empty string', 3)
  end
  optional_color(result.fg, 'result list renderer fg')
  optional_color(result.bg, 'result list renderer bg')
  optional_color(result.sp, 'result list renderer sp')
  return result
end

function M.build(instance, width)
  local state = instance_state(instance)
  local results = result_list(state)
  width = render_width(width)
  local gap = 3
  local name_width = math.min(36, math.max(24, width - 36))
  local remaining = math.max(18, width - name_width - (gap * 3))
  local fg_width = math.max(8, math.floor(remaining / 3))
  local bg_width = math.max(8, math.floor(remaining / 3))
  local sp_width = math.max(8, remaining - fg_width - bg_width)
  local lines = {}
  local selectable = {}
  local cells = {}
  local gap_text = string.rep(' ', gap)

  local header = table.concat({
    render_util.pad('NAME', name_width),
    render_util.pad('FG', fg_width),
    render_util.pad('BG', bg_width),
    render_util.pad('SP', sp_width),
  }, gap_text)

  lines[#lines + 1] = header
  lines[#lines + 1] = string.rep('─', vim.fn.strdisplaywidth(header))

  if #results == 0 then
    lines[#lines + 1] = search_scene.empty_message(instance)
  else
    for index, result in ipairs(results) do
      result = highlight_result(result)
      local fg = dynamic_display.list_cell(result, 'fg')
      local bg = dynamic_display.list_cell(result, 'bg')
      local sp = dynamic_display.list_cell(result, 'sp')
      local name_text = render_util.pad(render_util.truncate(result.name, name_width), name_width)
      local fg_text = render_util.pad(fg.text, fg_width)
      local bg_text = render_util.pad(bg.text, bg_width)
      local sp_text = render_util.pad(sp.text, sp_width)
      local line_nr = #lines + 1
      local fg_start = #name_text + #gap_text
      local bg_start = fg_start + #fg_text + #gap_text
      local sp_start = bg_start + #bg_text + #gap_text
      lines[line_nr] = table.concat({
        name_text,
        fg_text,
        bg_text,
        sp_text,
      }, gap_text)
      cells[line_nr] = {
        fg = vim.tbl_extend('force', fg, { start_col = fg_start }),
        bg = vim.tbl_extend('force', bg, { start_col = bg_start }),
        sp = vim.tbl_extend('force', sp, { start_col = sp_start }),
      }
      selectable[#lines] = index
    end
  end

  return lines, selectable, cells
end

return M
