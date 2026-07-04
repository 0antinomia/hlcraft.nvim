local source = require('hlcraft.core.source')
local render_util = require('hlcraft.render.util')
local highlights = require('hlcraft.core.highlights')
local session = require('hlcraft.ui.session')
local theme = require('hlcraft.ui.theme')

local M = {}

local label_width = 8

local function label_token(label)
  return { render_util.pad(label .. ':', label_width), theme.groups.section }
end

local function value_token(value, hl)
  return { tostring(value or '-'), hl or theme.groups.value }
end

local function info_line(label, value, value_hl)
  return {
    label_token(label),
    value_token(value, value_hl),
  }
end

--- Build virtual lines for the detail info panel (name, colors, attrs, source, links, file)
--- @param result table Highlight group result with resolved colors and metadata
--- @param get_color_hl function Callback(bg, suffix) -> string highlight name
--- @param width integer Display width
--- @return table[] Array of virtual line token arrays
function M.build_virt_lines(result, get_color_hl, width)
  local value_width = math.max(8, (width or 96) - label_width)
  local src_file, src_line = source.get_source(result.name)
  local source_text = src_file and ('%s:%s'):format(src_file, tostring(src_line or '?')) or '-'
  local chain = result.link_chain and #result.link_chain > 0 and table.concat(result.link_chain, ' -> ') or '-'
  local persist_path = session.file_path(result.name) or '-'

  local resolved_fg = result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  local resolved_bg = result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  local fg_text = render_util.display_color(resolved_fg)
  local bg_text = render_util.display_color(resolved_bg)
  local sp_text = render_util.display_color(result.sp)
  local attrs_text = highlights.bool_attrs(result)
  local blend_text = result.blend ~= nil and tostring(result.blend) or '-'
  local dist_text = result.distance and ('%.1f'):format(result.distance) or '-'

  return {
    { { string.rep('─', math.max(20, width or 20)), theme.groups.rule } },
    info_line('Name', result.name, theme.groups.title),
    {
      label_token('Colors'),
      { 'FG ', theme.groups.muted },
      { fg_text, get_color_hl(resolved_fg, 'fg') },
      { '  BG ', theme.groups.muted },
      { bg_text, get_color_hl(resolved_bg, 'bg') },
      { '  SP ', theme.groups.muted },
      { sp_text, get_color_hl(result.sp, 'sp') },
    },
    {
      label_token('Attrs'),
      value_token(attrs_text),
      { '  Blend ', theme.groups.muted },
      value_token(blend_text),
      { '  Dist ', theme.groups.muted },
      value_token(dist_text),
    },
    info_line('Source', render_util.truncate(source_text, value_width), theme.groups.muted),
    info_line('Links', render_util.truncate(chain, value_width), theme.groups.muted),
    { { '' } },
    info_line('File', render_util.truncate(persist_path, value_width), theme.groups.muted),
    { { '' } },
  }
end

return M
