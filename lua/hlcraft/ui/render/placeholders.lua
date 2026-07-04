local M = {}

local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local theme = require('hlcraft.ui.theme')
local ui_fields = require('hlcraft.ui.fields')
local window = require('hlcraft.ui.workspace.window')

local function get_detail_scene()
  return require('hlcraft.ui.scene.detail')
end

local function set_overlay(instance, buf, key, row0, text, hl)
  instance.state.placeholder_marks[key] = vim.api.nvim_buf_set_extmark(buf, instance.ns, row0, 0, {
    id = instance.state.placeholder_marks[key],
    virt_text = { { text, hl } },
    virt_text_pos = 'overlay',
    right_gravity = false,
  })
end

local function clear_overlay(instance, key)
  local mark_id = instance.state.placeholder_marks[key]
  if not mark_id or not window.is_valid_buf(instance.state.buf) then
    return
  end
  pcall(vim.api.nvim_buf_del_extmark, instance.state.buf, instance.ns, mark_id)
  instance.state.placeholder_marks[key] = nil
end

local function detail_values(result)
  local resolved_fg = result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  local resolved_bg = result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  return {
    group = '',
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

local function text_for_field(instance, field)
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

  local result = get_detail_scene().current_result(instance)
  if not result then
    return nil
  end
  return detail_values(result)[name]
end

function M.refresh(instance)
  if not window.is_valid_buf(instance.state.buf) then
    return
  end

  for _, field in ipairs(instance.state.geometry.inputs or {}) do
    local key = field.key or field.name
    local text = text_for_field(instance, field)
    local value = buffer_fields.field_line_text(instance, field)
    if value == '' and text and text ~= '' then
      set_overlay(instance, instance.state.buf, key, field.line - 1, tostring(text), theme.groups.muted)
    else
      clear_overlay(instance, key)
    end
  end
end

return M
