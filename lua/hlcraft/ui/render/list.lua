local render_util = require('hlcraft.render.util')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local search_scene = require('hlcraft.ui.scene.search')

local M = {}

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('result list renderer requires an instance', 3)
  end
  return instance.state
end

local function result_list(state)
  if type(state.results) ~= 'table' then
    error('result list renderer results must be a table', 3)
  end
  if not tables.is_sequence(state.results) then
    error('result list renderer results must be a sequence', 3)
  end
  return state.results
end

local function render_width(width)
  if type(width) ~= 'number' then
    error('result list renderer width must be a number', 3)
  end
  if not numbers.is_finite(width) or math.floor(width) ~= width or width < 1 then
    error('result list renderer width must be a positive finite integer', 3)
  end
  return width
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

  local header = table.concat({
    render_util.pad('NAME', name_width),
    render_util.pad('FG', fg_width),
    render_util.pad('BG', bg_width),
    render_util.pad('SP', sp_width),
  }, string.rep(' ', gap))

  lines[#lines + 1] = header
  lines[#lines + 1] = string.rep('─', vim.fn.strdisplaywidth(header))

  if #results == 0 then
    lines[#lines + 1] = search_scene.empty_message(instance)
  else
    for index, result in ipairs(results) do
      result = highlight_result(result)
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

return M
