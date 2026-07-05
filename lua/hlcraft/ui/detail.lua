local source = require('hlcraft.core.source')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local render_util = require('hlcraft.render.util')
local highlights = require('hlcraft.core.highlights')
local session = require('hlcraft.ui.session')
local theme = require('hlcraft.ui.theme')

local M = {}

local label_width = 8

local function highlight_result(result)
  if type(result) ~= 'table' or type(result.name) ~= 'string' or result.name == '' then
    error('detail info requires a highlight result', 3)
  end
  return result
end

local function color_highlighter(get_color_hl)
  if type(get_color_hl) ~= 'function' then
    error('detail info requires a color highlighter callback', 3)
  end
  return get_color_hl
end

local function display_width(width)
  if width == nil then
    return 96
  end
  if type(width) ~= 'number' or not numbers.is_finite(width) or math.floor(width) ~= width or width < 0 then
    error('detail info width must be a non-negative finite integer', 3)
  end
  return width
end

local function optional_finite_number(value, label)
  if value == nil then
    return nil
  end
  if type(value) ~= 'number' or not numbers.is_finite(value) then
    error(('%s must be a finite number'):format(label), 3)
  end
  return value
end

local function link_chain_text(link_chain)
  if link_chain == nil then
    return '-'
  end
  if type(link_chain) ~= 'table' or not tables.is_sequence(link_chain) then
    error('detail info link chain must be a sequence', 3)
  end
  if next(link_chain) == nil then
    return '-'
  end
  for index, name in ipairs(link_chain) do
    if type(name) ~= 'string' or name == '' then
      error(('detail info link chain entry %d must be a non-empty string'):format(index), 3)
    end
  end
  return table.concat(link_chain, ' -> ')
end

local function label_token(label)
  return { render_util.pad(label .. ':', label_width), theme.groups.section }
end

local function value_token(value, hl)
  return { value == nil and '-' or tostring(value), hl or theme.groups.value }
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
  result = highlight_result(result)
  get_color_hl = color_highlighter(get_color_hl)
  width = display_width(width)

  local value_width = math.max(8, width - label_width)
  local src_file, src_line = source.get_source(result.name)
  local source_text = src_file and ('%s:%s'):format(src_file, tostring(src_line or '?')) or '-'
  local chain = link_chain_text(result.link_chain)
  local persist_path = session.file_path(result.name) or '-'

  local resolved_fg = result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  local resolved_bg = result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  local fg_text = render_util.display_color(resolved_fg)
  local bg_text = render_util.display_color(resolved_bg)
  local sp_text = render_util.display_color(result.sp)
  local attrs_text = highlights.bool_attrs(result)
  local blend = optional_finite_number(result.blend, 'detail info blend')
  local distance = optional_finite_number(result.distance, 'detail info distance')
  local blend_text = blend ~= nil and tostring(blend) or '-'
  local dist_text = distance ~= nil and ('%.1f'):format(distance) or '-'

  return {
    { { string.rep('─', math.max(20, width)), theme.groups.rule } },
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
    info_line('Style', attrs_text ~= '' and attrs_text or '-'),
    {
      label_token('Metrics'),
      { 'Blend ', theme.groups.muted },
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
