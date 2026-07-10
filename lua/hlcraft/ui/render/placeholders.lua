local M = {}

local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local core_fields = require('hlcraft.core.fields')
local input_sequence = require('hlcraft.ui.input.sequence')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local theme = require('hlcraft.ui.theme')
local ui_fields = require('hlcraft.ui.fields')
local window = require('hlcraft.ui.workspace.window')

local function get_detail_scene()
  return require('hlcraft.ui.scene.detail')
end

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('placeholder renderer requires an instance', 3)
  end
  return instance.state
end

local function instance_namespace(instance)
  return numbers.assert_non_negative_integer(instance.ns, 'placeholder namespace', 3)
end

local function placeholder_marks(state)
  if type(state.placeholder_marks) ~= 'table' then
    error('placeholder marks must be a table', 3)
  end
  return state.placeholder_marks
end

local function geometry_inputs(state)
  if type(state.geometry) ~= 'table' then
    error('placeholder geometry must be a table', 3)
  end
  return tables.assert_sequence(state.geometry.inputs, 'placeholder geometry inputs', 3)
end

local function positive_integer(value, label)
  return numbers.assert_positive_integer(value, label, 3)
end

local function extmark_id(value, label)
  if value == nil then
    return nil
  end
  return numbers.assert_positive_integer(value, label, 3)
end

local function detail_active(state)
  local index = state.detail_index
  if index == nil then
    return false
  end
  if not numbers.is_integer(index, 1) then
    error('placeholder detail index must be a positive finite integer or nil', 3)
  end
  return true
end

local function valid_buffer(state)
  return type(state.buf) == 'number' and window.is_valid_buf(state.buf)
end

local function set_overlay(state, ns, buf, key, row0, text, hl)
  local marks = placeholder_marks(state)
  marks[key] = vim.api.nvim_buf_set_extmark(buf, ns, row0, 0, {
    id = extmark_id(marks[key], 'placeholder extmark id'),
    virt_text = { { text, hl } },
    virt_text_pos = 'overlay',
    right_gravity = false,
  })
end

local function clear_overlay(state, ns, key)
  local marks = placeholder_marks(state)
  local mark_id = extmark_id(marks[key], 'placeholder extmark id')
  if not mark_id or not valid_buffer(state) then
    return
  end
  local deleted, err = pcall(vim.api.nvim_buf_del_extmark, state.buf, ns, mark_id)
  if not deleted then
    error(err, 0)
  end
  marks[key] = nil
end

local function detail_values(result)
  local resolved_fg = result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  local resolved_bg = result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  local values = {
    group = '',
    fg = resolved_fg or 'NONE',
    bg = resolved_bg or 'NONE',
    sp = result.sp or 'NONE',
    blend = result.blend ~= nil and tostring(result.blend) or '',
  }

  for _, key in ipairs(core_fields.style_keys) do
    values[key] = result[key] and 'true' or 'false'
  end

  return values
end

local function text_for_field(instance, state, field)
  local name = input_sequence.name(field)
  if name == 'name' then
    return ui_fields.search_placeholders.name
  end
  if name == 'color' then
    return ui_fields.search_placeholders.color
  end
  if not detail_active(state) then
    return nil
  end

  local result = get_detail_scene().current_result(instance)
  if not result then
    return nil
  end
  return detail_values(result)[name]
end

function M.refresh(instance)
  local state = instance_state(instance)
  if not valid_buffer(state) then
    return
  end

  local ns = instance_namespace(instance)
  placeholder_marks(state)
  for _, field in ipairs(geometry_inputs(state)) do
    local key = input_sequence.name(field)
    local line = positive_integer(field.line, 'placeholder field line')
    local text = text_for_field(instance, state, field)
    local value = buffer_fields.field_line_text(instance, field)
    if value == '' and text and text ~= '' then
      set_overlay(state, ns, state.buf, key, line - 1, tostring(text), theme.groups.muted)
    else
      clear_overlay(state, ns, key)
    end
  end
end

return M
