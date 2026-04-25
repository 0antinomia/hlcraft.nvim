local render_util = require('hlcraft.render.util')
local results_state = require('hlcraft.ui.state.results')

local M = {}

function M.build(instance, width)
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

return M
