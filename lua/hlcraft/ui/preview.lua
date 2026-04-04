local results_state = require('hlcraft.ui.state.results')
local config = require('hlcraft.config')

local M = {}

local preview_fg = '#00e5ff'
local preview_bg = '#ff3b30'
local preview_timeout_ms = 500

local function snapshot_existing_keymap(lhs)
  local info = vim.fn.maparg(lhs, 'n', false, true)
  if type(info) ~= 'table' or vim.tbl_isempty(info) then
    return nil
  end

  return info
end

local function restore_keymap(map)
  if not map or not map.lhs then
    return
  end

  local opts = {
    silent = map.silent == 1,
    expr = map.expr == 1,
    noremap = map.noremap == 1,
    nowait = map.nowait == 1,
    script = map.script == 1,
    replace_keycodes = map.replace_keycodes == 1,
  }

  if map.desc and map.desc ~= '' then
    opts.desc = map.desc
  end

  if map.callback then
    vim.keymap.set('n', map.lhs, map.callback, opts)
    return
  end

  local rhs = map.rhs or ''
  vim.api.nvim_set_keymap('n', map.lhs, rhs, opts)
end

local function restore(instance)
  local preview = instance.state.preview
  if not preview or not preview.name or not preview.spec then
    return
  end

  pcall(vim.api.nvim_set_hl, 0, preview.name, vim.deepcopy(preview.spec))
  preview.name = nil
  preview.spec = nil
end

local function stop_timer(instance)
  local preview = instance.state.preview
  if not preview or not preview.timer then
    return
  end

  if preview.timer.stop then
    preview.timer:stop()
  end
  if preview.timer.close then
    pcall(function()
      preview.timer:close()
    end)
  end

  preview.timer = nil
end

local function current_result(instance)
  if instance.state.detail_index then
    return results_state.current_detail_result(instance)
  end

  local list_index = instance.state.list_cursor
  if list_index and instance.state.results[list_index] then
    return instance.state.results[list_index]
  end

  local entry = results_state.current_entry(instance)
  return entry and entry.result or nil
end

--- Flash the currently focused highlight group with a temporary high-contrast color.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.flash_current(instance)
  local result = current_result(instance)
  if not result or not result.name then
    return
  end

  local ok, spec = pcall(vim.api.nvim_get_hl, 0, { name = result.name, create = false })
  if not ok or not spec or vim.tbl_isempty(spec) then
    return
  end

  stop_timer(instance)
  restore(instance)

  instance.state.preview.name = result.name
  instance.state.preview.spec = vim.deepcopy(spec)

  pcall(vim.api.nvim_set_hl, 0, result.name, {
    fg = preview_fg,
    bg = preview_bg,
    bold = true,
  })

  local timer = vim.uv.new_timer()
  if not timer then
    restore(instance)
    return
  end

  instance.state.preview.timer = timer
  timer:start(
    preview_timeout_ms,
    0,
    vim.schedule_wrap(function()
      stop_timer(instance)
      restore(instance)
    end)
  )
end

--- Stop any pending preview timer and restore the original highlight immediately.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.cleanup(instance)
  stop_timer(instance)
  restore(instance)
end

--- Install the temporary global preview keymap for the workspace lifetime.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.install_keymap(instance)
  local lhs = config.config.preview_key
  if lhs == false or lhs == nil or lhs == '' then
    return
  end

  M.uninstall_keymap(instance)

  instance.state.preview.keymap = {
    lhs = lhs,
    previous = snapshot_existing_keymap(lhs),
  }

  vim.keymap.set('n', lhs, function()
    M.flash_current(instance)
  end, {
    silent = true,
    nowait = true,
    desc = 'hlcraft flash current highlight',
  })
end

--- Remove the temporary global preview keymap and restore any previous mapping.
--- @param instance table The Instance object holding UI state
--- @return nil
function M.uninstall_keymap(instance)
  local map = instance.state.preview.keymap
  if not map or not map.lhs then
    return
  end

  pcall(vim.keymap.del, 'n', map.lhs)
  restore_keymap(map.previous)
  instance.state.preview.keymap = nil
end

return M
