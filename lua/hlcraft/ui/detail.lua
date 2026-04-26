local source = require('hlcraft.source')
local overrides = require('hlcraft.overrides')
local render_util = require('hlcraft.render.util')
local highlights = require('hlcraft.highlights')
local theme = require('hlcraft.ui.theme')

local M = {}

--- Build virtual lines for the detail info panel (name, colors, attrs, source, links, file)
--- @param result table Highlight group result with resolved colors and metadata
--- @param get_color_hl function Callback(bg, suffix) -> string highlight name
--- @param width integer Display width
--- @return table[] Array of virtual line token arrays
function M.build_virt_lines(result, get_color_hl, width)
  local src_file, src_line = source.get_source(result.name)
  local source_text = src_file and ('%s:%s'):format(src_file, tostring(src_line or '?')) or '-'
  local chain = result.link_chain and #result.link_chain > 0 and table.concat(result.link_chain, ' -> ') or '-'
  local persist_path = overrides.file_path(result.name) or '-'

  local resolved_fg = result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  local resolved_bg = result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  local fg_text = render_util.display_color(resolved_fg)
  local bg_text = render_util.display_color(resolved_bg)
  local sp_text = render_util.display_color(result.sp)

  return {
    { { string.rep('─', math.max(20, width or 20)), theme.groups.rule } },
    { { ('Name: %s'):format(result.name), theme.groups.text } },
    {
      { 'Colors: FG ', theme.groups.text },
      { fg_text, get_color_hl(resolved_fg, 'fg') },
      { '   BG ', theme.groups.text },
      { bg_text, get_color_hl(resolved_bg, 'bg') },
      { '   SP ', theme.groups.text },
      { sp_text, get_color_hl(result.sp, 'sp') },
    },
    {
      {
        ('Attrs:  %s   Blend %s   Dist %s'):format(
          highlights.bool_attrs(result),
          result.blend ~= nil and tostring(result.blend) or '-',
          result.distance and ('%.1f'):format(result.distance) or '-'
        ),
        theme.groups.text,
      },
    },
    { { ('Source: %s'):format(render_util.truncate(source_text, 88)), theme.groups.text } },
    { { ('Links:  %s'):format(render_util.truncate(chain, 88)), theme.groups.text } },
    { { '' } },
    { { ('File: %s'):format(render_util.truncate(persist_path, 88)), theme.groups.text } },
    { { '' } },
  }
end

return M
