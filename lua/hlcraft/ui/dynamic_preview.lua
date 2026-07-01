local config = require('hlcraft.config')
local effects = require('hlcraft.dynamic.effects')

local M = {}

local next_preview_instance_id = 0

local function valid_buffer(instance)
  return instance and instance.state and instance.state.buf and vim.api.nvim_buf_is_valid(instance.state.buf)
end

local function ensure_state(instance)
  instance.state.dynamic_preview_marks = instance.state.dynamic_preview_marks or {}
  instance.state.dynamic_preview_items = instance.state.dynamic_preview_items or {}
end

local function instance_preview_key(instance)
  if not instance.state.dynamic_preview_instance_id then
    next_preview_instance_id = next_preview_instance_id + 1
    instance.state.dynamic_preview_instance_id = next_preview_instance_id
  end

  return tostring(instance.state.dynamic_preview_instance_id)
end

local function close_timer(instance)
  local timer = instance and instance.state and instance.state.dynamic_preview_timer or nil
  if not timer then
    return
  end
  pcall(function()
    timer:stop()
  end)
  pcall(function()
    timer:close()
  end)
  instance.state.dynamic_preview_timer = nil
end

local function expected_hl_name(instance, item_id)
  local key = instance.state.dynamic_preview_instance_id
  if not key then
    return nil
  end
  return ('HlcraftDynamicPreview_%s_%d'):format(tostring(key), item_id)
end

local function is_tracked_preview_mark(instance, item_id, mark_id)
  local item = instance.state.dynamic_preview_items and instance.state.dynamic_preview_items[item_id] or nil
  if not item then
    return false
  end
  local expected_hl = expected_hl_name(instance, item_id)
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

local function clear_preview_marks(instance)
  ensure_state(instance)
  for item_id, mark_id in pairs(instance.state.dynamic_preview_marks) do
    if is_tracked_preview_mark(instance, item_id, mark_id) then
      pcall(vim.api.nvim_buf_del_extmark, instance.state.buf, instance.ns, mark_id)
    end
  end
  instance.state.dynamic_preview_marks = {}
end

local function set_preview_hl(instance, item, now_ms)
  local value = effects.compute(item.dynamic, item.base, item.now_ms or now_ms)
  if not value then
    return nil
  end
  local hl_name = ('HlcraftDynamicPreview_%s_%d'):format(instance_preview_key(instance), item.id)
  vim.api.nvim_set_hl(instance.ns, hl_name, { fg = value })
  return hl_name
end

local function set_preview_mark(instance, item, hl_name)
  local line = tonumber(item.line)
  if not line or line < 1 then
    return nil
  end

  local ok, mark_id =
    pcall(vim.api.nvim_buf_set_extmark, instance.state.buf, instance.ns, line - 1, item.col_start or 0, {
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

function M.register(instance, item)
  if not valid_buffer(instance) then
    return nil
  end
  ensure_state(instance)
  local id = #instance.state.dynamic_preview_items + 1
  local next_item = vim.deepcopy(item)
  next_item.id = id
  instance.state.dynamic_preview_items[id] = next_item
  return id
end

function M.tick(instance, now_ms)
  if not valid_buffer(instance) then
    return
  end
  ensure_state(instance)
  clear_preview_marks(instance)
  for _, item in pairs(instance.state.dynamic_preview_items) do
    local hl_name = set_preview_hl(instance, item, now_ms)
    if hl_name then
      instance.state.dynamic_preview_marks[item.id] = set_preview_mark(instance, item, hl_name)
    end
  end
end

function M.reset_marks(instance)
  if instance and instance.state then
    instance.state.dynamic_preview_marks = {}
  end
end

function M.sync(instance)
  if not valid_buffer(instance) then
    close_timer(instance)
    return
  end
  ensure_state(instance)
  if next(instance.state.dynamic_preview_items) == nil then
    close_timer(instance)
    return
  end
  if instance.state.dynamic_preview_timer then
    return
  end
  local ok, new_timer = pcall(vim.uv.new_timer)
  if not ok or not new_timer then
    return
  end
  local interval = config.config.dynamic.interval_ms
  local started = pcall(function()
    new_timer:start(interval, interval, function()
      vim.schedule(function()
        if not valid_buffer(instance) or next(instance.state.dynamic_preview_items) == nil then
          close_timer(instance)
          return
        end
        M.tick(instance, vim.uv.hrtime() / 1000000)
      end)
    end)
  end)
  if not started then
    pcall(function()
      new_timer:close()
    end)
    return
  end
  instance.state.dynamic_preview_timer = new_timer
end

function M.clear(instance)
  if instance and instance.state then
    if valid_buffer(instance) then
      clear_preview_marks(instance)
    else
      instance.state.dynamic_preview_marks = {}
    end
    instance.state.dynamic_preview_items = {}
  end
  close_timer(instance)
end

return M
