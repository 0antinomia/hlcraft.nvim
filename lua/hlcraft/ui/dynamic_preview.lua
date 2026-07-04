local config = require('hlcraft.config')
local effects = require('hlcraft.dynamic.effects')
local model = require('hlcraft.dynamic.model')
local numbers = require('hlcraft.core.number')
local timers = require('hlcraft.core.timers')

local M = {}

local next_preview_instance_id = 0

local function preview_state(instance)
  if not instance or not instance.state then
    error('dynamic preview requires an instance', 3)
  end
  local preview = instance.state.dynamic_preview
  if type(preview) ~= 'table' then
    error('dynamic preview state must be a table', 3)
  end
  if type(preview.marks) ~= 'table' then
    error('dynamic preview marks must be a table', 3)
  end
  if type(preview.items) ~= 'table' then
    error('dynamic preview items must be a table', 3)
  end
  return preview
end

local function valid_buffer(instance)
  return instance.state.buf and vim.api.nvim_buf_is_valid(instance.state.buf)
end

local function instance_preview_key(preview)
  if not preview.instance_id then
    next_preview_instance_id = next_preview_instance_id + 1
    preview.instance_id = next_preview_instance_id
  end

  return tostring(preview.instance_id)
end

local function close_timer(preview)
  timers.stop(preview.timer)
  preview.timer = nil
end

local function expected_hl_name(preview, item_id)
  if not preview.instance_id then
    return nil
  end
  return ('HlcraftDynamicPreview_%s_%d'):format(tostring(preview.instance_id), item_id)
end

local function is_tracked_preview_mark(instance, preview, item_id, mark_id)
  local item = preview.items[item_id]
  if not item then
    return false
  end
  local expected_hl = expected_hl_name(preview, item_id)
  if not expected_hl then
    return false
  end
  local ok, mark = pcall(vim.api.nvim_buf_get_extmark_by_id, instance.state.buf, instance.ns, mark_id, {
    details = true,
  })
  if not ok or #mark == 0 then
    return false
  end

  local virt_text = mark[3] and mark[3].virt_text or nil
  local chunk = virt_text and virt_text[1] or nil
  return chunk and chunk[1] == item.text and chunk[2] == expected_hl
end

local function clear_preview_marks(instance, preview)
  for item_id, mark_id in pairs(preview.marks) do
    if is_tracked_preview_mark(instance, preview, item_id, mark_id) then
      pcall(vim.api.nvim_buf_del_extmark, instance.state.buf, instance.ns, mark_id)
    end
  end
  preview.marks = {}
end

local function set_preview_hl(instance, preview, item, now_ms)
  local value = effects.compute(item.dynamic, item.base, item.now_ms or now_ms)
  if not value then
    return nil
  end
  local hl_name = ('HlcraftDynamicPreview_%s_%d'):format(instance_preview_key(preview), item.id)
  vim.api.nvim_set_hl(instance.ns, hl_name, { fg = value })
  return hl_name
end

local function set_preview_mark(instance, item, hl_name)
  local ok, mark_id =
    pcall(vim.api.nvim_buf_set_extmark, instance.state.buf, instance.ns, item.line - 1, item.col_start, {
      end_col = item.col_end,
      virt_text = { { item.text, hl_name } },
      virt_text_pos = 'overlay',
      hl_mode = 'replace',
    })
  if not ok then
    return nil
  end
  return mark_id
end

local function normalize_item(item, dynamic)
  if type(item) ~= 'table' or type(item.text) ~= 'string' or item.text == '' then
    return nil
  end
  if
    type(item.line) ~= 'number'
    or not numbers.is_finite(item.line)
    or item.line < 1
    or math.floor(item.line) ~= item.line
  then
    return nil
  end
  if type(item.col_start) ~= 'number' or not numbers.is_finite(item.col_start) or item.col_start < 0 then
    return nil
  end
  if type(item.col_end) ~= 'number' or not numbers.is_finite(item.col_end) or item.col_end <= item.col_start then
    return nil
  end
  if item.now_ms ~= nil and (type(item.now_ms) ~= 'number' or not numbers.is_finite(item.now_ms)) then
    return nil
  end

  local normalized = vim.deepcopy(item)
  normalized.dynamic = dynamic
  return normalized
end

function M.register(instance, item)
  local preview = preview_state(instance)
  if not valid_buffer(instance) then
    return nil
  end
  local dynamic = model.normalize_channel(item and item.dynamic)
  if not dynamic then
    return nil
  end
  local next_item = normalize_item(item, dynamic)
  if not next_item then
    return nil
  end
  local id = #preview.items + 1
  next_item.id = id
  preview.items[id] = next_item
  return id
end

function M.tick(instance, now_ms)
  local preview = preview_state(instance)
  if not valid_buffer(instance) then
    return
  end
  clear_preview_marks(instance, preview)
  for _, item in pairs(preview.items) do
    local hl_name = set_preview_hl(instance, preview, item, now_ms)
    if hl_name then
      preview.marks[item.id] = set_preview_mark(instance, item, hl_name)
    end
  end
end

function M.reset_items(instance)
  preview_state(instance).items = {}
end

function M.reset_marks(instance)
  preview_state(instance).marks = {}
end

function M.sync(instance)
  local preview = preview_state(instance)
  if not valid_buffer(instance) then
    close_timer(preview)
    return
  end
  if next(preview.items) == nil then
    close_timer(preview)
    return
  end
  if preview.timer then
    return
  end
  local interval = config.config.dynamic.interval_ms
  preview.timer = timers.repeating(interval, function()
    vim.schedule(function()
      if not valid_buffer(instance) or next(preview.items) == nil then
        close_timer(preview)
        return
      end
      M.tick(instance, vim.uv.hrtime() / 1000000)
    end)
  end)
end

function M.clear(instance)
  local preview = preview_state(instance)
  if valid_buffer(instance) then
    clear_preview_marks(instance, preview)
  else
    preview.marks = {}
  end
  preview.items = {}
  close_timer(preview)
end

return M
