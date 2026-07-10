local config = require('hlcraft.config')
local effects = require('hlcraft.dynamic.effects')
local model = require('hlcraft.dynamic.model')
local notify = require('hlcraft.notify')
local numbers = require('hlcraft.core.number')
local tables = require('hlcraft.core.tables')
local timers = require('hlcraft.core.timers')

local M = {}

local next_preview_instance_id = 0

local function instance_state(instance)
  if type(instance) ~= 'table' or type(instance.state) ~= 'table' then
    error('dynamic preview requires an instance', 3)
  end
  return instance.state
end

local function preview_state(state)
  local preview = state.dynamic_preview
  if type(preview) ~= 'table' then
    error('dynamic preview state must be a table', 3)
  end
  if type(preview.marks) ~= 'table' then
    error('dynamic preview marks must be a table', 3)
  end
  preview.items = tables.assert_sequence(preview.items, 'dynamic preview items', 3)
  return preview
end

local function preview_namespace(instance)
  if type(instance.ns) ~= 'number' then
    error('dynamic preview namespace must be a number', 3)
  end
  if not numbers.is_integer(instance.ns, 0) then
    error('dynamic preview namespace must be a non-negative finite integer', 3)
  end
  return instance.ns
end

local function valid_buffer(state)
  return type(state.buf) == 'number' and vim.api.nvim_buf_is_valid(state.buf)
end

local function assert_time(now_ms)
  if not numbers.is_finite(now_ms) then
    error('dynamic preview time must be finite', 3)
  end
  return now_ms
end

local function is_non_negative_integer(value)
  return numbers.is_integer(value, 0)
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

local function is_tracked_preview_mark(state, ns, preview, item_id, mark_id)
  local item = preview.items[item_id]
  if not item then
    return false
  end
  local expected_hl = expected_hl_name(preview, item_id)
  if not expected_hl then
    return false
  end
  local ok, mark = pcall(vim.api.nvim_buf_get_extmark_by_id, state.buf, ns, mark_id, {
    details = true,
  })
  if not ok or #mark == 0 then
    return false
  end

  local virt_text = mark[3] and mark[3].virt_text or nil
  local chunk = virt_text and virt_text[1] or nil
  return chunk and chunk[1] == item.text and chunk[2] == expected_hl
end

local function clear_preview_marks(state, ns, preview)
  local remaining = {}
  for item_id, mark_id in pairs(preview.marks) do
    item_id = numbers.assert_positive_integer(item_id, 'dynamic preview item id', 3)
    mark_id = numbers.assert_positive_integer(mark_id, 'dynamic preview mark id', 3)
    if is_tracked_preview_mark(state, ns, preview, item_id, mark_id) then
      local ok, deleted = pcall(vim.api.nvim_buf_del_extmark, state.buf, ns, mark_id)
      if (not ok or deleted == false) and is_tracked_preview_mark(state, ns, preview, item_id, mark_id) then
        remaining[item_id] = mark_id
      end
    end
  end
  for item_id in pairs(preview.marks) do
    preview.marks[item_id] = nil
  end
  for item_id, mark_id in pairs(remaining) do
    preview.marks[item_id] = mark_id
  end
  return next(remaining) == nil
end

local function clear_inactive_preview_marks(state, ns, preview, active_items)
  local remaining = {}
  for item_id, mark_id in pairs(preview.marks) do
    item_id = numbers.assert_positive_integer(item_id, 'dynamic preview item id', 3)
    mark_id = numbers.assert_positive_integer(mark_id, 'dynamic preview mark id', 3)
    if active_items[item_id] then
      remaining[item_id] = mark_id
    elseif is_tracked_preview_mark(state, ns, preview, item_id, mark_id) then
      local ok, deleted = pcall(vim.api.nvim_buf_del_extmark, state.buf, ns, mark_id)
      if (not ok or deleted == false) and is_tracked_preview_mark(state, ns, preview, item_id, mark_id) then
        remaining[item_id] = mark_id
      end
    end
  end
  for item_id in pairs(preview.marks) do
    preview.marks[item_id] = nil
  end
  for item_id, mark_id in pairs(remaining) do
    preview.marks[item_id] = mark_id
  end
  for item_id in pairs(remaining) do
    if not active_items[item_id] then
      return false
    end
  end
  return true
end

local function reset_preview_marks(instance, state, preview)
  if valid_buffer(state) then
    return clear_preview_marks(state, preview_namespace(instance), preview)
  end
  preview.marks = {}
  return true
end

local function set_preview_hl(ns, preview, item, now_ms)
  local value = effects.compute(item.dynamic, item.base, item.now_ms or now_ms, item.context)
  if not value then
    return nil
  end
  local hl_name = ('HlcraftDynamicPreview_%s_%d'):format(instance_preview_key(preview), item.id)
  vim.api.nvim_set_hl(ns, hl_name, { fg = value })
  return hl_name
end

local function set_preview_mark(state, ns, item, hl_name, previous_mark_id)
  local opts = {
    end_col = item.col_end,
    virt_text = { { item.text, hl_name } },
    virt_text_pos = 'overlay',
    hl_mode = 'replace',
  }
  if previous_mark_id ~= nil then
    opts.id = numbers.assert_positive_integer(previous_mark_id, 'dynamic preview mark id', 3)
  end
  local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, state.buf, ns, item.line - 1, item.col_start, opts)
  if not ok then
    return nil
  end
  return mark_id
end

local function run_timer_tick(instance, state, preview)
  local ok, err = xpcall(function()
    if state.dynamic_preview ~= preview then
      close_timer(preview)
      return
    end
    if not valid_buffer(state) or next(preview.items) == nil then
      close_timer(preview)
      return
    end
    M.tick(instance, vim.uv.hrtime() / 1000000)
  end, debug.traceback)
  if not ok then
    local message = ('dynamic preview timer failed: %s'):format(tostring(err))
    local closed, close_err = pcall(close_timer, preview)
    if not closed then
      message = ('%s; timer cleanup failed: %s'):format(message, tostring(close_err))
    end
    notify.warn(message)
  end
end

local function normalize_context(context)
  if context == nil then
    return nil
  end
  if type(context) ~= 'table' then
    return nil
  end

  local normalized = {}
  for _, key in ipairs(model.channels) do
    normalized[key] = context[key]
  end
  return normalized
end

local function normalize_item(item, dynamic)
  if type(item) ~= 'table' or type(item.text) ~= 'string' or item.text == '' then
    return nil
  end
  if not numbers.is_integer(item.line, 1) then
    return nil
  end
  if not is_non_negative_integer(item.col_start) then
    return nil
  end
  if not is_non_negative_integer(item.col_end) or item.col_end <= item.col_start then
    return nil
  end
  if item.now_ms ~= nil and (type(item.now_ms) ~= 'number' or not numbers.is_finite(item.now_ms)) then
    return nil
  end
  local context = normalize_context(item.context)
  if item.context ~= nil and not context then
    return nil
  end

  return {
    line = item.line,
    col_start = item.col_start,
    col_end = item.col_end,
    text = item.text,
    base = item.base,
    dynamic = dynamic,
    now_ms = item.now_ms,
    context = context,
  }
end

function M.register(instance, item)
  local state = instance_state(instance)
  local preview = preview_state(state)
  if not valid_buffer(state) then
    return nil
  end
  preview_namespace(instance)
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

function M.begin_render(instance)
  local state = instance_state(instance)
  local preview = preview_state(state)
  preview_namespace(instance)
  local snapshot = {
    items = preview.items,
    marks = preview.marks,
  }
  preview.items = {}
  preview.marks = {}
  return snapshot
end

function M.rollback_render(instance, snapshot)
  if type(snapshot) ~= 'table' then
    error('dynamic preview render snapshot must be a table', 2)
  end
  if type(snapshot.items) ~= 'table' or type(snapshot.marks) ~= 'table' then
    error('dynamic preview render snapshot is invalid', 2)
  end
  local state = instance_state(instance)
  local preview = preview_state(state)
  preview.items = snapshot.items
  preview.marks = snapshot.marks
end

function M.restore_render(instance, snapshot)
  local ok, err = xpcall(function()
    M.rollback_render(instance, snapshot)
    M.tick(instance, vim.uv.hrtime() / 1000000)
  end, debug.traceback)
  if not ok then
    return false, err
  end
  return true, nil
end

function M.tick(instance, now_ms)
  local state = instance_state(instance)
  local preview = preview_state(state)
  now_ms = assert_time(now_ms)
  if not valid_buffer(state) then
    return
  end
  local ns = preview_namespace(instance)
  local active_items = {}
  for _, item in ipairs(preview.items) do
    active_items[item.id] = true
  end
  if not clear_inactive_preview_marks(state, ns, preview, active_items) then
    return
  end
  for _, item in ipairs(preview.items) do
    local hl_name = set_preview_hl(ns, preview, item, now_ms)
    local previous_mark_id = preview.marks[item.id]
    if hl_name then
      local mark_id = set_preview_mark(state, ns, item, hl_name, previous_mark_id)
      if mark_id then
        preview.marks[item.id] = mark_id
      elseif previous_mark_id == nil or not is_tracked_preview_mark(state, ns, preview, item.id, previous_mark_id) then
        preview.marks[item.id] = nil
      end
    end
  end
end

function M.reset_marks(instance)
  local state = instance_state(instance)
  local preview = preview_state(state)
  reset_preview_marks(instance, state, preview)
end

function M.sync(instance)
  local state = instance_state(instance)
  local preview = preview_state(state)
  if not valid_buffer(state) then
    close_timer(preview)
    return true
  end
  if next(preview.items) == nil then
    close_timer(preview)
    return true
  end
  preview_namespace(instance)
  if preview.timer then
    return true
  end
  local interval = config.config.dynamic.interval_ms
  local timer = timers.repeating(interval, function()
    vim.schedule(function()
      run_timer_tick(instance, state, preview)
    end)
  end)
  if not timer then
    notify.warn('dynamic preview timer failed to start')
    return false
  end
  preview.timer = timer
  return true
end

function M.clear(instance)
  local state = instance_state(instance)
  local preview = preview_state(state)
  if reset_preview_marks(instance, state, preview) then
    preview.items = {}
  end
  close_timer(preview)
end

return M
